import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:shadcn_jaspr/shadcn_jaspr.dart';

import '../styles/docs_styles.dart';
import '../wiki/wiki.dart';

/// Documentation page layout with shadcn navigation primitives.
final class DartEdgeDocsLayout extends PageLayoutBase {
  const DartEdgeDocsLayout({
    required this.wiki,
    this.stylesheetHref = '/styles.css',
    this.includeFallbackStyles = true,
  });

  final DartEdgeDocsWiki wiki;
  final String stylesheetHref;
  final bool includeFallbackStyles;

  @override
  String get name => 'docs';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield link(rel: 'stylesheet', href: stylesheetHref);
    if (includeFallbackStyles) {
      yield Style(styles: dartEdgeDocsStyles);
    }
  }

  @override
  Component buildBody(Page page, Component child) {
    final pageTitle = switch (page.data.page['title']) {
      final String title => title,
      _ => wiki.pageFor(page.url)?.title ?? wiki.title,
    };
    final breadcrumbs = dartEdgeDocsBreadcrumbsFor(
      href: page.url,
      rootLabel: wiki.title,
      rootHref: wiki.homeHref,
      currentTitle: pageTitle,
    );
    final neighbors = wiki.neighborsFor(page.url);

    return div(
      classes: 'de-docs-shell min-h-screen bg-background text-foreground',
      [
        header(classes: 'de-docs-header border-b bg-background/95', [
          div(classes: 'de-docs-header-inner', [
            a(
              href: wiki.homeHref,
              classes: 'de-docs-brand font-semibold tracking-tight',
              [Component.text(wiki.title)],
            ),
            if (wiki.versionLabel case final version?)
              ShadBadge([
                Component.text(version),
              ], variant: BadgeVariant.secondary),
            span(classes: 'de-docs-header-spacer', []),
            if (wiki.repositoryHref case final repositoryHref?)
              a(
                href: repositoryHref,
                classes: 'de-docs-header-link text-sm text-muted-foreground',
                [Component.text('Repository')],
              ),
          ]),
        ]),
        div(classes: 'de-docs-layout', [
          aside(classes: 'de-docs-sidebar border-r', [
            nav(
              attributes: {'aria-label': 'Documentation'},
              [
                for (final docsSection in wiki.sections)
                  section(classes: 'de-docs-nav-section', [
                    h2(classes: 'de-docs-nav-title text-sm font-medium', [
                      Component.text(docsSection.title),
                    ]),
                    ul(classes: 'de-docs-nav-list', [
                      for (final item in docsSection.pages)
                        li([
                          a(
                            href: item.href,
                            classes: _navLinkClasses(page.url, item.href),
                            [Component.text(item.title)],
                          ),
                        ]),
                    ]),
                  ]),
              ],
            ),
          ]),
          main_(classes: 'de-docs-main', [
            ShadBreadcrumb([
              ShadBreadcrumbList([
                for (var i = 0; i < breadcrumbs.length; i += 1) ...[
                  ShadBreadcrumbItem([
                    if (breadcrumbs[i].current)
                      ShadBreadcrumbPage([Component.text(breadcrumbs[i].label)])
                    else
                      ShadBreadcrumbLink([
                        Component.text(breadcrumbs[i].label),
                      ], href: breadcrumbs[i].href),
                  ]),
                  if (i < breadcrumbs.length - 1)
                    const ShadBreadcrumbSeparator(),
                ],
              ]),
            ]),
            article(classes: 'de-docs-content', [child]),
            _DocsPager(previous: neighbors.previous, next: neighbors.next),
          ]),
        ]),
      ],
    );
  }
}

final class _DocsPager extends StatelessComponent {
  const _DocsPager({required this.previous, required this.next});

  final DartEdgeDocsPage? previous;
  final DartEdgeDocsPage? next;

  @override
  Component build(BuildContext context) {
    if (previous == null && next == null) {
      return Component.fragment([]);
    }
    return nav(
      classes: 'de-docs-pager',
      attributes: {'aria-label': 'Page navigation'},
      [
        if (previous case final previous?)
          ShadCard([
            ShadCardContent([
              a(href: previous.href, [
                span(classes: 'de-docs-pager-label', [
                  Component.text('Previous'),
                ]),
                span(classes: 'de-docs-pager-title', [
                  Component.text(previous.title),
                ]),
              ]),
            ]),
          ])
        else
          span([]),
        if (next case final next?)
          ShadCard([
            ShadCardContent([
              a(href: next.href, [
                span(classes: 'de-docs-pager-label', [Component.text('Next')]),
                span(classes: 'de-docs-pager-title', [
                  Component.text(next.title),
                ]),
              ]),
            ]),
          ]),
      ],
    );
  }
}

String _navLinkClasses(String currentUrl, String href) {
  final active =
      _normalizeComparableHref(currentUrl) == _normalizeComparableHref(href);
  return [
    'de-docs-nav-link',
    'rounded-md px-3 py-2 text-sm',
    active ? 'bg-muted font-medium text-foreground' : 'text-muted-foreground',
  ].join(' ');
}

String _normalizeComparableHref(String href) {
  if (href == '/') return '/';
  return href.endsWith('/') ? href.substring(0, href.length - 1) : href;
}
