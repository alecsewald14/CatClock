/// How loud each of the five volume levels is, as the peak of the sound file as a
/// fraction of full scale. These are the numbers tool/make_sounds.dart uses when it writes
/// the files, and a test checks that the files really match.
const List<double> levelPeaks = <double>[0.06, 0.125, 0.25, 0.5, 0.9];

/// Lowest and highest level on the volume slider.
const int minVolumeLevel = 1;
const int maxVolumeLevel = 5;

/// The player volume, from 0 to 1, that gives [level] when playing the loudest file.
///
/// Windows plays one file per sound and turns it down with this. The iPhone cannot turn
/// the volume down from inside the app, so it plays the pre-scaled file for the level
/// instead; both end up equally loud.
double gainForLevel(int level) {
  RangeError.checkValueInInterval(level, minVolumeLevel, maxVolumeLevel, 'level');
  return levelPeaks[level - 1] / levelPeaks.last;
}
