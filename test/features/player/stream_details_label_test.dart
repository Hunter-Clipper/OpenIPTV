import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/features/player/player_controls.dart';

void main() {
  test('shows size, frame rate and audio', () {
    expect(
      streamDetailsLabel(
          tier: 'HD',
          width: 1280,
          height: 720,
          frameRate: 59.94,
          audioChannels: 2),
      'HD · 1280×720 · 59.94 FPS · STEREO',
    );
    expect(
      streamDetailsLabel(
          tier: 'FHD',
          width: 1920,
          height: 1080,
          frameRate: 60,
          audioChannels: 6),
      'FHD · 1920×1080 · 60 FPS · 5.1',
    );
  });

  test('leaves out what the stream does not report', () {
    expect(
      streamDetailsLabel(
          tier: 'SD', width: 0, height: 480, frameRate: -1, audioChannels: 0),
      'SD',
    );
  });

  test('names the sound format, also when the channels are unknown', () {
    expect(
      streamDetailsLabel(
          tier: 'HD',
          width: 1280,
          height: 720,
          frameRate: 25,
          audioChannels: 6,
          audioMime: 'audio/ac3'),
      'HD · 1280×720 · 25 FPS · AC3 5.1',
    );
    expect(
      streamDetailsLabel(
          tier: 'HD',
          width: 1280,
          height: 720,
          frameRate: 0,
          audioChannels: 0,
          audioMime: 'audio/mp4a-latm'),
      'HD · 1280×720 · AAC',
    );
  });
}
