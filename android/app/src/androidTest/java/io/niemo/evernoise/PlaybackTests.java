package io.niemo.evernoise;

import android.content.*;
import android.media.*;
import android.media.session.*;
import android.os.*;
import android.test.ActivityInstrumentationTestCase2;
import java.nio.*;
import java.util.concurrent.*;

/** Device tests exercise real AudioTrack/foreground service, not a mock renderer. */
@SuppressWarnings("deprecation")
public final class PlaybackTests extends ActivityInstrumentationTestCase2<MainActivity> {
  public PlaybackTests() {
    super(MainActivity.class);
  }

  private PlaybackService service;
  private ServiceConnection connection;

  private void connect() throws Exception {
    MainActivity activity = getActivity();
    CountDownLatch connected = new CountDownLatch(1);
    connection =
        new ServiceConnection() {
          public void onServiceConnected(ComponentName n, IBinder b) {
            service = ((PlaybackService.LocalBinder) b).service();
            connected.countDown();
          }

          public void onServiceDisconnected(ComponentName n) {
            service = null;
          }
        };
    activity.bindService(
        new Intent(activity, PlaybackService.class), connection, Context.BIND_AUTO_CREATE);
    assertTrue("Service bound", connected.await(10, TimeUnit.SECONDS));
    long deadline = SystemClock.elapsedRealtime() + 10000;
    while (!PlaybackService.playing && SystemClock.elapsedRealtime() < deadline) Thread.sleep(40);
    assertTrue("Auto-start", PlaybackService.playing);
  }

  private void main(Runnable r) {
    getInstrumentation().runOnMainSync(r);
  }

  public void test01NativePcmAndFades() {
    long a = NativeAudio.create(12345), b = NativeAudio.create(12345);
    assertTrue(a != 0 && b != 0);
    ByteBuffer x = ByteBuffer.allocateDirect(8192).order(ByteOrder.nativeOrder()),
        y = ByteBuffer.allocateDirect(8192).order(ByteOrder.nativeOrder());
    try {
      NativeAudio.configure(a, 3, 3, 2, true, 0, false);
      NativeAudio.configure(b, 3, 3, 2, true, 0, true);
      NativeAudio.play(a, true);
      NativeAudio.play(b, true);
      double ll = 0, rr = 0, lr = 0;
      float peak = 0;
      for (int block = 0; block < 500; block++) {
        NativeAudio.render(a, x, 1024);
        NativeAudio.render(b, y, 1024);
        for (int i = 0; i < 2048; i++) {
          float s = x.getFloat(i * 4);
          assertTrue(Float.isFinite(s));
          assertEquals("Capture cannot change sound", s, y.getFloat(i * 4));
          peak = Math.max(peak, Math.abs(s));
        }
        for (int i = 0; i < 1024; i++) {
          float l = x.getFloat(i * 8), r = x.getFloat(i * 8 + 4);
          ll += l * l;
          rr += r * r;
          lr += l * r;
        }
      }
      assertTrue("Headroom", peak > 0 && peak < .9);
      assertTrue("Independent ears", Math.abs(lr / Math.sqrt(ll * rr)) < .1);
      assertEquals(512000, NativeAudio.frames(a));
      NativeAudio.play(a, false);
      for (int i = 0; i < 100; i++) NativeAudio.render(a, x, 1024);
      assertTrue(NativeAudio.silent(a));
      assertEquals(0f, x.getFloat(8192 - 4));
      NativeAudio.fadeIn(a);
      NativeAudio.render(a, x, 1024);
      assertTrue(Math.abs(x.getFloat(0)) < .001);
    } finally {
      NativeAudio.destroy(a);
      NativeAudio.destroy(b);
    }
  }

  public void test02BackgroundAndMediaControls() throws Exception {
    connect();
    Thread.sleep(1200);
    long before = service.frames();
    main(() -> getActivity().moveTaskToBack(true));
    Thread.sleep(4000);
    assertTrue("Generator advances in background", service.frames() > before + 48000 * 3);
    assertEquals("No device underruns", 0, service.underruns());
    main(() -> service.pause());
    Thread.sleep(1000);
    assertFalse(PlaybackService.playing);
    long paused = service.frames();
    Thread.sleep(350);
    assertEquals("Paused generator sleeps", paused, service.frames());
    main(() -> service.play());
    Thread.sleep(1000);
    assertTrue(PlaybackService.playing);
    assertTrue(service.frames() > paused);
  }

  public void test03FocusInterruptAndResume() throws Exception {
    connect();
    AudioManager manager = getActivity().getSystemService(AudioManager.class);
    AudioFocusRequest other =
        new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            .setOnAudioFocusChangeListener(x -> {})
            .build();
    final int[] result = {0};
    main(() -> result[0] = manager.requestAudioFocus(other));
    assertEquals(AudioManager.AUDIOFOCUS_REQUEST_GRANTED, result[0]);
    Thread.sleep(1200);
    assertFalse("Transient focus loss pauses", PlaybackService.playing);
    main(() -> manager.abandonAudioFocusRequest(other));
    Thread.sleep(1200);
    assertTrue("Focus gain resumes", PlaybackService.playing);
  }

  public void test04PreferencesAndMaxSpectrum() throws Exception {
    connect();
    main(() -> service.configure(new Preferences(3, 3, 2, true, -12, 4)));
    main(() -> service.visible(true));
    long start = service.frames();
    Thread.sleep(9000);
    assertTrue(service.frames() > start + 48000 * 8);
    float[] column = service.column(); // MainActivity may have consumed the latest column.
    main(() -> service.observe(null));
    Thread.sleep(200);
    column = service.column();
    // Native FFT's numeric checks also run on the host; this exercises scheduling.
    assertEquals(0, service.underruns());
    assertEquals(-12, Preferences.load(getActivity()).offset);
    main(() -> service.configure(new Preferences(3, 3, 2, true, 0, 0)));
    Thread.sleep(200);
    assertEquals(0, Preferences.load(getActivity()).visuals);
  }

  public void test05VisualProof() throws Exception {
    connect();
    Thread.sleep(1200);
    assertEquals(
        "High Mid Low plus title remain visible",
        android.view.View.VISIBLE,
        getActivity().getWindow().getDecorView().getVisibility());
    for (int level : new int[] {2, 3, 4, 0}) {
      main(() -> service.configure(new Preferences(3, 3, 2, true, -18, level)));
      Thread.sleep(level == 4 ? 8000 : 1800);
      android.graphics.Bitmap bitmap = getInstrumentation().getUiAutomation().takeScreenshot();
      assertNotNull("Rendered device screenshot", bitmap);
      java.io.File destination =
          new java.io.File(getActivity().getExternalFilesDir(null), "visual-" + level + ".png");
      try (java.io.FileOutputStream out = new java.io.FileOutputStream(destination)) {
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out);
      }
      bitmap.recycle();
    }
  }

  @Override
  protected void tearDown() throws Exception {
    if (service != null)
      main(
          () -> {
            service.pause();
            service.configure(new Preferences(3, 3, 2, true, 0, 2));
          });
    if (connection != null) getActivity().unbindService(connection);
    super.tearDown();
  }
}
