import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'docker_config.dart';

export 'docker_config.dart';

final class DockerGenerator {
  DockerGenerator({required Directory projectRoot})
    : projectRoot = projectRoot.absolute;

  final Directory projectRoot;

  Directory get outputRoot => Directory(
    p.join(projectRoot.path, '.dart_tool', 'dart_edge_ci', 'docker'),
  );

  Future<DockerProjectConfig> loadConfig() {
    return DockerProjectConfig.load(projectRoot);
  }

  Future<DockerGenerationResult> generate({String? selectedImage}) async {
    final config = await loadConfig();
    final images = selectedImage == null
        ? config.images.values.toList()
        : [
            config.images[selectedImage] ??
                (throw DockerConfigException(
                  'Unknown image "$selectedImage".',
                )),
          ];
    await outputRoot.create(recursive: true);

    final labels = await OciLabels.resolve(
      projectRoot: projectRoot,
      config: config,
    );
    final generated = <GeneratedDockerImage>[];
    for (final image in images) {
      generated.add(await _writeImage(config, labels, image));
    }
    final bakeFile = await _writeBakeFile(config, labels, config.images.values);
    return DockerGenerationResult(
      images: generated,
      bakeFile: bakeFile,
      labels: labels,
    );
  }

  Future<GeneratedDockerImage> _writeImage(
    DockerProjectConfig project,
    OciLabels labels,
    DockerImageConfig image,
  ) async {
    final directory = Directory(p.join(outputRoot.path, image.name));
    await directory.create(recursive: true);
    final dockerfile = File(p.join(directory.path, 'Dockerfile'));
    final entrypoint = File(p.join(directory.path, 'nginx-env.sh'));

    if (image case final FlutterAppImageConfig app) {
      await entrypoint.writeAsString(_nginxEntrypoint(app));
    }
    await dockerfile.writeAsString(_dockerfile(project, labels, image));
    return GeneratedDockerImage(
      name: image.name,
      tag: image.name,
      version: image.version,
      dockerfile: dockerfile,
      context: projectRoot,
    );
  }

  Future<File> _writeBakeFile(
    DockerProjectConfig project,
    OciLabels labels,
    Iterable<DockerImageConfig> images,
  ) async {
    final file = File(p.join(outputRoot.path, 'docker-bake.hcl'));
    await file.writeAsString(_bakeFile(project, labels, images));
    return file;
  }
}

final class DockerGenerationResult {
  const DockerGenerationResult({
    required this.images,
    required this.bakeFile,
    required this.labels,
  });

  final List<GeneratedDockerImage> images;
  final File bakeFile;
  final OciLabels labels;
}

final class GeneratedDockerImage {
  const GeneratedDockerImage({
    required this.name,
    required this.tag,
    required this.version,
    required this.dockerfile,
    required this.context,
  });

  final String name;
  final String tag;
  final String version;
  final File dockerfile;
  final Directory context;
}

final class OciLabels {
  const OciLabels({
    required this.revision,
    required this.created,
    required this.source,
    required this.vendor,
  });

  final String revision;
  final String created;
  final String source;
  final String? vendor;

  static Future<OciLabels> resolve({
    required Directory projectRoot,
    required DockerProjectConfig config,
  }) async {
    final revision = await _git(projectRoot, ['rev-parse', 'HEAD']);
    final source =
        config.source ??
        await _git(projectRoot, ['config', '--get', 'remote.origin.url']);
    return OciLabels(
      revision: revision ?? 'unknown',
      created: DateTime.now().toUtc().toIso8601String(),
      source: source ?? 'unknown',
      vendor: config.vendor,
    );
  }

  Map<String, String> forImage(DockerImageConfig image) => {
    'org.opencontainers.image.title': image.title,
    'org.opencontainers.image.description': image.description,
    'org.opencontainers.image.version': image.version,
    'org.opencontainers.image.revision': revision,
    'org.opencontainers.image.created': created,
    'org.opencontainers.image.source': source,
    ...?vendor == null ? null : {'org.opencontainers.image.vendor': vendor!},
  };
}

final class DockerProcessRunner {
  const DockerProcessRunner();

  Future<int> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

List<String> buildxCommand(
  GeneratedDockerImage image, {
  required bool push,
  required OciLabels labels,
}) {
  final relativeDockerfile = p.relative(
    image.dockerfile.path,
    from: image.context.path,
  );
  return [
    'docker',
    'buildx',
    'build',
    '--file',
    relativeDockerfile,
    '--tag',
    image.tag,
    '--build-arg',
    'VERSION=${image.version}',
    '--build-arg',
    'REVISION=${labels.revision}',
    '--build-arg',
    'CREATED=${labels.created}',
    '--build-arg',
    'SOURCE=${labels.source}',
    if (push) '--push',
    '.',
  ];
}

String shellCommand(List<String> command) {
  return command.map(_shell).join(' ');
}

String _dockerfile(
  DockerProjectConfig project,
  OciLabels labels,
  DockerImageConfig image,
) {
  return switch (image) {
    final DartServerImageConfig server => _dartServerDockerfile(
      project,
      labels,
      server,
    ),
    final DbMigratorImageConfig migrator => _dbMigratorDockerfile(
      project,
      labels,
      migrator,
    ),
    final FlutterAppImageConfig app => _flutterAppDockerfile(
      project,
      labels,
      app,
    ),
  };
}

String _dartServerDockerfile(
  DockerProjectConfig project,
  OciLabels labels,
  DartServerImageConfig image,
) {
  final runtimePackages = _runtimePackages(
    sqlite: true,
    postgres: true,
    pglite: false,
  );
  return [
    '# syntax=docker/dockerfile:1',
    '',
    ...image.dockerfile.prelude,
    if (image.presets.pjproject case final pjproject?)
      _pjprojectStage(pjproject),
    'FROM ghcr.io/cirruslabs/flutter:${project.flutterVersion} AS build',
    '',
    'USER root',
    'WORKDIR /app',
    if (image.presets.pjproject != null) ...[
      'COPY --from=pjproject /usr/local/include/ /usr/local/include/',
      'COPY --from=pjproject /usr/local/lib/ /usr/local/lib/',
      'RUN ldconfig',
    ],
    ...image.dockerfile.buildBeforePubGet,
    _workspacePubspecCopies(image.packagePath),
    'RUN flutter pub get',
    ...image.dockerfile.buildAfterPubGet,
    if (!image.packagePath.startsWith('packages/'))
      'COPY ${image.packagePath} ${image.packagePath}',
    'COPY packages packages',
    'WORKDIR /app/${image.packagePath}',
    ...image.dockerfile.buildBeforeCompile,
    'RUN dart build cli --target=${image.target} --output=/app/build-output',
    '',
    _debianRuntime(runtimePackages),
    'WORKDIR /app',
    'COPY --from=build /app/build-output/bundle/ /app/',
    if (image.presets.pjproject != null) ...[
      'COPY --from=pjproject /usr/local/lib/*.so* /usr/local/lib/',
      "RUN ldconfig && ldconfig -p | grep -q 'libpjsua\\.so'",
      'ENV LD_PRELOAD=/usr/local/lib/libpjsua.so',
    ],
    'USER nonroot',
    if (image.expose != null) 'EXPOSE ${image.expose}',
    ...image.dockerfile.runtimeBeforeLabels,
    _ociArgsAndLabels(labels, image),
    'ENTRYPOINT ${jsonEncode(['/app/bin/${image.executable}'])}',
    '',
  ].join('\n');
}

String _dbMigratorDockerfile(
  DockerProjectConfig project,
  OciLabels labels,
  DbMigratorImageConfig image,
) {
  final runtimePackages = _runtimePackages(
    sqlite: image.databases.sqlite || image.databases.pglite,
    postgres: image.databases.postgres,
    pglite: image.databases.pglite,
  );
  return [
    '# syntax=docker/dockerfile:1',
    '',
    ...image.dockerfile.prelude,
    'FROM ghcr.io/cirruslabs/flutter:${project.flutterVersion} AS build',
    '',
    'USER root',
    'WORKDIR /app',
    ...image.dockerfile.buildBeforePubGet,
    _workspacePubspecCopies(image.packagePath),
    'RUN flutter pub get',
    ...image.dockerfile.buildAfterPubGet,
    if (!image.packagePath.startsWith('packages/'))
      'COPY ${image.packagePath} ${image.packagePath}',
    'COPY packages packages',
    'WORKDIR /app/${image.packagePath}',
    ...image.dockerfile.buildBeforeCompile,
    'RUN dart build cli --target=${image.target} --output=/app/build-output',
    '',
    _debianRuntime(runtimePackages),
    'WORKDIR /app',
    'COPY --from=build /app/build-output/bundle/ /app/',
    'USER nonroot',
    ...image.dockerfile.runtimeBeforeLabels,
    _ociArgsAndLabels(labels, image),
    'ENTRYPOINT ${jsonEncode(['/app/bin/${image.executable}'])}',
    '',
  ].join('\n');
}

String _flutterAppDockerfile(
  DockerProjectConfig project,
  OciLabels labels,
  FlutterAppImageConfig image,
) {
  final flutterVersion = image.flutterVersion ?? project.flutterVersion;
  final buildArgs = [
    'flutter',
    'build',
    'web',
    '--release',
    if (image.web.wasm) '--wasm',
    '--web-renderer=${image.web.renderer}',
    if (image.web.baseHrefEnv != null)
      '--base-href=\${${image.web.baseHrefEnv}}',
  ];
  return [
    '# syntax=docker/dockerfile:1',
    '',
    ...image.dockerfile.prelude,
    'FROM ghcr.io/cirruslabs/flutter:$flutterVersion AS build',
    '',
    'USER root',
    'WORKDIR /app',
    if (image.web.baseHrefEnv != null) 'ARG ${image.web.baseHrefEnv}=/',
    ...image.dockerfile.buildBeforePubGet,
    _workspacePubspecCopies(image.packagePath),
    'RUN flutter pub get',
    ...image.dockerfile.buildAfterPubGet,
    if (!image.packagePath.startsWith('packages/'))
      'COPY ${image.packagePath} ${image.packagePath}',
    'COPY packages packages',
    'WORKDIR /app/${image.packagePath}',
    ...image.dockerfile.buildBeforeCompile,
    'RUN ${buildArgs.map(_shell).join(' ')}',
    '',
    'FROM nginx:1.29-alpine',
    '',
    _ociArgsAndLabels(labels, image),
    'COPY .dart_tool/dart_edge_ci/docker/${image.name}/nginx-env.sh '
        '/docker-entrypoint.d/99-dart-edge-env.sh',
    'RUN chmod +x /docker-entrypoint.d/99-dart-edge-env.sh',
    'COPY --from=build /app/${image.packagePath}/build/web '
        '/usr/share/nginx/html',
    _flutterCacheBusting(),
    'EXPOSE 80',
    ...image.dockerfile.runtimeBeforeLabels,
    '',
  ].join('\n');
}

String _workspacePubspecCopies(String packagePath) {
  final packagePubspec = '$packagePath/pubspec.yaml';
  final packageCopy = packagePath.startsWith('packages/')
      ? ''
      : '$packagePubspec ';
  return 'COPY --parents pubspec.yaml pubspec.lock ${packageCopy}packages/*/pubspec.yaml ./';
}

String _debianRuntime(List<String> packages) {
  return [
    'FROM debian:trixie-slim',
    '',
    'RUN apt-get update && \\',
    '    apt-get install -y --no-install-recommends \\',
    for (final package in packages) '      $package \\',
    '    && rm -rf /var/lib/apt/lists/* && \\',
    '    useradd --system --create-home --home-dir /home/nonroot nonroot',
  ].join('\n');
}

List<String> _runtimePackages({
  required bool sqlite,
  required bool postgres,
  required bool pglite,
}) {
  return [
    'ca-certificates',
    if (sqlite) 'libsqlite3-0',
    'libstdc++6',
    if (postgres) 'libpq5',
    'libssl3t64',
    if (pglite) 'zlib1g',
  ];
}

String _ociArgsAndLabels(OciLabels labels, DockerImageConfig image) {
  final values = labels.forImage(image);
  return [
    'ARG VERSION=${_shell(image.version)}',
    'ARG REVISION=unknown',
    'ARG CREATED=unknown',
    'ARG SOURCE=unknown',
    '',
    'LABEL ${values.entries.map((entry) {
      final value = switch (entry.key) {
        'org.opencontainers.image.version' => r'${VERSION}',
        'org.opencontainers.image.revision' => r'${REVISION}',
        'org.opencontainers.image.created' => r'${CREATED}',
        'org.opencontainers.image.source' => r'${SOURCE}',
        _ => entry.value,
      };
      return '${entry.key}="${_dockerLabel(value)}"';
    }).join(' \\\n      ')}',
  ].join('\n');
}

String _pjprojectStage(PjprojectPreset preset) {
  return r'''
FROM debian:trixie-slim AS pjproject

ARG PJPROJECT_VERSION={{pjprojectVersion}}

ENV CFLAGS="-D_DEFAULT_SOURCE"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      autoconf \
      automake \
      build-essential \
      ca-certificates \
      curl \
      libssl-dev \
      libtool \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/pjsip/pjproject/archive/refs/tags/${PJPROJECT_VERSION}.tar.gz" | \
      tar -xz -C /tmp && \
    cd "/tmp/pjproject-${PJPROJECT_VERSION}" && \
    CFLAGS="-fPIC" ./configure \
      --prefix=/usr/local \
      --enable-shared \
      --disable-sound \
      --disable-video \
      --disable-opencore-amr \
      --disable-silk \
      --disable-g7221 \
      --disable-libwebrtc && \
    make dep && \
    make -j"$(nproc)" && \
    make install && \
    sed -i 's/bzero(dst, size);/memset(dst, 0, size);/' /usr/local/include/pj/string.h && \
    rm -rf "/tmp/pjproject-${PJPROJECT_VERSION}"
'''
      .replaceAll('{{pjprojectVersion}}', preset.version);
}

String _flutterCacheBusting() {
  return r'''
RUN set -eu; \
    cache_tag="$REVISION"; \
    if [ "$cache_tag" = "unknown" ] || [ -z "$cache_tag" ]; then \
      cache_tag="$(find /usr/share/nginx/html -type f -exec sha256sum {} + | sort | sha256sum | cut -c 1-16)"; \
    fi; \
    cache_tag="$(printf '%s' "$cache_tag" | sed 's/[^A-Za-z0-9._-]/-/g')"; \
    html=/usr/share/nginx/html/index.html; \
    bootstrap=/usr/share/nginx/html/flutter_bootstrap.js; \
    manifest=/usr/share/nginx/html/manifest.json; \
    font_manifest=/usr/share/nginx/html/assets/FontManifest.json; \
    sed -i \
      -e "s|flutter_bootstrap\.js|flutter_bootstrap.js?v=$cache_tag|g" \
      -e "s|manifest\.json|manifest.json?v=$cache_tag|g" \
      -e "s|favicon\.png|favicon.png?v=$cache_tag|g" \
      -e "s|icons/Icon-192\.png|icons/Icon-192.png?v=$cache_tag|g" \
      "$html"; \
    sed -i \
      -e "s|main\.dart\.js|main.dart.js?v=$cache_tag|g" \
      -e "s|main\.dart\.mjs|main.dart.mjs?v=$cache_tag|g" \
      -e "s|main\.dart\.wasm|main.dart.wasm?v=$cache_tag|g" \
      "$bootstrap"; \
    sed -i \
      -e "s|icons/Icon-192\.png|icons/Icon-192.png?v=$cache_tag|g" \
      -e "s|icons/Icon-512\.png|icons/Icon-512.png?v=$cache_tag|g" \
      -e "s|icons/Icon-maskable-192\.png|icons/Icon-maskable-192.png?v=$cache_tag|g" \
      -e "s|icons/Icon-maskable-512\.png|icons/Icon-maskable-512.png?v=$cache_tag|g" \
      "$manifest"; \
    if [ -f "$font_manifest" ]; then \
      font_asset_list="$(mktemp)"; \
      find /usr/share/nginx/html/assets -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.woff' -o -name '*.woff2' \) > "$font_asset_list"; \
      while IFS= read -r path; do \
        dir="${path%/*}"; file="${path##*/}"; base="${file%.*}"; ext="${file##*.}"; \
        cp "$path" "$dir/$base.v-$cache_tag.$ext"; \
      done < "$font_asset_list"; \
      rm "$font_asset_list"; \
      sed -i \
        -e "s|\.ttf\"|.v-$cache_tag.ttf\"|g" \
        -e "s|\.otf\"|.v-$cache_tag.otf\"|g" \
        -e "s|\.woff\"|.v-$cache_tag.woff\"|g" \
        -e "s|\.woff2\"|.v-$cache_tag.woff2\"|g" \
        "$font_manifest"; \
    fi
''';
}

String _nginxEntrypoint(FlutterAppImageConfig image) {
  final required = image.nginx.requiredEnv;
  final optional = image.nginx.optionalEnv;
  final baseHrefEnv = image.web.baseHrefEnv ?? 'BASE_HREF';
  final envEntries = {...required, ...optional.keys}
    ..remove(baseHrefEnv)
    ..remove('BASE_HREF');
  final sortedEnvEntries = envEntries.toList()..sort();
  return [
    '#!/bin/sh',
    'set -eu',
    '',
    for (final name in required)
      ': "\${$name:?$name is required for this container}"',
    for (final entry in optional.entries)
      ': "\${${entry.key}:=${entry.value}}"',
    if (!required.contains(baseHrefEnv) && !optional.containsKey(baseHrefEnv))
      ': "\${$baseHrefEnv:=/}"',
    if (baseHrefEnv != 'BASE_HREF') 'BASE_HREF="\${$baseHrefEnv}"',
    '',
    r'''
web_root=/usr/share/nginx/html
env_file="$web_root/.env"
env_url_file="$web_root/env-url.js"
index_html="$web_root/index.html"
nginx_conf=/etc/nginx/conf.d/default.conf

case "$BASE_HREF" in
  /*) ;;
  *) BASE_HREF="/$BASE_HREF" ;;
esac

case "$BASE_HREF" in
  */) ;;
  *) BASE_HREF="$BASE_HREF/" ;;
esac

BASE_PREFIX="${BASE_HREF#/}"
BASE_PREFIX="${BASE_PREFIX%/}"
BASE_REDIRECT_PATH="/$BASE_PREFIX"

if [ -z "$BASE_PREFIX" ]; then
  BASE_REDIRECT_PATH="/__dart_edge_disabled_base_href_redirect__"
fi

{
''',
    for (final name in sortedEnvEntries)
      '  printf ${_shell('%s=%s\\n')} ${_shell(name)} "\${$name}"',
    r'''
} > "$env_file"

env_hash="$(sha256sum "$env_file" | cut -d ' ' -f 1)"
printf 'window.DART_EDGE_ENV_URL = "%s.env?v=%s";\n' "$BASE_HREF" "$env_hash" > "$env_url_file"

if [ -f "$index_html" ]; then
  if grep -q '<base[[:space:]][^>]*href=' "$index_html"; then
    sed -i 's|<base[[:space:]][^>]*href="[^"]*"[^>]*>|<base href="'"$BASE_HREF"'">|' "$index_html"
  else
    awk -v base="$BASE_HREF" '
      BEGIN { inserted=0 }
      /<\/head>/ && !inserted {
        print "  <base href=\"" base "\">"
        inserted=1
      }
      { print }
    ' "$index_html" > "$index_html.__tmp__" && mv "$index_html.__tmp__" "$index_html"
  fi
fi

cat > "$nginx_conf" <<EOF
map \$arg_v \$dart_edge_static_cache_control {
  default "public, max-age=31536000, immutable";
  "" "no-cache";
}

server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;
  etag on;

  include /etc/nginx/mime.types;
  types {
    application/javascript mjs;
    application/wasm wasm;
  }

  location = $BASE_REDIRECT_PATH {
    return 308 $BASE_HREF;
  }

  location = ${BASE_HREF} {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files /index.html =404;
    add_header Cache-Control "no-cache";
  }

  location = ${BASE_HREF}index.html {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files /index.html =404;
    add_header Cache-Control "no-cache";
  }

  location = ${BASE_HREF}env-url.js {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files /env-url.js =404;
    default_type application/javascript;
    add_header Cache-Control "no-cache";
  }

  location = ${BASE_HREF}.env {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files /.env =404;
    default_type text/plain;
    add_header Cache-Control "public, max-age=31536000, immutable";
  }

  location ~* ^${BASE_HREF}assets/(?:FontManifest\.json|AssetManifest\.bin(?:\.json)?)\$ {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files \$uri =404;
    add_header Cache-Control "no-store";
  }

  location ~* ^${BASE_HREF}assets/.+\.v-[A-Za-z0-9._-]+\.(?:ttf|otf|woff|woff2)\$ {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files \$uri =404;
    add_header Cache-Control "public, max-age=31536000, immutable";
  }

  location ~* ^${BASE_HREF}assets/.+\.(?:ttf|otf|woff|woff2)\$ {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files \$uri =404;
    add_header Cache-Control "no-store";
  }

  location ~* ^${BASE_HREF}.+\.(?:css|js|mjs|json|wasm|png|jpg|jpeg|gif|ico|svg|webp|ttf|otf|woff|woff2)\$ {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files \$uri =404;
    add_header Cache-Control \$dart_edge_static_cache_control;
  }

  location ${BASE_HREF} {
    rewrite ^${BASE_HREF}(.*)\$ /\$1 break;
    try_files \$uri \$uri/ /index.html;
    add_header Cache-Control "no-cache";
  }
}
EOF
''',
    '',
  ].join('\n');
}

String _bakeFile(
  DockerProjectConfig project,
  OciLabels labels,
  Iterable<DockerImageConfig> images,
) {
  return [
    'group "default" {',
    '  targets = [${images.map((image) => '"${image.name}"').join(', ')}]',
    '}',
    '',
    for (final image in images) ...[
      'target "${image.name}" {',
      '  context = "../.."',
      '  dockerfile = ".dart_tool/dart_edge_ci/docker/${image.name}/Dockerfile"',
      '  tags = ["${image.name}"]',
      '  args = {',
      '    VERSION = "${_hcl(image.version)}"',
      '    REVISION = "${_hcl(labels.revision)}"',
      '    CREATED = "${_hcl(labels.created)}"',
      '    SOURCE = "${_hcl(labels.source)}"',
      if (image case final FlutterAppImageConfig app
          when app.web.baseHrefEnv != null)
        '    ${app.web.baseHrefEnv} = "/"',
      '  }',
      '}',
      '',
    ],
  ].join('\n');
}

Future<String?> _git(Directory projectRoot, List<String> args) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: projectRoot.path,
  );
  if (result.exitCode != 0) {
    return null;
  }
  final value = (result.stdout as String).trim();
  return value.isEmpty ? null : value;
}

String _shell(String value) {
  if (RegExp(r'^[A-Za-z0-9_./:@+=-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", r"'\''")}'";
}

String _dockerLabel(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String _hcl(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
