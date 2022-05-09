import '../exception.dart';

/// Return option definition for extended commands.
class ReturnOption {
  /// Creates a new return option
  ReturnOption(this.name, {this.parameters, this.isSingleParam = false});

  /// Creates a new return option
  ReturnOption.specialUse() : this('SPECIAL-USE');

  /// Returns subscription state of all matching mailbox names.
  ReturnOption.subscribed() : this('SUBSCRIBED');

  /// Returns mailbox child information as flags "\HasChildren",
  /// "\HasNoChildren".
  ReturnOption.children() : this('CHILDREN');

  /// Returns given STATUS information of all matching mailbox names.
  ///
  /// A number of [parameters] must be provided for returning their status.
  ReturnOption.status([List<String>? parameters])
      : this(
          'STATUS',
          parameters: parameters,
        );

  /// Returns the minimum message id or UID satisfying the search parameters.
  ReturnOption.min() : this('MIN');

  /// Return the maximum message id or UID that satisfies the search parameters.
  ReturnOption.max() : this('MAX');

  /// Returns all the message ids or UIDs that satisfies the search parameters.
  ReturnOption.all() : this('ALL');

  /// Returns the match count of the search request.
  ReturnOption.count() : this('COUNT');

  /// Defines a partial range of the found results.
  ReturnOption.partial(String rangeSet)
      : this(
          'PARTIAL',
          parameters: [rangeSet],
          isSingleParam: true,
        );

  /// The name of this option
  final String name;

  /// Optional list of return option parameters.
  final List<String>? parameters;

  /// If set, the option allows only one parameter not enclosed by "()".
  final bool isSingleParam;

  /// Adds the given [parameter]
  void add(String parameter) {
    final parameters = this.parameters;
    if (parameters == null) {
      throw InvalidArgumentException(
          '$name return option doesn\'t allow any parameter');
    }
    if (isSingleParam && parameters.isNotEmpty) {
      parameters.replaceRange(0, 0, [parameter]);
    } else {
      parameters.add(parameter);
    }
  }

  /// Adds all parameters
  void addAll(List<String> parameters) {
    final parameters = this.parameters;

    if (parameters == null) {
      throw InvalidArgumentException(
          '$name return option doesn\'t allow any parameter');
    }
    if (isSingleParam && parameters.length > 1) {
      throw InvalidArgumentException(
          '$name return options allows only one parameter');
    }
    parameters.addAll(parameters);
  }

  /// Checks of this return options has the specified [parameter]
  bool hasParameter(String parameter) =>
      parameters?.contains(parameter) ?? false;

  @override
  String toString() {
    final result = StringBuffer(name);
    final parameters = this.parameters;
    if (parameters != null) {
      if (isSingleParam && parameters.isNotEmpty) {
        result
          ..write(' ')
          ..write(parameters[0]);
      } else if (parameters.isNotEmpty) {
        result
          ..write(' (')
          ..write(parameters.join(' '))
          ..write(')');
      }
    }
    return result.toString();
  }
}
