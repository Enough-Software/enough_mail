import 'dart:io';
import 'dart:typed_data';

/// Simple IMAP mock server for testing purposes
class MockImapServer {
  final Socket _socket;

  String response;
  String _overrideTag;

  static MockImapServer connect(Socket socket) {
    return MockImapServer(socket);
  }

  MockImapServer(this._socket) {
    _socket.listen((data) {
      parseRequest(data);
    }, onDone: () {
      print('server connection done');
    }, onError: (error) {
      print('server error: $error');
    });
  }

  void parseRequest(Uint8List data) {
    var line = String.fromCharCodes(data);
    // print('C: $line');
    final firstSpaceIndex = line.indexOf(' ');
    var tag = firstSpaceIndex == -1 ? '' : line.substring(0, firstSpaceIndex);
    if (response != null) {
      if (response.startsWith('+')) {
        _overrideTag = tag;
        final splitIndex = response.indexOf('\r\n');
        final firstLine = response.substring(0, splitIndex + 2);
        response = response.substring(splitIndex + 2);
        write(firstLine);
        return;
      }
      if (_overrideTag != null) {
        tag = _overrideTag;
        _overrideTag = null;
      }
      final lines = response.replaceAll('<tag>', tag).split('\r\n');
      response = null;
      for (final line in lines) {
        writeln(line);
      }
      return;
    }
  }

  void writeln(String data) {
    write('$data\r\n');
  }

  void write(String data) {
    // print('S: $data');
    _socket.write(data);
  }

  void fire(Duration duration, String s) async {
    await Future.delayed(duration);
    write(s);
  }
}
