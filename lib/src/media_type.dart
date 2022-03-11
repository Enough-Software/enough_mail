/// Top level media types
enum MediaToptype {
  /// text media
  text,

  /// image media, can be animated
  image,

  /// audio media
  audio,

  /// video media
  video,

  /// application specific media, eg JSON
  application,

  /// media consisting of several other media parts
  multipart,

  /// media that contains a message
  message,

  /// media containing a 3D model
  model,

  /// media containing a text font
  font,

  /// unrecognized media
  other,
}

// cSpell:disable
/// Detailed media types
/// Compare https://www.iana.org/assignments/media-types/media-types.xhtml
enum MediaSubtype {
  /// `text/plain` just plain/normal text
  textPlain,

  /// `text/html` text in HTML format
  textHtml,

  /// `text/calendar` or `x-vcalendar` https://www.iana.org/go/rfc5545
  ///
  /// as an attachment you can also use [MediaSubtype.applicationIcs]
  textCalendar,

  /// `text/vcard` https://www.iana.org/go/rfc6350
  textVcard,

  /// `text/markdown` https://www.iana.org/go/rfc7763
  textMarkdown,

  /// `text/rfc822-headers` Headers of an email message
  textRfc822Headers,

  /// `audio/basic` basic audio
  audioBasic,

  /// `audio/mpeg` mpeg audio
  audioMpeg,

  /// `audio/mp3` mp3 audio
  audioMp3,

  /// `audio/mp4` mp4 audio
  audioMp4,

  /// `audio/ogg` ogg audio
  audioOgg,

  /// `audio/wav` wav audio
  audioWav,

  /// `audio/midi` midi audio
  audioMidi,

  /// `audio/mod` mod audio
  audioMod,

  /// `audio/aiff` aiff audio
  audioAiff,

  /// `audio/webm` webm audio
  audioWebm,

  /// `audio/aac` aac audio
  audioAac,

  /// `image/jpeg` jpeg/jpg image
  imageJpeg,

  /// `image/png` png image
  imagePng,

  /// `image/gif` gif image
  imageGif,

  /// `image/webp` webp image
  imageWebp,

  /// `image/bmp` bmp image
  imageBmp,

  /// `image/svg+xml` svg image in xml format
  imageSvgXml,

  /// `video/mpeg` mpeg video
  videoMpeg,

  /// `video/mp4` mp4 video
  videoMp4,

  /// `video/webm` webm video
  videoWebm,

  /// `video/h264` h264 video
  videoH264,

  /// `video/ogg` ogg video
  videoOgg,

  /// `application/json` json data
  applicationJson,

  /// `application/zip` compressed file
  applicationZip,

  /// `application/xml` xml data
  applicationXml,

  /// `application/octet-stream` binary data
  applicationOctetStream,

  /// `application/calendar+json` calendar data https://www.iana.org/go/rfc7265
  applicationCalendarJson,

  /// `application/calendar+xml` calendar data https://www.iana.org/go/rfc6321
  applicationCalendarXml,

  /// `application/vcard+json` contact data
  applicationVcardJson,

  /// `application/vcard+xml` contact data
  applicationVcardXml,

  /// `application/pdf` https://www.iana.org/go/rfc8118
  applicationPdf,

  /// `application/ics` iCalendar attachment
  ///
  /// Within an alternative multipart you need to use
  /// [MediaSubtype.textCalendar] instead
  applicationIcs,

  /// `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
  applicationOfficeDocumentWordProcessingDocument,

  /// `application/vnd.openxmlformats-officedocument.wordprocessingml.template`
  applicationOfficeDocumentWordProcessingTemplate,

  /// `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
  applicationOfficeDocumentSpreadsheetSheet,

  /// `application/vnd.openxmlformats-officedocument.spreadsheetml.template`
  applicationOfficeDocumentSpreadsheetTemplate,

  /// `application/vnd.openxmlformats-officedocument.presentationml.presentation`
  applicationOfficeDocumentPresentationPresentation,

  /// `application/vnd.openxmlformats-officedocument.presentationml.template`
  applicationOfficeDocumentPresentationTemplate,

  /// `application/pgp-signature` part that contains the signature
  ///
  /// https://tools.ietf.org/html/rfc3156
  applicationPgpSignature,

  /// `application/pgp-encrypted` encrypted message part
  ///
  /// https://tools.ietf.org/html/rfc3156
  applicationPgpEncrypted,

  /// `applicationPgpKeys` part that contains PGP keys
  ///
  /// compare https://tools.ietf.org/html/rfc3156
  applicationPgpKeys,

  /// `model/mesh` 3D model
  modelMesh,

  /// `model/vrml` 3D model
  modelVrml,

  /// `model/x3d+xml` 3D model
  modelX3dXml,

  /// `model/x3d+vrml` or `model/x3d-vrml` 3D model
  modelX3dVrml,

  /// `model/x3d+binary` or `model/x3d+fastinfoset` 3D model
  modelX3dBinary,

  /// `model/vnd.collada+xml` 3D model
  modelVndColladaXml,

  /// `message/rfc822` embedded message,
  ///
  /// https://tools.ietf.org/html/rfc2045 https://tools.ietf.org/html/rfc2046
  messageRfc822,

  /// `message/partial` partial message,
  ///
  /// https://tools.ietf.org/html/rfc2045 https://tools.ietf.org/html/rfc2046
  messagePartial,

  /// delivery status of a message,
  ///
  /// https://tools.ietf.org/html/rfc1894
  messageDeliveryStatus,

  /// read receipt,
  ///
  /// https://tools.ietf.org/html/rfc8098
  messageDispositionNotification,

  /// `multipart/alternative` show on of the embedded parts
  multipartAlternative,

  /// `multipart/mixed` show all embedded parts in the given sequence
  multipartMixed,

  /// `multipart/parallel` show all embedded parts at once
  multipartParallel,

  /// `multipart/partial` contains a single part of a bigger complete part.
  multipartPartial,

  /// `multipart/related` contains parts that belong logically together
  multipartRelated,

  /// `multipart/digest` contains several rcf822 messages
  multipartDigest,

  /// `multipart/signed` signed message
  ///
  /// https://tools.ietf.org/html/rfc1847
  multipartSigned,

  /// `multipart/encrypted` encrypted message
  ///
  /// https://tools.ietf.org/html/rfc1847
  multipartEncrypted,

  /// `multipart/report` Report
  ///
  /// https://tools.ietf.org/html/rfc6522
  multipartReport,

  /// `font/otf` otf font
  fontOtf,

  /// `font/ttf` ttf font
  fontTtf,

  /// `font/woff` woff font
  fontWoff,

  /// `font/woff2` woff2 font
  fontWoff2,

  /// `font/collection` collection of several fonts
  fontCollection,

  /// other  media sub type
  other
}
// cSpell:enable

/// Extension on [MediaSubtype]
extension MediaSubtypeExtension on MediaSubtype {
  /// Retrieves a new media type based on this subtype
  MediaType get mediaType => MediaType.fromSubtype(this);
}

/// Describes the media type of a MIME message part
///
/// Compare https://www.iana.org/assignments/media-types/media-types.xhtml for a list of common media types.
class MediaType {
  /// Creates a new media type
  const MediaType(this.text, this.top, this.sub);

  /// Creates a media type from the specified text
  ///
  /// The [text] must use the top/sub structure, e.g. 'text/plain'
  factory MediaType.fromText(String text) {
    final lcText = text.toLowerCase();
    final splitPos = lcText.indexOf('/');
    if (splitPos != -1) {
      final topText = lcText.substring(0, splitPos);
      final top = _topLevelByMimeName[topText] ?? MediaToptype.other;
      final sub = _subtypesByMimeType[lcText] ?? MediaSubtype.other;
      return MediaType(lcText, top, sub);
    } else {
      final top = _topLevelByMimeName[lcText] ?? MediaToptype.other;
      return MediaType(lcText, top, MediaSubtype.other);
    }
  }

  /// Creates a media type from the specified [subtype].
  factory MediaType.fromSubtype(MediaSubtype subtype) {
    for (final key in _subtypesByMimeType.keys) {
      final sub = _subtypesByMimeType[key];
      if (sub == subtype) {
        final splitPos = key.indexOf('/');
        if (splitPos != -1) {
          final topText = key.substring(0, splitPos);
          final top = _topLevelByMimeName[topText] ?? MediaToptype.other;
          return MediaType(key, top, subtype);
        }
        break;
      }
    }
    print('Error: unable to resolve media subtype $subtype');
    return MediaType('example/example', MediaToptype.other, subtype);
  }

  /// Tries to guess the media type from [fileNameOrPath].
  ///
  /// If it encounters an unknown extension, the `application/octet-stream`
  /// media type is returned.
  /// Alternatively use [MediaType.guessFromFileExtension]
  /// for the same results.
  factory MediaType.guessFromFileName(String fileNameOrPath) {
    final lastDotIndex = fileNameOrPath.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < fileNameOrPath.length - 1) {
      final ext = fileNameOrPath.substring(lastDotIndex + 1).toLowerCase();
      return MediaType.guessFromFileExtension(ext);
    }
    return MediaSubtype.applicationOctetStream.mediaType;
  }

  // cSpell:disable
  /// Tries to guess the media type from the specified file extension [ext].
  ///
  /// If it encounters an unknown extension, the `application/octet-stream`
  /// media type is returned.
  /// Alternatively use [MediaType.guessFromFileName] for the same results.
  factory MediaType.guessFromFileExtension(final String ext) {
    switch (ext.toLowerCase()) {
      case 'txt':
        return MediaType.textPlain;
      case 'html':
        return MediaSubtype.textHtml.mediaType;
      case 'vcf':
        return MediaSubtype.textVcard.mediaType;
      case 'jpg':
      case 'jpeg':
        return MediaSubtype.imageJpeg.mediaType;
      case 'png':
        return MediaSubtype.imagePng.mediaType;
      case 'webp':
        return MediaSubtype.imageWebp.mediaType;
      case 'pdf':
        return MediaSubtype.applicationPdf.mediaType;
      case 'doc':
      case 'docx':
        return MediaSubtype
            .applicationOfficeDocumentWordProcessingDocument.mediaType;
      case 'ppt':
      case 'pptx':
        return MediaSubtype
            .applicationOfficeDocumentPresentationPresentation.mediaType;
      case 'xls':
      case 'xlsx':
        return MediaSubtype.applicationOfficeDocumentSpreadsheetSheet.mediaType;
      case 'mp3':
        return MediaSubtype.audioMp3.mediaType;
      case 'mp4':
        return MediaSubtype.videoMp4.mediaType;
      case 'zip':
        return MediaSubtype.applicationZip.mediaType;
    }
    return MediaSubtype.applicationOctetStream.mediaType;
  }
  // cSpell:enable

  /// `text/plain` media type
  static const MediaType textPlain =
      MediaType('text/plain', MediaToptype.text, MediaSubtype.textPlain);

  static const Map<String, MediaToptype> _topLevelByMimeName =
      <String, MediaToptype>{
    'application': MediaToptype.application,
    'audio': MediaToptype.audio,
    'image': MediaToptype.image,
    'font': MediaToptype.font,
    'message': MediaToptype.message,
    'model': MediaToptype.model,
    'multipart': MediaToptype.multipart,
    'text': MediaToptype.text,
    'video': MediaToptype.video,
  };

  // cSpell:disable
  static const Map<String, MediaSubtype> _subtypesByMimeType =
      <String, MediaSubtype>{
    'text/plain': MediaSubtype.textPlain,
    'text/html': MediaSubtype.textHtml,
    'text/calendar': MediaSubtype.textCalendar,
    'text/x-vcalendar': MediaSubtype.textCalendar,
    'text/vcard': MediaSubtype.textVcard,
    'text/markdown': MediaSubtype.textMarkdown,
    'text/rfc822-headers': MediaSubtype.textRfc822Headers,
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
    'application/ics': MediaSubtype.applicationIcs,
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
  // cSpell:enable

  /// The original text of the media type, e.g. 'text/plain' or 'image/png'.
  final String text;

  /// The top level media type
  ///
  /// E.g. `text`, `image`, `video`, `audio`, `application`, `model`,
  /// `multipart` or other
  final MediaToptype top;

  /// The sub-type of the media, e.g. `text/plain`
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

  @override
  String toString() => text;
}
