part of '../docker_generator.dart';

String _dartServerDockerfile(
  Directory projectRoot,
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
