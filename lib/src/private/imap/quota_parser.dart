import '../../imap/resource_limit.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses responses to IMAP QUOTA commands
class QuotaParser extends ResponseParser<QuotaResult> {
  QuotaResult? _quota;

  @override
  QuotaResult? parse(
          ImapResponse imapResponse, Response<QuotaResult> response) =>
      response.isOkStatus ? _quota : null;

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<QuotaResult>? response) {
    var details = imapResponse.parseText;
    String? rootName;
    if (details.startsWith('QUOTA ')) {
      details = details.substring('QUOTA '.length);
      final startIndex = details.indexOf('(');
      if (details.startsWith('"')) {
        final endOfNameIndex = details.indexOf('"', 1);
        if (endOfNameIndex != -1) {
          rootName = details.substring(1, endOfNameIndex);
        }
      } else {
        rootName = details.substring(0, startIndex - 1);
      }
      final listEntries = parseListEntries(details, startIndex + 1, ')');
      if (listEntries == null) {
        return false;
      }
      final buffer = <ResourceLimit>[];
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

/// Pareses results to QUOTA ROOT requests
class QuotaRootParser extends ResponseParser<QuotaRootResult> {
  QuotaRootResult? _quotaRoot;

  @override
  QuotaRootResult? parse(
          ImapResponse imapResponse, Response<QuotaRootResult> response) =>
      response.isOkStatus ? _quotaRoot : null;

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<QuotaRootResult>? response) {
    var details = imapResponse.parseText;
    String? rootName;
    if (details.startsWith('QUOTA ')) {
      details = details.substring('QUOTA '.length);
      final startIndex = details.indexOf('(');
      if (details.startsWith('"')) {
        final endOfNameIndex = details.indexOf('"', 1);
        if (endOfNameIndex != -1) {
          rootName = details.substring(1, endOfNameIndex);
        }
      } else {
        rootName = details.substring(0, startIndex - 1);
      }
      final listEntries = parseListEntries(details, startIndex + 1, ')');
      if (listEntries == null) {
        return false;
      }
      final buffer = <ResourceLimit>[];
      for (var index = 0; index < listEntries.length; index += 3) {
        buffer.add(ResourceLimit(
            listEntries[index],
            int.tryParse(listEntries[index + 1]),
            int.tryParse(listEntries[index + 2])));
      }
      _quotaRoot!.quotaRoots[rootName] = QuotaResult(rootName, buffer);
      return true;
    } else if (details.startsWith('QUOTAROOT ')) {
      details = details.substring('QUOTAROOT '.length);
      final entries = _parseStringEntries(details);
      _quotaRoot = QuotaRootResult(entries.first, entries.sublist(1));
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  List<String> _parseStringEntries(String details) {
    final output = <String>[];
    for (final item in details.split(' ')) {
      if (item.startsWith('"')) {
        output.add('${item.replaceFirst('"', '')} ');
      } else if (item.endsWith('"')) {
        output.add(output.removeLast() + item.replaceFirst('"', ''));
      } else {
        output.add(item);
      }
    }
    return output;
  }
}
