import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';
import 'dart:web_audio';
import '../lib/kochmethod.dart';
import '../lib/letterchart.dart';
import '../lib/morsecode.dart';
import '../lib/morseaudio.dart';
import '../lib/utils.dart';

void main() {
  new TrainerUI();
}

class TrainerUI {
  SelectElement levelSelect;
  TextInputElement alphabetElem;
  SelectElement letterCountSelect;
  SelectElement speedSelect;
  ButtonElement startStopButton;
  Element playedLetterElem;
  Element typedLetterElem;
  Element letterChart;

  Trainer trainer = new Trainer();
  Guess currentGuess = null;

  int letterCount = 1;

  bool started = false;

  final String LS_ALPHABET = "alphabet";
  final String LS_LEVEL_SELECT = "levelSelect";
  final String LS_LETTER_COUNT = "trainerWidth";
  final String LS_WPM = "wpm";

  TrainerUI() {
    levelSelect = querySelector("#level");
    alphabetElem = querySelector("#alphabet");
    letterCountSelect = querySelector("#letterCount");
    speedSelect = querySelector("#speed");
    startStopButton = querySelector("#startStopButton");
    playedLetterElem = querySelector("#playedLetter");
    typedLetterElem = querySelector("#typedLetter");
    letterChart = querySelector("#letterChart");

    assert(levelSelect != null);
    assert(alphabetElem != null);
    assert(letterCountSelect != null);
    assert(speedSelect != null);
    assert(startStopButton != null);
    assert(playedLetterElem != null);
    assert(typedLetterElem != null);
    assert(letterChart != null);

    loadLevelSelect();
    loadSpeedSelect();
    loadAlphabet();
    loadLetterCount();
    updateLetterCount();

    levelSelect.onChange.listen((e) => updateLevelSelect());
    speedSelect.onChange.listen((e) => updateSpeedSelect());
    alphabetElem.onChange.listen((e) => updateAlphabet());
    letterCountSelect.onChange.listen((e) => updateLetterCount());
    startStopButton.onClick.listen((d) => startStopClicked());
    document.onKeyUp.listen(onKeyUp);
    startStopButton.focus();
  }

  void loadLevelSelect() {
    String indicesJson = window.localStorage[LS_LEVEL_SELECT];
    List<int> indices = [];
    if (indicesJson != null) {
      try {
        JsonDecoder decoder = new JsonDecoder(null);
        indices = decoder.convert(indicesJson);
        indices.forEach((int i) {
          if (i < 0 || i >= levelSelect.length) {
            throw new Exception("Wrong selected level index: ${i}");
          }
        });
      } catch (e) {
        window.localStorage.remove(LS_LEVEL_SELECT);
      }
    }
    if (indices.length == 0) {
      indices = [0, 1, 2, 3, 4];
    }
    KochMethod.populateSelectWithLevels(levelSelect, indices);
  }

  void loadSpeedSelect() {
    String speedStr = window.localStorage[LS_WPM];
    int speed = 20;
    if (speedStr != null) {
      try {
        speed = int.parse(speedStr);
      } catch (e) {
      }
    }
    for (int i = 0; i < speedSelect.options.length; ++i) {
      if (speedSelect.options[i].value == speed.toString()) {
        speedSelect.options[i].selected = true;
        break;
      }
    }
    trainer.setWpm(speed);
  }

  void loadAlphabet() {
    String alphabet = window.localStorage[LS_ALPHABET];
    if (alphabet == null) {
      alphabet = KochMethod.getAlphabet(levelSelect);
    }
    alphabetElem.value = alphabet;
  }

  void loadLetterCount() {
    String letterCountStr = window.localStorage[LS_LETTER_COUNT];
    int selected = 3;
    if (letterCountStr != null) {
      try {
        selected = int.parse(letterCountStr);
      } catch (e) {
      }
    }
    letterCountSelect.options[letterCountSelect.selectedIndex].selected = false;
    letterCountSelect.options[selected].selected = true;
  }

  void updateLevelSelect() {
    alphabetElem.value = KochMethod.getAlphabet(levelSelect);

    window.localStorage[LS_ALPHABET] = alphabetElem.value;

    List<int> indices = levelSelect.selectedOptions.map((o) => o.index).toList();
    JsonEncoder encoder = new JsonEncoder(null);
    window.localStorage[LS_LEVEL_SELECT] = encoder.convert(indices);
  }

  void updateAlphabet() {
    window.localStorage[LS_ALPHABET] = alphabetElem.value;
  }

  void updateLetterCount() {
    letterCount = int.parse(letterCountSelect.value);
    window.localStorage[LS_LETTER_COUNT] = (letterCount - 1).toString();

    String boxWidth = letterCount.toString() +'.5em';
    playedLetterElem.style.width = boxWidth;
    typedLetterElem.style.width = boxWidth;

    playedLetterElem.text = "";
    typedLetterElem.text = "";
  }

  void updateSpeedSelect() {
    int speed = int.parse(speedSelect.value);
    window.localStorage[LS_WPM] = speed.toString();
    trainer.setWpm(speed);
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
    speedSelect.disabled = !enabled;
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

    playedLetterElem.text = "";
    typedLetterElem.text = "";

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
      trainer.scoreGuess(currentGuess);
    }

    updateView();

    if (currentGuess.completed) {
      currentGuess = trainer.playNew();
    }
  }

  static String repeatString(String foo, int count) {
    return new List<String>.filled(count, foo).join();
  }

  void updateView() {
    typedLetterElem.classes.removeAll(['correct', 'incorrect']);

    if (!currentGuess.completed) {
      playedLetterElem.style.color = '#888';
    } else {
      playedLetterElem.style.removeProperty('color');
      playedLetterElem.text = currentGuess.expected;

      typedLetterElem.classes.add(currentGuess.successful ?
         'correct' : 'incorrect');
    }

    typedLetterElem.text = currentGuess.guessed +
        repeatString('·', letterCount - currentGuess.guessed.length);

    if (currentGuess.completed) {
     updateLetterChart();
    }
  }

  void updateLetterChart() {
    plotLetterChart(letterChart, trainer.letterDelayEMA);
  }
}

class Guess {
  final String expected;
  final double startTime;
  final List<double> letterEndTimestamps;
  List<double> guessesTimestamps = [];

  String guessed = '';
  bool aborted = false;

  Guess(this.expected, this.startTime, this.letterEndTimestamps);

  bool get successful => (expected == guessed);
  bool get completed => (aborted || guessed.length >= expected.length);

  void nextLetterGuess(String letter, double timestamp) {
    guessed += letter;
    guessesTimestamps.add(timestamp);
  }

  List<double> getDurations() {
    List<double> durations = [];
    for (int i = 0; i < guessesTimestamps.length; ++i) {
      durations.add(max(0, guessesTimestamps[i] - letterEndTimestamps[i]));
    }
    return durations;
  }
}

class Trainer {
  final double MU = 1.5;
  final double ALPHA = 0.5;
  final Random rng = new Random();
  final MorseAudio morseAudio = new MorseAudio(new AudioContext());

  String alphabet;
  int letterCount;

  Guess currentGuess;

  final String LS_KEY_LETTER_DELAY_EMA = "letterDelayEMA";
  Map<String, double> letterDelayEMA;

  Trainer() {
    MorseCode.initShortCodes();
    letterDelayEMA = loadLetterDelays();
  }

  void setWpm(num wpm) {
    morseAudio.setWpm(wpm);
  }

  Map<String, double> loadLetterDelays() {
    String letterDelayJSON = window.localStorage[LS_KEY_LETTER_DELAY_EMA];
    if (letterDelayJSON != null) {
      JsonDecoder decoder = new JsonDecoder(null);
      try {
        Map<String, double> result = decoder.convert(letterDelayJSON);
        // validate data
        result.forEach((String key, double value) {
            if (MorseCode.encodeElement(key) == '') {
              throw new Exception("unsupported key ${key}");
            }
            if (value <= 0.0 || !value.isFinite) {
              throw new Exception("unsupported value ${value.toString()}");
            }
        });
        return result;
      } catch (e) {
        window.localStorage.remove(LS_KEY_LETTER_DELAY_EMA);
      }
    }
    return <String, double>{};
  }

  void saveLetterDelays() {
    JsonEncoder encoder = new JsonEncoder(null);
    window.localStorage[LS_KEY_LETTER_DELAY_EMA] =
        encoder.convert(letterDelayEMA);
  }

  void skip() {
    onTypedLetter(' ');
  }

  void onTypedLetter(String typedLetter) {
    double now = morseAudio.currentTime();

    if (currentGuess == null) {
      return;
    }

    if (typedLetter == ' ') {
      currentGuess.aborted = true;
    } else {
      currentGuess.nextLetterGuess(typedLetter.toUpperCase(), now);
    }
  }

  void scoreGuess(Guess guess) {
    assert(guess.completed);

    List<double> durations = guess.getDurations();

    assert(durations.length == guess.guessed.length);
    assert(guess.guessed.length <= guess.expected.length);

    for (int i = 0; i < durations.length; ++i) {
      if (guess.guessed[i] == guess.expected[i]) {
        onCorrectAnswer(guess.guessed[i], durations[i]);
      } else {
        onMistake(guess.expected[i], guess.guessed[i], durations[i]);
      }
    }

    for (int i = durations.length; i < guess.expected.length; ++i) {
      onNotTyped(guess.expected[i]);
    }

    saveLetterDelays();
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
    String letters = chooseLetters();

    Tuple<double, Iterable<double>> timestampsTuple = morseAudio.play(letters);
    double startTime = timestampsTuple.fst;
    List<double> letterEndTimestamps = timestampsTuple.snd;

    this.currentGuess = new Guess(letters, startTime, letterEndTimestamps);
    return this.currentGuess;
  }
}
