package io.niemo.evernoise;

import java.nio.ByteBuffer;

final class NativeAudio {
  static {
    System.loadLibrary("evernoise");
  }

  static native long create(long seed);

  static native void destroy(long handle);

  static native void configure(
      long handle, int low, int mid, int high, boolean stereo, int offset, boolean capture);

  static native void play(long handle, boolean playing);

  static native void fadeIn(long handle);

  static native boolean silent(long handle);

  static native long frames(long handle);

  static native void render(long handle, ByteBuffer pcm, int frames);

  static native long createAnalyzer();

  static native void destroyAnalyzer(long handle);

  static native int analyze(long handle, long analyzer, ByteBuffer columns);
}
