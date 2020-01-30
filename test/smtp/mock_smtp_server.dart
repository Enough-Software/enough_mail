import 'dart:io';

enum MailSendState { notStarted, rcptTo, data }

class MockSmtpServer {
  String nextResponse;
  final Socket _socket;
  final String _userName;
  final String _userPassword;
  MailSendState _sendState = MailSendState.notStarted;

  static MockSmtpServer connect(
      Socket socket, String userName, String userPassword) {
    return MockSmtpServer(socket, userName, userPassword);
  }

  MockSmtpServer(this._socket, this._userName, this._userPassword) {
    _socket.listen((data) {
      onRequest(String.fromCharCodes(data));
    }, onDone: () {
      print('server connection done');
    }, onError: (error) {
      print('server error: ' + error);
    });
  }

  void onRequest(String request) {
    // check for supported request:
    if (_sendState != MailSendState.notStarted ||
        request.startsWith('MAIL FROM:')) {
      onMailSendRequest(request);
      return;
    } else if (request == 'QUIT\r\n') {
      writeln('221 2.0.0 Bye');
    } else if (nextResponse == null || nextResponse.isEmpty) {
      // // no supported request found, answer with the pre-defined response:
      writeln('500 Invalid state - define nextResponse for MockSmtpServer');
    } else {
      writeln(nextResponse);
      nextResponse = null;
    }
  }

  void onMailSendRequest(String request) {
    if (_sendState == MailSendState.notStarted) {
      _sendState = MailSendState.rcptTo;
      writeln('250 2.1.0 Ok');
    } else if (_sendState == MailSendState.rcptTo) {
      if (request.startsWith('DATA')) {
        _sendState = MailSendState.data;
        writeln('354 End data with <CR><LF>.<CR><LF>');
      } else {
        writeln('250 2.1.5 Ok');
      }
    } else if (request.endsWith('\r\n.\r\n')) {
      _sendState = MailSendState.notStarted;
      writeln('250 2.0.0 Ok: queued as 66BF93C0360');
    }
  }

  void writeln(String response) {
    _socket.writeln(response);
  }
}
