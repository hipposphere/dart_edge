/// Describes a Docker image generated for a compiled Dart AOT API.
final class DartEdgeDockerConfig {
  const DartEdgeDockerConfig({
    required this.imageName,
    required this.entrypoint,
    this.executableName = 'server',
    this.buildContext = '.',
    this.dartSdkImage = 'dart:stable',
    this.runtimeImage = 'debian:bookworm-slim',
    this.workdir = '/app',
    this.user,
    this.ports = const <int>[],
    this.environment = const <String, String>{},
    this.buildArgs = const <String, String>{},
    this.labels = const <String, String>{},
    this.extraFiles = const <String>[],
    this.compileArgs = const <String>[],
    this.runtimeArgs = const <String>[],
    this.dockerignore = const <String>[
      '.dart_tool/',
      'build/',
      '.git/',
      '*.dockerfile',
      '*.docker_build.json',
    ],
  });

  /// Docker image tag or repository name, for example `my-api`.
  final String imageName;

  /// Dart entrypoint compiled with `dart compile exe`.
  final String entrypoint;

  /// Name of the compiled executable inside the runtime image.
  final String executableName;

  /// Docker build context used by the generated metadata file.
  final String buildContext;

  /// Build-stage image containing the Dart SDK.
  final String dartSdkImage;

  /// Runtime-stage base image.
  final String runtimeImage;

  /// Runtime working directory.
  final String workdir;

  /// Optional runtime user.
  final String? user;

  /// Ports exposed by the runtime image.
  final List<int> ports;

  /// Runtime environment variables.
  final Map<String, String> environment;

  /// Docker build args emitted before the build stage.
  final Map<String, String> buildArgs;

  /// Docker image labels.
  final Map<String, String> labels;

  /// Extra files or directories copied from the build stage into [workdir].
  final List<String> extraFiles;

  /// Additional arguments passed to `dart compile exe`.
  final List<String> compileArgs;

  /// Arguments appended to the executable in `ENTRYPOINT`.
  final List<String> runtimeArgs;

  /// Lines emitted into the generated `.dockerignore`.
  final List<String> dockerignore;
}
