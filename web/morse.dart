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
  SelectElement letterCountSelect;
  ButtonElement startStopButton;
  Element playedLetterElem;
  Element typedLetterElem;
  Element tardinessElem;

  Trainer trainer = new Trainer();
  Guess currentGuess = null;

  int letterCount = 1;

  bool started = false;

  TrainerUI({int level: 5}) {
    levelSelect = querySelector("#level");
    alphabetElem = querySelector("#alphabet");
    letterCountSelect = querySelector("#letterCount");
    startStopButton = querySelector("#startStopButton");
    playedLetterElem = querySelector("#playedLetter");
    typedLetterElem = querySelector("#typedLetter");
    tardinessElem = querySelector("#tardiness");

    assert(levelSelect != null);
    assert(alphabetElem != null);
    assert(letterCountSelect != null);
    assert(startStopButton != null);
    assert(playedLetterElem != null);
    assert(typedLetterElem != null);
    assert(tardinessElem != null);

    KochMethod.populateSelectWithLevels(levelSelect, level);
    updateAlphabet();
    updateTrainerWidth();

    levelSelect.onChange.listen((e) => updateAlphabet());
    letterCountSelect.onChange.listen((e) => updateTrainerWidth());
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

  void setConfigurationEnabledStatus(bool enabled) {
    levelSelect.disabled = !enabled;
    alphabetElem.disabled = !enabled;
    letterCountSelect.disabled = !enabled;
  }

  void stop() {
    setConfigurationEnabledStatus(true);

    startStopButton.focus();

    startStopButton.text = "Start";
    started = false;
  }

  void start() {
    setConfigurationEnabledStatus(false);

    startStopButton.blur();

    startStopButton.text = "Stop";
    started = true;

    trainer.setAlphabet(alphabetElem.value);
    trainer.setLetterCount(letterCount);
    currentGuess = trainer.restart();
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
    if (currentGuess.completed) {
      updateView();
      currentGuess = trainer.playNew();
    }
  }

  void updateView() {
    playedLetterElem.text = currentGuess.expected;
    typedLetterElem.classes.removeAll(['correct', 'incorrect']);

    typedLetterElem.classes.add(currentGuess.successful ?
        'correct' : 'incorrect');
    typedLetterElem.text = currentGuess.guessed;
    tardinessElem.text = currentGuess.duration.toStringAsFixed(3);
  }

  void updateTrainerWidth() {
    letterCount = int.parse(letterCountSelect.value);

    String boxWidth = letterCount.toString() +'.5em';
    playedLetterElem.style.width = boxWidth;
    typedLetterElem.style.width = boxWidth;
  }
}

class Guess {
  String expected;
  DateTime endOfSound;
  double duration = double.NAN;

  String guessed = '';
  bool aborted = false;

  Guess(this.expected, this.endOfSound);

  bool get successful => (expected == guessed);
  bool get completed => (aborted || guessed.length >= expected.length);
}

class Trainer {
  final double MU = 1.5;
  final double ALPHA = 0.5;
  final Random rng = new Random();
  final MorseAudio morseAudio = new MorseAudio(new AudioContext());

  String alphabet;
  int letterCount;

  Guess currentGuess;
  Map<String,double> letterDelayEMA = {};

  Trainer() {
    MorseCode.initShortCodes();
  }

  void skip() {
    onTypedLetter('');
  }

  void onTypedLetter(String typedLetter) {
    if (currentGuess == null) {
      return;
    }

    if (typedLetter == ' ') {
      currentGuess.aborted = true;
    } else {
      currentGuess.guessed += typedLetter.toUpperCase();
    }

    if (currentGuess.completed) {
      DateTime now = new DateTime.now();
      currentGuess.duration = max(0.0, now.difference(currentGuess.endOfSound).inMilliseconds.toDouble() / 1000.0);

      scoreGuess(currentGuess);

      currentGuess = null;
    }
  }

  void scoreGuess(Guess guess) {
    for (int i = 0; i < guess.guessed.length && i < guess.expected.length; ++i) {
      if (guess.guessed[i] == guess.expected[i]) {
        onCorrectAnswer(guess.guessed[i], guess.duration);
      } else {
        onMistake(guess.expected[i], guess.guessed[i], guess.duration);
      }
    }

    for (int i = guess.guessed.length; i < guess.expected.length; ++i) {
      onNotTyped(guess.expected[i]);
    }
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

  void onNotTyped(String letter) {
    if (letterDelayEMA.containsKey(letter)) {
      letterDelayEMA[letter] *= MU;
    }
  }

  void setLetterCount(int letterCount) {
    this.letterCount = letterCount;
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

  String chooseLetters() {
    String letters = '';
    for (int i = 0; i < letterCount; ++i) {
      letters += chooseLetter();
    }
    return letters;
  }

  Guess restart() {
    currentGuess = null;
    return playNew();
  }

  Guess playNew() {
    if (currentGuess == null) {
      String letters = chooseLetters();

      DateTime now = new DateTime.now();
      double duration = morseAudio.play(letters);

      int durationSec = duration.floor();
      int durationMillis = ((duration - durationSec)*1000).floor();

      // TODO(ivant): request Duration(double sec) constructor
      DateTime endOfSound = now.add(new Duration(
          seconds: durationSec,
          milliseconds: durationMillis
        ));

      currentGuess = new Guess(letters, endOfSound);
      return currentGuess;
    } else {
      return null;
    }
  }
}