import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/sound_catalog.dart';
import 'package:cat_clock/alarm/volume_levels.dart';

/// A WAV file read back into numbers.
class Wav {
  Wav(this.bytes) {
    final header = ByteData.sublistView(bytes);
    riff = String.fromCharCodes(bytes.sublist(0, 4));
    wave = String.fromCharCodes(bytes.sublist(8, 12));
    format = header.getUint16(20, Endian.little);
    channels = header.getUint16(22, Endian.little);
    sampleRate = header.getUint32(24, Endian.little);
    bits = header.getUint16(34, Endian.little);
    final dataLength = header.getUint32(40, Endian.little);
    samples = Int16List.sublistView(Uint8List.fromList(bytes.sublist(44, 44 + dataLength)));
  }

  final Uint8List bytes;
  late final String riff;
  late final String wave;
  late final int format;
  late final int channels;
  late final int sampleRate;
  late final int bits;
  late final Int16List samples;

  double get seconds => samples.length / sampleRate;

  double get peak {
    var peak = 0;
    for (final s in samples) {
      if (s.abs() > peak) peak = s.abs();
    }
    return peak / 32767;
  }

  double get rms {
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s.toDouble();
    }
    return (sum / samples.length) == 0 ? 0 : (sum / samples.length) / (32767 * 32767);
  }
}

Wav load(AlarmSound sound, int level) =>
    Wav(File(sound.assetPath(level)).readAsBytesSync());

void main() {
  group('the catalog', () {
    test('has six sounds with different ids and readable names', () {
      expect(alarmSounds.length, 6);
      expect(alarmSounds.map((s) => s.id).toSet().length, 6);
      expect(alarmSounds.map((s) => s.name).toSet().length, 6);
      for (final sound in alarmSounds) {
        expect(sound.name, isNotEmpty);
        expect(sound.name, isNot(contains('_')));
      }
    });

    test('lists the default alarm sound first', () {
      expect(alarmSounds.first.id, const Alarm().soundId);
    });

    test('includes cat-themed sounds', () {
      final ids = alarmSounds.map((s) => s.id);
      expect(ids, containsAll(['purr_rise', 'meow_melody', 'cat_bell']));
    });

    test('soundById finds each sound', () {
      for (final sound in alarmSounds) {
        expect(soundById(sound.id), sound);
        expect(isKnownSound(sound.id), isTrue);
      }
    });

    test('soundById falls back to the default for an unknown id', () {
      expect(soundById('no_such_sound'), alarmSounds.first);
      expect(isKnownSound('no_such_sound'), isFalse);
    });

    test('asset paths follow the file naming, and levels outside 1 to 5 are refused', () {
      expect(soundById('cat_bell').assetPath(3), 'assets/sounds/cat_bell_3.wav');
      expect(soundById('cat_bell').fullVolumeAssetPath, 'assets/sounds/cat_bell_5.wav');
      expect(() => soundById('cat_bell').assetPath(0), throwsRangeError);
      expect(() => soundById('cat_bell').assetPath(6), throwsRangeError);
    });
  });

  group('volume levels', () {
    test('there are five, matching the alarm settings', () {
      expect(levelPeaks.length, 5);
      expect(minVolumeLevel, Alarm.minVolumeLevel);
      expect(maxVolumeLevel, Alarm.maxVolumeLevel);
    });

    test('each level is louder than the one before', () {
      for (var i = 1; i < levelPeaks.length; i++) {
        expect(levelPeaks[i], greaterThan(levelPeaks[i - 1]));
      }
    });

    test('the player volume is 1 at the top level and gets smaller below it', () {
      expect(gainForLevel(5), 1.0);
      for (var level = 1; level < 5; level++) {
        expect(gainForLevel(level), lessThan(gainForLevel(level + 1)));
        expect(gainForLevel(level), greaterThan(0));
      }
      expect(gainForLevel(1), closeTo(0.0667, 0.001));
    });

    test('levels outside 1 to 5 are refused', () {
      expect(() => gainForLevel(0), throwsRangeError);
      expect(() => gainForLevel(6), throwsRangeError);
    });
  });

  group('the sound files', () {
    test('all 30 exist (6 sounds in 5 levels)', () {
      for (final sound in alarmSounds) {
        for (var level = 1; level <= 5; level++) {
          expect(File(sound.assetPath(level)).existsSync(), isTrue, reason: sound.assetPath(level));
        }
      }
    });

    test('every file is a plain mono 16-bit WAV of about 6 seconds', () {
      for (final sound in alarmSounds) {
        for (var level = 1; level <= 5; level++) {
          final wav = load(sound, level);
          final name = sound.assetPath(level);
          expect(wav.riff, 'RIFF', reason: name);
          expect(wav.wave, 'WAVE', reason: name);
          expect(wav.format, 1, reason: '$name is plain PCM');
          expect(wav.channels, 1, reason: name);
          expect(wav.bits, 16, reason: name);
          expect(wav.sampleRate, 16000, reason: name);
          expect(wav.seconds, inInclusiveRange(5.9, 6.1), reason: name);
        }
      }
    });

    test('all of them together are at most 6 MB', () {
      var total = 0;
      for (final sound in alarmSounds) {
        for (var level = 1; level <= 5; level++) {
          total += File(sound.assetPath(level)).lengthSync();
        }
      }
      expect(total, lessThanOrEqualTo(6000000));
    });

    test('each file peaks where the level table says it should', () {
      for (final sound in alarmSounds) {
        for (var level = 1; level <= 5; level++) {
          expect(
            load(sound, level).peak,
            closeTo(levelPeaks[level - 1], levelPeaks[level - 1] * 0.03),
            reason: sound.assetPath(level),
          );
        }
      }
    });

    test('each level is clearly louder than the one below it', () {
      for (final sound in alarmSounds) {
        var previous = 0.0;
        for (var level = 1; level <= 5; level++) {
          final rms = load(sound, level).rms;
          expect(rms, greaterThan(previous * 1.5), reason: '${sound.id} level $level');
          previous = rms;
        }
      }
    });

    test('no sound clips, and none is almost silent at the top level', () {
      for (final sound in alarmSounds) {
        final wav = load(sound, 5);
        expect(wav.peak, lessThanOrEqualTo(0.95), reason: '${sound.id} clips');
        expect(wav.rms, greaterThan(0.015), reason: '${sound.id} is too quiet'); // about 12% RMS
      }
    });

    test('every sound starts and ends quietly, so looping does not click', () {
      for (final sound in alarmSounds) {
        final samples = load(sound, 5).samples;
        expect(samples.first.abs(), lessThan(200), reason: '${sound.id} start');
        expect(samples.last.abs(), lessThan(200), reason: '${sound.id} end');
      }
    });
  });

  testWidgets('the loudest file of every sound is bundled with the app', (tester) async {
    for (final sound in alarmSounds) {
      final data = await rootBundle.load(sound.fullVolumeAssetPath);
      expect(data.lengthInBytes, greaterThan(100000), reason: sound.fullVolumeAssetPath);
    }
  });
}
