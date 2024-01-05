/// Extracts the value or throws an [ArgumentError] if the value is `null`.
T toValueOrThrow<T>(
  T? value,
  String reason,
) =>
    value.toValueOrThrow(reason);

/// Allows to extract the non-nullable value or throws an [ArgumentError] if the
/// value is `null`.
extension ValueExtension<T> on T? {
  /// Extracts the value or throws an [ArgumentError] if the value is `null`.
  T toValueOrThrow(
    String reason,
  ) {
    final value = this;
    if (value == null) {
      throw ArgumentError(reason);
    }

    return value;
  }
}
