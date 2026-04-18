import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  SoundManager._();

  static final AudioPlayer _buttonPlayer = AudioPlayer(playerId: 'button_sfx')
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _denyPlayer = AudioPlayer(playerId: 'deny_sfx')
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> playButton() async {
    await _play(_buttonPlayer, 'audio/button.mp3');
  }

  static Future<void> playDeny() async {
    await _play(_denyPlayer, 'audio/deny.mp3');
  }

  static Future<void> _play(AudioPlayer player, String path) async {
    try {
      await player.stop();
      await player.play(AssetSource(path));
    } catch (_) {
      // Audio should never crash gameplay/UI interactions.
    }
  }
}
