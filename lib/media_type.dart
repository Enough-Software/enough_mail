/// Top level media types
enum MediaToptype {
  text,
  image,
  audio,
  video,
  application,
  multipart,
  message,
  model,
  font,
  other
}

/// Detailed media types
/// Compare https://www.iana.org/assignments/media-types/media-types.xhtml
enum MediaSubtype {
  textPlain,
  textHtml,

  /// https://www.iana.org/go/rfc5545
  textCalendar,

  /// https://www.iana.org/go/rfc6350
  textVcard,

  /// https://www.iana.org/go/rfc7763
  textMarkdown,
  audioBasic,
  audioMpeg,
  audioMp3,
  audioMp4,
  audioOgg,
  audioWav,
  audioMidi,
  audioMod,
  audioAiff,
  audioWebm,
  audioAac,
  imageJpeg,
  imagePng,
  imageGif,
  imageWebp,
  imageBmp,
  imageSvgXml,
  videoMpeg,
  videoMp4,
  videoWebm,
  videoH264,
  videoOgg,
  applicationJson,
  applicationZip,
  applicationXml,
  applicationOctetStream,

  /// https://www.iana.org/go/rfc7265
  applicationCalendarJson,

  /// https://www.iana.org/go/rfc6321
  applicationCalendarXml,
  applicationVcardJson,
  applicationVcardXml,

  /// https://www.iana.org/go/rfc8118
  applicationPdf,
  applicationOfficeDocumentWordProcessingDocument,
  applicationOfficeDocumentWordProcessingTemplate,
  applicationOfficeDocumentSpreadsheetSheet,
  applicationOfficeDocumentSpreadsheetTemplate,
  applicationOfficeDocumentPresentationPresentation,
  applicationOfficeDocumentPresentationTemplate,

  /// part that contains the signature, https://tools.ietf.org/html/rfc3156
  applicationPgpSignature,

  /// encrypted message part, https://tools.ietf.org/html/rfc3156
  applicationPgpEncrypted,

  /// part that contains PGP keys, compare https://tools.ietf.org/html/rfc3156
  applicationPgpKeys,

  modelMesh,
  modelVrml,
  modelX3dXml,
  modelX3dVrml,
  modelX3dBinary,
  modelVndColladaXml,

  /// embedded message, https://tools.ietf.org/html/rfc2045 https://tools.ietf.org/html/rfc2046
  messageRfc822,

  /// partial message, https://tools.ietf.org/html/rfc2045 https://tools.ietf.org/html/rfc2046
  messagePartial,

  /// delivery status of a message, https://tools.ietf.org/html/rfc1894
  messageDeliveryStatus,

  /// read receipt, https://tools.ietf.org/html/rfc8098
  messageDispositionNotification,
  multipartAlternative,
  multipartMixed,
  multipartParallel,
  multipartPartial,
  multipartRelated,
  multipartDigest,

  /// signed message, https://tools.ietf.org/html/rfc1847
  multipartSigned,

  /// encrypted message, https://tools.ietf.org/html/rfc1847
  multipartEncrypted,

  /// Report https://tools.ietf.org/html/rfc6522
  multipartReport,
  fontOtf,
  fontTtf,
  fontWoff,
  fontWoff2,
  fontCollection,
  other
}

/// Describes the media type of a MIME message part
///
/// Compare https://www.iana.org/assignments/media-types/media-types.xhtml for a list of common media types.
class MediaType {
  static const MediaType textPlain =
      MediaType('text/plain', MediaToptype.text, MediaSubtype.textPlain);

  static const Map<String, MediaToptype> _topLevelByMimeName =
      <String, MediaToptype>{
    'text': MediaToptype.text,
    'image': MediaToptype.image,
    'video': MediaToptype.video,
    'application': MediaToptype.application,
    'model': MediaToptype.model,
    'multipart': MediaToptype.multipart,
    'message': MediaToptype.message,
    'font': MediaToptype.font
  };

  static const Map<String, MediaSubtype> _subtypesByMimeType =
      <String, MediaSubtype>{
    'text/plain': MediaSubtype.textPlain,
    'text/html': MediaSubtype.textHtml,
    'text/calendar': MediaSubtype.textCalendar,
    'text/x-vcalendar': MediaSubtype.textCalendar,
    'text/vcard': MediaSubtype.textVcard,
    'image/jpeg': MediaSubtype.imageJpeg,
    'image/jpg': MediaSubtype.imageJpeg,
    'image/png': MediaSubtype.imagePng,
    'image/bmp': MediaSubtype.imageBmp,
    'image/gif': MediaSubtype.imageGif,
    'image/webp': MediaSubtype.imageWebp,
    'image/svg+xml': MediaSubtype.imageSvgXml,
    'audio/basic': MediaSubtype.audioBasic,
    'audio/webm': MediaSubtype.audioWebm,
    'audio/aac': MediaSubtype.audioAac,
    'audio/aiff': MediaSubtype.audioAiff,
    'audio/mp4': MediaSubtype.audioMp4,
    'audio/mp3': MediaSubtype.audioMp3,
    'audio/midi': MediaSubtype.audioMidi,
    'audio/mod': MediaSubtype.audioMod,
    'audio/x-mod': MediaSubtype.audioMod,
    'audio/mpeg': MediaSubtype.audioMpeg,
    'audio/ogg': MediaSubtype.audioOgg,
    'audio/wav': MediaSubtype.audioWav,
    'audio/x-wav': MediaSubtype.audioWav,
    'video/ogg': MediaSubtype.videoOgg,
    'application/ogg': MediaSubtype.videoOgg,
    'video/h264': MediaSubtype.videoH264,
    'video/mp4': MediaSubtype.videoMp4,
    'application/mp4': MediaSubtype.videoMp4,
    'video/mpeg': MediaSubtype.videoMpeg,
    'video/webm': MediaSubtype.videoWebm,
    'model/mesh': MediaSubtype.modelMesh,
    'model/vnd.collada+xml': MediaSubtype.modelVndColladaXml,
    'model/vrml': MediaSubtype.modelVrml,
    'model/x3d+xml': MediaSubtype.modelX3dXml,
    'model/x3d+vrml': MediaSubtype.modelX3dVrml,
    'model/x3d-vrml': MediaSubtype.modelX3dVrml,
    'model/x3d+binary': MediaSubtype.modelX3dBinary,
    'model/x3d+fastinfoset': MediaSubtype.modelX3dBinary,
    'application/json': MediaSubtype.applicationJson,
    'application/octet-stream': MediaSubtype.applicationOctetStream,
    'application/xml': MediaSubtype.applicationXml,
    'application/zip': MediaSubtype.applicationZip,
    'application/x-zip': MediaSubtype.applicationZip,
    'application/vcard+json': MediaSubtype.applicationVcardJson,
    'application/vcard+xml': MediaSubtype.applicationVcardXml,
    'application/calendar+json': MediaSubtype.applicationCalendarJson,
    'application/calendar+xml': MediaSubtype.applicationCalendarXml,
    'application/pdf': MediaSubtype.applicationPdf,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        MediaSubtype.applicationOfficeDocumentWordProcessingDocument,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.template':
        MediaSubtype.applicationOfficeDocumentWordProcessingTemplate,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        MediaSubtype.applicationOfficeDocumentSpreadsheetSheet,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.template':
        MediaSubtype.applicationOfficeDocumentSpreadsheetTemplate,
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        MediaSubtype.applicationOfficeDocumentPresentationPresentation,
    'application/vnd.openxmlformats-officedocument.presentationml.template':
        MediaSubtype.applicationOfficeDocumentPresentationTemplate,
    'application/pgp-signature': MediaSubtype.applicationPgpSignature,
    'application/pgp-encrypted': MediaSubtype.applicationPgpEncrypted,
    'application/pgp-keys': MediaSubtype.applicationPgpKeys,
    'message/delivery-status': MediaSubtype.messageDeliveryStatus,
    'message/disposition-notification':
        MediaSubtype.messageDispositionNotification,
    'message/rfc822': MediaSubtype.messageRfc822,
    'message/partial': MediaSubtype.messagePartial,
    'multipart/alternative': MediaSubtype.multipartAlternative,
    'multipart/mixed': MediaSubtype.multipartMixed,
    'multipart/parallel': MediaSubtype.multipartParallel,
    'multipart/related': MediaSubtype.multipartRelated,
    'multipart/partial': MediaSubtype.multipartPartial,
    'multipart/digest': MediaSubtype.multipartDigest,
    'multipart/report': MediaSubtype.multipartReport,
    'multipart/signed': MediaSubtype.multipartSigned,
    'multipart/encrypted': MediaSubtype.multipartEncrypted,
    'font/otf': MediaSubtype.fontOtf,
    'font/ttf': MediaSubtype.fontTtf,
    'font/woff': MediaSubtype.fontWoff,
    'font/woff2': MediaSubtype.fontWoff2,
    'font/collection': MediaSubtype.fontCollection
  };

  /// The original text of the media type, e.g. 'text/plain' or 'image/png'.
  final String text;

  /// The top level media type, e.g. text, image, video, audio, application, model, multipart or other
  final MediaToptype top;

  /// The subtdetailed type of the media, e.g. text/plain
  final MediaSubtype sub;

  /// Convenience getter to check of the [top] MediaTopType is text
  bool get isText => top == MediaToptype.text;

  /// Convenience getter to check of the [top] MediaTopType is image
  bool get isImage => top == MediaToptype.image;

  /// Convenience getter to check of the [top] MediaTopType is video
  bool get isVideo => top == MediaToptype.video;

  /// Convenience getter to check of the [top] MediaTopType is audio
  bool get isAudio => top == MediaToptype.audio;

  /// Convenience getter to check of the [top] MediaTopType is application
  bool get isApplication => top == MediaToptype.application;

  /// Convenience getter to check of the [top] MediaTopType is multipart
  bool get isMultipart => top == MediaToptype.multipart;

  /// Convenience getter to check of the [top] MediaTopType is model
  bool get isModel => top == MediaToptype.model;

  /// Convenience getter to check of the [top] MediaTopType is message
  bool get isMessage => top == MediaToptype.message;

  /// Convenience getter to check of the [top] MediaTopType is font
  bool get isFont => top == MediaToptype.font;

  const MediaType(this.text, this.top, this.sub);

  /// Creates a media type from the specified text
  /// The [text] must use the top/sub structure, e.g. 'text/plain'
  static MediaType fromText(String text) {
    text = text.toLowerCase();
    var splitPos = text.indexOf('/');
    if (splitPos != -1) {
      var topText = text.substring(0, splitPos);
      var top = _topLevelByMimeName[topText] ?? MediaToptype.other;
      var sub = _subtypesByMimeType[text] ?? MediaSubtype.other;
      return MediaType(text, top, sub);
    } else {
      var top = _topLevelByMimeName[text] ?? MediaToptype.other;
      return MediaType(text, top, MediaSubtype.other);
    }
  }

  /// Creates a media type from the specified [subtype].
  static MediaType fromSubtype(MediaSubtype subtype) {
    for (var key in _subtypesByMimeType.keys) {
      var sub = _subtypesByMimeType[key];
      if (sub == subtype) {
        var splitPos = key.indexOf('/');
        if (splitPos != -1) {
          var topText = key.substring(0, splitPos);
          var top = _topLevelByMimeName[topText] ?? MediaToptype.other;
          return MediaType(key, top, subtype);
        }
        break;
      }
    }
    print('Error: unable to resolve media subtype $subtype');
    return MediaType('example/example', MediaToptype.other, subtype);
  }

  @override
  String toString() {
    return text;
  }
}
