import '../../imap/extended_data.dart';
import '../../imap/imap_client.dart';
import '../../imap/mailbox.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';
import 'status_parser.dart';

/// Parses `LIST` and `LSUB` responses
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
      final boxFlags = <MailboxFlag>[];
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
                boxFlags.add(MailboxFlag.hasNoChildren);
                break;
              case r'\haschildren':
                boxFlags.add(MailboxFlag.hasChildren);
                break;
              case r'\unmarked':
                boxFlags.add(MailboxFlag.unMarked);
                break;
              case r'\marked':
                boxFlags.add(MailboxFlag.marked);
                break;
              case r'\noselect':
                boxFlags.add(MailboxFlag.noSelect);
                break;
              case r'\select':
                boxFlags.add(MailboxFlag.select);
                break;
              case r'\noinferiors':
                boxFlags.add(MailboxFlag.noInferior);
                if (isExtended) {
                  boxFlags.add(MailboxFlag.hasNoChildren);
                }
                break;
              case r'\nonexistent':
                boxFlags.add(MailboxFlag.nonExistent);
                if (isExtended) {
                  boxFlags.add(MailboxFlag.noSelect);
                }
                break;
              case r'\subscribed':
                boxFlags.add(MailboxFlag.subscribed);
                break;
              case r'\remote':
                boxFlags.add(MailboxFlag.remote);
                break;
              case r'\all':
                boxFlags.add(MailboxFlag.all);
                break;
              case r'\inbox':
                boxFlags.add(MailboxFlag.inbox);
                break;
              case r'\sent':
                boxFlags.add(MailboxFlag.sent);
                break;
              case r'\drafts':
                boxFlags.add(MailboxFlag.drafts);
                break;
              case r'\junk':
                boxFlags.add(MailboxFlag.junk);
                break;
              case r'\trash':
                boxFlags.add(MailboxFlag.trash);
                break;
              case r'\archive':
                boxFlags.add(MailboxFlag.archive);
                break;
              case r'\flagged':
                boxFlags.add(MailboxFlag.flagged);
                break;
              // X-List flags:
              case r'\allmail':
                boxFlags.add(MailboxFlag.all);
                break;
              case r'\important':
                boxFlags.add(MailboxFlag.flagged);
                break;
              case r'\spam':
                boxFlags.add(MailboxFlag.junk);
                break;
              case r'\starred':
                boxFlags.add(MailboxFlag.flagged);
                break;

              default:
                print('encountered unexpected flag: [$flagName]');
            }
          }
        }
        listDetails = listDetails.substring(flagsEndIndex + 2);
      }
      // Parses extended data
      final boxExtendedData = <String, List<String>>{};
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
            final childInfo = boxExtendedData[ExtendedData.childinfo] ?? [];
            if (!boxExtendedData.containsKey(ExtendedData.childinfo)) {
              boxExtendedData[ExtendedData.childinfo] = childInfo;
            }
            final optsStartIndex = extraInfo.indexOf('(');
            final optsEndIndex = extraInfo.indexOf(')');
            if (optsStartIndex != -1 && optsStartIndex < optsEndIndex) {
              final opts = extraInfo
                  .substring(optsStartIndex + 1, optsEndIndex)
                  .split(' ')
                  .map((e) => e.substring(1, e.length - 1));
              childInfo.addAll(opts);
            }
          }
        }
      }
      if (listDetails.startsWith('"')) {
        final endOfPathSeparatorIndex = listDetails.indexOf('"', 1);
        if (endOfPathSeparatorIndex != -1) {
          final separator = listDetails.substring(1, endOfPathSeparatorIndex);
          info.pathSeparator = separator;
          listDetails = listDetails.substring(endOfPathSeparatorIndex + 2);
        }
      }
      if (listDetails.startsWith('"')) {
        listDetails = listDetails.substring(1, listDetails.length - 1);
      }
      final boxPath = listDetails;
      // Maybe was requested only the hierarchy separator without reference name
      if (listDetails.length > 2 && info.pathSeparator != null) {
        final lastPathSeparatorIndex = listDetails.lastIndexOf(
            info.pathSeparator!, listDetails.length - 2);
        if (lastPathSeparatorIndex != -1) {
          listDetails = listDetails.substring(lastPathSeparatorIndex + 1);
        }
      }
      final boxName = listDetails;
      final box = Mailbox(
        encodedName: boxName,
        encodedPath: boxPath,
        flags: boxFlags,
        pathSeparator: info.pathSeparator ?? '/',
        extendedData: boxExtendedData,
      );
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
