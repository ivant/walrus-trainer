import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:web_audio';
import '../lib/kochmethod.dart';
import '../lib/morsecode.dart';
import '../lib/morseaudio.dart';

void main() {
  new TrainerUI();
}

class TrainerUI {
  SelectElement levelSelect;
  TextInputElement alphabetElem;
  ButtonElement startStopButton;
  Element playedLetterElem;
  Element typedLetterElem;
  Element tardinessElem;

  Trainer trainer = new Trainer();

  bool started = false;

  TrainerUI({int level: 5}) {
    levelSelect = querySelector("#level");
    alphabetElem = querySelector("#alphabet");
    startStopButton = querySelector("#startStopButton");
    playedLetterElem = querySelector("#playedLetter");
    typedLetterElem = querySelector("#typedLetter");
    tardinessElem = querySelector("#tardiness");

    assert(levelSelect != null);
    assert(alphabetElem != null);
    assert(startStopButton != null);
    assert(playedLetterElem != null);
    assert(typedLetterElem != null);
    assert(tardinessElem != null);

    KochMethod.populateSelectWithLevels(levelSelect, level);
    updateAlphabet();

    levelSelect.onChange.listen((e) => updateAlphabet());
    startStopButton.onClick.listen((d) => startStopClicked());
    document.onKeyUp.listen(onKeyUp);
    startStopButton.focus();
  }

  void updateAlphabet() {
    alphabetElem.value = KochMethod.getAlphabet(levelSelect);
  }

  void startStopClicked() {
    if (!started) {
      start();
    } else {
      stop();
    }
  }

  void stop() {
    levelSelect.disabled = false;
    alphabetElem.disabled = false;

    startStopButton.focus();

    startStopButton.text = "Start";
    started = false;
  }

  void start() {
    levelSelect.disabled = true;
    alphabetElem.disabled = true;

    startStopButton.blur();

    startStopButton.text = "Stop";
    started = true;

    trainer.setAlphabet(alphabetElem.value);
    trainer.restart();
  }

  void onKeyUp(KeyboardEvent k) {
    if (!started) {
      return;
    }

    switch (k.keyCode) {
      case 27:
        stop();
        return;
      case 32:
        trainer.skip();
        break;
      default:
        trainer.onTypedLetter(new String.fromCharCode(k.keyCode));
        break;
    }
    updateView();
    trainer.playNew();
  }

  void updateView() {
    playedLetterElem.text = trainer.lastGuess.expected;
    typedLetterElem.classes.removeAll(['correct', 'incorrect']);

    typedLetterElem.classes.add(trainer.lastGuess.successful ?
        'correct' : 'incorrect');
    typedLetterElem.text = trainer.lastGuess.guessed;
    tardinessElem.text = trainer.lastGuess.duration.toStringAsFixed(3);
  }
}

class Guess {
  String expected;
  String guessed;
  double duration;

  Guess(this.expected, this.guessed, this.duration);
  bool get successful => (expected == guessed);
  bool get skipped => (guessed == '');
}

class Trainer {
  final double MU = 1.5;
  final double ALPHA = 0.5;
  final Random rng = new Random();
  final MorseAudio morseAudio = new MorseAudio(new AudioContext());

  String alphabet;

  Guess lastGuess;
  String lastLetter = '';
  DateTime lastLetterTimestamp;
  Map<String,double> letterDelayEMA = {};
  bool waitingForInput = false;

  Trainer() {
    MorseCode.initShortCodes();
  }

  void skip() {
    onTypedLetter('');
  }

  void onTypedLetter(String typedLetter) {
    if (!waitingForInput) {
      return;
    }

    waitingForInput = false;

    DateTime now = new DateTime.now();
    double dur = max(0.0, now.difference(lastLetterTimestamp).inMilliseconds.toDouble() / 1000.0);

    typedLetter = typedLetter.toUpperCase();
    if (lastLetter != typedLetter) {
      onMistake(lastLetter, typedLetter, dur);
    } else {
      onCorrectAnswer(typedLetter, dur);
    }

    lastGuess = new Guess(lastLetter, typedLetter, dur);
  }

  void onMistake(String expected, String typed, double duration) {
    letterDelayEMA[expected] *= MU;
    if (letterDelayEMA.containsKey(typed)) {
      letterDelayEMA[typed] *= MU;
    }
  }

  void onCorrectAnswer(String typed, double duration) {
    letterDelayEMA[typed] = ALPHA * duration + (1.0-ALPHA) * letterDelayEMA[typed];
  }

  void setAlphabet(String alphabet) {
    alphabet = alphabet.toUpperCase();
    for (int i = 0; i < alphabet.length; ++i) {
      String letter = alphabet[i];
      if (MorseCode.encodeElement(letter.toLowerCase()) != null) {
        letterDelayEMA.putIfAbsent(letter, () => 10.0);
      }
    }

    this.alphabet = alphabet;
  }

  String chooseLetter() {
    double sum = 0.0;
    for (int i = 0; i < alphabet.length; ++i) {
      String letter = alphabet[i];
      double ema = letterDelayEMA[letter];
      sum += ema;
    }


    double choice = rng.nextDouble() * sum;
    String chosenLetter = '';
    for (int i = 0; i < alphabet.length && choice > 0; ++i) {
      chosenLetter = alphabet[i];
      choice -= letterDelayEMA[chosenLetter];
    }

    return chosenLetter;
  }

  void restart() {
    waitingForInput = false;
    playNew();
  }

  void playNew() {
    if (!waitingForInput) {
      lastLetter = chooseLetter();

      waitingForInput = true;

      DateTime now = new DateTime.now();
      double duration = morseAudio.play(lastLetter);

      int durationSec = duration.floor();
      int durationMillis = ((duration - durationSec)*1000).floor();

      // TODO(ivant): request Duration(double sec) constructor
      lastLetterTimestamp = now.add(new Duration(
          seconds: durationSec,
          milliseconds: durationMillis
        ));
    }
  }
}