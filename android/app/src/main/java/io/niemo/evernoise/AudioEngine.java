package io.niemo.evernoise;

import android.media.*;
import android.os.*;
import android.os.Process;
import java.nio.*;
import java.security.SecureRandom;
import java.util.concurrent.atomic.AtomicReference;

/** One owner thread for the generator and AudioTrack. Analysis never blocks it. */
final class AudioEngine {
  interface Listener {
    void running(boolean running, String error);
  }

  private final Object gate = new Object();
  private final Handler main = new Handler(Looper.getMainLooper());
  private final Listener listener;
  private volatile Preferences preferences;
  private volatile boolean requested, closed, capture;
  private volatile long renderedFrames;
  private volatile int underruns;
  private final AtomicReference<float[]> latestColumn = new AtomicReference<>();

  AudioEngine(Preferences p, Listener l) {
    preferences = p;
    listener = l;
    new Thread(this::run, "EverNoise audio").start();
  }

  void configure(Preferences p, boolean visible) {
    preferences = p;
    capture = visible && p.visuals == 4;
    synchronized (gate) {
      gate.notifyAll();
    }
  }

  void play(boolean value) {
    requested = value;
    synchronized (gate) {
      gate.notifyAll();
    }
  }

  boolean requested() {
    return requested;
  }

  long frames() {
    return renderedFrames;
  }

  int underruns() {
    return underruns;
  }

  float[] column() {
    return latestColumn.getAndSet(null);
  }

  void close() {
    closed = true;
    play(false);
  }

  private void report(boolean on, String error) {
    main.post(() -> listener.running(on, error));
  }

  private AudioTrack makeTrack() {
    int min =
        AudioTrack.getMinBufferSize(
            48000, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_FLOAT);
    if (min <= 0) throw new IllegalStateException("This output does not support 48 kHz audio.");
    AudioTrack t =
        new AudioTrack.Builder()
            .setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build())
            .setAudioFormat(
                new AudioFormat.Builder()
                    .setSampleRate(48000)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build())
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(Math.max(min * 4, 96000))
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_POWER_SAVING)
            .build();
    if (t.getState() != AudioTrack.STATE_INITIALIZED) {
      t.release();
      throw new IllegalStateException("The audio output is unavailable.");
    }
    return t;
  }

  private static final class Disconnected extends Exception {}

  private void write(AudioTrack track, ByteBuffer pcm) throws Disconnected {
    pcm.position(0);
    pcm.limit(8192);
    while (pcm.hasRemaining() && !closed) {
      int n = track.write(pcm, pcm.remaining(), AudioTrack.WRITE_BLOCKING);
      if (n == AudioTrack.ERROR_DEAD_OBJECT) throw new Disconnected();
      if (n <= 0) throw new IllegalStateException("Audio output disconnected. Tap Play to retry.");
    }
  }

  private void run() {
    Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);
    long handle = NativeAudio.create(new SecureRandom().nextLong());
    if (handle == 0) {
      report(false, "Could not initialize audio.");
      return;
    }
    ByteBuffer pcm = ByteBuffer.allocateDirect(8192).order(ByteOrder.nativeOrder());
    Thread analysis = new Thread(() -> analyze(handle), "EverNoise spectrum");
    analysis.start();
    AudioTrack track = null;
    boolean active = false;
    int recoveries = 0, successfulBlocks = 0;
    Preferences applied = null;
    boolean appliedCapture = false;
    try {
      while (!closed) {
        Preferences p = preferences;
        boolean c = capture && requested;
        if (p != applied || c != appliedCapture) {
          NativeAudio.configure(handle, p.low, p.mid, p.high, p.stereo, p.offset, c);
          applied = p;
          appliedCapture = c;
        }
        if (!requested && !active) {
          synchronized (gate) {
            if (!requested && !closed) gate.wait();
          }
          continue;
        }
        try {
          if (requested && !active) {
            track = makeTrack();
            NativeAudio.fadeIn(handle);
            active = true;
            // Queue a full buffer before play. A smaller queue cannot satisfy
            // AudioTrack's start threshold on every route.
            int blocks = Math.max(1, track.getBufferSizeInFrames() / 1024);
            for (int i = 0; i < blocks && !closed; i++) {
              NativeAudio.render(handle, pcm, 1024);
              write(track, pcm);
            }
            track.play();
            report(true, null);
          }
          NativeAudio.play(handle, requested);
          NativeAudio.render(handle, pcm, 1024);
          write(track, pcm);
          renderedFrames = NativeAudio.frames(handle);
          underruns = track.getUnderrunCount();
          if (++successfulBlocks >= 480) {
            recoveries = 0;
            successfulBlocks = 0;
          }
          if (!requested && NativeAudio.silent(handle)) {
            track.stop();
            track.release();
            track = null;
            active = false;
            report(false, null);
          }
        } catch (Disconnected e) {
          // A route/audio-server reset invalidates the output, not the generator.
          // Recreate only the device, preserve PRNG/filter state, and fade in.
          track.release();
          track = null;
          active = false;
          successfulBlocks = 0;
          if (++recoveries > 3)
            throw new IllegalStateException("Audio output unavailable. Tap Play to retry.");
          if (!requested) report(false, null);
        }
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    } catch (Exception e) {
      requested = false;
      report(false, e.getMessage());
    } finally {
      closed = true;
      synchronized (gate) {
        gate.notifyAll();
      }
      if (track != null) {
        try {
          track.stop();
        } catch (Exception ignored) {
        }
        track.release();
      }
      try {
        analysis.join();
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
      }
      NativeAudio.destroy(handle);
    }
  }

  private void analyze(long handle) {
    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
    long analyzer = 0;
    ByteBuffer out = ByteBuffer.allocateDirect(4 * 1024 * 4).order(ByteOrder.nativeOrder());
    try {
      while (!closed) {
        if (!capture || !requested) {
          if (analyzer != 0) {
            NativeAudio.destroyAnalyzer(analyzer);
            analyzer = 0;
          }
          latestColumn.set(null);
          synchronized (gate) {
            while (!closed && (!capture || !requested)) gate.wait();
          }
          continue;
        }
        if (analyzer == 0) {
          analyzer = NativeAudio.createAnalyzer();
          if (analyzer == 0) return;
        }
        int count = NativeAudio.analyze(handle, analyzer, out);
        if (count > 0) {
          float[] column = new float[1024];
          out.position((count - 1) * 4096);
          out.asFloatBuffer().get(column);
          latestColumn.set(column);
        } else Thread.sleep(8);
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    } finally {
      if (analyzer != 0) NativeAudio.destroyAnalyzer(analyzer);
    }
  }
}
