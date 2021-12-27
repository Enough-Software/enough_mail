import 'package:enough_mail/src/imap/extended_data.dart';
import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/imap/mailbox.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';
import 'package:enough_mail/src/private/imap/status_parser.dart';

import 'imap_response.dart';

/// Pareses LIST and LSUB respones
class ListParser extends ResponseParser<List<Mailbox>> {
  /// Creates a new parser
  ListParser(this.info,
      {bool isLsubParser = false,
      this.isExtended = false,
      bool hasReturnOptions = false})
      : startSequence = isLsubParser ? 'LSUB ' : 'LIST ',
        // Return options are available only for LIST responses.
        _hasReturnOptions = !isLsubParser && hasReturnOptions;

  /// The remote service info
  final ImapServerInfo info;

  /// The resulting mailboxes
  final List<Mailbox> boxes = <Mailbox>[];

  /// The command's start sequence
  final String startSequence;

  /// Is an extended response expected?
  ///
  /// e.g. when hasSelectionOptions || hasMailboxPatterns || hasReturnOptions
  final bool isExtended;
  final bool _hasReturnOptions;

  @override
  List<Mailbox>? parse(
          ImapResponse? imapResponse, Response<List<Mailbox>> response) =>
      response.isOkStatus ? boxes : null;

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<Mailbox>>? response) {
    final parseText = imapResponse.parseText;
    if (parseText.startsWith(startSequence)) {
      final box = Mailbox();
      var listDetails = parseText.substring(startSequence.length);
      final flagsStartIndex = listDetails.indexOf('(');
      final flagsEndIndex = listDetails.indexOf(')');
      if (flagsStartIndex != -1 && flagsStartIndex < flagsEndIndex) {
        if (flagsStartIndex < flagsEndIndex - 1) {
          // there are actually flags, not an empty ()
          final flagsText = listDetails
              .substring(flagsStartIndex + 1, flagsEndIndex)
              .toLowerCase();
          final flagNames = flagsText.split(' ');
          for (final flagName in flagNames) {
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
                if (isExtended) {
                  box.flags.add(MailboxFlag.hasNoChildren);
                }
                break;
              case r'\nonexistent':
                box.flags.add(MailboxFlag.nonExistent);
                if (isExtended) {
                  box.flags.add(MailboxFlag.noSelect);
                }
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
      // Parses extended data
      if (isExtended) {
        final extraInfoStartIndex = listDetails.indexOf('(');
        final extraInfoEndIndex = listDetails.lastIndexOf(')');
        if (extraInfoEndIndex != -1 &&
            extraInfoStartIndex < extraInfoEndIndex) {
          final extraInfo =
              listDetails.substring(extraInfoStartIndex + 1, extraInfoEndIndex);
          listDetails = listDetails.substring(0, extraInfoStartIndex - 1);
          // Convert to loop if more extended data results will be present
          //todo Address when multiple extended data list are returned
          // by non conforming servers while (extraInfo.isNotEmpty)
          if (extraInfo.startsWith(ExtendedData.childinfo) ||
              extraInfo.startsWith('"${ExtendedData.childinfo}"')) {
            if (!box.extendedData.containsKey(ExtendedData.childinfo)) {
              box.extendedData[ExtendedData.childinfo] = [];
            }
            final optsStartIndex = extraInfo.indexOf('(');
            final optsEndIndex = extraInfo.indexOf(')');
            if (optsStartIndex != -1 && optsStartIndex < optsEndIndex) {
              final opts = extraInfo
                  .substring(optsStartIndex + 1, optsEndIndex)
                  .split(' ')
                  .map((e) => e.substring(1, e.length - 1));
              box.extendedData[ExtendedData.childinfo]!.addAll(opts);
            }
          }
        }
      }
      if (listDetails.startsWith('"')) {
        final endOfPathSeparatorIndex = listDetails.indexOf('"', 1);
        if (endOfPathSeparatorIndex != -1) {
          final separator = listDetails.substring(1, endOfPathSeparatorIndex);
          info.pathSeparator = separator;
          box.pathSeparator = separator;
          listDetails = listDetails.substring(endOfPathSeparatorIndex + 2);
        }
      }
      if (listDetails.startsWith('"')) {
        listDetails = listDetails.substring(1, listDetails.length - 1);
      }
      box.path = listDetails;
      if (listDetails.toUpperCase() == 'INBOX' && !box.isInbox) {
        box.flags.add(MailboxFlag.inbox);
      }
      // Maybe was requested only the hierarchy separator without reference name
      if (listDetails.isNotEmpty) {
        final lastPathSeparatorIndex = listDetails.lastIndexOf(
            info.pathSeparator!, listDetails.length - 2);
        if (lastPathSeparatorIndex != -1) {
          listDetails = listDetails.substring(lastPathSeparatorIndex + 1);
        }
      }
      box.name = listDetails;
      boxes.add(box);
      return true;
    } else if (_hasReturnOptions) {
      if (parseText.startsWith('NO')) {
        // Swallows failed STATUS result
        // This is a special case in which a STATUS result fails with 'NO' for a
        // non existent folder. Nevertheless, the mailbox is added with a \Nonexistent flag.
        return true;
      }
      if (parseText.startsWith('STATUS')) {
        // Reuses the StatusParser class
        final parser = StatusParser(boxes.last);
        // ignore: cascade_invocations
        parser.parseUntagged(imapResponse, null);
        return true;
      }
    }
    return super.parseUntagged(imapResponse, response);
  }
}
