import '../../imap/namespace.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'imap_response_line.dart';
import 'response_parser.dart';

/// Parses IMAP NAMESPACE responses,
/// compare [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342).
///
/// The formal syntax is
/// ```
/// Namespace_Response = "*" SP "NAMESPACE" SP Namespace SP Namespace
///                      SP Namespace
/// Namespace = nil / "(" 1*( "(" string SP (DQUOTE QUOTED_CHAR DQUOTE / nil)
///             *(Namespace_Response_Extension) ")" ) ")"
/// Namespace_Response_Extension = SP string SP "(" string *(SP string) ")"
/// ```
/// Prefixes and extension values are IMAP strings, so they may arrive as
/// literals; the parser tokenizes the response line by line to keep a
/// literal's bytes as one token.
class NamespaceParser extends ResponseParser<NamespaceResponse?> {
  NamespaceResponse? _response;

  @override
  NamespaceResponse? parse(
    ImapResponse imapResponse,
    Response<NamespaceResponse?> response,
  ) => response.isOkStatus ? _response : null;

  @override
  bool parseUntagged(
    ImapResponse imapResponse,
    Response<NamespaceResponse?>? response,
  ) {
    final text = imapResponse.first.line ?? '';
    final start = text.startsWith('* NAMESPACE ')
        ? '* NAMESPACE '.length
        : text.startsWith('NAMESPACE ')
        ? 'NAMESPACE '.length
        : -1;
    if (start == -1) {
      return super.parseUntagged(imapResponse, response);
    }
    final parsed = parseNamespaceResponse(imapResponse, start);
    if (parsed == null) {
      return false;
    }
    _response = parsed;

    return true;
  }

  /// Parses the namespace response contained in [imapResponse], skipping
  /// the first [offset] characters of its first line.
  ///
  /// Returns `null` when the response does not follow the RFC 2342 syntax.
  static NamespaceResponse? parseNamespaceResponse(
    ImapResponse imapResponse,
    int offset,
  ) {
    final tokens = _tokenize(imapResponse.lines, offset);
    if (tokens == null) {
      return null;
    }
    final reader = _TokenReader(tokens);
    final personal = reader.readNamespaces();
    final otherUsers = reader.readNamespaces();
    final shared = reader.readNamespaces();
    if (personal == null ||
        otherUsers == null ||
        shared == null ||
        !reader.isDone) {
      return null;
    }

    return NamespaceResponse(
      personal: personal,
      otherUsers: otherUsers,
      shared: shared,
    );
  }

  /// Tokenizes [lines] into parentheses, `NIL` atoms and strings.
  ///
  /// A line that announces a literal is followed by a raw line holding the
  /// literal's bytes, which become one string token.
  static List<_Token>? _tokenize(List<ImapResponseLine> lines, int offset) {
    final tokens = <_Token>[];
    var expectLiteral = false;
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (expectLiteral) {
        tokens.add(_Token.string(line.line ?? ''));
        expectLiteral = false;
        continue;
      }
      final text = line.line ?? '';
      var index = lineIndex == 0 ? offset : 0;
      while (index < text.length) {
        final char = text[index];
        if (char == ' ') {
          index++;
        } else if (char == '(' || char == ')') {
          tokens.add(_Token.paren(char));
          index++;
        } else if (char == '"') {
          final buffer = StringBuffer();
          index++;
          var closed = false;
          while (index < text.length) {
            final c = text[index];
            if (c == r'\' && index + 1 < text.length) {
              buffer.write(text[index + 1]);
              index += 2;
            } else if (c == '"') {
              closed = true;
              index++;
              break;
            } else {
              buffer.write(c);
              index++;
            }
          }
          if (!closed) {
            return null;
          }
          tokens.add(_Token.string(buffer.toString()));
        } else {
          final start = index;
          while (index < text.length &&
              text[index] != ' ' &&
              text[index] != '(' &&
              text[index] != ')') {
            index++;
          }
          // Strings are quoted or literals; the only bare atom is NIL.
          if (text.substring(start, index).toUpperCase() != 'NIL') {
            return null;
          }
          tokens.add(_Token.nil());
        }
      }
      if (line.isWithLiteral) {
        expectLiteral = true;
      }
    }
    if (expectLiteral) {
      return null;
    }

    return tokens;
  }
}

enum _TokenType { open, close, nil, string }

class _Token {
  _Token.paren(String char)
    : type = char == '(' ? _TokenType.open : _TokenType.close,
      value = null;

  _Token.nil() : type = _TokenType.nil, value = null;

  _Token.string(this.value) : type = _TokenType.string;

  final _TokenType type;
  final String? value;
}

class _TokenReader {
  _TokenReader(this._tokens);

  final List<_Token> _tokens;
  int _index = 0;

  bool get isDone => _index >= _tokens.length;

  _Token? get _peek => isDone ? null : _tokens[_index];

  bool _accept(_TokenType type) {
    if (_peek?.type == type) {
      _index++;

      return true;
    }

    return false;
  }

  String? _readString() {
    final token = _peek;
    if (token?.type != _TokenType.string) {
      return null;
    }
    _index++;

    return token?.value;
  }

  /// Reads one `Namespace` production: `NIL` or a parenthesized list of
  /// at least one namespace. Returns `null` on a syntax error.
  List<Namespace>? readNamespaces() {
    if (_accept(_TokenType.nil)) {
      return const [];
    }
    if (!_accept(_TokenType.open)) {
      return null;
    }
    final namespaces = <Namespace>[];
    while (_accept(_TokenType.open)) {
      final prefix = _readString();
      if (prefix == null) {
        return null;
      }
      String? delimiter;
      if (!_accept(_TokenType.nil)) {
        delimiter = _readString();
        if (delimiter == null) {
          return null;
        }
      }
      final extensions = <String, List<String>>{};
      while (_peek?.type == _TokenType.string) {
        final name = _readString()!;
        if (!_accept(_TokenType.open)) {
          return null;
        }
        final values = <String>[];
        while (_peek?.type == _TokenType.string) {
          values.add(_readString()!);
        }
        if (!_accept(_TokenType.close)) {
          return null;
        }
        extensions[name] = values;
      }
      if (!_accept(_TokenType.close)) {
        return null;
      }
      namespaces.add(
        Namespace(
          encodedPrefix: prefix,
          delimiter: delimiter,
          extensions: extensions,
        ),
      );
    }
    if (namespaces.isEmpty || !_accept(_TokenType.close)) {
      return null;
    }

    return namespaces;
  }
}
