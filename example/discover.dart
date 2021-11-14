import 'dart:io';

import 'package:enough_mail/discover.dart';

// ignore: avoid_void_async
void main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
  }
  var forceSsl = false;
  var log = false;
  var onlyPreferred = false;
  var email = args.first;
  if (args.length > 1) {
    final arguments = [...args];
    forceSsl = arguments.remove('--ssl');
    log = arguments.remove('--log');
    onlyPreferred = arguments.remove('--preferred');
    email = arguments.last;
    if (arguments.length != 1) {
      email = args.firstWhere((arguments) => arguments.contains('@'),
          orElse: () => '');
      arguments.remove(email);
      print('Invalid arguments: $arguments');
      _usage();
    }
  }
  if (!email.contains('@')) {
    _usage();
  }
  print('Resolving for email $email...');
  final config = await Discover.discover(
    email,
    forceSslConnection: forceSsl,
    isLogEnabled: log,
  );
  if (config == null) {
    print('Unable to discover settings for $email');
  } else {
    print('Settings for $email:');
    for (final provider in config.emailProviders!) {
      print('provider: ${provider.displayName}');
      print('provider-domains: ${provider.domains}');
      print('documentation-url: ${provider.documentationUrl}');
      if (!onlyPreferred) {
        print('Incoming:');
        provider.incomingServers?.forEach(print);
      }
      print('Preferred incoming:');
      print(provider.preferredIncomingServer);
      if (!onlyPreferred) {
        print('Outgoing:');
        provider.outgoingServers?.forEach(print);
      }
      print('Preferred outgoing:');
      print(provider.preferredOutgoingServer);
    }
  }
  exit(0);
}

void _usage() {
  print('Tries to discover email settings.');
  print('Usage: dart example/discover.dart [options] email');
  print('Options:');
  print('--ssl: enforce SSL usage');
  print('--log: log details during discovery');
  print('--preferred: only print the preferred incoming and outgoing servers');
  print('');
  print('Example:');
  print('dart example/discover.dart --log your-email@domain.com');
  exit(1);
}
