import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

class PopListParser extends PopResponseParser<List<MessageListing>> {
  @override
  PopResponse<List<MessageListing>> parse(List<String?> responseLines) {
    var response = PopResponse<List<MessageListing>>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      var result = <MessageListing>[];
      response.result = result;
      for (var line in responseLines) {
        if (line == '+OK') {
          continue;
        }
        var parts = line!.split(' ');
        var listing = MessageListing();
        if (parts.length == 2) {
          listing.id = int.tryParse(parts[0]);
          listing.sizeInBytes = int.tryParse(parts[1]);
        } else if (parts.length == 3) {
          // eg '+OK 123 123231'
          listing.id = int.tryParse(parts[1]);
          listing.sizeInBytes = int.tryParse(parts[2]);
        } else {
          print('Unexpected LIST response line [$line]');
        }
        result.add(listing);
      }
    }
    return response;
  }
}
