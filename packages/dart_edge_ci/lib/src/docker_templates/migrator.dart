part of '../docker_generator.dart';

String _dbMigratorDockerfile(
  Directory projectRoot,
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
    _workspacePubspecCopies(projectRoot, image.packagePath),
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
