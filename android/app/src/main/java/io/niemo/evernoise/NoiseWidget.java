package io.niemo.evernoise;

import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.widget.RemoteViews;

public final class NoiseWidget extends AppWidgetProvider {
  @Override
  public void onUpdate(Context c, AppWidgetManager manager, int[] ids) {
    updateAll(c);
  }

  static void updateAll(Context c) {
    AppWidgetManager manager = AppWidgetManager.getInstance(c);
    for (int id : manager.getAppWidgetIds(new ComponentName(c, NoiseWidget.class))) {
      RemoteViews views = new RemoteViews(c.getPackageName(), R.layout.noise_widget);
      views.setTextViewText(R.id.widget_play, PlaybackService.playing ? "Ⅱ" : "▶");
      views.setContentDescription(
          R.id.widget_play, PlaybackService.playing ? "Pause EverNoise" : "Start EverNoise");
      views.setTextViewText(
          R.id.widget_status,
          PlaybackService.playing ? "Your sound. All night." : "Play your sound");
      views.setOnClickPendingIntent(
          R.id.widget_play,
          PendingIntent.getForegroundService(
              c,
              1,
              new Intent(c, PlaybackService.class).setAction(PlaybackService.TOGGLE),
              PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
      views.setOnClickPendingIntent(
          R.id.widget_title,
          PendingIntent.getActivity(
              c,
              0,
              new Intent(c, MainActivity.class),
              PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
      manager.updateAppWidget(id, views);
    }
  }
}
