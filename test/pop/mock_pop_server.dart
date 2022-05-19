import 'dart:io';
// cSpell:disable

class MockPopServer {
  // ignore: avoid_unused_constructor_parameters
  MockPopServer(this._socket) {
    _socket.listen((data) {
      onRequest(String.fromCharCodes(data));
    }, onDone: () {
      print('server connection done');
    }, onError: (error) {
      print('server error: $error');
    });
  }

  String? nextResponse;
  List<String>? nextResponses;
  final Socket _socket;

  void onRequest(String request) {
    final response = nextResponse ??
        ((nextResponses?.isNotEmpty ?? false)
            ? nextResponses!.removeAt(0)
            : '-ERR no reponse defined');
    writeln(response);
    nextResponse = null;
  }

  void writeln(String? response) {
    _socket.writeln(response);
  }
}
