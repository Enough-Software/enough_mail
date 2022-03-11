// METADATA supporting classes, compare https://tools.ietf.org/html/rfc5464

import 'dart:typed_data';

/// Contains meta data entries
class MetaDataEntries {
  /// Defines a comment or note that is associated with the server
  /// and that is shared with authorized users of the server.
  static const String sharedCommend = '/shared/comment';

  /// Indicates a method for contacting the server administrator.
  ///
  /// The value MUST be a URI (e.g., a mailto: or tel: URL).  This entry is
  /// always read-only -- clients cannot change it.  It is visible to
  /// authorized users of the system.
  static const String sharedAdmin = '/shared/admin';

  /// Defines the top level of shared entries associated with the server,
  /// as created by a particular product of some vendor.
  ///
  /// This entry can be used by vendors to provide server- or client-specific
  /// annotations.  The vendor-token MUST be registered with IANA, using
  /// the Application Configuration Access Protocol (ACAP) RFC2244
  /// vendor subtree registry.
  static const String sharedVendor = '/shared/vendor/';

  /// Defines the top level of private entries associated with the server,
  ///  as created by a particular product of some vendor.
  ///
  /// This entry can be used by vendors to provide server- or client-specific
  /// annotations.  The vendor-token MUST be registered with IANA, using
  /// the ACAP RFC2244 vendor subtree registry.
  static const String privateVendor = '/private/vendor/';
}

/// The depth of a meta data request
enum MetaDataDepth {
  /// only direct value is returned, no children (0)
  none,

  /// the direct value plus its immediate children are returned (1)
  directChildren,

  /// the direct value and any children and children's children etc are
  /// returned (infinity)
  allChildren
}

/// A meta data element
class MetaDataEntry {
  /// Creates a new meta data entry
  MetaDataEntry({required this.name, this.mailboxName = '', this.value});

  /// name of the associated mailbox
  final String mailboxName;

  /// name of this entry
  final String name;

  /// Optional binary value
  final Uint8List? value;

  /// Optional textual value
  String? get valueText {
    final value = this.value;
    return value == null ? null : String.fromCharCodes(value);
  }
}
