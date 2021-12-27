/// A word within another text
class Word {
  /// Creates a new word
  Word(this.text, this.startIndex);

  /// The word content
  String text;

  /// The index of the word in the parent text
  int startIndex;

  /// The end index of the work
  int get endIndex => startIndex + text.length;
}
