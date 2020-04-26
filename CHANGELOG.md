## 0.0.12

- Forward messages with MessageBuilder.prepareForwardMessage() (issue #24)

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
