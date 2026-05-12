/// Structured navigation model for a documentation wiki.
final class DartEdgeDocsWiki {
  const DartEdgeDocsWiki({
    required this.title,
    required this.sections,
    this.description,
    this.homeHref = '/',
    this.repositoryHref,
    this.versionLabel,
  });

  /// Short product or package name shown in the docs shell.
  final String title;

  /// Optional subtitle for metadata and the shell masthead.
  final String? description;

  /// Link used by the masthead title.
  final String homeHref;

  /// Optional source repository link.
  final String? repositoryHref;

  /// Optional package or docs version label.
  final String? versionLabel;

  /// Top-level navigation sections.
  final List<DartEdgeDocsSection> sections;

  /// All pages in section order.
  Iterable<DartEdgeDocsPage> get pages sync* {
    for (final section in sections) {
      yield* section.pages;
    }
  }

  /// Finds the page with [href], ignoring a trailing slash mismatch.
  DartEdgeDocsPage? pageFor(String href) {
    final normalized = _normalizeHref(href);
    for (final page in pages) {
      if (_normalizeHref(page.href) == normalized) {
        return page;
      }
    }
    return null;
  }

  /// Returns the previous and next wiki pages for [href].
  ({DartEdgeDocsPage? previous, DartEdgeDocsPage? next}) neighborsFor(
    String href,
  ) {
    final flattened = pages.toList(growable: false);
    final normalized = _normalizeHref(href);
    final index = flattened.indexWhere(
      (page) => _normalizeHref(page.href) == normalized,
    );
    if (index == -1) {
      return (previous: null, next: null);
    }
    return (
      previous: index == 0 ? null : flattened[index - 1],
      next: index == flattened.length - 1 ? null : flattened[index + 1],
    );
  }
}

/// Top-level group of documentation pages.
final class DartEdgeDocsSection {
  const DartEdgeDocsSection({required this.title, required this.pages});

  final String title;
  final List<DartEdgeDocsPage> pages;
}

/// Linkable documentation page metadata.
final class DartEdgeDocsPage {
  const DartEdgeDocsPage({
    required this.title,
    required this.href,
    this.description,
  });

  final String title;
  final String href;
  final String? description;
}

/// A breadcrumb entry derived from the current page URL.
final class DartEdgeDocsBreadcrumb {
  const DartEdgeDocsBreadcrumb({
    required this.label,
    required this.href,
    required this.current,
  });

  final String label;
  final String href;
  final bool current;
}

/// Builds readable breadcrumbs from a URL and optional current page title.
List<DartEdgeDocsBreadcrumb> dartEdgeDocsBreadcrumbsFor({
  required String href,
  required String rootLabel,
  String rootHref = '/',
  String? currentTitle,
}) {
  final normalized = _normalizeHref(href);
  if (normalized == '/') {
    return [
      DartEdgeDocsBreadcrumb(label: rootLabel, href: rootHref, current: true),
    ];
  }

  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final breadcrumbs = <DartEdgeDocsBreadcrumb>[
    DartEdgeDocsBreadcrumb(label: rootLabel, href: rootHref, current: false),
  ];

  for (var i = 0; i < segments.length; i += 1) {
    final isCurrent = i == segments.length - 1;
    final href = '/${segments.take(i + 1).join('/')}';
    breadcrumbs.add(
      DartEdgeDocsBreadcrumb(
        label: isCurrent && currentTitle != null
            ? currentTitle
            : _humanizePathSegment(segments[i]),
        href: href,
        current: isCurrent,
      ),
    );
  }
  return breadcrumbs;
}

String _normalizeHref(String href) {
  if (href.isEmpty) return '/';
  final withoutHash = href.split('#').first;
  final withoutQuery = withoutHash.split('?').first;
  if (withoutQuery == '/') return '/';
  return withoutQuery.endsWith('/')
      ? withoutQuery.substring(0, withoutQuery.length - 1)
      : withoutQuery;
}

String _humanizePathSegment(String segment) {
  final words = segment
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty);
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
