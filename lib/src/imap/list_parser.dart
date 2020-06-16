import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

/// Pareses LIST and LSUB respones
class ListParser extends ResponseParser<List<Mailbox>> {
  final ImapServerInfo info;
  final List<Mailbox> boxes = <Mailbox>[];
  String startSequence;

  ListParser(this.info, {bool isLsubParser = false}) {
    startSequence = isLsubParser ? 'LSUB ' : 'LIST ';
  }

  @override
  List<Mailbox> parse(ImapResponse details, Response<List<Mailbox>> response) {
    return response.isOkStatus ? boxes : null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<Mailbox>> response) {
    var details = imapResponse.parseText;
    if (details.startsWith(startSequence)) {
      var box = Mailbox();
      var listDetails = details.substring(startSequence.length);
      var flagsStartIndex = listDetails.indexOf('(');
      var flagsEndIndex = listDetails.indexOf(')');
      if (flagsStartIndex != -1 && flagsStartIndex < flagsEndIndex) {
        if (flagsStartIndex < flagsEndIndex - 1) {
          // there are actually flags, not an empty ()
          var flagsText = listDetails
              .substring(flagsStartIndex + 1, flagsEndIndex)
              .toLowerCase();
          var flagNames = flagsText.split(' ');
          for (var flagName in flagNames) {
            switch (flagName) {
              case r'\hasnochildren':
                box.flags.add(MailboxFlag.hasNoChildren);
                break;
              case r'\haschildren':
                box.flags.add(MailboxFlag.hasChildren);
                box.hasChildren = true;
                break;
              case r'\unmarked':
                box.flags.add(MailboxFlag.unMarked);
                break;
              case r'\marked':
                box.flags.add(MailboxFlag.marked);
                box.isMarked = true;
                break;
              case r'\noselect':
                box.flags.add(MailboxFlag.noSelect);
                box.isUnselectable = true;
                break;
              case r'\select':
                box.flags.add(MailboxFlag.select);
                box.isSelected = true;
                break;
              case r'\noinferiors':
                box.flags.add(MailboxFlag.noInferior);
                break;
              case r'\nonexistent':
                box.flags.add(MailboxFlag.nonExistent);
                break;
              case r'\subscribed':
                box.flags.add(MailboxFlag.subscribed);
                break;
              case r'\remote':
                box.flags.add(MailboxFlag.remote);
                break;
              case r'\all':
                box.flags.add(MailboxFlag.all);
                break;
              case r'\inbox':
                box.flags.add(MailboxFlag.inbox);
                break;
              case r'\sent':
                box.flags.add(MailboxFlag.sent);
                break;
              case r'\drafts':
                box.flags.add(MailboxFlag.drafts);
                break;
              case r'\junk':
                box.flags.add(MailboxFlag.junk);
                break;
              case r'\trash':
                box.flags.add(MailboxFlag.trash);
                break;
              case r'\archive':
                box.flags.add(MailboxFlag.archive);
                break;
              case r'\flagged':
                box.flags.add(MailboxFlag.flagged);
                break;
              // X-List flags:
              case r'\allmail':
                box.flags.add(MailboxFlag.all);
                break;
              case r'\important':
                box.flags.add(MailboxFlag.flagged);
                break;
              case r'\spam':
                box.flags.add(MailboxFlag.junk);
                break;
              case r'\starred':
                box.flags.add(MailboxFlag.flagged);
                break;

              default:
                print('enountered unexpected flag: [$flagName]');
            }
          }
        }
        listDetails = listDetails.substring(flagsEndIndex + 2);
      }
      if (listDetails.startsWith('"')) {
        var endOfPathSeparatorIndex = listDetails.indexOf('"', 1);
        if (endOfPathSeparatorIndex != -1) {
          info.pathSeparator =
              listDetails.substring(1, endOfPathSeparatorIndex);
          //print("path-separator: " + info.pathSeparator);
          listDetails = listDetails.substring(endOfPathSeparatorIndex + 2);
        }
      }
      if (listDetails.startsWith('"')) {
        listDetails = listDetails.substring(1, listDetails.length - 1);
      }
      box.path = listDetails;
      var lastPathSeparatorIndex =
          listDetails.lastIndexOf(info.pathSeparator, listDetails.length - 2);
      if (lastPathSeparatorIndex != -1) {
        listDetails = listDetails.substring(lastPathSeparatorIndex + 1);
      }
      box.name = listDetails;
      boxes.add(box);
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }
}
