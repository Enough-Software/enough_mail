class Word {
  String text;
  int startIndex;
  int get endIndex => startIndex + text.length;

  Word(this.text, this.startIndex);
}