package io.niemo.evernoise;

import android.content.Context;
import android.opengl.*;
import android.os.SystemClock;
import java.nio.*;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

/** The same linear-light liquid material used by the web and Apple artwork. */
final class RibbonView extends GLSurfaceView implements GLSurfaceView.Renderer {
  static final float[][] COLORS = {
    {.679977f, .422528f, .401320f},
    {.580084f, .493912f, .253602f},
    {.373181f, .556164f, .377719f},
    {.202675f, .562493f, .581097f},
    {.404896f, .499108f, .704015f},
    {.604564f, .432928f, .613018f}
  };

  static float linear(float v) {
    return v <= .04045f ? v / 12.92f : (float) Math.pow((v + .055) / 1.055, 2.4);
  }

  private volatile Preferences settings;
  private volatile boolean playing, reduced;
  private volatile float top, height;
  private int program, width, screenHeight;
  private long last;
  private float phase, active;
  private final float[] power = new float[3];
  private final FloatBuffer vertices =
      ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer();

  RibbonView(Context c) {
    super(c);
    settings = Preferences.load(c);
    setEGLContextClientVersion(3);
    setPreserveEGLContextOnPause(true);
    vertices.put(new float[] {-1, -1, 1, -1, -1, 1, 1, 1}).position(0);
    setRenderer(this);
    setRenderMode(RENDERMODE_WHEN_DIRTY);
    setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
  }

  void configure(Preferences p, boolean on, boolean reduce, float y, float h) {
    settings = p;
    playing = on;
    reduced = reduce;
    top = y;
    height = h;
    requestRender();
  }

  private String asset(String name) throws Exception {
    try (var in = getContext().getAssets().open(name)) {
      java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
      byte[] chunk = new byte[4096];
      int n;
      while ((n = in.read(chunk)) != -1) bytes.write(chunk, 0, n);
      return bytes.toString("UTF-8");
    }
  }

  private int shader(int type, String source) {
    int s = GLES30.glCreateShader(type);
    GLES30.glShaderSource(s, source);
    GLES30.glCompileShader(s);
    int[] status = new int[1];
    GLES30.glGetShaderiv(s, GLES30.GL_COMPILE_STATUS, status, 0);
    if (status[0] == 0) throw new IllegalStateException(GLES30.glGetShaderInfoLog(s));
    return s;
  }

  public void onSurfaceCreated(GL10 unused, EGLConfig config) {
    try {
      program = GLES30.glCreateProgram();
      GLES30.glAttachShader(program, shader(GLES30.GL_VERTEX_SHADER, asset("ribbon.vert")));
      GLES30.glAttachShader(program, shader(GLES30.GL_FRAGMENT_SHADER, asset("ribbon.frag")));
      GLES30.glLinkProgram(program);
      int[] ok = new int[1];
      GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, ok, 0);
      if (ok[0] == 0) throw new IllegalStateException(GLES30.glGetProgramInfoLog(program));
      GLES30.glUseProgram(program);
      int[] buffer = new int[1];
      GLES30.glGenBuffers(1, buffer, 0);
      GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, buffer[0]);
      GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, 32, vertices, GLES30.GL_STATIC_DRAW);
      GLES30.glEnableVertexAttribArray(0);
      GLES30.glVertexAttribPointer(0, 2, GLES30.GL_FLOAT, false, 0, 0);
      float[] colors = new float[18];
      for (int i = 0; i < 6; i++)
        for (int ch = 0; ch < 3; ch++) colors[i * 3 + ch] = linear(COLORS[i][ch]);
      GLES30.glUniform3fv(u("hues"), 6, colors, 0);
    } catch (Exception e) {
      android.util.Log.e("EverNoise", "Artwork unavailable", e);
      program = 0;
    }
  }

  public void onSurfaceChanged(GL10 unused, int w, int h) {
    width = w;
    screenHeight = h;
    GLES30.glViewport(0, 0, w, h);
    last = SystemClock.elapsedRealtime();
  }

  private int u(String name) {
    return GLES30.glGetUniformLocation(program, name);
  }

  public void onDrawFrame(GL10 unused) {
    long now = SystemClock.elapsedRealtime();
    float dt = Math.min(.1f, (now - last) / 1000f);
    last = now;
    float smoothing = 1 - (float) Math.exp(-dt / 1.15);
    float target = playing && settings.audible() ? 1 : 0;
    active += (target - active) * smoothing;
    int[] levels = {settings.low, settings.mid, settings.high};
    double[] weights = {0, .001, .0158489319246111, .0630957344480193, .251188643150958, 1};
    for (int i = 0; i < 3; i++) power[i] += (weights[levels[i]] - power[i]) * smoothing;
    if (settings.visuals >= 2 && !reduced)
      phase = (phase + dt * active * (float) Math.PI / 120) % (2 * (float) Math.PI);
    GLES30.glClearColor(0, 0, 0, 1);
    GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
    if (program == 0 || settings.visuals == 0 || settings.visuals == 4) return;
    GLES30.glUseProgram(program);
    GLES30.glUniform2f(u("canvas"), width, screenHeight);
    GLES30.glUniform4f(u("infinityRect"), width * .04f, top, width * .92f, height);
    GLES30.glUniform1f(u("phase"), phase);
    GLES30.glUniform1f(u("activity"), active);
    GLES30.glUniform1f(u("ambience"), settings.visuals == 3 ? 1 : 0);
    GLES30.glUniform3fv(u("power"), 1, power, 0);
    float[] chosen = new float[3];
    for (int ch = 0; ch < 3; ch++)
      chosen[ch] =
          linear(COLORS[0][ch]) * power[0]
              + linear(COLORS[2][ch]) * power[1]
              + linear(COLORS[4][ch]) * power[2];
    GLES30.glUniform3fv(u("chosen"), 1, chosen, 0);
    GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4);
    boolean changing = false;
    for (int i = 0; i < 3; i++) changing |= Math.abs(weights[levels[i]] - power[i]) > .001;
    if ((settings.visuals >= 2 && playing && !reduced)
        || Math.abs(target - active) > .002
        || changing) postDelayed(this::requestRender, 33);
  }
}
