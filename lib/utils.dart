library utils;

import 'dart:math';

class Tuple<A, B> {
  A fst;
  B snd;

  Tuple(this.fst, this.snd);
  Tuple<B, A> swap() => new Tuple(snd, fst);
}

String pickRandom(String alphabetStr, Map<String, double> probabilities) {
  Iterable<String> alphabet = alphabetStr.runes.map((c) =>
      new String.fromCharCode(c));

  double sum = alphabet.fold(0.0, (v, letter) =>
      v + probabilities.putIfAbsent(letter, () => 0.0));
  double choice = new Random().nextDouble() * sum;

  for (String letter in alphabet) {
    double p = probabilities[letter];
    if (choice < p) {
      return letter;
    }
    choice -= p;
  }
  return alphabetStr[alphabetStr.length - 1];
}