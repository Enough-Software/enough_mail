# 2.1.7
* chore: Update plugin and dependencies versions - thanks to [Dr-Usman](https://github.com/Dr-Usman)!
* chore: pub upgrade to bring in intl 0.20.2 - thanks to [jpohhhh](https://github.com/jpohhhh)!
* Fix: FetchImapResult.replaceMatchingMessages - thanks to [scribetw](https://github.com/scribetw)!
* Fix: trim lines read after decoding - thanks to [vware](https://github.com/vware)!
* Fix: Remove extra double quotes for search query dates - thanks to [ig-garcia](https://github.com/ig-garcia)!

# 2.1.6
* Fix: Fix serialization of ServerConfig - thanks to [RobinJespersen](https://github.com/RobinJespersen)!
* Feat: allow to specify connection timeout in high level API and increase default timeout

# 2.1.5
* Fix: Ensure compatibility with Flutter 3.16 - thanks to [Tzanou123](https://github.com/Tzanou123)!

# 2.1.4
* Fix: use refreshed OAUTH tokens when using the high level MailClient API.
* Fix: handle edge cases in IMAP `FETCH` responses.
* Feat: Add details for low level IMAP errors when using the high level MailCLient API.
* Feat: Refresh OAUTH tokens 15 minutes in advance before they expire to reduce the risk of a token expiring during a long running operation.
* Feat: show error details when SMTP XOAuth2 authentication fails.
* Feat: synchronize access to low level clients when using the high level MailClient API.

# 2.1.3
* Fix: Apply correct mailbox path separator - thanks [nruzzu](https://github.com/nruzzu)!
* Feat: add firstWhereOrNull search method for a Tree
* Feat: add identityFlag getter to Mailbox

# 2.1.2
* Fix: RangeError when a Mailbox name contains a parentheses - thanks [nruzzu](https://github.com/nruzzu)
* Fix: base64 decoding of headers with a lowercase b
* Feat: support more name variations for ISO codecs
* Feat: update dependencies - thanks [hatch01](https://github.com/hatch01)
* Feat: use standard serialization based on json_serializable
* Feat: Improve high level API fetch message support

# 2.1.1
* Loosened dependency restrictions a bit upon suggestion from [hpoul](https://github.com/Enough-Software/enough_mail/issues/194)
* Added support for Big5, KOI8-r and KOI8-u character encodings
* Load encodings only when required

# 2.1.0
* The `MailClient.deleteMessages()` / `undoDeleteMessages()` as well as the `moveMessages()` and `undoMoveMessages()` calls
  will now update the given `messages` UIDs automatically, when they have been specified.
* Simplify building a `multipart/alternative` message or message part by adding the option `plainText` and `htmlText` parameters
  in `MessageBuilder.prepareMultipartAlternativeMessage()` and `addMultipartAlternative()`.
* Fixed documentation for generating a mime message with an attachment (thanks [lqmminh](https://github.com/lqmminh)!).

# 2.0.1
* Thanks to [yarsort](https://github.com/yarsort) resolved various POP3 bugs.
* Interpret mime messages with an (invalid) 2-digit year as coming from the current millennium.


# 2.0.0
Improvements and fixes:
* Thanks to [matthiasn](https://github.com/matthiasn) the date parsing/generation on west of greenwich timezones now works properly.
* Improve automatic re-connecting when using the high-level MailClient API.
* Support timeouts for IMAP, SMTP and POP calls.
* `MimeMessage`:
  - Get an alternative mime part easier with  `MimePart? getAlternativePart(MediaSubtype subtype)`.
  - Retrieve all recipients via the `List<MailAddress> get recipients` getter.
  - Support decoding `binary` transfer-encoding for text message parts.
  - Introduce `guid` / global unique IDs which are set automatically when using the high-level `MailClient`.
  - Correctly unwrap header values before decoding them.
  - Accept headers that have no space after the colon-separator.
* Improve high level API support for OAUTH:
  - You can now define `refresh` and `onConfigChanged` callback methods when connecting to a mail service using `MailClient`.
* Support expunging messages when deleting them in `MailClient` with `Future<DeleteResult> deleteMessages( MessageSequence sequence, {bool expunge = false})`.
OauthAuthentication now contains a complete OauthToken.
 main
* `MessageBuilder`: Access also text-attachments in the `attachments` getter.
* Only use `STARTTLS` when the IMAP service supports it.
* Simplify search API.

Breaking changes:
* Package structure is simplified, so that imports of specific classes are not possible anymore. Instead either `import 'package:enough_mail/enough_mail.dart';` or one of the specializes sub-packages `codecs.dart`,`discover.dart`, `highlevel.dart`, `imap.dart`, `mime.dart`, `pop.dart` or `smtp.dart`.
* `Authentication.passwordCleartext` is renamed to `Authentication.passwordClearText`
* `Mailbox` API has changed specifically when creating mailboxes yourself.

Other:
* Improved code style, enforcing linting rules.
* Improve [API documentation](https://pub.dev/documentation/enough_mail/latest/).
* Improve package structure
* Many further small-scale improvements.

# 1.3.6
- Fix generating messages with several recipients in `MessageBuilder`. Previously semicolons were used that were not accepted by all mail providers.

# 1.3.5
- Add `bool Function(X509Certificate)? onBadCertificate` callback to handle invalid certificates #167
- Stop polling when disconnecting high level `MailClient`
- Ignore subsequent `IDLE` requests when already in idle mode in `ImapClient`
- Improve documentation

# 1.3.4
- Fix some IMAP mailbox commands when there is no mailbox selected: #160 #164 #165

# 1.3.3
- Add easier method to setup a `MailAccount` with manual settings by calling `MailAccount.fromManualSettings()` 
  or `MailAccount.fromManualSettingsWithAuth()`. This is useful when settings cannot or should not be auto-discovered, for example.

# 1.3.2
- Fix login for IMAP servers that do not define capabilities in their `AUTH`/`LOGIN` response #159

# 1.3.1
- Always quote user name and password in IMAP login, #158
- Thanks to [fttx2020](https://github.com/fttx2020) we have these great improvements:
  - Fix for POP3 UID LIST command
  - Fix parsing of POP3 responses
  - Handle more Chinese character encodings
  - Handle some base64 text variations better
- `SmtpException`s now contain the full error description

# 1.3.0
- Support read receipts #149
  - Check if a message contains a read receipt request with `MimeMessage.isReadReceiptRequested`
  - Generate a read request response with `MessageBuilder.buildReadReceipt()`
- Support Windows-1256 encoding
- Add another message as an attachment with `MessageBuilder.addMessagePart()` #153
- Easily retrieve all leaf parts after loading `BODYSTRUCTURE` with `MimeMessage.body.allLeafParts`
- Fix for responses with a line break spread around 2 chunks #140
- Improve identification of message parts with their `fetchId` #141 #143 - Thanks to [A.Zulli](https://github.com/azulli) again!
- Messages are now send with `utf-8` rather than `utf8` to reduce problems #144 - Thanks to [gmalakov](https://github.com/gmalakov)
- Fix for responses with a literal `{0}` response #145
- Better detection of plain text messages thanks to [castaway](https://github.com/castaway)


# 1.2.2
- Assume `8bit` encoding when no `content-transfer-encoding` is specified in a MIME message.
- Exclude empty address-lists when building a message with `MessageBuilder`.
- Retrieve a MIME part wit the fetchId `1` correctly.
- `ImapClient.idleStart()` throws an error when no mailbox is selected.
- `MailClient.fetchMessageContents()` allows you to specify which media types you want to include with the `includedInlineTypes` parameter, e.g. `final mime = await mailClient.fetchMessageContents(envelopeMime, includedInlineTypes: [MediaToptype.image]);`.
- Convenience improvements:
  * Select a mailbox just by it's flag like `MailboxFlag.sent` with `MailClient.selectMailboxByFlag(MailboxFlag)` method.
  * Check if an email address contains a personal name with `MailAddress.hasPersonalName` getter.

# 1.2.1
- Handle raw data in parameter values of IMAP `FETCH` responses.

# 1.2.0
- Thanks to [KevinBLT](https://github.com/KevinBLT) mime messages will now always have a valid date header.
- The high level search API has been extended and access simplified
- The high level thread API has been simplified

# 1.1.0
- Thanks to [A.Zulli](https://github.com/azulli) the `UNSELECT` IMAP command of [rfc3691](https://tools.ietf.org/html/rfc3691) is now supported with `ImapClient.unselectMailbox()`.
- Support [THREAD](https://tools.ietf.org/html/rfc5256) IMAP Extension with `ImapClient.threadMessages()` and `uidThreadMessage()` as well as the high level API `MailClient.fetchThreads()` and `fetchThreadData()`, the latter can set the `MimeMessage.threadSequence` automatically. #44
- Access embedded `message/rfc822` messages using `mimePart.decodeContentMessage()`. #138
- Added `SearchQueryType.toOrFrom` to easily search for recipients or senders of a message.
- All Mailbox commands now return the mailbox in question, not the currently selected mailbox.
- Improve automatic reconnects in high level `MailClient` API.
- Added high level OAuth login option and `MailAccount.fromDiscoveredSettingsWithAuth()` for easy setup. #137
- Appending a message will now return the new UID of that message.
- Continue editing a draft easily by calling `MessageBuilder prepareFromDraft(MimeMessage draft)`.
- You now easier load the next page of of search using `MailClient.searchMessagesNextPage(MailSearchResult)`.
- Improve null-safety.
- Breaking API changes:
  - To align with Dart APIs, `MessageSequence.isEmpty` and `isNotEmpty` are now getters and not methods anymore. So instead of `if (sequence.isEmpty())` please now use `if (sequence.isEmpty)`, etc.
  - Date headers are always decoded to local time. Instead of `mimeMessage.decodeDate().toLocal()` now just call `mimeMessage.decodeDate()`.
  - High level API `MailSearchResult` has been refactored to use `PagedMessageSequence`.

# 1.0.0
- `enough_mail` is now [null safe](https://dart.dev/null-safety/tour) #127
- Support `zulu` timezone in date decoding #132
- When the `MailClient` loses a connection or reconnects, it will now fire corresponding `MailConnectionLost` and `MailConnectionReEstablished` events.
- When the `MailClient` reconnects, it will fetch new messages automatically and notify about them using `MailLoadEvent`.
- Breaking changes to `v0.3`:
  * `MessageBuilder.encoding` is renamed to `MessageBuilder.transferEncoding` and the `enum` previously called  `MessageEncoding` is now called `TransferEncoding`. All optional parameters previously called `encoding` are now also named `transferEncoding`.
  * `MetaDataEntry.entry` has been renamed to `MetaDataEntry.name`.
  * `ImapClient.setQuota()` and `getQuota()` methods use named parameters.
  * Due to null safety, a lots of functions that previously (wrongly) accepted `null` parameters do not accept `null` as input anymore.
  * Some fields changed to `final` to ensure consistency.


## 0.3.1
* Fix for handling `PARTIAL` IMAP responses - thanks to [A.Zulli](https://github.com/azulli)
* Fix for handling `FETCH` IMAP responses that are spread across several response lines for a single message - #131

## 0.3.0
- [KevinBLT](https://github.com/KevinBLT) contributed the following improvements and features:
  * Check out the experimental [DKIM](https://tools.ietf.org/html/rfc6376) signing of messages.
  * Enjoy the improved the performance of `QuotedPrintable` encoding.
  * BCC header is now stripped from messages before sending them via SMTP
- [A.Zulli](https://github.com/azulli) contributed major IMAP features in this release:
  * Sort messages with `ImapClient.sortMessages(...)` [SORT](https://tools.ietf.org/html/rfc5256) - and also use the extended sort mechanism with specifying `returnOptions` on servers with [ESORT](https://tools.ietf.org/html/rfc5267).
  * `ImapClient.searchMessages(...)` now accepts `List<ReturnOption>` parameter for extending the search according to the [ESEARCH](https://tools.ietf.org/html/rfc4731) standard.
  * Support `PARTIAL` responses according to the [CONTEXT](https://tools.ietf.org/html/rfc5267) IMAP extension.
  * Use the LIST extensions:
    * [rfc5258](https://tools.ietf.org/html/rfc5258): `LIST` command extensions
    * [rfc5819](https://tools.ietf.org/html/rfc5819): return `STATUS` in extended lists
    * [rfc6154](https://tools.ietf.org/html/rfc6154): `SPECIAL-USE` mailboxes
- [Alexander Sotnikov](https://github.com/SotnikAP) fixed `POP3` so that you can now use the `PopClient` as intended.
- SMTP improvements:
  * You can now send messages via the SMTP `BDAT` command using `SmtpClient.sendChunkedMessage()` / `sendChunkedMessageData()` / `sendChunkedMessageText()`.
  * You don't require a `MimeMessage` to send any more when you send messages either via `SmtpClient.sendMessageData()` or `SmtpClient.sendMessageText()`.
- MessageBuilder / MIME generation improvements:
  * Attachments are now also added when forrwarding a message without quoting in `MessageBuilder.prepareForwardMessage()`.
  * You can now also prepend parts by setting `insert` to `true` when calling `addPart()`.
- Other improvements and bugfixes:
  * Remove some dependencies and relax constraints on some so that we all get quicker through the `null-safety` challenge.
  * Fixed decoding of 8bit messages that use a different charset than UTF8
  * Fixed header decoding in some edge cases
  * Some fixes in parsing personal names in email addresses
  * Support Chinese encodings `GBK` and `GB-2312`
  * Improve reconnecting when using the high level API
  * Only download the `ENVELOPE` information when a new mail is detected in high level API
- Breaking changes:
  * `MessageBuilder.replyToMessage` is renamed to `MessageBuilder.originalMessage`

## 0.2.1
- Allow to specify `connectionTimeout` for all low level clients
- Support non-ASCII IMAP searches when supported by server
- Fix reconnection issue for `ImapClient`
- Fix decoding of sequentiell encoded words in edge cases
- Do a `noop` when resuming `MailClient` when server does not support `IDLE`

## 0.2.0
- ImapClient now processes tasks sequentially, removing the dreaded `StreamSink is bound to a stream` exception when accessing ImapClient from several threads.
- Highlevel API for adding mail messages with `MailClient.appendMessage(...)` / `.appendMessageToFlag(...)` and `MailClient.saveDraftMessage(...)`
- Searching for messages is now easier than ever with `MailClient.search(MailSearch)` and `SearchQueryBuilder`- #109
- Sent messages are now appended automatically when using the high level `MailClient.sentMessage(...)` call unless setting the `appendToSent` parameter to `false`.
- Create IMAP search criteria with `SearchQueryBuilder` and conduct common searches with `MailClient.search(MailSearch)`
- Fixed detection of audio media types
- Added `CRAM-MD5` authentication support for SMTP - #108
- Added `XOAUTH2` authentication support for SMTP -  #107
- Create MessageSequence from list of mime messages with `MessageSequence.fromMessages(List<MimeMessage>)`
- You can now check with the highlevel API if you can send 8bit messages with `MailClient.supports8BitEncoding()` and set the preferred encoding with `MailClient.buildMimeMessageWithRecommendedTextEncoding(MessageBuilder)`.
- `MessageBuilder` now can recommend text encodings with `MessageBuilder.setRecommendedTextEncoding(bool supports8Bit)` and sets content types automatically depending on attachments.
- Access attachment information easier using the `MessageBuilder.attachments` field and the `AttachmentInfo` class.
- You can send a `MessageBuilder` instance instead of a `MimeMessage` with `MailClient.sendMessageBuilder(...)`.
- Breaking API changes:
  * `SmtpClient.login()` is deprecated, please use the better named `SmtpClient.authenticate()` instead, e.g.:
   `await smtpClient.authenticate(userName, password, AuthMechanism.login)`
  * `BodyPart.id` is renamed to `BodyPart.cid` to make the meaning clearer.

## 0.1.0
- Moving from response based to exceptions, compare the migration guide for details compare the migration guide in [Readme.md](https://github.com/Enough-Software/enough_mail/blob/main/README.md#Migrating) and #101 for details - specicial thanks to [Tienisto](https://github.com/Tienisto)
- Improved performance when downloading large data significantly
- High Level API now checks for SMTP START TLS support before switching to a secure connection when connected via plan sockets
- Low level SMTP API now exposes all found server capabilities
- Fix decoding bug for UTF8 8 bit encoded text
- `ImapClient.search(...)` now returns a `MessageSequence` instead just a list of integers
- High level API now supports moving messages with `MailClient.moveMessages(...)` and `MailClient.undoMoveMessages()` methods
- High level API now supports deleting messages with `MailClient.deleteMessages(...)` and `MailClient.undoDeleteMessages()`  methods

## 0.0.36
- Remove spaces between two encoded words in headers
- High level API support for deleting messages and undoing it:
  - `Future<MailResponse<DeleteResult>> deleteMessages(`
    `  MessageSequence sequence, Mailbox trashMailbox)`
  - `Future<MailResponse<DeleteResult>> deleteAllMessages(Mailbox mailbox,`
    `  {bool expunge})`
- Deleted messages are now preferably moved to `\Trash` folder, when possible.
- Optionally mark a message as seen by setting `markAsSeen` parameter to `true` when fetching messages or message contents
  using the high level API, e.g. `MailClient.fetchMessageContents(message, markAsSeen: true)`;

## 0.0.35
- Ignoring malformed UT8 when logging thanks to [Tienisto](https://github.com/Tienisto).
- Use `enough_convert` package for previously missing character encodings.
- Add ` MimeMessage.parseFromText(String text)` helper method.
- Add Open PGP mime types like `MediaSubtype.applicationPgpSignature` to known media types.

## 0.0.34
- Fix handling of `VANISHED (EARLIER)` responses in edge cases thanks to [Andrea](https://github.com/andreademasi).
- Find a mime message part by its content-ID with the `MimeMessage.getPartWithContentId(String cid)` helper method.
- List all parts of a mime message sequentially using the `MimeMessage.allPartsFlat` getter.
- Fix problems with `UTF8` 8-bit decoded answers.
- Use the [enough_serialization](https://pub.dev/packages/enough_serialization) for JSON (de)serialization support.
- Improve discovery of mail settings.
- Allow to limit the download size of messages:  `MailClient.fetchMessageContents(MimeMessage message, {int maxSize})` fetches all parts apart from attachments when the message size is bigger than the one specified in bytes in `maxSize`.
- Improve documentation, also thanks to [TheOneWithTheBraid](https://github.com/theonewiththebraid).


## 0.0.33
- Support IMAP [QUOTA Extension](https://tools.ietf.org/html/rfc2087) thanks to [azulli](https://github.com/azulli).
- Throw exceptions that might occur while sending a message thanks to [hpoul](https://github.com/hpoul).
- Retrieve currently selected mailbox in highlevel API with `MailClient.selectedMailbox`.
- Specify `fetchPreference` in highlevel API when fetching messages, for example to only fetch `ENVELOPE`s first.
- Create a message builder based on a mailto link with `MessageBuilder.prepareMailtoBasedMessage()`.
- Mail events now contain the originating ImapClient, SmtpClient or MailClient instance to match the event when having several active accounts at the same time.
- Support the SMTP `AUTH LOGIN` authentication by specying the `authMechanism` parameter in `SmtpClient.login()`.
- Ease flagging of messages with `MailClient.flagMessage()`.
- Highlevel API now udates flags of a message correctly when they have changed remotely.

## 0.0.32
- easier to retrieve and set common message flags such as `\Seen`, `\Answered` and `$Forwarded`
- use `MimeMessage.isSeen`, `.isAnswered`, `.isForwarded` to query the corresponding flags
- use `MimeMessage.hasAttachments()` or `MimeMessage.hasAttachmentsOrInlineNonTextualParts()` to determine if the message contains attachment parts.
- [Q-Encoding](https://tools.ietf.org/html/rfc2047#section-4.2) is used for encoding/decoding corresponding MIME message headers now, compare #77 for details

## 0.0.31
- Mime: List all message parts with a specfic Content-Disposition with `MimeMessage.findContentInfo(ContenDisposition disposition)`.
- Mime: Retrieve an individual message part with `MimeMessage.getPart(String fetchId)`
- Bugfix: fetch individual message parts via IMAP with `BODY[1.2]` now works.
- MailClient: Download individual message parts with `MailClient.fetchMessagePart(MimeMessage message, String fetchId)`.
- MailClient: events now provide reference to used `MailClient` instance, so that apps can differentiate between accounts.
- MessageBuilder: allow to specify user aliases and to handle + aliases and to differentiate between reply and reply-all in `MessageBuilder.prepareReplyToMessage()`
- ImapClient: Ensure that every Inbox has a `MailboxFlag.inbox`.

## 0.0.30
- Thanks to [hpoul](https://github.com/hpoul) the XML library now works with both beta and stable flutter channels.
- Thanks to [hydeparkk](https://github.com/hydeparkk) encoded mailbox paths are now used in copy, move, status and append/
- Fix decoding message date headers
- Fix handling mailboxes with a space in their path
- Allow to easly serialize and deserialize [MailAccount](https://pub.dev/documentation/enough_mail/latest/mail_mail_account/MailAccount-class.html) to/from JSON.
- Extended high level [MailClient API](https://pub.dev/documentation/enough_mail/latest/mail_mail_client/MailClient-class.html):
  - Allow to select mailbox by path
  - Disconnect to close connections
  - Include fetching message flags when fetching messages
  - Allow to store message flags, e.g. mark as read
  - Provide access to low level API from within the high level API

## 0.0.29
- Add `discconect()` method to high level `MailClient` API
- Encode and decode mailbox names using Modified UTF7 encoding
- Add [IMAP support for UTF-8](https://tools.ietf.org/html/rfc6855)

## 0.0.28
- High level `MailClient` API supports IMAP IDLE, POP and SMTP.

## 0.0.27
- Downgraded crypto dependency to be compatible with flutter_test ons stable flutter channel again

## 0.0.26
- Added high level `MailClient` API
- Downgraded XML dependency to be compatible with flutter_test again
- Fixed `ImapClient`'s `eventBus` registration when this is specified outside of ImapClient.

## 0.0.25
- Add support to discover email settings using the `Discover` class.

## 0.0.24
- Improve parsing of IMAP `BODYSTRUCTURE` responses to FETCH commands.
- Add message media types.

## 0.0.23
- Provide [POP3](https://tools.ietf.org/html/rfc1939) support

## 0.0.22
- Breaking API change: use FETCH IMAP methods now return `FetchImapResult` instead of `List<MimeMessage>`
- Breaking API change: `ImapFetchEvent` now contains a full `MimeMessage` instead of just the sequence ID and flags
- Added `ImapVanishedEvent` that is called instead of `ImapExpungeEvent` when QRESYNC has been enabled
- Added support for [QRESYNC extension](https://tools.ietf.org/html/rfc7162)
- Added support for [ENABLE extension](https://tools.ietf.org/html/rfc5161)
- Fix handling STATUS responses (issue #56)

## 0.0.21
- Added support for ISO 8859-15 / latin9 encoding - based on UTF-8

## 0.0.20
- Breaking change: use `MessageSequence` for defining message ID or UID ranges instead of integer-based IDs

## 0.0.19
- Fix for fetching recent messages when the chunksize is larger than the existing messages - thanks to studiozocaro!

## 0.0.18
- Breaking API changes: `MimeMessage.body` API, get and set text/plain and text/html parts in MimeMessage
- Support nested BODY and BODYSTRUCTURE responeses when fetching message data
- Support [CONDSTORE IMAP extension](https://tools.ietf.org/html/rfc5161)
- Support [MOVE IMAP extension](https://tools.ietf.org/html/rfc6851)
- Support [UIDPLUS IMAP extension](https://tools.ietf.org/html/rfc6851)

## 0.0.17
- Supports parsing BODYSTRUCTURE responses when fetching message data
- Also eased API for accessing BODY and BODYSTRUCTURE response data

## 0.0.16
- Adding 'name' parameter with quotes to 'Content-Type' header when adding a file

## 0.0.15
- Adding 'name' parameter to 'Content-Type' header when adding a file

## 0.0.14

- Save messages to the server with `ImapClient.appendMessage()`.
- Store message flags using the `ImapClient.store()` method or use one of the mark-methods like `markFlagged()` or `markSeen()`.
- Copy message(s) using `ImapClient.copy()`.
- Copy, fetch, store or search message with UIDs using `ImapClient.uidCopy()`, `uidStore()`, etc.
- Remove messages marked with the \Deleted flag using `ImapClient.expunge()`
- Authenticate via OAUTH 2.0 using `ImapClient.authenticateWithOAuth2()` (AUTH=XOAUTH2) or `authenticateWithOAuthBearer()` (AUTH=OAUTHBEARER).
- You can now switch to TLS using `ImapClient.startTls()`.
- Query the capabilities using the `ImapClient.capability()` call.
- Let the server do some housekeeping using the `ImapClient.check()` method.

## 0.0.13

- Forward complex messages with `MessageBuilder.prepareForwardMessage()`, too  (issue #24)

## 0.0.12

- Forward messages with `MessageBuilder.prepareForwardMessage()`

## 0.0.11

- Adding simple reply generation with `MessageBuilder.prepareReplyToMessage()` (issue #25)
- Improvement for adding larger files (issue #28)


## 0.0.10

- Fix for message sending via SMTP (issue #27)

## 0.0.9

- Introducing MessageBuilder for easy mime message creation
- Adapted example

## 0.0.8

- Ease access to text contents of a mime message
- Adapted example

## 0.0.7

- Parse MIME messages using MimeMessage.parse()
- Handle content encodings more reliably


## 0.0.6

- Supporting ASCII character character encodings and padding BASE64 headers if required

## 0.0.5

- Addressed health and syntax recommendations

## 0.0.4

- Support [IMAP METADATA Extension](https://tools.ietf.org/html/rfc5464)

## 0.0.3

- Always end lines with `\r\n` when communicating either with SMTP or IMAP server, parse iso-8859-1 encoded headers

## 0.0.2

- Cleaning architecture, adding support for `BODY[HEADER.FIELDS]` messages

## 0.0.1

- Initial alpha version
