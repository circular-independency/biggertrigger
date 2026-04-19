import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  SoundManager._();

  static const double _buttonVolume = 0.55;
  static const double _denyVolume = 0.55;
  static const double _laserVolume = 0.95;
  static const double _hurtVolume = 0.95;

  static final AudioPlayer _buttonPlayer = AudioPlayer(playerId: 'button_sfx')
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _denyPlayer = AudioPlayer(playerId: 'deny_sfx')
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _laserPlayer = AudioPlayer(playerId: 'laser_sfx')
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _hurtPlayer = AudioPlayer(playerId: 'hurt_sfx')
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> playButton() async {
    await _play(_buttonPlayer, 'audio/button.mp3', volume: _buttonVolume);
  }

  static Future<void> playDeny() async {
    await _play(_denyPlayer, 'audio/deny.mp3', volume: _denyVolume);
  }

  static Future<void> playLaser() async {
    await _play(_laserPlayer, 'audio/laser.wav', volume: _laserVolume);
  }

  static Future<void> playHurt() async {
    await _play(_hurtPlayer, 'audio/hurt.wav', volume: _hurtVolume);
  }

  static Future<void> _play(
    AudioPlayer player,
    String path, {
    required double volume,
  }) async {
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(path));
    } catch (_) {
      // Audio should never crash gameplay/UI interactions.
    }
  }
}
