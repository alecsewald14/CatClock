// ignore_for_file: avoid_print
// (This is a command-line tool, so printing to the screen is its whole job.)
//
// Makes the alarm sounds. Run from the project folder:
//   dart run tool/make_sounds.dart
//
// Six original sounds, each about 6 seconds, written in five loudness levels as
// assets/sounds/<id>_<level>.wav (level 1 quietest, 5 loudest). Everything is generated
// from scratch by arithmetic, so there is no recording to license. The cat sounds are
// synthesized and will sound like a synthesizer doing an impression of a cat.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 16000;
const double seconds = 6.0;
final int total = (sampleRate * seconds).round();

/// Peak level of each loudness level, as a fraction of full scale. Level 5 stays under
/// 0.9 so the sound never clips. The app uses the same table to set the volume on Windows
/// (see lib/alarm/volume_levels.dart).
const List<double> levelPeak = [0.06, 0.125, 0.25, 0.5, 0.9];

double sine(double phase) => math.sin(2 * math.pi * phase);

/// A decaying bell note starting at [start] seconds.
void addNote(
  Float64List out,
  double start,
  double frequency, {
  required double decay,
  List<double> partialRatios = const [1, 2, 3],
  List<double> partialLevels = const [1, 0.35, 0.15],
  double gain = 1,
}) {
  final first = (start * sampleRate).round();
  final length = (math.min(seconds - start, 4.0) * sampleRate).round();
  for (var i = 0; i < length && first + i < out.length; i++) {
    final t = i / sampleRate;
    final attack = math.min(1.0, t / 0.006);
    final envelope = attack * math.exp(-t * decay);
    var value = 0.0;
    for (var p = 0; p < partialRatios.length; p++) {
      final f = frequency * partialRatios[p];
      if (f < sampleRate / 2 - 200) value += partialLevels[p] * sine(f * t);
    }
    out[first + i] += gain * envelope * value;
  }
}

Float64List classicBeep() {
  final out = Float64List(total);
  const beep = 0.18, gap = 0.12, pause = 0.5;
  const group = 3 * (beep + gap) + pause;
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final inGroup = t % group;
    final slot = beep + gap;
    final index = (inGroup / slot).floor();
    if (index < 3) {
      final inBeep = inGroup - index * slot;
      if (inBeep < beep) {
        final edge = math.min(math.min(inBeep, beep - inBeep) / 0.01, 1.0);
        out[i] = edge * (sine(880 * t) + 0.3 * sine(2640 * t));
      }
    }
  }
  return out;
}

Float64List softChime() {
  final out = Float64List(total);
  const notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 659.25, 523.25, 392.0];
  for (var n = 0; n < notes.length; n++) {
    addNote(out, n * 0.75, notes[n], decay: 2.2);
  }
  return out;
}

Float64List morningBells() {
  final out = Float64List(total);
  const notes = [784.0, 1046.5, 1318.5, 1568.0];
  for (var group = 0; group < 4; group++) {
    for (var n = 0; n < notes.length; n++) {
      addNote(
        out,
        group * 1.5 + n * 0.22,
        notes[n],
        decay: 2.2,
        partialRatios: const [1, 2.0, 2.76, 5.4],
        partialLevels: const [1, 0.5, 0.35, 0.15],
      );
    }
  }
  return out;
}

Float64List purrRise() {
  final out = Float64List(total);
  final random = math.Random(7);
  var low = 0.0;
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    // Soft noise, kept to low frequencies with a simple one-pole filter.
    low += 0.04 * ((random.nextDouble() * 2 - 1) - low);
    // The purr: a pulse about 24 times a second.
    final pulse = 0.5 + 0.5 * math.cos(2 * math.pi * 24 * t);
    final body = 0.55 * sine(72 * t) + 0.25 * sine(144 * t) + 4.0 * low;
    // Swells up and falls back so the loop has no jump.
    final swell = 0.3 + 0.7 * math.pow(math.sin(math.pi * t / seconds), 2);
    out[i] = body * (0.35 + 0.65 * pulse) * swell;
  }
  return out;
}

/// One synthesized meow starting at [start], lasting [length] seconds.
void addMeow(Float64List out, double start, double length) {
  final first = (start * sampleRate).round();
  final count = (length * sampleRate).round();
  var phase = 0.0;
  for (var i = 0; i < count && first + i < out.length; i++) {
    final x = i / count; // 0 to 1 through the meow
    final t = i / sampleRate;
    // Pitch rises quickly, then glides down.
    final rise = x < 0.3 ? x / 0.3 : 1.0;
    final fall = x < 0.3 ? 0.0 : (x - 0.3) / 0.7;
    final pitch = 420 + 360 * math.sin(rise * math.pi / 2) - 300 * fall * fall +
        6 * sine(5.5 * t);
    phase += 2 * math.pi * pitch / sampleRate;
    // The vowel moves from "ee" through "ah" to "oo": the two resonances shift.
    final f1 = 380 + 520 * math.sin(math.min(x / 0.35, 1) * math.pi / 2) - 300 * fall;
    final f2 = 2200 - 800 * math.min(x / 0.35, 1) - 400 * fall;
    var value = 0.0;
    for (var h = 1; h * pitch < 7500; h++) {
      final f = h * pitch;
      final r1 = math.exp(-math.pow((f - f1) / 260, 2));
      final r2 = 0.55 * math.exp(-math.pow((f - f2) / 480, 2));
      final weight = (r1 + r2 + 0.04) / h;
      value += weight * math.sin(h * phase);
    }
    final attack = math.min(1.0, x / 0.08);
    final release = math.min(1.0, (1 - x) / 0.22);
    out[first + i] += value * attack * release;
  }
}

Float64List meowMelody() {
  final out = Float64List(total);
  addMeow(out, 0.3, 1.25);
  addMeow(out, 3.4, 1.25);
  return out;
}

Float64List catBell() {
  final out = Float64List(total);
  const hits = [0.0, 0.18, 0.31, 0.58, 0.72, 0.9];
  for (var period = 0; period < 4; period++) {
    for (final hit in hits) {
      final jitter = hit == 0.0 ? 0.0 : 0.012 * ((period * 7 + (hit * 100).round()) % 3);
      addNote(
        out,
        period * 1.5 + hit + jitter,
        2650,
        decay: 6,
        partialRatios: const [1, 1.5, 2.4],
        partialLevels: const [1, 0.5, 0.3],
        gain: 0.8 + 0.2 * ((hit * 10).round() % 2),
      );
    }
  }
  return out;
}

double peakOf(Float64List signal) {
  var peak = 0.0;
  for (final v in signal) {
    peak = math.max(peak, v.abs());
  }
  return peak;
}

double rmsOf(Float64List signal) {
  var sum = 0.0;
  for (final v in signal) {
    sum += v * v;
  }
  return math.sqrt(sum / signal.length);
}

/// Scales so the loudest sample is exactly 1, and softens the very start and end.
Float64List normalized(Float64List signal) {
  final fade = (0.008 * sampleRate).round();
  final peak = peakOf(signal);
  final out = Float64List(signal.length);
  for (var i = 0; i < signal.length; i++) {
    final edge = math.min(math.min(i, signal.length - 1 - i) / fade, 1.0);
    out[i] = signal[i] / peak * edge;
  }
  return out;
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
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // plain PCM
  header.setUint16(22, 1, Endian.little); // one channel
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  final out = BytesBuilder();
  out.add(header.buffer.asUint8List());
  out.add(pcm.buffer.asUint8List(pcm.offsetInBytes, dataLength));
  return out.toBytes();
}

void main() {
  final sounds = <String, Float64List Function()>{
    'classic_beep': classicBeep,
    'soft_chime': softChime,
    'morning_bells': morningBells,
    'purr_rise': purrRise,
    'meow_melody': meowMelody,
    'cat_bell': catBell,
  };
  final folder = Directory('assets/sounds')..createSync(recursive: true);
  var bytes = 0;
  sounds.forEach((id, make) {
    final base = normalized(make());
    for (var level = 1; level <= levelPeak.length; level++) {
      final pcm = Int16List(base.length);
      for (var i = 0; i < base.length; i++) {
        pcm[i] = (base[i] * levelPeak[level - 1] * 32767).round();
      }
      final file = File('${folder.path}/${id}_$level.wav');
      final data = wavBytes(pcm);
      file.writeAsBytesSync(data);
      bytes += data.length;
    }
    print('wrote $id (5 levels)');
  });
  print('Total: ${(bytes / 1000000).toStringAsFixed(2)} MB in ${sounds.length * levelPeak.length} files');
}
