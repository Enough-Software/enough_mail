/// Helps with byte arrays
class ByteUtils {
  /// Finds a [sequence] of bytes into a [pool],
  /// returns the starting position or -1 if not found.
  static int findSequence(final List<int> pool, final List<int> sequence) {
    // The pool size is reduced by the sequence length to
    // avoid the eventual overflow
    final dataSize = pool.length - sequence.length;
    final needleSize = sequence.length;
    var result = -1;
    for (var pos = 0; pos < dataSize; pos++) {
      var matchFound = true;
      for (var j = 0; j < needleSize; j++) {
        if (pool[pos + j] != sequence[j]) {
          matchFound = false;
          break;
        }
      }
      if (matchFound) {
        result = pos;
        break;
      }
    }
    return result;
  }
}
