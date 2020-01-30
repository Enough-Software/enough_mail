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
  void add(List<int> data) {
    // TODO: implement add
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    // TODO: implement addError
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    // TODO: implement addStream
    return null;
  }

  @override
  // TODO: implement address
  InternetAddress get address => null;

  @override
  Future<bool> any(bool Function(Uint8List element) test) {
    // TODO: implement any
    return null;
  }

  @override
  Stream<Uint8List> asBroadcastStream(
      {void Function(StreamSubscription<Uint8List> subscription) onListen,
      void Function(StreamSubscription<Uint8List> subscription) onCancel}) {
    // TODO: implement asBroadcastStream
    return null;
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E> Function(Uint8List event) convert) {
    // TODO: implement asyncExpand
    return null;
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Uint8List event) convert) {
    // TODO: implement asyncMap
    return null;
  }

  @override
  Stream<R> cast<R>() {
    // TODO: implement cast
    return null;
  }

  @override
  Future close() {
    _subscription.handleDone();
    return null;
  }

  @override
  Future<bool> contains(Object needle) {
    // TODO: implement contains
    return null;
  }

  @override
  void destroy() {
    // TODO: implement destroy
  }

  @override
  Stream<Uint8List> distinct(
      [bool Function(Uint8List previous, Uint8List next) equals]) {
    // TODO: implement distinct
    return null;
  }

  @override
  // TODO: implement done
  Future get done => null;

  @override
  Future<E> drain<E>([E futureValue]) {
    // TODO: implement drain
    return null;
  }

  @override
  Future<Uint8List> elementAt(int index) {
    // TODO: implement elementAt
    return null;
  }

  @override
  Future<bool> every(bool Function(Uint8List element) test) {
    // TODO: implement every
    return null;
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Uint8List element) convert) {
    // TODO: implement expand
    return null;
  }

  @override
  // TODO: implement first
  Future<Uint8List> get first => null;

  @override
  Future<Uint8List> firstWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    // TODO: implement firstWhere
    return null;
  }

  @override
  Future flush() {
    // TODO: implement flush
    return null;
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, Uint8List element) combine) {
    // TODO: implement fold
    return null;
  }

  @override
  Future forEach(void Function(Uint8List element) action) {
    // TODO: implement forEach
    return null;
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    // TODO: implement getRawOption
    return null;
  }

  @override
  Stream<Uint8List> handleError(Function onError, {bool test(error)}) {
    // TODO: implement handleError
    return null;
  }

  @override
  // TODO: implement isBroadcast
  bool get isBroadcast => null;

  @override
  // TODO: implement isEmpty
  Future<bool> get isEmpty => null;

  @override
  Future<String> join([String separator = ""]) {
    // TODO: implement join
    return null;
  }

  @override
  // TODO: implement last
  Future<Uint8List> get last => null;

  @override
  Future<Uint8List> lastWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    // TODO: implement lastWhere
    return null;
  }

  @override
  // TODO: implement length
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
    // TODO: implement map
    return null;
  }

  @override
  Future pipe(StreamConsumer<Uint8List> streamConsumer) {
    // TODO: implement pipe
    return null;
  }

  @override
  // TODO: implement port
  int get port => null;

  @override
  Future<Uint8List> reduce(
      Uint8List Function(Uint8List previous, Uint8List element) combine) {
    // TODO: implement reduce
    return null;
  }

  @override
  // TODO: implement remoteAddress
  InternetAddress get remoteAddress => null;

  @override
  // TODO: implement remotePort
  int get remotePort => null;

  @override
  bool setOption(SocketOption option, bool enabled) {
    // TODO: implement setOption
    return null;
  }

  @override
  void setRawOption(RawSocketOption option) {
    // TODO: implement setRawOption
  }

  @override
  // TODO: implement single
  Future<Uint8List> get single => null;

  @override
  Future<Uint8List> singleWhere(bool Function(Uint8List element) test,
      {Uint8List Function() orElse}) {
    // TODO: implement singleWhere
    return null;
  }

  @override
  Stream<Uint8List> skip(int count) {
    // TODO: implement skip
    return null;
  }

  @override
  Stream<Uint8List> skipWhile(bool Function(Uint8List element) test) {
    // TODO: implement skipWhile
    return null;
  }

  @override
  Stream<Uint8List> take(int count) {
    // TODO: implement take
    return null;
  }

  @override
  Stream<Uint8List> takeWhile(bool Function(Uint8List element) test) {
    // TODO: implement takeWhile
    return null;
  }

  @override
  Stream<Uint8List> timeout(Duration timeLimit,
      {void Function(EventSink<Uint8List> sink) onTimeout}) {
    // TODO: implement timeout
    return null;
  }

  @override
  Future<List<Uint8List>> toList() {
    // TODO: implement toList
    return null;
  }

  @override
  Future<Set<Uint8List>> toSet() {
    // TODO: implement toSet
    return null;
  }

  @override
  Stream<S> transform<S>(StreamTransformer<Uint8List, S> streamTransformer) {
    // TODO: implement transform
    return null;
  }

  @override
  Stream<Uint8List> where(bool Function(Uint8List event) test) {
    // TODO: implement where
    return null;
  }

  @override
  void write(Object obj) {
    var text = obj.toString();
    var data = _encoder.convert(text);
    //print("socket writing " + text + ", handler: " + _other._subscription.handleData.toString());
    _other._subscription.handleData(data);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    // TODO: implement writeAll
  }

  @override
  void writeCharCode(int charCode) {
    // TODO: implement writeCharCode
  }

  @override
  void writeln([Object obj = ""]) {
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
    // TODO: implement asFuture
    return null;
  }

  @override
  Future cancel() {
    // TODO: implement cancel
    return null;
  }

  @override
  // TODO: implement isPaused
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
  void pause([Future resumeSignal]) {
    // TODO: implement pause
  }

  @override
  void resume() {
    // TODO: implement resume
  }
}
