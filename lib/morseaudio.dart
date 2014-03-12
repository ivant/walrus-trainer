library morseaudio;

import 'morsecode.dart';
import 'utils.dart';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'dart:web_audio';

class MorseAudio {
  AudioContext context;

  int dashLength = 3,
      intraCharacterGap = 1,
      letterGap = 3,
      wordGap = 7;
  double dotDuration;
  double wpm;

  static final int rampSize = 6;
  static final List<double> ramp = new List<double>.generate(rampSize+1, (x) => (1 - cos(x / rampSize * PI)) / 2);
  static final Float32List rampUp = new Float32List.fromList(ramp);
  static final Float32List rampDown = new Float32List.fromList(ramp.reversed.toList());
  double rampDuration;

  double frequency = 700.0;
  final double rampLength = 0.1; // measured in a part of a dotDuration

  MorseAudio(AudioContext context) {
    this.context = context;
    setWpm(20);
  }

  void setWpm(num w, [calibrationWord = 'PARIS']) {
    wpm = w.toDouble();
    List<String> mcs = MorseCode.encodeWord(calibrationWord);
    int duration = (mcs.length - 1) * letterGap;
    for (var mc in mcs) {
      duration += (mc.length - 1) * intraCharacterGap +
          '-'.allMatches(mc).length * dashLength +
          '.'.allMatches(mc).length;
    }
    final int allWordsDuration = (w-1) * wordGap + w * duration;
    dotDuration = 60.0 / allWordsDuration;

    // Initialize volume ramp
    rampDuration = dotDuration * rampLength;
  }

  double currentTime() => context.currentTime;

  // returns the timestamps for the start of the sounds and the end of each played letter
  Tuple<double, List<double>> play(String text) {
    final List<List<String>> morseWords = MorseCode.encodeText(text);

    final OscillatorNode oscillator = context.createOscillator();
    oscillator.frequency.value = frequency;
    final GainNode gainNode = context.createGain();
    oscillator.connectNode(gainNode);
    gainNode.connectNode(context.destination);

    final AudioParam gain = gainNode.gain;
    gain.value = 0;

    double startTime = context.currentTime;
    double curTime = startTime;
    oscillator.start(curTime);

    final List<double> letterEndTimestamps = [];

    for (List<String> letters in morseWords) {
      for (String letter in letters) {
        for (var code in letter.runes) {
          var s = new String.fromCharCode(code);

          assert(s == '.' || s == '-');
          double duration = dotDuration * (s == '.' ? 1 : dashLength);
          gain.setValueCurveAtTime(rampUp, curTime, rampDuration);
          gain.setValueCurveAtTime(rampDown, curTime + duration, rampDuration);
          curTime += duration;
          curTime += dotDuration * intraCharacterGap;
          letterEndTimestamps.add(curTime);
        }
        // pause between letters
        curTime += dotDuration * (letterGap - intraCharacterGap);
      }
      // pause between words
      curTime += dotDuration * (wordGap - letterGap);
    }
    oscillator.stop(curTime + dotDuration);
    curTime += rampDuration;
    return new Tuple(startTime, letterEndTimestamps);
  }
}