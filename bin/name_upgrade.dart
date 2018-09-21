import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:w_module/src/bin/analyzer_tools.dart';
import 'package:w_module/src/bin/utils.dart';

const String helpArg = 'help';
const String helpAbbr = 'h';
const String targetArg = 'target';
const String targetAbbr = 't';

final ArgParser argParser = new ArgParser()
  ..addOption(helpArg, abbr: helpAbbr, help: 'Shows this help');

void showHelpAndExit() {
  stdout.writeln(argParser.usage);
  exit(0);
}

Future main(List<String> args) async {
  ArgResults argResults;
  try {
    argResults = argParser.parse(args);
  } catch (e) {
    print('Error parsing args:\n${e.toString()}');
    showHelpAndExit();
  }

  if (argResults.wasParsed(helpArg) && argResults[helpArg]) {
    showHelpAndExit();
  }

  final List<String> targets = ['example', 'examples'];

  // The AnalyzerContext we use only contains the content in lib.
  // Move all the code we care about into lib temporarily to upgrade any
  // modules that might live outside of there normally.
  moveTargetsIntoLib(targets);

  try {
    print('Analyzing sources to find modules to upgrade.');
    print('(This can take several minutes for large repos)');
    final classes = getModulesWithoutNamesBySource();
    print('Upgrading modules...');
    classes.forEach(writeGettersForSource);
  } finally {
    moveTargetsOutOfLib(targets);
  }
}
