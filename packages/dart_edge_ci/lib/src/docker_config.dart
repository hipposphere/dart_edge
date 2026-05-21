import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package_version.dart';

final class DockerConfigException implements Exception {
  const DockerConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DockerProjectConfig {
  const DockerProjectConfig({
    required this.images,
    this.vendor,
    this.source,
    this.flutterVersion = '3.44.0',
  });

  final Map<String, DockerImageConfig> images;
  final String? vendor;
  final String? source;
  final String flutterVersion;

  static Future<DockerProjectConfig> load(Directory projectRoot) async {
    final file = File('${projectRoot.path}/docker.yaml');
    if (!await file.exists()) {
      throw const DockerConfigException('docker.yaml not found.');
    }
    return parse(await file.readAsString(), projectRoot: projectRoot);
  }

  static DockerProjectConfig parse(String source, {Directory? projectRoot}) {
    final document = loadYaml(source);
    final root = _map(document, 'docker.yaml');
    final imagesYaml = _map(root['images'], 'images');
    final images = <String, DockerImageConfig>{};
    for (final entry in imagesYaml.entries) {
      final name = _key(entry.key, 'images');
      final value = _map(entry.value, 'images.$name');
      images[name] = DockerImageConfig.parse(name, value, projectRoot);
    }
    if (images.isEmpty) {
      throw const DockerConfigException(
        'images must contain at least one image.',
      );
    }
    return DockerProjectConfig(
      images: images,
      vendor: _string(root['vendor'], 'vendor'),
      source: _string(root['source'], 'source'),
      flutterVersion:
          _string(root['flutter_version'], 'flutter_version') ?? '3.44.0',
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert({
      if (vendor != null) 'vendor': vendor,
      if (source != null) 'source': source,
      'flutter_version': flutterVersion,
      'images': {for (final entry in images.entries) entry.key: entry.value.toJson()},
    })}\n';
  }
}

sealed class DockerImageConfig {
  const DockerImageConfig({
    required this.name,
    required this.type,
    required this.packagePath,
    required this.title,
    required this.description,
    required this.version,
    required this.dockerfile,
    this.executable,
  });

  final String name;
  final DockerImageType type;
  final String packagePath;
  final String title;
  final String description;
  final String version;
  final DockerfileExtensions dockerfile;
  final String? executable;

  static DockerImageConfig parse(
    String name,
    YamlMap map,
    Directory? projectRoot,
  ) {
    final typeName = _requiredString(map['type'], 'images.$name.type');
    final type = DockerImageType.byName(typeName, 'images.$name.type');
    final packagePath = _requiredString(map['package'], 'images.$name.package');
    final version = _packageVersion(projectRoot, packagePath) ?? 'dev';
    final title = _string(map['title'], 'images.$name.title') ?? name;
    final description =
        _string(map['description'], 'images.$name.description') ?? title;
    final executable = _string(map['executable'], 'images.$name.executable');
    final dockerfile = DockerfileExtensions.parse(
      map['dockerfile'],
      'images.$name.dockerfile',
    );

    return switch (type) {
      DockerImageType.dartServer => DartServerImageConfig(
        name: name,
        packagePath: packagePath,
        target: _requiredString(map['target'], 'images.$name.target'),
        executable: executable ?? 'server',
        expose: _int(map['expose'], 'images.$name.expose'),
        title: title,
        description: description,
        version: version,
        dockerfile: dockerfile,
        presets: ImagePresets.parse(map['presets'], 'images.$name.presets'),
      ),
      DockerImageType.dbMigrator => DbMigratorImageConfig(
        name: name,
        packagePath: packagePath,
        target: _requiredString(map['target'], 'images.$name.target'),
        executable: executable ?? 'migrator',
        title: title,
        description: description,
        version: version,
        dockerfile: dockerfile,
        databases: DatabasePresets.parse(
          map['databases'],
          'images.$name.databases',
        ),
      ),
      DockerImageType.flutterApp => FlutterAppImageConfig(
        name: name,
        packagePath: packagePath,
        flutterVersion: _string(
          map['flutter_version'],
          'images.$name.flutter_version',
        ),
        title: title,
        description: description,
        version: version,
        dockerfile: dockerfile,
        web: FlutterWebConfig.parse(map['web'], 'images.$name.web'),
        nginx: NginxConfig.parse(map['nginx'], 'images.$name.nginx'),
      ),
    };
  }

  Map<String, Object?> toJson();
}

final class DartServerImageConfig extends DockerImageConfig {
  const DartServerImageConfig({
    required super.name,
    required super.packagePath,
    required this.target,
    required super.executable,
    required super.title,
    required super.description,
    required super.version,
    required super.dockerfile,
    required this.presets,
    this.expose,
  }) : super(type: DockerImageType.dartServer);

  final String target;
  final int? expose;
  final ImagePresets presets;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'package': packagePath,
    'target': target,
    'executable': executable,
    if (expose != null) 'expose': expose,
    'title': title,
    'description': description,
    'version': version,
    'dockerfile': dockerfile.toJson(),
    'presets': presets.toJson(),
  };
}

final class DbMigratorImageConfig extends DockerImageConfig {
  const DbMigratorImageConfig({
    required super.name,
    required super.packagePath,
    required this.target,
    required super.executable,
    required super.title,
    required super.description,
    required super.version,
    required super.dockerfile,
    required this.databases,
  }) : super(type: DockerImageType.dbMigrator);

  final String target;
  final DatabasePresets databases;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'package': packagePath,
    'target': target,
    'executable': executable,
    'title': title,
    'description': description,
    'version': version,
    'dockerfile': dockerfile.toJson(),
    'databases': databases.toJson(),
  };
}

final class FlutterAppImageConfig extends DockerImageConfig {
  const FlutterAppImageConfig({
    required super.name,
    required super.packagePath,
    required super.title,
    required super.description,
    required super.version,
    required super.dockerfile,
    required this.web,
    required this.nginx,
    this.flutterVersion,
  }) : super(type: DockerImageType.flutterApp);

  final String? flutterVersion;
  final FlutterWebConfig web;
  final NginxConfig nginx;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'package': packagePath,
    if (flutterVersion != null) 'flutter_version': flutterVersion,
    'title': title,
    'description': description,
    'version': version,
    'dockerfile': dockerfile.toJson(),
    'web': web.toJson(),
    'nginx': nginx.toJson(),
  };
}

enum DockerImageType {
  dartServer('dart_server'),
  dbMigrator('db_migrator'),
  flutterApp('flutter_app');

  const DockerImageType(this.name);

  final String name;

  static DockerImageType byName(String value, String path) {
    for (final type in values) {
      if (type.name == value) {
        return type;
      }
    }
    throw DockerConfigException(
      '$path must be one of ${values.map((type) => type.name).join(', ')}.',
    );
  }
}

final class ImagePresets {
  const ImagePresets({this.pjproject});

  final PjprojectPreset? pjproject;

  static ImagePresets parse(Object? value, String path) {
    if (value == null) {
      return const ImagePresets();
    }
    final map = _map(value, path);
    return ImagePresets(
      pjproject: PjprojectPreset.parse(map['pjproject'], '$path.pjproject'),
    );
  }

  Map<String, Object?> toJson() => {
    if (pjproject != null) 'pjproject': pjproject!.toJson(),
  };
}

final class PjprojectPreset {
  const PjprojectPreset({this.version = '2.17'});

  final String version;

  static PjprojectPreset? parse(Object? value, String path) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value ? const PjprojectPreset() : null;
    }
    final map = _map(value, path);
    final enabled = _bool(map['enabled'], '$path.enabled') ?? true;
    if (!enabled) {
      return null;
    }
    return PjprojectPreset(
      version: _stringScalar(map['version'], '$path.version') ?? '2.17',
    );
  }

  Map<String, Object?> toJson() => {'version': version};
}

final class DockerfileExtensions {
  const DockerfileExtensions({
    this.prelude = const [],
    this.buildBeforePubGet = const [],
    this.buildAfterPubGet = const [],
    this.buildBeforeCompile = const [],
    this.runtimeBeforeLabels = const [],
  });

  final List<String> prelude;
  final List<String> buildBeforePubGet;
  final List<String> buildAfterPubGet;
  final List<String> buildBeforeCompile;
  final List<String> runtimeBeforeLabels;

  static DockerfileExtensions parse(Object? value, String path) {
    if (value == null) {
      return const DockerfileExtensions();
    }
    final map = _map(value, path);
    return DockerfileExtensions(
      prelude: _stringList(map['prelude'], '$path.prelude'),
      buildBeforePubGet: _stringList(
        map['build_before_pub_get'],
        '$path.build_before_pub_get',
      ),
      buildAfterPubGet: _stringList(
        map['build_after_pub_get'],
        '$path.build_after_pub_get',
      ),
      buildBeforeCompile: _stringList(
        map['build_before_compile'],
        '$path.build_before_compile',
      ),
      runtimeBeforeLabels: _stringList(
        map['runtime_before_labels'],
        '$path.runtime_before_labels',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    if (prelude.isNotEmpty) 'prelude': prelude,
    if (buildBeforePubGet.isNotEmpty) 'build_before_pub_get': buildBeforePubGet,
    if (buildAfterPubGet.isNotEmpty) 'build_after_pub_get': buildAfterPubGet,
    if (buildBeforeCompile.isNotEmpty)
      'build_before_compile': buildBeforeCompile,
    if (runtimeBeforeLabels.isNotEmpty)
      'runtime_before_labels': runtimeBeforeLabels,
  };
}

final class DatabasePresets {
  const DatabasePresets({
    this.sqlite = false,
    this.postgres = false,
    this.pglite = false,
  });

  final bool sqlite;
  final bool postgres;
  final bool pglite;

  static DatabasePresets parse(Object? value, String path) {
    if (value == null) {
      return const DatabasePresets();
    }
    final map = _map(value, path);
    final all = _bool(map['all'], '$path.all') ?? false;
    return DatabasePresets(
      sqlite: all || (_bool(map['sqlite'], '$path.sqlite') ?? false),
      postgres: all || (_bool(map['postgres'], '$path.postgres') ?? false),
      pglite: all || (_bool(map['pglite'], '$path.pglite') ?? false),
    );
  }

  Map<String, Object?> toJson() => {
    'sqlite': sqlite,
    'postgres': postgres,
    'pglite': pglite,
  };
}

final class FlutterWebConfig {
  const FlutterWebConfig({
    this.wasm = false,
    this.renderer = 'auto',
    this.baseHrefEnv,
  });

  final bool wasm;
  final String renderer;
  final String? baseHrefEnv;

  static FlutterWebConfig parse(Object? value, String path) {
    if (value == null) {
      return const FlutterWebConfig();
    }
    final map = _map(value, path);
    return FlutterWebConfig(
      wasm: _bool(map['wasm'], '$path.wasm') ?? false,
      renderer: _string(map['renderer'], '$path.renderer') ?? 'auto',
      baseHrefEnv: _string(map['base_href_env'], '$path.base_href_env'),
    );
  }

  Map<String, Object?> toJson() => {
    'wasm': wasm,
    'renderer': renderer,
    if (baseHrefEnv != null) 'base_href_env': baseHrefEnv,
  };
}

final class NginxConfig {
  const NginxConfig({this.requiredEnv = const [], this.optionalEnv = const {}});

  final List<String> requiredEnv;
  final Map<String, String> optionalEnv;

  static NginxConfig parse(Object? value, String path) {
    if (value == null) {
      return const NginxConfig();
    }
    final map = _map(value, path);
    final env = map['env'] == null ? null : _map(map['env'], '$path.env');
    return NginxConfig(
      requiredEnv: env == null
          ? const []
          : _stringList(env['required'], '$path.env.required'),
      optionalEnv: env == null
          ? const {}
          : _stringMap(env['optional'], '$path.env.optional'),
    );
  }

  Map<String, Object?> toJson() => {
    'env': {'required': requiredEnv, 'optional': optionalEnv},
  };
}

String? _packageVersion(Directory? projectRoot, String packagePath) {
  if (projectRoot == null) {
    return null;
  }
  try {
    return PackageVersionOutput.readSync(
      Directory('${projectRoot.path}/$packagePath'),
    ).version;
  } on PackageVersionException catch (error) {
    throw DockerConfigException(
      'Could not read package version for "$packagePath": ${error.message}',
    );
  }
}

YamlMap _map(Object? value, String path) {
  if (value is YamlMap) {
    return value;
  }
  throw DockerConfigException('$path must be a YAML map.');
}

String _key(Object? value, String path) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw DockerConfigException('$path contains a non-string key.');
}

String _requiredString(Object? value, String path) {
  final result = _string(value, path);
  if (result == null || result.isEmpty) {
    throw DockerConfigException('$path is required.');
  }
  return result;
}

String? _string(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw DockerConfigException('$path must be a string.');
}

String? _stringScalar(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is String || value is num) {
    return value.toString();
  }
  throw DockerConfigException('$path must be a string or number.');
}

int? _int(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw DockerConfigException('$path must be an integer.');
}

bool? _bool(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw DockerConfigException('$path must be a boolean.');
}

List<String> _stringList(Object? value, String path) {
  if (value == null) {
    return const [];
  }
  if (value is! YamlList) {
    throw DockerConfigException('$path must be a YAML list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _requiredString(value[index], '$path[$index]'),
  ];
}

Map<String, String> _stringMap(Object? value, String path) {
  if (value == null) {
    return const {};
  }
  final map = _map(value, path);
  return {
    for (final entry in map.entries)
      _key(entry.key, path): _requiredString(entry.value, '$path.${entry.key}'),
  };
}
