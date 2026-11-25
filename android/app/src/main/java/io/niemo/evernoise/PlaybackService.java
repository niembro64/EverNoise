package io.niemo.evernoise;

import android.app.*;
import android.content.*;
import android.media.*;
import android.media.session.*;
import android.os.*;
import java.io.*;

public final class PlaybackService extends Service {
  static final String PLAY = "io.niemo.evernoise.PLAY",
      PAUSE = "io.niemo.evernoise.PAUSE",
      TOGGLE = "io.niemo.evernoise.TOGGLE";
  static volatile boolean playing = false;

  final class LocalBinder extends Binder {
    PlaybackService service() {
      return PlaybackService.this;
    }
  }

  private final LocalBinder binder = new LocalBinder();
  private AudioEngine engine;
  private AudioManager manager;
  private AudioFocusRequest focus;
  private MediaSession session;
  private PowerManager.WakeLock wake;
  private boolean foreground, resumeOnFocus, visible;
  private String error;
  private Preferences preferences;
  private Runnable observer;
  private int generation;
  private final BroadcastReceiver noisy =
      new BroadcastReceiver() {
        public void onReceive(Context c, Intent i) {
          pause();
        }
      };

  @Override
  public void onCreate() {
    super.onCreate();
    preferences = Preferences.load(this);
    manager = getSystemService(AudioManager.class);
    NotificationChannel channel =
        new NotificationChannel("playback", "Noise playback", NotificationManager.IMPORTANCE_LOW);
    channel.setSound(null, null);
    channel.setShowBadge(false);
    getSystemService(NotificationManager.class).createNotificationChannel(channel);
    wake =
        getSystemService(PowerManager.class)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "EverNoise:playback");
    wake.setReferenceCounted(false);
    focus =
        new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build())
            .setWillPauseWhenDucked(true)
            .setOnAudioFocusChangeListener(this::focusChanged, new Handler(Looper.getMainLooper()))
            .build();
    session = new MediaSession(this, "EverNoise");
    session.setCallback(
        new MediaSession.Callback() {
          public void onPlay() {
            play();
          }

          public void onPause() {
            pause();
          }

          public void onStop() {
            pause();
          }
        });
    session.setMetadata(
        new MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, "EverNoise")
            .putString(MediaMetadata.METADATA_KEY_ARTIST, "Your sound. All night.")
            .build());
    session.setSessionActivity(
        PendingIntent.getActivity(
            this,
            0,
            new Intent(this, MainActivity.class),
            PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
    session.setActive(true);
    if (Build.VERSION.SDK_INT >= 33)
      registerReceiver(
          noisy,
          new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
          Context.RECEIVER_NOT_EXPORTED);
    else registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    makeEngine();
    update();
  }

  private void makeEngine() {
    int current = ++generation;
    engine =
        new AudioEngine(
            preferences,
            (on, message) -> {
              if (current != generation) return;
              playing = on;
              error = message;
              if (!on && wake.isHeld()) wake.release();
              if (!on && !resumeOnFocus) {
                stopForeground(STOP_FOREGROUND_DETACH);
                foreground = false;
              }
              update();
            });
    engine.configure(preferences, visible);
  }

  @Override
  public IBinder onBind(Intent i) {
    return binder;
  }

  @Override
  public int onStartCommand(Intent i, int flags, int startId) {
    startForeground(1, notification());
    foreground = true;
    String a = i == null ? PAUSE : i.getAction();
    if (PLAY.equals(a)) play();
    else if (TOGGLE.equals(a)) {
      if (engine.requested()) pause();
      else play();
    } else pause();
    return START_NOT_STICKY;
  }

  void play() {
    if (engine.requested()) return;
    if (!foreground) {
      startForeground(1, notification());
      foreground = true;
    }
    if (manager.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
      error = "Another app is using audio. Tap Play to try again.";
      stopForeground(STOP_FOREGROUND_DETACH);
      foreground = false;
      update();
      return;
    }
    if (error != null) {
      engine.close();
      makeEngine();
    }
    error = null;
    resumeOnFocus = false;
    if (!wake.isHeld()) wake.acquire();
    engine.play(true);
    update();
  }

  void pause() {
    resumeOnFocus = false;
    engine.play(false);
    manager.abandonAudioFocusRequest(focus);
    if (!playing) {
      stopForeground(STOP_FOREGROUND_DETACH);
      foreground = false;
      if (wake.isHeld()) wake.release();
    }
    update();
  }

  private void focusChanged(int change) {
    if (change == AudioManager.AUDIOFOCUS_GAIN) {
      if (resumeOnFocus) {
        resumeOnFocus = false;
        if (!wake.isHeld()) wake.acquire();
        engine.play(true);
      }
    } else if (change == AudioManager.AUDIOFOCUS_LOSS) {
      pause();
    } else {
      resumeOnFocus = engine.requested();
      engine.play(false);
    }
    update();
  }

  Preferences preferences() {
    return preferences;
  }

  void observe(Runnable callback) {
    observer = callback;
  }

  void configure(Preferences p) {
    preferences = p;
    p.save(this);
    engine.configure(p, visible);
    update();
  }

  void visible(boolean value) {
    visible = value;
    engine.configure(preferences, value);
  }

  String status() {
    return error != null
        ? error
        : resumeOnFocus
            ? "Audio interrupted"
            : playing ? preferences.audible() ? "Playing continuously" : "All bands off" : "Paused";
  }

  long frames() {
    return engine.frames();
  }

  int underruns() {
    return engine.underruns();
  }

  float[] column() {
    return engine.column();
  }

  private PendingIntent command(String action) {
    return PendingIntent.getForegroundService(
        this,
        action.hashCode(),
        new Intent(this, PlaybackService.class).setAction(action),
        PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }

  private Notification notification() {
    return new Notification.Builder(this, "playback")
        .setSmallIcon(R.drawable.ic_noise)
        .setContentTitle("EverNoise")
        .setContentText(status())
        .setContentIntent(
            PendingIntent.getActivity(
                this,
                0,
                new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT))
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .setOnlyAlertOnce(true)
        .setOngoing(playing)
        .setCategory(Notification.CATEGORY_TRANSPORT)
        .addAction(
            new Notification.Action.Builder(
                    playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
                    playing ? "Pause" : "Play",
                    command(playing ? PAUSE : PLAY))
                .build())
        .setStyle(
            new Notification.MediaStyle()
                .setMediaSession(session.getSessionToken())
                .setShowActionsInCompactView(0))
        .build();
  }

  private void update() {
    if (session == null) return;
    session.setPlaybackState(
        new PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY
                    | PlaybackState.ACTION_PAUSE
                    | PlaybackState.ACTION_PLAY_PAUSE
                    | PlaybackState.ACTION_STOP)
            .setState(
                playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                playing ? 1 : 0)
            .build());
    getSystemService(NotificationManager.class).notify(1, notification());
    NoiseWidget.updateAll(this);
    android.service.quicksettings.TileService.requestListeningState(
        this, new ComponentName(this, NoiseTile.class));
    if (observer != null) observer.run();
  }

  @Override
  public void onDestroy() {
    generation++;
    playing = false;
    engine.close();
    manager.abandonAudioFocusRequest(focus);
    session.release();
    unregisterReceiver(noisy);
    if (wake.isHeld()) wake.release();
    NoiseWidget.updateAll(this);
    super.onDestroy();
  }

  @Override
  protected void dump(FileDescriptor fd, PrintWriter w, String[] args) {
    w.println(
        "EverNoise state="
            + status()
            + " frames="
            + frames()
            + " underruns="
            + underruns()
            + " visuals="
            + preferences.visuals);
  }

  static void send(Context c, String action) {
    c.startForegroundService(new Intent(c, PlaybackService.class).setAction(action));
  }
}
