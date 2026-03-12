import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_companion/app/node_support.dart';

void main() {
  test('node registry exposes the expected desktop baseline', () async {
    final catalog = buildCompanionNodeCommandCatalog();
    final names = catalog
        .map((command) => command.name)
        .toList(growable: false);
    final snapshot = await buildCompanionNodeRegistry().snapshot();

    expect(names, contains('system.notify'));
    expect(names, contains('system.which'));
    expect(snapshot.commands, contains('system.notify'));
    expect(snapshot.commands, contains('system.which'));

    if (Platform.isMacOS) {
      expect(names, containsAll(<String>['device.info', 'device.status']));
      expect(snapshot.capabilities, contains('device'));
    } else {
      expect(names, isNot(contains('device.info')));
      expect(names, isNot(contains('device.status')));
      expect(snapshot.capabilities, isNot(contains('device')));
    }
  });

  test('system.which resolver finds executables in a custom PATH', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'openclaw-companion-node-support-',
    );
    try {
      final name = Platform.isWindows ? 'custom-tool.exe' : 'custom-tool';
      final file = File('${tempDir.path}${Platform.pathSeparator}$name');
      await file.writeAsString('placeholder');

      final found = resolveCompanionSystemBins(
        const <String>['custom-tool'],
        pathEnv: tempDir.path,
        pathExt: Platform.isWindows ? '.EXE;.CMD' : null,
      );

      expect(found.keys, contains('custom-tool'));
      expect(found['custom-tool'], file.path);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
