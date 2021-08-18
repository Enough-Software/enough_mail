import 'dart:io';

import 'package:enough_mail/discover.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
  }
  var forceSsl = false;
  var log = false;
  var onlyPreferred = false;
  var email = args.first;
  if (args.length > 1) {
    args = [...args];
    forceSsl == args.remove('--ssl');
    log = args.remove('--log');
    onlyPreferred = args.remove('--preferred');
    email = args.last;
    if (args.length != 1) {
      email = args.firstWhere((arg) => arg.contains('@'), orElse: () => '');
      args.remove(email);
      print('Invalid arguments: $args');
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
    for (var provider in config.emailProviders!) {
      print('provider: ${provider.displayName}');
      print('provider-domains: ${provider.domains}');
      print('documentation-url: ${provider.documentationUrl}');
      if (!onlyPreferred) {
        print('Incoming:');
        for (var server in provider.incomingServers!) {
          print(server);
        }
      }
      print('Preferred incoming:');
      print(provider.preferredIncomingServer);
      if (!onlyPreferred) {
        print('Outgoing:');
        for (var server in provider.outgoingServers!) {
          print(server);
        }
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
