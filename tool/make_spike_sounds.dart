// Makes the five test alarm sounds for the Phase 1 iPhone test.
//
// Run from the project folder:
//   dart run tool/make_spike_sounds.dart
//
// Each file is the same 6-second beeping pattern, scaled to a different
// loudness (level 1 is quietest, level 5 is loudest). The beeps are
// generated from scratch, so there is nothing to license.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;
const double seconds = 6.0;

// Peak amplitude for levels 1 to 5, as a fraction of full scale.
const List<double> levelAmplitude = [0.06, 0.125, 0.25, 0.5, 0.9];

Int16List buildBeeps(double amplitude) {
  final total = (sampleRate * seconds).round();
  final samples = Int16List(total);
  const frequency = 880.0;
  const beepLength = 0.18; // seconds on
  const gapLength = 0.12; // seconds off between beeps
  const beepsPerGroup = 3;
  const groupPause = 0.5; // seconds of silence after each group
  const groupLength = beepsPerGroup * (beepLength + gapLength) + groupPause;
  const fade = 0.01; // 10 ms fade in and out so beeps do not click

  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final inGroup = t % groupLength;
    final slot = beepLength + gapLength;
    final beepIndex = (inGroup / slot).floor();
    var value = 0.0;
    if (beepIndex < beepsPerGroup) {
      final inBeep = inGroup - beepIndex * slot;
      if (inBeep < beepLength) {
        var envelope = 1.0;
        if (inBeep < fade) envelope = inBeep / fade;
        if (beepLength - inBeep < fade) envelope = (beepLength - inBeep) / fade;
        value = math.sin(2 * math.pi * frequency * t) * envelope;
      }
    }
    samples[i] = (value * amplitude * 32767).round();
  }
  return samples;
}

Uint8List wavBytes(Int16List pcm) {
  final dataLength = pcm.lengthInBytes;
  final header = ByteData(44);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // size of the format block
  header.setUint16(20, 1, Endian.little); // plain PCM
  header.setUint16(22, 1, Endian.little); // one channel
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // bytes per second
  header.setUint16(32, 2, Endian.little); // bytes per sample frame
  header.setUint16(34, 16, Endian.little); // bits per sample
  text(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  final out = BytesBuilder();
  out.add(header.buffer.asUint8List());
  out.add(pcm.buffer.asUint8List(pcm.offsetInBytes, dataLength));
  return out.toBytes();
}

void main() {
  final folder = Directory('spike/alarmkit_test/Sounds');
  folder.createSync(recursive: true);
  for (var level = 1; level <= levelAmplitude.length; level++) {
    final pcm = buildBeeps(levelAmplitude[level - 1]);
    final file = File('${folder.path}/catbeep_$level.wav');
    file.writeAsBytesSync(wavBytes(pcm));
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}
