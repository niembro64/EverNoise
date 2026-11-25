package io.niemo.evernoise;

import android.app.*;
import android.content.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;

public final class MainActivity extends Activity {
  private PlaybackService service;
  private Preferences prefs;
  private RibbonView ribbon;
  private SpectrumView spectrum;
  private FrameLayout art;
  private TextView status;
  private Button play;
  private final Button[][] bands = new Button[3][6];
  private boolean bound, visible;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private final Runnable tick =
      new Runnable() {
        public void run() {
          if (!visible || service == null || prefs.visuals != 4 || !PlaybackService.playing) return;
          spectrum.add(service.column());
          handler.postDelayed(this, 33);
        }
      };
  private final ServiceConnection connection =
      new ServiceConnection() {
        public void onServiceConnected(ComponentName n, IBinder binder) {
          service = ((PlaybackService.LocalBinder) binder).service();
          prefs = service.preferences();
          service.observe(() -> refresh());
          service.visible(true);
          refresh();
        }

        public void onServiceDisconnected(ComponentName n) {
          service = null;
          refresh();
        }
      };

  int dp(float n) {
    return Math.round(n * getResources().getDisplayMetrics().density);
  }

  @Override
  public void onCreate(Bundle saved) {
    super.onCreate(saved);
    setVolumeControlStream(android.media.AudioManager.STREAM_MUSIC);
    prefs = Preferences.load(this);
    FrameLayout root = new FrameLayout(this);
    root.setBackgroundColor(Color.BLACK);
    if (Build.VERSION.SDK_INT >= 29) root.setForceDarkAllowed(false);
    ribbon = new RibbonView(this);
    root.addView(ribbon, new FrameLayout.LayoutParams(-1, -1));
    ScrollView scroll = new ScrollView(this);
    scroll.setFillViewport(true);
    scroll.setDefaultFocusHighlightEnabled(false);
    scroll.setClipToPadding(false);
    root.addView(scroll, new FrameLayout.LayoutParams(-1, -1));
    LinearLayout content = new LinearLayout(this);
    content.setOrientation(LinearLayout.VERTICAL);
    content.setGravity(Gravity.CENTER_HORIZONTAL);
    content.setPadding(dp(26), dp(18), dp(26), dp(18));
    scroll.addView(content, new ScrollView.LayoutParams(-1, -1));
    root.setOnApplyWindowInsetsListener(
        (v, insets) -> {
          content.setPadding(
              dp(26) + insets.getSystemWindowInsetLeft(),
              dp(18) + insets.getSystemWindowInsetTop(),
              dp(26) + insets.getSystemWindowInsetRight(),
              dp(18) + insets.getSystemWindowInsetBottom());
          return insets;
        });
    TextView title = text("EverNoise", 44, 0xffeeeeF2);
    title.setGravity(Gravity.CENTER);
    title.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
    content.addView(title);
    TextView subtitle = text("Your sound. All night.", 17, 0xff9696a1);
    subtitle.setGravity(Gravity.CENTER);
    content.addView(subtitle);
    art = new FrameLayout(this);
    content.addView(art, new LinearLayout.LayoutParams(-1, dp(210), 1));
    art.addOnLayoutChangeListener((v, l, t, r, b, ol, ot, or, ob) -> refresh());
    String[] names = {"High", "Mid", "Low"};
    for (int row = 0; row < 3; row++) {
      TextView label = text(names[row], 25, 0xffdddde5);
      label.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
      label.setGravity(Gravity.START);
      LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
      lp.topMargin = dp(14);
      lp.bottomMargin = dp(8);
      content.addView(label, lp);
      LinearLayout choices = new LinearLayout(this);
      choices.setOrientation(LinearLayout.HORIZONTAL);
      content.addView(choices, new LinearLayout.LayoutParams(-1, dp(51)));
      for (int level = 0; level < 6; level++) {
        final int rr = row, ll = level;
        Button b = new Button(this);
        b.setText(level == 0 ? "○" : "●");
        b.setTextSize(new float[] {17, 9, 12, 16, 21, 27}[level]);
        b.setPadding(0, 0, 0, 0);
        b.setMinimumWidth(0);
        b.setMinWidth(0);
        b.setMinimumHeight(0);
        b.setMinHeight(0);
        b.setAllCaps(false);
        b.setContentDescription(
            names[row]
                + (level == 0
                    ? " off"
                    : " "
                        + level
                        + " of 5, "
                        + new int[] {0, -30, -18, -12, -6, 0}[level]
                        + " decibels relative"));
        b.setOnClickListener(
            v -> {
              int[] values = {prefs.high, prefs.mid, prefs.low};
              values[rr] = ll;
              change(
                  new Preferences(
                      values[2], values[1], values[0], prefs.stereo, prefs.offset, prefs.visuals));
            });
        LinearLayout.LayoutParams item = new LinearLayout.LayoutParams(0, -1, 1);
        if (level > 0) item.leftMargin = dp(7);
        choices.addView(b, item);
        bands[row][level] = b;
      }
    }
    FrameLayout bottom = new FrameLayout(this);
    LinearLayout.LayoutParams bottomParams = new LinearLayout.LayoutParams(-1, dp(100));
    bottomParams.topMargin = dp(16);
    content.addView(bottom, bottomParams);
    play = new Button(this);
    play.setTextSize(28);
    play.setAllCaps(false);
    play.setBackground(glass(0xffa6b8eb, true));
    FrameLayout.LayoutParams playParams =
        new FrameLayout.LayoutParams(dp(112), dp(80), Gravity.CENTER);
    bottom.addView(play, playParams);
    play.setOnClickListener(
        v ->
            PlaybackService.send(
                this, PlaybackService.playing ? PlaybackService.PAUSE : PlaybackService.PLAY));
    Button settings = new Button(this);
    settings.setText("⚙");
    settings.setTextSize(26);
    settings.setTextColor(0xffb8b8c4);
    settings.setBackgroundColor(Color.TRANSPARENT);
    settings.setContentDescription("Settings");
    FrameLayout.LayoutParams gear =
        new FrameLayout.LayoutParams(dp(80), dp(80), Gravity.END | Gravity.CENTER_VERTICAL);
    bottom.addView(settings, gear);
    settings.setOnClickListener(v -> settings());
    status = text("Starting your sound…", 12, 0xff8d8d9b);
    status.setGravity(Gravity.CENTER);
    content.addView(status);
    setContentView(root);
    refresh();
  }

  private TextView text(String value, int size, int color) {
    TextView v = new TextView(this);
    v.setText(value);
    v.setTextSize(size);
    v.setTextColor(color);
    return v;
  }

  private GradientDrawable glass(int color, boolean selected) {
    GradientDrawable d =
        new GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            new int[] {selected ? (color & 0xffffff) | 0x33000000 : 0x13ffffff, 0x07000000});
    d.setCornerRadius(dp(17));
    d.setStroke(dp(selected ? 2 : 1), selected ? color : 0x22ffffff);
    return d;
  }

  private void change(Preferences p) {
    prefs = p;
    if (service != null) service.configure(p);
    else p.save(this);
    refresh();
  }

  private void refresh() {
    if (service != null) prefs = service.preferences();
    if (play == null) return;
    boolean on = PlaybackService.playing;
    int[] values = {prefs.high, prefs.mid, prefs.low};
    int[] colors = {0xff677fb4, 0xff5f8e60, 0xffad6c66};
    for (int row = 0; row < 3; row++)
      for (int n = 0; n < 6; n++) {
        Button b = bands[row][n];
        boolean selected = values[row] == n;
        int color = on && prefs.audible() ? colors[row] : 0xff9999a3;
        b.setSelected(selected);
        b.setTextColor(color);
        b.setAlpha(n == 0 ? 1 : new float[] {1, .45f, .6f, .72f, .85f, 1}[n]);
        b.setBackground(glass(color, selected));
      }
    play.setText(on ? "Ⅱ" : "▶");
    play.setContentDescription(on ? "Pause EverNoise" : "Start EverNoise");
    status.setText(service == null ? "Starting your sound…" : service.status());
    if (prefs.visuals == 4 && spectrum == null) {
      spectrum = new SpectrumView(this);
      art.addView(spectrum, new FrameLayout.LayoutParams(-1, -1));
    }
    if (spectrum != null) {
      spectrum.setVisibility(prefs.visuals == 4 ? View.VISIBLE : View.GONE);
      spectrum.playing(on);
    }
    handler.removeCallbacks(tick);
    if (visible && on && prefs.visuals == 4) handler.post(tick);
    int[] position = new int[2];
    art.getLocationInWindow(position);
    boolean reduce =
        Settings.Global.getFloat(getContentResolver(), Settings.Global.ANIMATOR_DURATION_SCALE, 1)
            == 0;
    ribbon.configure(prefs, on, reduce, position[1], art.getHeight());
  }

  private void settings() {
    ScrollView scroll = new ScrollView(this);
    LinearLayout box = new LinearLayout(this);
    box.setOrientation(LinearLayout.VERTICAL);
    box.setPadding(dp(24), dp(12), dp(24), dp(24));
    scroll.addView(box);
    box.addView(text("Audio", 18, 0xffddddE5));
    segment(
        box,
        new String[] {"Mono", "Stereo"},
        prefs.stereo ? 1 : 0,
        n ->
            change(
                new Preferences(
                    prefs.low, prefs.mid, prefs.high, n == 1, prefs.offset, prefs.visuals)));
    space(box);
    box.addView(text("Animations", 18, 0xffdddde5));
    segment(
        box,
        new String[] {"Off", "Low", "Med", "High", "Max"},
        prefs.visuals,
        n ->
            change(
                new Preferences(prefs.low, prefs.mid, prefs.high, prefs.stereo, prefs.offset, n)));
    space(box);
    TextView loudness = text("App Loudness: " + prefs.offset + " dB", 18, 0xffdddde5);
    box.addView(loudness);
    SeekBar bar = new SeekBar(this);
    bar.setMax(21);
    bar.setProgress(prefs.offset + 18);
    box.addView(bar);
    bar.setContentDescription("App Loudness");
    bar.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onStartTrackingTouch(SeekBar b) {}

          public void onStopTrackingTouch(SeekBar b) {}

          public void onProgressChanged(SeekBar b, int v, boolean user) {
            if (user) {
              change(
                  new Preferences(
                      prefs.low, prefs.mid, prefs.high, prefs.stereo, v - 18, prefs.visuals));
              loudness.setText("App Loudness: " + prefs.offset + " dB");
            }
          }
        });
    space(box);
    box.addView(text("Your sound, close at hand", 20, 0xffddddE5));
    paragraph(
        box,
        "Use the playback notification or Lock Screen to play and pause. Add EverNoise from your"
            + " Home Screen’s widget picker, or edit Quick Settings and add the EverNoise tile."
            + " Headphone media buttons work too.");
    paragraph(
        box,
        "Audio continues with the screen off. Phone calls, another app taking audio focus, a"
            + " disconnected headset, force-stop, or device shutdown can interrupt playback. Some"
            + " manufacturers impose extra battery restrictions; use the system’s app battery"
            + " settings if needed.");
    Button battery = new Button(this);
    battery.setText("App battery & permissions");
    battery.setAllCaps(false);
    box.addView(battery);
    battery.setOnClickListener(
        v ->
            startActivity(
                new Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    android.net.Uri.parse("package:" + getPackageName()))));
    space(box);
    box.addView(text("For the ones you care for", 20, 0xffdddde5));
    paragraph(
        box,
        "Babies, children and pets may hear frequencies you do not. EverNoise tapers at the edges"
            + " of the human audible range; it does not cover pets’ entire hearing ranges. Keep"
            + " listening quiet, place speakers away from a child’s head, and give pets a quiet"
            + " place to retreat. Digital peak protection is not a limit on sound pressure at"
            + " anyone’s ears.");
    paragraph(
        box,
        "Generated on your device. No microphone, account, ads, network access or tracking. Your"
            + " preferences stay on this device.\n\n"
            + "EverNoise 1.0.0");
    new AlertDialog.Builder(this)
        .setTitle("Settings")
        .setView(scroll)
        .setPositiveButton("Done", null)
        .show();
  }

  private void paragraph(LinearLayout box, String value) {
    TextView t = text(value, 14, 0xffaaaab7);
    t.setLineSpacing(dp(3), 1);
    LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2);
    p.topMargin = dp(12);
    box.addView(t, p);
  }

  private void space(LinearLayout b) {
    Space s = new Space(this);
    b.addView(s, new LinearLayout.LayoutParams(1, dp(22)));
  }

  private void segment(
      LinearLayout box, String[] labels, int selected, java.util.function.IntConsumer action) {
    LinearLayout group = new LinearLayout(this);
    Button[] buttons = new Button[labels.length];
    for (int i = 0; i < labels.length; i++) {
      final int index = i;
      Button b = new Button(this);
      b.setText(labels[i]);
      b.setTextSize(14);
      b.setAllCaps(false);
      b.setMinWidth(0);
      b.setMinimumWidth(0);
      b.setPadding(0, 0, 0, 0);
      b.setBackground(glass(i == selected ? 0xff8299c9 : 0xff707079, i == selected));
      b.setSelected(i == selected);
      b.setOnClickListener(
          v -> {
            action.accept(index);
            for (int j = 0; j < buttons.length; j++) {
              buttons[j].setSelected(j == index);
              buttons[j].setBackground(glass(j == index ? 0xff8299c9 : 0xff707079, j == index));
            }
          });
      buttons[i] = b;
      LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(46), 1);
      p.setMargins(dp(2), dp(8), dp(2), 0);
      group.addView(b, p);
    }
    box.addView(group);
  }

  @Override
  protected void onStart() {
    super.onStart();
    visible = true;
    ribbon.onResume();
    PlaybackService.send(this, PlaybackService.PLAY);
    bound = bindService(new Intent(this, PlaybackService.class), connection, BIND_AUTO_CREATE);
  }

  @Override
  protected void onStop() {
    visible = false;
    handler.removeCallbacks(tick);
    if (service != null) {
      service.observe(null);
      service.visible(false);
    }
    if (bound) {
      unbindService(connection);
      bound = false;
    }
    service = null;
    ribbon.onPause();
    super.onStop();
  }
}
