## 0.0.16
- Adding 'name' parameter with quotes to 'Content-Type' header when adding a file

## 0.0.15
- Adding 'name' parameter to 'Content-Type' header when adding a file

## 0.0.14

- Save messages to the server with ImapClient.appendMessage().
- Store message flags using the ImapClient.store() method or use one of the mark-methods like markFlagged() or markSeen().
- Copy message(s) using ImapClient.copy().
- Copy, fetch, store or search message with UIDs using ImapClient.uidCopy(), uidStore(), etc.
- Remove messages marked with the \Deleted flag using ImapClient.expunge()
- Authenticate via OAUTH 2.0 using ImapClient.authenticateWithOAuth2() (AUTH=XOAUTH2) or authenticateWithOAuthBearer() (AUTH=OAUTHBEARER).
- You can now switch to TLS using ImapClient.startTls().
- Query the capabilities using the ImapClient.capability() call.
- Let the server do some housekeeping using the ImapClient.check() method.

## 0.0.13

- Forward complex messages with MessageBuilder.prepareForwardMessage(), too  (issue #24)

## 0.0.12

- Forward messages with MessageBuilder.prepareForwardMessage() 

## 0.0.11

- Adding simple reply generation with MessageBuilder.prepareReplyToMessage() (issue #25)
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

- Always end lines with \r\n when communicating either with SMTP or IMAP server, parse iso-8859-1 encoded headers

## 0.0.2

- Cleaning architecture, adding support for BODY[HEADER.FIELDS] messages

## 0.0.1

- Initial alpha version
