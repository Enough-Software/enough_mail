import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:event_bus/event_bus.dart';

import '../mail_address.dart';
import '../mime_data.dart';
import '../mime_message.dart';
import '../private/smtp/commands/all_commands.dart';
import '../private/smtp/smtp_command.dart';
import '../private/util/client_base.dart';
import '../private/util/uint8_list_reader.dart';
import 'smtp_events.dart';
import 'smtp_exception.dart';
import 'smtp_response.dart';

/// Keeps information about the remote SMTP server
///
/// Persist this information to improve initialization times.
class SmtpServerInfo {
  /// Creates a new server information
  SmtpServerInfo(this.host, this.port, {required this.isSecure});

  /// The remote host
  final String host;

  /// Is a secure connection being used (from the start)?
  final bool isSecure;

  /// The remote port
  final int port;

  /// The maximum message size in bytes
  int? maxMessageSize;

  /// The server capabilities
  List<String> capabilities = <String>[];

  /// The supported authentication mechanisms
  List<AuthMechanism> authMechanisms = <AuthMechanism>[];

  /// Checks of the specified [authMechanism] is supported.
  bool supportsAuth(AuthMechanism authMechanism) =>
      authMechanisms.contains(authMechanism);

  /// Checks if the server supports sending of `8bit` encoded messages.
  bool get supports8BitMime => capabilities.contains('8BITMIME');

  /// Checks if the server supports chunked message transfer
  /// using the `BDATA` command.
  ///
  /// Compare https://tools.ietf.org/html/rfc3030 for details
  bool get supportsChunking => capabilities.contains('CHUNKING');

  /// Checks if the server supports (and usually expects)
  /// switching to SSL connection before authentication.
  bool get supportsStartTls => capabilities.contains('STARTTLS');

  /// Checks if the given capability is supported, e.g.
  /// `final supportsPipelining = smtpClient.serverInfo.supports(PIPELINING);`.
  bool supports(String capability) => capabilities.contains(capability);
}

/// Defines the available authentication mechanism
enum AuthMechanism {
  /// PLAIN text authentication
  ///
  /// Should only be used over SSL protected connections.
  /// Compare https://tools.ietf.org/html/rfc4616.
  plain,

  /// LOGIN authentication
  ///
  /// Should only be used over SSL protected connections. Compare https://datatracker.ietf.org/doc/draft-murchison-sasl-login/.
  login,

  /// CRAM-MD5 authentication.
  ///
  /// Compare https://tools.ietf.org/html/rfc2195
  cramMd5,

  /// OAUTH 2.0 authentication
  ///
  /// Compare https://tools.ietf.org/html/rfc6750.
  xoauth2
}

/// Low-level SMTP library for Dart
///
/// Compliant to [Extended SMTP standard](https://tools.ietf.org/html/rfc5321).
class SmtpClient extends ClientBase {
  /// Creates a new instance with the specified [clientDomain]
  /// that is associated with your service's domain,
  /// e.g. `domain.com` or `enough.de`.
  ///
  /// Set the [eventBus] to add your specific `EventBus`
  /// to listen to SMTP events.
  ///
  /// Set [isLogEnabled] to `true` to see log output.
  /// Set the [logName] for adding the name to each log entry.
  /// [onBadCertificate] is an optional handler for unverifiable certificates.
  /// The handler receives the [X509Certificate], and can inspect it and
  /// decide (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  SmtpClient(
    String clientDomain, {
    EventBus? bus,
    bool isLogEnabled = false,
    String? logName,
    bool Function(X509Certificate)? onBadCertificate,
  })  : _eventBus = bus ?? EventBus(),
        _clientDomain = clientDomain,
        super(
          isLogEnabled: isLogEnabled,
          logName: logName,
          onBadCertificate: onBadCertificate,
        );

  /// Information about the SMTP service
  late SmtpServerInfo serverInfo;

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor,
  /// an asynchronous bus is used.
  /// Usage:
  /// ```dart
  /// eventBus.on<SmtpConnectionLostEvent>().listen((event) {
  ///   // All events are of type SmtpConnectionLostEvent (or subtypes of it).
  ///   _log(event.type);
  /// });
  ///
  /// eventBus.on<SmtpEvent>().listen((event) {
  ///   // All events are of type SmtpEvent (or subtypes of it).
  ///   _log(event.type);
  /// });
  /// ```
  EventBus get eventBus => _eventBus;
  final EventBus _eventBus;

  final String _clientDomain;

  final Uint8ListReader _uint8listReader = Uint8ListReader();
  SmtpCommand? _currentCommand;

  @override
  FutureOr<void> onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting) {
    serverInfo = SmtpServerInfo(connectionInfo.host, connectionInfo.port,
        isSecure: connectionInfo.isSecure);
    log('SMTP: got server greeting $serverGreeting', initial: 'A');
  }

  @override
  void onConnectionError(dynamic error) {
    eventBus.fire(SmtpConnectionLostEvent(this));
  }

  @override
  void onDataReceived(Uint8List data) {
    //print('onData: [${String.fromCharCodes(data).
    //       replaceAll("\r\n", "<CRLF>\n")}]');
    _uint8listReader.add(data);
    final lines = _uint8listReader.readLines();
    if (lines != null) {
      onServerResponse(lines);
    }
  }

  /// Issues the enhanced helo command to find out the service capabilities
  ///
  /// EHLO or HELO always needs to be the first command
  /// that is sent to the SMTP server.
  Future<SmtpResponse> ehlo() async {
    final result = await sendCommand(SmtpEhloCommand(_clientDomain));
    for (final line in result.responseLines) {
      if (line.code == 250) {
        serverInfo.capabilities.add(line.message);
        if (line.message.startsWith('AUTH ')) {
          if (line.message.contains('PLAIN')) {
            serverInfo.authMechanisms.add(AuthMechanism.plain);
          }
          if (line.message.contains('LOGIN')) {
            serverInfo.authMechanisms.add(AuthMechanism.login);
          }
          if (line.message.contains('CRAM-MD5')) {
            serverInfo.authMechanisms.add(AuthMechanism.cramMd5);
          }
          if (line.message.contains('XOAUTH2')) {
            serverInfo.authMechanisms.add(AuthMechanism.xoauth2);
          }
        } else {
          serverInfo.capabilities.add(line.message);
          if (line.message.startsWith('SIZE ')) {
            final maxSizeText = line.message.substring('SIZE '.length);
            serverInfo.maxMessageSize = int.tryParse(maxSizeText);
          }
        }
      }
    }
    return result;
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade
  /// a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate
  ///  port for encrypted communication.
  Future<SmtpResponse> startTls() async {
    final response = await sendCommand(SmtpStartTlsCommand());
    if (response.isOkStatus) {
      log('STARTTLS: upgrading socket to secure one...', initial: 'A');
      await upgradeToSslSocket();
      await ehlo();
    }
    return response;
  }

  /// Sends the specified [message].
  ///
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  /// Specify [from] in case the originator is different from the `From`
  /// header in the message.
  /// Optionally specify the [recipients], in which case the recipients
  /// defined in the message are ignored.
  Future<SmtpResponse> sendMessage(MimeMessage message,
      {bool use8BitEncoding = false,
      MailAddress? from,
      List<MailAddress>? recipients}) {
    final recipientEmails = recipients != null
        ? recipients.map((r) => r.email).toList()
        : message.recipientAddresses;
    if (recipientEmails.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(
      SmtpSendMailCommand(
        message,
        from,
        recipientEmails,
        use8BitEncoding: use8BitEncoding,
      ),
    );
  }

  /// Sends the specified message [data] [from] to the [recipients].
  ///
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  Future<SmtpResponse> sendMessageData(
      MimeData data, MailAddress from, List<MailAddress> recipients,
      {bool use8BitEncoding = false}) {
    if (recipients.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(
      SmtpSendMailDataCommand(
        data,
        from,
        recipients.map((r) => r.email).toList(),
        use8BitEncoding: use8BitEncoding,
      ),
    );
  }

  /// Sends the specified message [text] [from] to the [recipients].
  ///
  /// In contrast to the other methods the text is not modified apart from
  /// the padding of `<CR><LF>.<CR><LF>` sequences.
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  Future<SmtpResponse> sendMessageText(
      String text, MailAddress from, List<MailAddress> recipients,
      {bool use8BitEncoding = false}) {
    if (recipients.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(
      SmtpSendMailTextCommand(
        text,
        from,
        recipients.map((r) => r.email).toList(),
        use8BitEncoding: use8BitEncoding,
      ),
    );
  }

  /// Sends the specified [message] using the `BDAT` SMTP command.
  ///
  /// `BDATA` is supported when the SMTP server announces the `CHUNKING`
  /// capability in its `EHLO` response.
  /// You can query `SmtpServerInfo.supportsChunking` for this.
  ///
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  ///
  /// Specify [from] in case the originator is different from the `From`
  /// header in the message.
  ///
  /// Optionally specify the [recipients], in which case the recipients
  /// defined in the message are ignored.
  Future<SmtpResponse> sendChunkedMessage(
    MimeMessage message, {
    bool use8BitEncoding = false,
    MailAddress? from,
    List<MailAddress>? recipients,
  }) {
    final recipientEmails = recipients != null
        ? recipients.map((r) => r.email).toList()
        : message.recipientAddresses;
    if (recipientEmails.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(SmtpSendBdatMailCommand(message, from, recipientEmails,
        use8BitEncoding: use8BitEncoding));
  }

  /// Sends the specified message [data] [from] to the [recipients]
  /// using the `BDAT` SMTP command.
  ///
  /// `BDATA` is supported when the SMTP server announces the `CHUNKING`
  /// capability in its `EHLO` response.
  /// You can query `SmtpServerInfo.supportsChunking` for this.
  ///
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  Future<SmtpResponse> sendChunkedMessageData(
      MimeData data, MailAddress from, List<MailAddress> recipients,
      {bool use8BitEncoding = false}) {
    if (recipients.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(
      SmtpSendBdatMailDataCommand(
        data,
        from,
        recipients.map((r) => r.email).toList(),
        use8BitEncoding: use8BitEncoding,
      ),
    );
  }

  /// Sends the specified message [text] [from] to the [recipients]
  /// using the `BDAT` SMTP command.
  ///
  /// `BDATA` is supported when the SMTP server announces the `CHUNKING`
  /// capability in its `EHLO` response.
  /// You can query `SmtpServerInfo.supportsChunking` for this.
  ///
  /// In contrast to the other methods the text is not modified apart from the
  /// padding of `<CR><LF>.<CR><LF>` sequences.
  ///
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  Future<SmtpResponse> sendChunkedMessageText(
      String text, MailAddress from, List<MailAddress> recipients,
      {bool use8BitEncoding = false}) {
    if (recipients.isEmpty) {
      throw SmtpException(this, SmtpResponse(['500 no recipients']));
    }
    return sendCommand(
      SmtpSendBdatMailTextCommand(
        text,
        from,
        recipients.map((r) => r.email).toList(),
        use8BitEncoding: use8BitEncoding,
      ),
    );
  }

  /// Signs in the user with the given [name] and [password].
  ///
  /// For `AuthMechanism.xoauth2` the [password] must be the OAuth token.
  /// By default the [authMechanism] `AUTH PLAIN` is being used.
  Future<SmtpResponse> authenticate(String name, String password,
      [AuthMechanism authMechanism = AuthMechanism.plain]) {
    late SmtpCommand command;
    switch (authMechanism) {
      case AuthMechanism.plain:
        command = SmtpAuthPlainCommand(name, password);
        break;
      case AuthMechanism.login:
        command = SmtpAuthLoginCommand(name, password);
        break;
      case AuthMechanism.cramMd5:
        command = SmtpAuthCramMd5Command(name, password);
        break;
      case AuthMechanism.xoauth2:
        command = SmtpAuthXOauth2Command(name, password);
        break;
    }
    return sendCommand(command);
  }

  /// Signs the user out and terminates the connection
  Future<SmtpResponse> quit() async {
    final response = await sendCommand(SmtpQuitCommand(this));
    isLoggedIn = false;
    return response;
  }

  /// Sends the command to the server
  Future<SmtpResponse> sendCommand(SmtpCommand command) {
    _currentCommand = command;
    writeText(command.command, command);
    return command.completer.future;
  }

  /// Handles server responses
  void onServerResponse(List<String> responseTexts) {
    if (isLogEnabled) {
      for (final responseText in responseTexts) {
        log(responseText, isClient: false);
      }
    }
    final response = SmtpResponse(responseTexts);
    final cmd = _currentCommand;
    if (cmd != null) {
      try {
        final next = cmd.next(response);
        if (next?.text != null) {
          writeText(next!.text!);
        } else if (next?.data != null) {
          writeData(next!.data!);
        } else if (cmd.isCommandDone(response)) {
          if (response.isFailedStatus) {
            cmd.completer.completeError(SmtpException(this, response));
          } else {
            cmd.completer.complete(response);
          }
          //_log("Done with command ${_currentCommand.command}");
          _currentCommand = null;
        }
      } catch (exception, stackTrace) {
        log('Error proceeding to nextCommand: $exception');
        _currentCommand?.completer.completeError(exception, stackTrace);
        _currentCommand = null;
      }
    }
  }

  @override
  Object createClientError(String message) =>
      SmtpException.message(this, message);
}
