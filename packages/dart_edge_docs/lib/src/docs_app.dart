import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:shadcn_jaspr/shadcn_jaspr.dart';

import 'mdx.dart';
import 'wiki.dart';

/// A Jaspr documentation app for file-system-backed `.md` and `.mdx` pages.
final class DartEdgeDocsApp extends StatelessComponent {
  const DartEdgeDocsApp({
    required this.wiki,
    this.contentDirectory = 'content',
    this.dataDirectory = 'content/_data',
    this.stylesheetHref = '/styles.css',
    this.eagerlyLoadAllPages = true,
    this.additionalComponents = const [],
    this.debugPrintRoutes = false,
    super.key,
  });

  /// Structured wiki navigation shown in the shell.
  final DartEdgeDocsWiki wiki;

  /// Directory containing `.md` and `.mdx` files.
  final String contentDirectory;

  /// Directory containing optional `jaspr_content` data files.
  final String dataDirectory;

  /// Compiled stylesheet path. Projects using `shadcn_jaspr` should compile
  /// their Tailwind entrypoint to this URL.
  final String stylesheetHref;

  /// Whether all pages should be loaded before rendering.
  final bool eagerlyLoadAllPages;

  /// Extra MDX components available to documentation pages.
  final List<CustomComponent> additionalComponents;

  /// Prints generated route information while developing.
  final bool debugPrintRoutes;

  @override
  Component build(BuildContext context) {
    return ContentApp(
      directory: contentDirectory,
      dataDirectory: dataDirectory,
      eagerlyLoadAllPages: eagerlyLoadAllPages,
      parsers: DartEdgeDocsMdx.parsers(),
      extensions: DartEdgeDocsMdx.extensions(),
      components: DartEdgeDocsMdx.components(additional: additionalComponents),
      layouts: [DartEdgeDocsLayout(wiki: wiki, stylesheetHref: stylesheetHref)],
      debugPrint: debugPrintRoutes,
    );
  }
}

/// Documentation page layout with shadcn navigation primitives.
final class DartEdgeDocsLayout extends PageLayoutBase {
  const DartEdgeDocsLayout({
    required this.wiki,
    this.stylesheetHref = '/styles.css',
  });

  final DartEdgeDocsWiki wiki;
  final String stylesheetHref;

  @override
  String get name => 'docs';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield link(rel: 'stylesheet', href: stylesheetHref);
    yield Style(styles: _styles);
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

List<StyleRule> get _styles => [
  css('.de-docs-header').styles(
    position: Position.sticky(top: Unit.zero),
    zIndex: ZIndex(10),
  ),
  css('.de-docs-header-inner').styles(
    display: Display.flex,
    alignItems: AlignItems.center,
    gap: Gap(column: 0.75.rem),
    minHeight: 3.5.rem,
    padding: Padding.symmetric(horizontal: 1.rem),
  ),
  css('.de-docs-brand').styles(textDecoration: TextDecoration.none),
  css('.de-docs-header-spacer').styles(flex: Flex(grow: 1)),
  css('.de-docs-header-link').styles(textDecoration: TextDecoration.none),
  css('.de-docs-layout').styles(
    display: Display.grid,
    raw: {'grid-template-columns': '17rem minmax(0, 1fr)'},
  ),
  css('.de-docs-sidebar').styles(
    position: Position.sticky(top: 3.5.rem),
    overflow: Overflow.auto,
    padding: Padding.all(1.rem),
    raw: {'height': 'calc(100vh - 3.5rem)'},
  ),
  css(
    '.de-docs-nav-section + .de-docs-nav-section',
  ).styles(margin: Margin.only(top: 1.25.rem)),
  css('.de-docs-nav-title').styles(margin: Margin.only(bottom: 0.5.rem)),
  css('.de-docs-nav-list').styles(
    listStyle: ListStyle.none,
    margin: Margin.zero,
    padding: Padding.zero,
  ),
  css(
    '.de-docs-nav-link',
  ).styles(display: Display.block, textDecoration: TextDecoration.none),
  css('.de-docs-main').styles(
    minWidth: Unit.zero,
    maxWidth: 56.rem,
    padding: Padding.symmetric(horizontal: 2.rem, vertical: 2.rem),
  ),
  css('.de-docs-content').styles(margin: Margin.only(top: 2.rem)),
  css(
    '.de-docs-content :is(h1, h2, h3)',
  ).styles(raw: {'scroll-margin-top': '5rem'}),
  css('.de-docs-pager').styles(
    display: Display.grid,
    gap: Gap(column: 1.rem),
    margin: Margin.only(top: 3.rem),
    raw: {'grid-template-columns': 'minmax(0, 1fr) minmax(0, 1fr)'},
  ),
  css('.de-docs-pager a').styles(
    display: Display.grid,
    gap: Gap(row: 0.25.rem),
    textDecoration: TextDecoration.none,
  ),
  css('.de-docs-pager-label').styles(fontSize: 0.75.rem),
  css('.de-docs-pager-title').styles(fontWeight: FontWeight.w600),
  css.media(MediaQuery.all(maxWidth: 860.px), [
    css('.de-docs-layout').styles(display: Display.block),
    css('.de-docs-sidebar').styles(
      position: Position.relative(),
      height: Unit.auto,
      border: Border.only(bottom: BorderSide(width: 1.px)),
      raw: {'top': '0'},
    ),
    css('.de-docs-main').styles(padding: Padding.all(1.rem)),
  ]),
];
