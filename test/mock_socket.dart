import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

class MockConnection {
  MockSocket socketClient;
  MockSocket socketServer;

  MockConnection() {
    socketClient = MockSocket();
    socketServer = MockSocket();
    socketClient._other = socketServer;
    socketServer._other = socketClient;
  }
}

class MockSocket implements Socket {
  MockSocket _other;
  MockStreamSubscription _subscription;
  final Utf8Encoder _encoder = Utf8Encoder();
  static const String _CRLF = '\r\n';

  @override
  Encoding encoding;

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) {
    return null;
  }

  @override
  InternetAddress get address => null;

  @override
  Future<bool> any(bool Function(Uint8List element) test) {
    return null;
  }

  @override
  Stream<Uint8List> asBroadcastStream(
      {void Function(StreamSubscription<Uint8List> subscription) onListen,
      void Function(StreamSubscription<Uint8List> subscription) onCancel}) {
    return null;
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E> Function(Uint8List event) convert) {
    return null;
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Uint8List event) convert) {
    return null;
  }

  @override
  Stream<R> cast<R>() {
    return null;
  }

  @override
  Future close() {
    _subscription.handleDone();
    return null;
  }

  @override
  Future<bool> contains(Object needle) {
    return null;
  }

  @override
  void destroy() {}

  @override
  Stream<Uint8List> distinct(
      [bool Function(Uint8List previous, Uint8List next) equals]) {
    return null;
  }

  @override
  Future get done => null;

  @override
  Future<E> drain<E>([E futureValue]) {
    return null;
  }

  @override
  Future<Uint8List> elementAt(int index) {
    return null;
  }

  @override
  Future<bool> every(bool Function(Uint8List element) test) {
    return null;
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Uint8List element) convert) {
    return null;
  }

  @override
  Future<Uint8List> get first => null;

  @override
  Future<Uint8List> firstWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    return null;
  }

  @override
  Future flush() {
    return null;
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, Uint8List element) combine) {
    return null;
  }

  @override
  Future forEach(void Function(Uint8List element) action) {
    return null;
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    return null;
  }

  @override
  Stream<Uint8List> handleError(Function onError,
      {bool Function(dynamic) test}) {
    return null;
  }

  @override
  bool get isBroadcast => null;

  @override
  Future<bool> get isEmpty => null;

  @override
  Future<String> join([String separator = '']) {
    return null;
  }

  @override
  Future<Uint8List> get last => null;

  @override
  Future<Uint8List> lastWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    return null;
  }

  @override
  Future<int> get length => null;

  void onErrorImpl(dynamic error) {
    print('ON SOCKET ERROR');
  }

  void onDoneImpl() {
    print('ON SOCKET DONE');
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    onError ??= onErrorImpl;
    onDone ??= onDoneImpl;
    var subscription = MockStreamSubscription(onData, onError, onDone);
    _subscription = subscription;
    return subscription;
  }

  @override
  Stream<S> map<S>(S Function(Uint8List event) convert) {
    return null;
  }

  @override
  Future pipe(StreamConsumer<Uint8List> streamConsumer) {
    return null;
  }

  @override
  int get port => null;

  @override
  Future<Uint8List> reduce(
      Uint8List Function(Uint8List previous, Uint8List element) combine) {
    return null;
  }

  @override
  InternetAddress get remoteAddress => null;

  @override
  int get remotePort => null;

  @override
  bool setOption(SocketOption option, bool enabled) {
    return null;
  }

  @override
  void setRawOption(RawSocketOption option) {}

  @override
  Future<Uint8List> get single => null;

  @override
  Future<Uint8List> singleWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    return null;
  }

  @override
  Stream<Uint8List> skip(int count) {
    return null;
  }

  @override
  Stream<Uint8List> skipWhile(bool Function(Uint8List element) test) {
    return null;
  }

  @override
  Stream<Uint8List> take(int count) {
    return null;
  }

  @override
  Stream<Uint8List> takeWhile(bool Function(Uint8List element) test) {
    return null;
  }

  @override
  Stream<Uint8List> timeout(Duration timeLimit,
      {void Function(EventSink<Uint8List> sink) onTimeout}) {
    return null;
  }

  @override
  Future<List<Uint8List>> toList() {
    return null;
  }

  @override
  Future<Set<Uint8List>> toSet() {
    return null;
  }

  @override
  Stream<S> transform<S>(StreamTransformer<Uint8List, S> streamTransformer) {
    return null;
  }

  @override
  Stream<Uint8List> where(bool Function(Uint8List event) test) {
    return null;
  }

  @override
  void write(Object obj) {
    var text = obj.toString();
    var data = _encoder.convert(text);
    //print('socket: [$text]');
    // make the socket asynchronous.
    Timer.run(() => _other._subscription.handleData(data));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object obj = '']) {
    //print('writeln [$obj]');
    write(obj.toString() + _CRLF);
  }
}

class MockStreamSubscription extends StreamSubscription<Uint8List> {
  void Function(Uint8List data) handleData;
  Function handleError;
  void Function() handleDone;

  MockStreamSubscription(this.handleData, this.handleError, this.handleDone);

  @override
  Future<E> asFuture<E>([E futureValue]) {
    return null;
  }

  @override
  Future cancel() {
    return null;
  }

  @override
  bool get isPaused => null;

  @override
  void onData(void Function(Uint8List data) handleData) {
    this.handleData = handleData;
  }

  @override
  void onDone(void Function() handleDone) {
    this.handleDone = handleDone;
  }

  @override
  void onError(Function handleError) {
    this.handleError = handleError;
  }

  @override
  void pause([Future resumeSignal]) {}

  @override
  void resume() {}
}
