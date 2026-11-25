package io.niemo.evernoise;

import android.content.Context;
import android.content.SharedPreferences;

final class Preferences {
  final int low, mid, high, offset, visuals;
  final boolean stereo;

  Preferences(int l, int m, int h, boolean s, int o, int v) {
    low = clamp(l, 0, 5);
    mid = clamp(m, 0, 5);
    high = clamp(h, 0, 5);
    stereo = s;
    offset = clamp(o, -18, 3);
    visuals = clamp(v, 0, 4);
  }

  static int clamp(int x, int a, int b) {
    return Math.max(a, Math.min(b, x));
  }

  static Preferences load(Context c) {
    SharedPreferences p = c.getSharedPreferences("sound", 0);
    return new Preferences(
        p.getInt("low", 3),
        p.getInt("mid", 3),
        p.getInt("high", 2),
        p.getBoolean("stereo", true),
        p.getInt("offset", 0),
        p.getInt("visuals", 2));
  }

  void save(Context c) {
    c.getSharedPreferences("sound", 0)
        .edit()
        .putInt("low", low)
        .putInt("mid", mid)
        .putInt("high", high)
        .putBoolean("stereo", stereo)
        .putInt("offset", offset)
        .putInt("visuals", visuals)
        .apply();
  }

  boolean audible() {
    return low + mid + high > 0;
  }
}
