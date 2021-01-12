import 'dart:typed_data';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/smtp/smtp_events.dart';
import 'package:enough_mail/src/util/client_base.dart';
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';
import 'package:enough_mail/src/smtp/commands/all_commands.dart';
import 'package:enough_mail/src/util/uint8_list_reader.dart';

import 'smtp_exception.dart';

/// Keeps information about the remote SMTP server
///
/// Persist this information to improve initialization times.
class SmtpServerInfo {
  final String host;
  final bool isSecure;
  final int port;
  int maxMessageSize;
  List<String> capabilities = <String>[];
  List<AuthMechanism> authMechanisms = <AuthMechanism>[];

  SmtpServerInfo(this.host, this.port, this.isSecure);

  bool supportsAuth(AuthMechanism authMechanism) {
    return authMechanisms.contains(authMechanism);
  }

  bool get supports8BitMime => capabilities.contains('8BITMIME');

  bool get supportsStartTls => capabilities.contains('STARTTLS');
}

enum AuthMechanism { plain, login, cramMd5, xoauth2 }

/// Low-level SMTP library for Dartlang
///
/// Compliant to [Extended SMTP standard](https://tools.ietf.org/html/rfc5321).
class SmtpClient extends ClientBase {
  /// Information about the SMTP service
  SmtpServerInfo serverInfo;

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor, an aysnchronous bus is used.
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
  EventBus _eventBus;

  String _clientDomain;

  final Uint8ListReader _uint8listReader = Uint8ListReader();
  SmtpCommand _currentCommand;

  /// Creates a new instance with the optional [bus] event bus.
  ///
  /// Compare [eventBus] for more information.
  SmtpClient(String clientDomain,
      {EventBus bus, bool isLogEnabled = false, String logName})
      : super(isLogEnabled: isLogEnabled, logName: logName) {
    _clientDomain = clientDomain;
    bus ??= EventBus();
    _eventBus = bus;
  }

  @override
  void onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting) {
    serverInfo = SmtpServerInfo(
        connectionInfo.host, connectionInfo.port, connectionInfo.isSecure);
    log('SMTP: got server greeting $serverGreeting', initial: 'A');
  }

  @override
  void onConnectionError(error) {
    eventBus.fire(SmtpConnectionLostEvent());
  }

  @override
  void onDataReceived(Uint8List data) {
    //print('onData: [${String.fromCharCodes(data).replaceAll("\r\n", "<CRLF>\n")}]');
    _uint8listReader.add(data);
    onServerResponse(_uint8listReader.readLines());
  }

  /// Issues the enhanced helo command to find out the capabilities of the SMTP server
  ///
  /// EHLO or HELO always needs to be the first command that is sent to the SMTP server.
  Future<SmtpResponse> ehlo() async {
    var result = await sendCommand(SmtpEhloCommand(_clientDomain));
    if (result.responseLines != null) {
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
              var maxSizeText = line.message.substring('SIZE '.length);
              serverInfo.maxMessageSize = int.tryParse(maxSizeText);
            }
          }
        }
      }
    }
    return result;
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate port for encrypted communication.
  Future<SmtpResponse> startTls() async {
    var response = await sendCommand(SmtpStartTlsCommand());
    if (response.isOkStatus) {
      log('STARTTL: upgrading socket to secure one...', initial: 'A');
      await upradeToSslSocket();
      await ehlo();
    }
    return response;
  }

  /// Sends the specified [message].
  /// Set [use8BitEncoding] to `true` for sending a UTF-8 encoded message body.
  /// Specify [from] in case the originator is different from the `From` header in the message.
  Future<SmtpResponse> sendMessage(MimeMessage message,
      {bool use8BitEncoding = false, MailAddress from}) {
    return sendCommand(SmtpSendMailCommand(message, use8BitEncoding, from));
  }

  /// Signs in the user with the given [name] and [password].
  /// For `AuthMechanism.xoauth2` the password must be the OAuth token.
  /// By default the [authMechanism] `AUTH PLAIN` is being used.
  Future<SmtpResponse> login(String name, String password,
      [AuthMechanism authMechanism = AuthMechanism.plain]) {
    SmtpCommand command;
    switch (authMechanism) {
      case AuthMechanism.plain:
        command = SmtpAuthPlainCommand(name, password);
        break;
      case AuthMechanism.login:
        command = SmtpAuthLoginCommand(name, password);
        break;
      case AuthMechanism.cramMd5:
        // TODO implement AUTH CRAM-MD5
        throw StateError('AUTH CRAM-MD5 is not yet implemented');
        break;
      case AuthMechanism.xoauth2:
        command = SmtpAuthXOauth2Command(name, password);
        break;
    }
    return sendCommand(command);
  }

  Future<SmtpResponse> quit() async {
    var response = await sendCommand(SmtpQuitCommand(this));
    isLoggedIn = false;
    return response;
  }

  Future<SmtpResponse> sendCommand(SmtpCommand command) {
    _currentCommand = command;
    writeText(command.command, command);
    return command.completer.future;
  }

  void onServerResponse(List<String> responseTexts) {
    if (isLogEnabled) {
      for (var responseText in responseTexts) {
        log(responseText, isClient: false);
      }
    }
    var response = SmtpResponse(responseTexts);
    if (_currentCommand != null) {
      try {
        var commandText = _currentCommand.nextCommand(response);
        if (commandText != null) {
          writeText(commandText);
        } else if (_currentCommand.isCommandDone(response)) {
          if (response.isFailedStatus) {
            _currentCommand.completer
                .completeError(SmtpException(this, response));
          } else {
            _currentCommand.completer.complete(response);
          }
          //_log("Done with command ${_currentCommand.command}");
          _currentCommand = null;
        }
      } catch (exception, stackTrace) {
        log('Error proceeding to nextCommand. $exception');
        _currentCommand?.completer?.completeError(exception, stackTrace);
        _currentCommand = null;
      }
    }
  }

  /// Closes the connection to the remote SMTP server.
  Future<dynamic> closeConnection() {
    return disconnect();
  }
}
