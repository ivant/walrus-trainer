library morseaudio;

import 'morsecode.dart';
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

  double frequency = 700.0;
  double rampLength = 0.1; // measured in a part of a dotDuration

  String calibrationWord = 'PARIS';

  MorseAudio(AudioContext context) {
    this.context = context;
    wpm = 20;
  }

  num wpm_;

  num get wpm => wpm_;
      set wpm(num w) {
        wpm_ = w;
        List<String> mcs = MorseCode.encodeWord(calibrationWord);
        int duration = (mcs.length - 1) * letterGap;
        for (var mc in mcs) {
          duration += (mc.length - 1) * intraCharacterGap +
              '-'.allMatches(mc).length * dashLength +
              '.'.allMatches(mc).length;
        }
        int allWordsDuration = (w-1) * wordGap + w * duration;
        dotDuration = 60.0 / allWordsDuration;
      }

  // returns duration in seconds
  double play(String text) {
    final List<List<String>> morseWords = MorseCode.encodeText(text);

    final OscillatorNode oscillator = context.createOscillator();
    oscillator.frequency.value = frequency;
    final GainNode gainNode = context.createGain();
    oscillator.connectNode(gainNode);
    gainNode.connectNode(context.destination);

    final AudioParam gain = gainNode.gain;
    gain.value = 0;

    final double rampDuration = dotDuration * rampLength;
    final List<double> ramp = new List<double>.generate(11, (x) => (1 - cos(x / 10 * PI)) / 2);
    final Float32List rampUp = new Float32List.fromList(ramp);
    final Float32List rampDown = new Float32List.fromList(ramp.reversed.toList());

    double startTime = context.currentTime;
    double curTime = startTime;
    oscillator.start(curTime);

    bool firstWord = true;

    for (List<String> letters in morseWords) {
      // pause between words
      if (!firstWord) {
        curTime += dotDuration * wordGap;
      } else {
        firstWord = false;
      }

      // play the word
      bool firstLetter = true;
      for (String letter in letters) {
        // pause between letters
        if (!firstLetter) {
          curTime += dotDuration * letterGap;
        } else {
          firstLetter = false;
        }

        // play the Letter
        bool firstElement = true;
        for (var code in letter.runes) {
          var s = new String.fromCharCode(code);
          // pause between dots/dashes
          if (!firstElement) {
            curTime += dotDuration * intraCharacterGap;
          } else {
            firstElement = false;
          }

          assert(s == '.' || s == '-');
          double duration = dotDuration * (s == '.' ? 1 : dashLength);
          gain.setValueCurveAtTime(rampUp, curTime, rampDuration);
          gain.setValueCurveAtTime(rampDown, curTime + duration, rampDuration);
          curTime += duration;
        }
      }
    }
    oscillator.stop(curTime + dotDuration);
    curTime += rampDuration;
    return curTime - startTime;
  }
}