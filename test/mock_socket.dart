import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

class MockConnection {
  final MockSocket socketClient;
  final MockSocket socketServer;

  MockConnection()
      : socketClient = MockSocket(),
        socketServer = MockSocket() {
    socketClient._other = socketServer;
    socketServer._other = socketClient;
  }
}

class MockSocket implements Socket {
  MockSocket? _other;
  late MockStreamSubscription _subscription;
  final Utf8Encoder _encoder = Utf8Encoder();
  static const String _CRLF = '\r\n';

  @override
  late Encoding encoding;

  @override
  void add(List<int> data) {
    Timer.run(() => _other!._subscription.handleData!(data as Uint8List));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) {
    throw UnimplementedError();
  }

  @override
  InternetAddress get address => throw UnimplementedError();

  @override
  Future<bool> any(bool Function(Uint8List element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> asBroadcastStream(
      {void Function(StreamSubscription<Uint8List> subscription)? onListen,
      void Function(StreamSubscription<Uint8List> subscription)? onCancel}) {
    throw UnimplementedError();
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Uint8List event) convert) {
    throw UnimplementedError();
  }

  @override
  Stream<R> cast<R>() {
    throw UnimplementedError();
  }

  @override
  Future close() {
    _subscription.handleDone!();
    return Future.value();
  }

  @override
  Future<bool> contains(Object? needle) {
    throw UnimplementedError();
  }

  @override
  void destroy() {}

  @override
  Stream<Uint8List> distinct(
      [bool Function(Uint8List previous, Uint8List next)? equals]) {
    throw UnimplementedError();
  }

  @override
  Future get done => throw UnimplementedError();

  @override
  Future<E> drain<E>([E? futureValue]) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> elementAt(int index) {
    throw UnimplementedError();
  }

  @override
  Future<bool> every(bool Function(Uint8List element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Uint8List element) convert) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> get first => throw UnimplementedError();

  @override
  Future<Uint8List> firstWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Future flush() {
    return Future.value();
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, Uint8List element) combine) {
    throw UnimplementedError();
  }

  @override
  Future forEach(void Function(Uint8List element) action) {
    throw UnimplementedError();
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> handleError(Function onError,
      {bool Function(dynamic)? test}) {
    throw UnimplementedError();
  }

  @override
  bool get isBroadcast => throw UnimplementedError();

  @override
  Future<bool> get isEmpty => throw UnimplementedError();

  @override
  Future<String> join([String separator = '']) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> get last => throw UnimplementedError();

  @override
  Future<Uint8List> lastWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Future<int> get length => throw UnimplementedError();

  void onErrorImpl(dynamic error) {
    print('ON SOCKET ERROR');
  }

  void onDoneImpl() {
    print('ON SOCKET DONE');
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    onError ??= onErrorImpl;
    onDone ??= onDoneImpl;
    var subscription = MockStreamSubscription(onData, onError, onDone);
    _subscription = subscription;
    return subscription;
  }

  @override
  Stream<S> map<S>(S Function(Uint8List event) convert) {
    throw UnimplementedError();
  }

  @override
  Future pipe(StreamConsumer<Uint8List> streamConsumer) {
    throw UnimplementedError();
  }

  @override
  int get port => throw UnimplementedError();

  @override
  Future<Uint8List> reduce(
      Uint8List Function(Uint8List previous, Uint8List element) combine) {
    throw UnimplementedError();
  }

  @override
  InternetAddress get remoteAddress => throw UnimplementedError();

  @override
  int get remotePort => throw UnimplementedError();

  @override
  bool setOption(SocketOption option, bool enabled) {
    throw UnimplementedError();
  }

  @override
  void setRawOption(RawSocketOption option) {}

  @override
  Future<Uint8List> get single => throw UnimplementedError();

  @override
  Future<Uint8List> singleWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> skip(int count) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> skipWhile(bool Function(Uint8List element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> take(int count) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> takeWhile(bool Function(Uint8List element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> timeout(Duration timeLimit,
      {void Function(EventSink<Uint8List> sink)? onTimeout}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Uint8List>> toList() {
    throw UnimplementedError();
  }

  @override
  Future<Set<Uint8List>> toSet() {
    throw UnimplementedError();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<Uint8List, S> streamTransformer) {
    throw UnimplementedError();
  }

  @override
  Stream<Uint8List> where(bool Function(Uint8List event) test) {
    throw UnimplementedError();
  }

  @override
  void write(Object? obj) {
    var text = obj.toString();
    var data = _encoder.convert(text);
    add(data);
    //print('socket: [$text]');
    // make the socket asynchronous.
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? obj = '']) {
    //print('writeln [$obj]');
    write(obj.toString() + _CRLF);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(Uint8List event) convert) {
    throw UnimplementedError();
  }
}

class MockStreamSubscription extends StreamSubscription<Uint8List> {
  void Function(Uint8List data)? handleData;
  Function? handleError;
  void Function()? handleDone;

  MockStreamSubscription(this.handleData, this.handleError, this.handleDone);

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    throw UnimplementedError();
  }

  @override
  Future cancel() {
    return Future.value();
  }

  @override
  bool get isPaused => throw UnimplementedError();

  @override
  void onData(void Function(Uint8List data)? handleData) {
    this.handleData = handleData;
  }

  @override
  void onDone(void Function()? handleDone) {
    this.handleDone = handleDone;
  }

  @override
  void onError(Function? handleError) {
    this.handleError = handleError;
  }

  @override
  void pause([Future? resumeSignal]) {}

  @override
  void resume() {}
}
