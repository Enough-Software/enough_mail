import 'package:enough_mail/imap/resource_limit.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

class QuotaParser extends ResponseParser<QuotaResult> {
  QuotaResult _quota;

  @override
  QuotaResult parse(ImapResponse imapResponse, Response<QuotaResult> response) {
    return response.isOkStatus ? _quota : null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<QuotaResult> response) {
    var details = imapResponse.parseText;
    var rootName;
    if (details.startsWith('QUOTA ')) {
      details = details.substring('QUOTA '.length);
      var startIndex = details.indexOf('(');
      if (details.startsWith('"')) {
        var endOfNameIndex = details.indexOf('"', 1);
        if (endOfNameIndex != -1) {
          rootName = details.substring(1, endOfNameIndex);
        }
      } else {
        rootName = details.substring(0, startIndex - 1);
      }
      var listEntries = parseListEntries(details, startIndex + 1, ')');
      var buffer = <ResourceLimit>[];
      for (var index = 0; index < listEntries.length; index += 3) {
        buffer.add(ResourceLimit(
            listEntries[index],
            int.tryParse(listEntries[index + 1]),
            int.tryParse(listEntries[index + 2])));
      }
      _quota = QuotaResult(rootName, buffer);
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }
}

class QuotaRootParser extends ResponseParser<QuotaRootResult> {
  QuotaRootResult _quotaRoot;

  @override
  QuotaRootResult parse(
      ImapResponse imapResponse, Response<QuotaRootResult> response) {
    return response.isOkStatus ? _quotaRoot : null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<QuotaRootResult> response) {
    var details = imapResponse.parseText;
    var rootName;
    if (details.startsWith('QUOTA ')) {
      details = details.substring('QUOTA '.length);
      var startIndex = details.indexOf('(');
      if (details.startsWith('"')) {
        var endOfNameIndex = details.indexOf('"', 1);
        if (endOfNameIndex != -1) {
          rootName = details.substring(1, endOfNameIndex);
        }
      } else {
        rootName = details.substring(0, startIndex - 1);
      }
      var listEntries = parseListEntries(details, startIndex + 1, ')');
      var buffer = <ResourceLimit>[];
      for (var index = 0; index < listEntries.length; index += 3) {
        buffer.add(ResourceLimit(
            listEntries[index],
            int.tryParse(listEntries[index + 1]),
            int.tryParse(listEntries[index + 2])));
      }
      _quotaRoot.quotaRoots[rootName] = QuotaResult(rootName, buffer);
      return true;
    } else if (details.startsWith('QUOTAROOT ')) {
      details = details.substring('QUOTAROOT '.length);
      var entries = _parseStringEntries(details);
      _quotaRoot = QuotaRootResult(entries.first, entries.sublist(1));
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  List<String> _parseStringEntries(String details) {
    var output = <String>[];
    for (var item in details.split(' ')) {
      if (item.startsWith('"')) {
        output.add(item.replaceFirst('"', '') + ' ');
      } else if (item.endsWith('"')) {
        output.add(output.removeLast() + item.replaceFirst('"', ''));
      } else {
        output.add(item);
      }
    }
    return output;
  }
}
