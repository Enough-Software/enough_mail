import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/parsers/pop_status_parser.dart';
import 'package:enough_mail/src/pop/pop_command.dart';

class PopStatusCommand extends PopCommand<PopStatus> {
  PopStatusCommand() : super('STAT', parser: PopStatusParser());
}
