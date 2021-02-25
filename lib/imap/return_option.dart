/// Return option definition for extended commands.
class ReturnOption {
  final String name;

  /// Optional list of return option parameters.
  final List<String> _parameters;

  /// If set, the option allows only one parameter not enclosed by "()".
  final bool _isSingleParam;

  ReturnOption(this.name, [this._parameters, this._isSingleParam = false]);

  ReturnOption.specialUse() : this('SPECIAL-USE');

  /// Returns subscription state of all matching mailbox names.
  ReturnOption.subscribed() : this('SUBSCRIBED');

  /// Returns mailbox child information as flags "\HasChildren", "\HasNoChildren".
  ReturnOption.children() : this('CHILDREN');

  /// Returns given STATUS informations of all matching mailbox names.
  /// A number of [attributes] must be provided for returning their status.
  ReturnOption.status([List<String> parameters]) : this('STATUS', parameters);

  /// Returns the minimum message id or UID that satisfies the search parameters.
  ReturnOption.min() : this('MIN');

  /// Return the maximum message id or UID that satisfies the search parameters.
  ReturnOption.max() : this('MAX');

  /// Returns all the message ids or UIDs that satisfies the search parameters.
  ReturnOption.all() : this('ALL');

  /// Returns the match count of the search request.
  ReturnOption.count() : this('COUNT');

  /// Defines a partial range of the found results.
  ReturnOption.partial(String rangeSet) : this('PARTIAL', [rangeSet], true);

  void add(String parameter) {
    if (_parameters == null) {
      throw StateError('$name return option doesn\'t allow any parameter');
    }
    if (_isSingleParam && _parameters.isNotEmpty) {
      _parameters.replaceRange(0, 0, [parameter]);
    } else {
      _parameters.add(parameter);
    }
  }

  void addAll(List<String> parameters) {
    if (_parameters == null) {
      throw StateError('$name return option doesn\'t allow any parameter');
    }
    if (_isSingleParam && parameters.length > 1) {
      throw StateError('$name return options allows only one parameter');
    }
    _parameters.addAll(parameters);
  }

  bool hasParameter(String parameter) =>
      _parameters?.contains(parameter) ?? false;

  @override
  String toString() {
    final result = StringBuffer(name);
    if (_parameters != null) {
      if (_isSingleParam && _parameters.isNotEmpty) {
        result..write(' ')..write(_parameters[0]);
      } else if (_parameters.isNotEmpty) {
        result..write(' (')..write(_parameters.join(' '))..write(')');
      }
    }
    return result.toString();
  }
}
