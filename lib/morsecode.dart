library morsecode;

import 'dart:core';

class MorseCode {
  static final List<String> morseOrder = [
    // 1 dot/dash
    'e', 't',
    // 2 dots/dashes
    'i', 'a', 'n', 'm',
    // 3 dots/dashes
    's', 'u', 'r', 'w', 'd', 'k', 'g', 'o',
    // 4 dots/dashes
    'h', 'v', 'f', 'ü', 'l', 'ä', 'p', 'j', 'b', 'x', 'c', 'y', 'z', 'q', 'ö', 'ch',
    // 5 dots/dashes
    '5', '4', ' ', '3', 'é', '¿', ' ', '2', '&', '#', '+', ' ', '%', 'à', ' ', '1',
    '6', '=', '/', ' ', 'ç', ' ', '(', ' ', '7', ' ', ' ', 'ñ', '8', ' ', '9', '0',
  ];
  static final Map<String, String> longCodes = {
    '.' : '.-.-.-',
    ',' : '--..--',
    ':' : '---...',
    ';' : '-.-.-.',
    '?' : '..--..',
    '!' : '-.-.--',
    '-' : '-....-',
    '_' : '..--.-',
    '"' : '.-..-.',
    '\'' : '.----.',
    '@' : '.--.-.',
    ')' : '-.--.-',
    '¡' : '--...-',
    '\$' : '...-..-',
  };
  static final Map<String, String> prosigns = {
    'SN' : '...-.',     // Understood.
    'CT' : '-.-.-',     // Start.
    'AR' : '.-.-.',     // Stop (EOM). Same as '+'.
    'AS' : '.-...',     // Wait. Same as '&'.
    'BK' : '-...-.-',   // Break.
    'CL' : '-.-..-..',  // Closing down.
    'KN' : '-.--.',     // Invitation to a specific named station to transmit. Same as '('.
    'SK' : '...-.-',    // End of contact.
    'SOS' : '...---...',
    'EEEEEEEE' : '........',
  };
  static Map<String, String> shortCodes = null;

  static void initShortCodes() {
    if (shortCodes != null) {
      return;
    }
    Map<String, String> sc = {};
    for (int i = 0; i < morseOrder.length; ++i) {
      int letterEncoding = i + 2;
      String morse = '';
      while (letterEncoding > 1) {
        morse = (letterEncoding & 1 == 0 ? '.' : '-') + morse;
        letterEncoding >>= 1;
      }
      sc[morseOrder[i]] = morse;
    }
    shortCodes = sc;
  }

  static String encodeElement(String elem) {
    initShortCodes();
    String s = null;
    return (s = shortCodes[elem]) != null ? s : (
           (s = longCodes[elem]) != null ? s : (
           (s = prosigns[elem]) != null ? s : ''));
  }

  // returns a list of morse code sequences, one per word character
  static List<String> encodeWord(String word) {
    return word.toLowerCase().runes.map((r) =>
        encodeElement(new String.fromCharCode(r))
      ).toList();
  }

  //returns a list of encodeWord results, one per word
  static List<List<String>> encodeText(String text) {
    List<String> words = text.split(r'\s+');
    return words.map(encodeWord).toList();
  }
}
