/// A typed stack of elements
class StackList<T> {
  final List<T> _elements = <T>[];

  /// Adds the [value] on top of the stack
  void put(T value) {
    _elements.add(value);
  }

  /// Retrieves the last added element without changing the stack
  T? peek() {
    if (_elements.isEmpty) {
      return null;
    }
    return _elements.last;
  }

  /// Removes the last added element from the stack
  T? pop() {
    if (_elements.isEmpty) {
      return null;
    }
    return _elements.removeLast();
  }

  /// Returns `true` when the stack has elements
  bool get isNotEmpty => _elements.isNotEmpty;

  /// Returns `true` when the stack has no elements
  bool get isEmpty => _elements.isEmpty;

  @override
  String toString() => _elements.toString();
}
