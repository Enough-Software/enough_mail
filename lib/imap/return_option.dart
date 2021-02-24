/// Return option definition for extended commands.
class ReturnOption {
  final String name;

  /// Optional list of return option parameters.
  final List<String> _parameters;

  ReturnOption(this.name, [this._parameters]);

  /// Returns the minimum message id or UID that satisfies the search parameters.
  ReturnOption.min() : this('MIN');

  /// Return the maximum message id or UID that satisfies the search parameters.
  ReturnOption.max() : this('MAX');

  /// Returns all the message ids or UIDs that satisfies the search parameters.
  ReturnOption.all() : this('ALL');

  /// Returns the match count of the search request.
  ReturnOption.count() : this('COUNT');

  void add(String parameter) {
    _parameters?.add(parameter);
  }

  void addAll(List<String> parameters) {
    _parameters?.addAll(parameters);
  }

  bool hasParameter(String parameter) =>
      _parameters?.contains(parameter) ?? false;

  @override
  String toString() {
    final result = StringBuffer(name);
    if (_parameters != null && _parameters.isNotEmpty) {
      result..write(' (')..write(_parameters.join(' '))..write(')');
    }
    return result.toString();
  }
}
