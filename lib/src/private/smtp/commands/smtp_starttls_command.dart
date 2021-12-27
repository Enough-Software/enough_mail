import '../smtp_command.dart';

/// Triggers conversion to a secure connection
class SmtpStartTlsCommand extends SmtpCommand {
  /// Creates a new STARTTLS command
  SmtpStartTlsCommand() : super('STARTTLS');
}
