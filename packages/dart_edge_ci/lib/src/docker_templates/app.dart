part of '../docker_generator.dart';

String _flutterAppDockerfile(
  Directory projectRoot,
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
    _workspacePubspecCopies(projectRoot, image.packagePath),
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
