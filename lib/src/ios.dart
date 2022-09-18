import 'dart:convert';
import 'dart:io';

import 'package:auto_screenshot/src/commands.dart';
import 'package:auto_screenshot/src/devices.dart';
import 'package:auto_screenshot/src/exceptions.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

Future<void Function()> bootIOSSimulator(Device device) async {
  print("xcrun simctl bootstatus ${device.id} -b");
  final process = await Process.run(
    "xcrun",
    ["simctl", "bootstatus", device.id, "-b"],
    runInShell: true,
  );

  if (process.exitCode != 0) {
    throw IOSSimulatorBootException(
      "iOS Simulator failed to boot: ${process.stderr}",
    );
  }

  return () async {
    print("xcrun simctl shutdown ${device.id}");
    await Process.run("xcrun", ["simctl", "shutdown", device.id]);
  };
}

Future<void> captureIOSScreen(Device device, String outputPath) async {
  print('outputPath: $outputPath');

  // xcrun simctl io booted screenshot ./screen.png
  await runToCompletion(
    process: Process.run(
        "xcrun",
        [
          "simctl",
          "io",
          "booted",
          "screenshot",
          './$outputPath',
        ],
        workingDirectory: File(path.dirname("pubspec.yaml")).absolute.path),
    onException: (data) =>
        IOSCommandException("Failed to capture screen. $data"),
  );
}

Future<List<Device>> getInstalledIOSSimulators() async {
  final resultsJson = await Process.run("xcrun", ["simctl", "list", "--json"]);
  if (resultsJson.stdout == null) {
    return [];
  }

  final results = jsonDecode(resultsJson.stdout) as Map;
  final deviceCategories = results["devices"] as Map;
  final devices = (deviceCategories.values)
      .map((deviceList) => deviceList as Iterable<dynamic>)
      .flattened
      .where((device) => device["isAvailable"] == true);

  return devices
      .map((device) => Device(device["udid"], device["name"], DeviceType.iOS))
      .toList();
}

Future<void> installIOSApp(Device device, String appFolder) async {
  final dir = Directory(appFolder);
  if (!dir.existsSync()) {
    throw MissingPackageException(
        "Couldn't find folder at [$appFolder]. Make sure to run `flutter run` targeting an iOS Simulator first.");
  }

  final files = dir.listSync();
  final file = files.firstWhereOrNull((f) => f.path.endsWith('.app'));
  if (file == null) {
    throw MissingPackageException(
      "Couldn't find APP file in [$appFolder]. Make sure to run `flutter run` targeting an iOS Simulator first.",
    );
  }

  print('App found at [${file.absolute.path}].');

  // xcrun simctl install $DEVICE_UDID /path/to/your/app
  await runToCompletion(
    process: Process.run(
      "xcrun",
      [
        "simctl",
        "install",
        device.id,
        path.basename(file.path),
      ],
      workingDirectory: path.dirname(file.absolute.path),
    ),
    onException: (data) => IOSCommandException("Couldn't install app. $data"),
  );
}

Future<void> loadIOSDeepLink(Device device, String url) async {
  // xcrun simctl openurl booted customscheme://flutterbooksample.com/book/1
  await runToCompletion(
    process: Process.run("xcrun", [
      "simctl",
      "openurl",
      device.id,
      url,
    ]),
    onException: (data) =>
        IOSCommandException("Failed to load deep link. $data"),
  );
}