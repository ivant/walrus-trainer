import 'package:unittest/unittest.dart';

import '../lib/utils.dart';
import 'dart:math';

void main() {
  test("pickRandom produces expected distribution", checkPickRandomFit);
}

void checkPickRandomFit() {
  Map<String, double> prob = {
    '1' : 1.0,
    '2' : 2.0,
    '3' : 3.0,
    '4' : 4.0,
    '5' : 5.0
  };
  String alphabet = prob.keys.join('');

  double sum = prob.values.fold(0.0, (s, v) => s + v);
  Map<String, double> probD = {};
  prob.forEach((k, v) => probD[k] = v / sum);

  Map<String, int> counts = {};
  prob.forEach((k, v) => counts[k] = 0);

  int N = 100000;
  for (int i = 0; i < N; ++i) {
    String c = pickRandom(alphabet, prob);
    counts[c]++;
  }

  double chiSquared = 0.0;
  counts.forEach((k, observed) {
    double expected = N.toDouble() * probD[k];
    chiSquared += pow((observed.toDouble() - expected), 2.0) / expected;
  });
  expect(chiSquared, lessThan(13.277));
}