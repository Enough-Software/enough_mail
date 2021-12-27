import 'dart:io';

enum _MailSendState { notStarted, rcptTo, data, bdat }

class MockSmtpServer {
  // ignore: avoid_unused_constructor_parameters
  MockSmtpServer(this._socket, String? userName, String? userPassword) {
    _socket.listen((data) {
      onRequest(String.fromCharCodes(data));
    }, onDone: () {
      print('server connection done');
    }, onError: (error) {
      print('server error: $error');
    });
  }

  String? nextResponse;
  final Socket _socket;

  _MailSendState _sendState = _MailSendState.notStarted;

  void onRequest(String request) {
    // check for supported request:
    // print('onMockRequest "$request"');
    if (_sendState != _MailSendState.notStarted ||
        request.startsWith('MAIL FROM:')) {
      onMailSendRequest(request);
      return;
    } else if (request == 'QUIT\r\n') {
      writeln('221 2.0.0 Bye');
    } else if (nextResponse == null || nextResponse!.isEmpty) {
      // // no supported request found, answer with the pre-defined response:
      writeln('500 Invalid state - define nextResponse for MockSmtpServer');
    } else {
      writeln(nextResponse);
      nextResponse = null;
    }
  }

  void onMailSendRequest(String request) {
    if (_sendState == _MailSendState.notStarted) {
      _sendState = _MailSendState.rcptTo;
      writeln('250 2.1.0 Ok');
    } else if (_sendState == _MailSendState.rcptTo) {
      if (request.startsWith('DATA')) {
        _sendState = _MailSendState.data;
        writeln('354 End data with <CR><LF>.<CR><LF>');
      } else if (request.startsWith('BDAT')) {
        if (request.contains('LAST\r\n')) {
          _sendState = _MailSendState.notStarted;
          writeln('250 2.0.0 Ok: queued as 66BF93C0360');
        } else {
          _sendState = _MailSendState.bdat;
          writeln('354 continue');
        }
      } else {
        writeln('250 2.1.5 Ok');
      }
    } else if (_sendState == _MailSendState.data) {
      if (request.endsWith('\r\n.\r\n')) {
        _sendState = _MailSendState.notStarted;
        writeln('250 2.0.0 Ok: queued as 66BF93C0360');
      } else {
        writeln('354 continue');
      }
    } else if (_sendState == _MailSendState.bdat) {
      if (request.contains('LAST\r\n')) {
        _sendState = _MailSendState.notStarted;
        writeln('250 2.0.0 Ok: queued as 66BF93C0360');
      } else {
        writeln('354 continue');
      }
    }
  }

  void writeln(String? response) {
    _socket.writeln(response);
  }
}
