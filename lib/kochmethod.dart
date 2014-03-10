library kochmethod;

import 'dart:collection';
import 'dart:html';

class KochMethod {
  static List<String> levels = [
    'KM',
    'RS',
    'UA',
    'PT',
    'LO',
    'WI',
    '.N',
    'JE',
    'F0',
    'Y,',
    'VG',
    '5/',
    'Q9',
    'ZH',
    '38',
    'B?',
    '42',
    '7C',
    '1D',
    '6X'
  ];

  static void populateSelectWithLevels(SelectElement select, List<int> selectedLevels) {
    Set<int> selectedLevelsSet = new HashSet<int>.from(selectedLevels);

    select.childNodes.toList().forEach((Node n) => n.remove());
    select.setAttribute("size", levels.length.toString());

    for (int i = 0; i < levels.length; ++i) {
      OptionElement option = new OptionElement(
          data: "${i+1}: ${levels[i][0]} ${levels[i][1]}",
          value: i.toString(),
          selected: selectedLevelsSet.contains(i));
      select.append(option);
    }
  }

  static String getAlphabet(SelectElement select) {
    return select.selectedOptions.map((OptionElement e) =>
        levels[int.parse(e.value)]).join();
  }
}
