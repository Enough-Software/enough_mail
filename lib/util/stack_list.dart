class StackList<T> {
  final List<T> _elements = <T>[];

  void put(T value) {
    _elements.add(value);
  }

  T peek() {
    if (_elements.isEmpty) {
      return null;
    }
    return _elements.last;
  }

  T pop() {
    if (_elements.isEmpty) {
      return null;
    }
    return _elements.removeLast();
  }

  bool get isNotEmpty => _elements.isNotEmpty;

  bool get isEmpty => _elements.isEmpty;

  @override
  String toString() {
    return _elements.toString();
  }

}