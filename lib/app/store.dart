import 'dart:convert';
import 'dart:io';

import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';
import 'package:path_provider/path_provider.dart';

class CompanionStoreBundle {
  const CompanionStoreBundle({
    required this.configStore,
    required this.authStateStore,
    required this.resetAll,
  });

  final CompanionConfigStore configStore;
  final GatewayJsonAuthStateStore authStateStore;
  final Future<void> Function() resetAll;
}

class CompanionConfigStore {
  CompanionConfigStore._({required File file}) : _file = file;

  final File _file;

  static Future<CompanionStoreBundle> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final separator = Platform.pathSeparator;
    final authFile = File(
      '${directory.path}${separator}gateway_auth_state.json',
    );
    final configStore = CompanionConfigStore._(
      file: File('${directory.path}${separator}companion_config.json'),
    );
    final stringStore = _FileStringStore(authFile);
    final authStateStore = GatewayJsonAuthStateStore(store: stringStore);
    return CompanionStoreBundle(
      configStore: configStore,
      authStateStore: authStateStore,
      resetAll: () async {
        await configStore.delete();
        await stringStore.deleteString(authStateStore.key);
      },
    );
  }

  Future<CompanionConfig> load() async {
    if (!await _file.exists()) {
      return const CompanionConfig();
    }

    final raw = await _file.readAsString();
    if (raw.trim().isEmpty) {
      return const CompanionConfig();
    }

    final decoded = jsonDecode(raw);
    return CompanionConfig.fromJson(
      _asJsonMap(decoded, 'CompanionConfigStore'),
    );
  }

  Future<void> save(CompanionConfig config) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
      flush: true,
    );
  }

  Future<void> delete() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

class _FileStringStore implements GatewayStringStore {
  _FileStringStore(this._file);

  final File _file;

  @override
  Future<void> deleteString(String key) async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  @override
  Future<String?> readString(String key) async {
    if (!await _file.exists()) {
      return null;
    }
    final raw = await _file.readAsString();
    return raw.trim().isEmpty ? null : raw;
  }

  @override
  Future<void> writeString(String key, String value) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(value, flush: true);
  }
}

JsonMap _asJsonMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  throw FormatException('Expected object for $context.');
}
