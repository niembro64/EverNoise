package io.niemo.evernoise;

import android.content.Context;
import android.graphics.*;
import android.view.View;

final class SpectrumView extends View {
  private final Bitmap image = Bitmap.createBitmap(660, 1024, Bitmap.Config.ARGB_8888);
  private final Canvas history = new Canvas(image);
  private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
  private final int[] column = new int[1024];
  private final int[][] palette = new int[1024][401];
  private boolean playing;

  SpectrumView(Context c) {
    super(c);
    setContentDescription("Spectrogram of the generated stereo output, 2 hertz to 48 kilohertz");
    for (int row = 0; row < 1024; row++)
      for (int i = 0; i <= 400; i++) palette[row][i] = color(row, -110 + i * .25);
  }

  void playing(boolean value) {
    playing = value;
    invalidate();
  }

  void add(float[] values) {
    if (values == null) return;
    history.drawBitmap(image, -1, 0, null);
    for (int i = 0; i < 1024; i++)
      column[1023 - i] =
          Float.isFinite(values[i])
              ? palette[i][Math.max(0, Math.min(400, Math.round((values[i] + 110) * 4)))]
              : Color.BLACK;
    image.setPixels(column, 0, 1, 659, 0, 1, 1024);
    invalidate();
  }

  private int color(int row, double db) {
    double hz = 2 * Math.pow(24000, row / 1023.0);
    double t = Math.tan(Math.PI * Math.min(hz, 23999.99) / 48000);
    double low = 1 / (1 + Math.pow(t / Math.tan(Math.PI * 200 / 48000), 4));
    double mid = (1 - low) / (1 + Math.pow(t / Math.tan(Math.PI * 2000 / 48000), 4));
    double[] weights = {low, mid, 1 - low - mid}, rgb = new double[3];
    double lum = 0;
    for (int ch = 0; ch < 3; ch++) {
      for (int b = 0; b < 3; b++)
        rgb[ch] += RibbonView.linear(RibbonView.COLORS[b * 2][ch]) * weights[b];
      lum += rgb[ch] * new double[] {.2126, .7152, .0722}[ch];
    }
    double intensity = Math.max(0, Math.pow(2, (db + 35) / 10) - Math.pow(2, -6.5)),
        light = 70 * (1 - 1 / (1 + intensity)),
        y = light <= 8 ? light / (24389.0 / 27) : Math.pow((light + 16) / 116, 3);
    int[] out = new int[3];
    for (int ch = 0; ch < 3; ch++) {
      double v = rgb[ch] / lum * y;
      out[ch] =
          (int)
              Math.round(
                  255
                      * Math.min(
                          1,
                          Math.max(
                              0, v <= .0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - .055)));
    }
    return Color.rgb(out[0], out[1], out[2]);
  }

  @Override
  protected void onDraw(Canvas c) {
    super.onDraw(c);
    if (!playing) {
      ColorMatrix m = new ColorMatrix();
      m.setSaturation(0);
      paint.setColorFilter(new ColorMatrixColorFilter(m));
    } else paint.setColorFilter(null);
    c.drawBitmap(image, null, new Rect(0, 0, getWidth(), getHeight()), paint);
    paint.setColorFilter(null);
    paint.setColor(0xffb8b8c2);
    paint.setTextSize(10 * getResources().getDisplayMetrics().scaledDensity);
    String[] labels = {"48k", "2k", "200", "20", "2 Hz"};
    double[] frequencies = {48000, 2000, 200, 20, 2};
    for (int i = 0; i < 5; i++) {
      float y = (float) ((1 - Math.log(frequencies[i] / 2) / Math.log(24000)) * getHeight());
      c.drawText(labels[i], 8, Math.max(paint.getTextSize(), Math.min(getHeight() - 4, y)), paint);
    }
  }
}
