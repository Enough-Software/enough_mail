import '../smtp_command.dart';

class SmtpStartTlsCommand extends SmtpCommand {
  SmtpStartTlsCommand() : super('STARTTLS');
}
