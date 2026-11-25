package io.niemo.evernoise;

import android.service.quicksettings.*;

public final class NoiseTile extends TileService {
  @Override
  public void onStartListening() {
    Tile t = getQsTile();
    if (t != null) {
      t.setState(PlaybackService.playing ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
      t.setLabel("EverNoise");
      t.updateTile();
    }
  }

  @Override
  public void onClick() {
    PlaybackService.send(this, PlaybackService.TOGGLE);
    onStartListening();
  }
}
