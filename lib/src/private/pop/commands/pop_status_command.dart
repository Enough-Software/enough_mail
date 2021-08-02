import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/parsers/pop_status_parser.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopStatusCommand extends PopCommand<PopStatus> {
  PopStatusCommand() : super('STAT', parser: PopStatusParser());
}
