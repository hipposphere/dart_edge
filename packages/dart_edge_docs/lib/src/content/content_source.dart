import 'package:jaspr_content/jaspr_content.dart';

/// Loads one Dart data asset as text.
///
/// The Dart 3.12 hook API can register data assets, but app runtimes still need
/// to provide the actual string loader for the target platform.
typedef DartEdgeDocsDataAssetStringLoader =
    Future<String> Function(String assetId);

/// One documentation page loaded from a non-filesystem source.
final class DartEdgeDocsContentPage {
  const DartEdgeDocsContentPage({
    required this.path,
    required this.content,
    this.keepSuffix = false,
    this.initialData = const {},
  });

  /// Page path in posix form, for example `docs/users/calls.mdx`.
  final String path;

  /// Raw Markdown or MDX source.
  final String content;

  /// Whether `jaspr_content` should keep the file suffix in the route.
  final bool keepSuffix;

  /// Initial data applied before frontmatter and configured data loaders.
  final Map<String, Object?> initialData;
}

/// Source for documentation content that can be rendered by [DartEdgeDocsApp].
abstract interface class DartEdgeDocsContentSource {
  Future<List<DartEdgeDocsContentPage>> loadPages();
}

/// Loads docs content from Dart data assets.
final class DartEdgeDocsDataAssetContentSource
    implements DartEdgeDocsContentSource {
  const DartEdgeDocsDataAssetContentSource({
    required this.package,
    required this.assetNames,
    required this.loadString,
    this.pathPrefixToStrip,
  });

  /// Package that owns the registered data assets.
  final String package;

  /// Asset names registered by the owning package hook.
  ///
  /// The runtime asset id is `package:<package>/<assetName>`.
  final Iterable<String> assetNames;

  /// Runtime asset string loader supplied by the consuming application.
  final DartEdgeDocsDataAssetStringLoader loadString;

  /// Optional prefix stripped from [assetNames] before producing page paths.
  final String? pathPrefixToStrip;

  @override
  Future<List<DartEdgeDocsContentPage>> loadPages() async {
    final pages = <DartEdgeDocsContentPage>[];
    for (final assetName in assetNames) {
      final normalizedName = _normalizePath(assetName);
      pages.add(
        DartEdgeDocsContentPage(
          path: _stripPrefix(normalizedName),
          content: await loadString('package:$package/$normalizedName'),
        ),
      );
    }
    return List.unmodifiable(pages);
  }

  String _stripPrefix(String assetName) {
    final prefix = pathPrefixToStrip;
    if (prefix == null || prefix.isEmpty) {
      return assetName;
    }
    final normalizedPrefix = _normalizePath(prefix);
    if (assetName == normalizedPrefix) {
      return assetName.split('/').last;
    }
    final prefixWithSlash = normalizedPrefix.endsWith('/')
        ? normalizedPrefix
        : '$normalizedPrefix/';
    if (assetName.startsWith(prefixWithSlash)) {
      return assetName.substring(prefixWithSlash.length);
    }
    return assetName;
  }
}

/// Loads docs from an embedded Dart string manifest.
///
/// This is a deterministic fallback for builds where data assets can be
/// registered by hooks but cannot be read through the runtime yet.
final class DartEdgeDocsStringManifestContentSource
    implements DartEdgeDocsContentSource {
  const DartEdgeDocsStringManifestContentSource(this.pages);

  /// Map from page path to raw MDX or Markdown content.
  final Map<String, String> pages;

  @override
  Future<List<DartEdgeDocsContentPage>> loadPages() async {
    final paths = pages.keys.toList()..sort();
    return List.unmodifiable([
      for (final path in paths)
        DartEdgeDocsContentPage(
          path: _normalizePath(path),
          content: pages[path]!,
        ),
    ]);
  }
}

/// Route loader backed by a [DartEdgeDocsContentSource].
final class DartEdgeDocsContentSourceLoader
    extends RouteLoaderBase<DartEdgeDocsContentPageSource> {
  DartEdgeDocsContentSourceLoader({required this.source, super.debugPrint});

  final DartEdgeDocsContentSource source;

  @override
  Future<List<DartEdgeDocsContentPageSource>> loadPageSources() async {
    final pages = await source.loadPages();
    return [
      for (final page in pages)
        DartEdgeDocsContentPageSource(
          page,
          page.path,
          this,
          keepSuffix: page.keepSuffix,
        ),
    ];
  }
}

/// Page source created from a [DartEdgeDocsContentPage].
final class DartEdgeDocsContentPageSource extends PageSource {
  DartEdgeDocsContentPageSource(
    this._page,
    super.path,
    super.loader, {
    super.keepSuffix,
  });

  final DartEdgeDocsContentPage _page;

  @override
  Future<Page> buildPage() async {
    return Page(
      path: path,
      url: url,
      content: _page.content,
      initialData: _page.initialData,
      config: config,
      loader: loader,
    );
  }
}

String _normalizePath(String path) {
  return path.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+'), '');
}
