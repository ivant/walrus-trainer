library letterchart;

import 'package:chart/chart.dart';
import 'dart:html';
import 'dart:math';

void plotLetterChart(Element container, Map<String,double> letterDelay) {
  List<String> keys = letterDelay.keys.toList();
  keys.sort((k1, k2) => letterDelaySortF(letterDelay, k1, k2));
  List<double> values = keys.map((k) => letterDelay[k]).toList();

  double valuesMax = maximum(values);

  Bar chart = new Bar({
      'labels' : keys,
      'datasets' : [{
          'fillColor' : "rgba(0,110,220,0.5)",
          'strokeColor' : "rgba(0,110,220,1)",
          'data' : values,
        }]
    },
    {
      'titleText' : 'Letter delays',
      'scaleOverride' : true,
      'scaleMinValue' : 0.0,
      'scaleMaxValue' : valuesMax,
//      'scaleStepValue' : stepWidth,
    });

  container.style.removeProperty('display');
  while (container.hasChildNodes()) {
    container.firstChild.remove();
  }

  DivElement chartContainer = new DivElement();
  container.append(chartContainer);
  chart.show(chartContainer);
}

int letterDelaySortF(Map<String,double> letterDelay, String k1, String k2) {
  double v1 = letterDelay[k1];
  double v2 = letterDelay[k2];
  if (v1 == v2) {
    return k1.compareTo(k2);
  } else {
    return v2.compareTo(v1);
  }
}

double maximum(Iterable<double> values) => values.reduce(max);