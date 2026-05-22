import 'package:jaspr/dom.dart';

/// Fallback styles for the built-in Dart Edge docs shell.
List<StyleRule> get dartEdgeDocsStyles => [
  css('.de-docs-header').styles(
    position: Position.sticky(top: Unit.zero),
    zIndex: ZIndex(10),
    raw: {'backdrop-filter': 'blur(8px)'},
  ),
  css('.de-docs-header-inner').styles(
    display: Display.flex,
    alignItems: AlignItems.center,
    gap: Gap(column: 0.75.rem),
    minHeight: 3.5.rem,
    maxWidth: 96.rem,
    margin: Margin.symmetric(horizontal: Unit.auto),
    padding: Padding.symmetric(horizontal: 1.rem),
  ),
  css('.de-docs-brand').styles(textDecoration: TextDecoration.none),
  css('.de-docs-header-spacer').styles(flex: Flex(grow: 1)),
  css('.de-docs-header-link').styles(textDecoration: TextDecoration.none),
  css('.de-docs-theme-toggle').styles(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    padding: Padding.all(0.125.rem),
    border: Border.all(width: 1.px),
    raw: {
      'border-color': 'var(--border)',
      'border-radius': '0.5rem',
      'background': 'var(--muted)',
    },
  ),
  css('.de-docs-theme-button').styles(
    border: Border.none,
    cursor: Cursor.pointer,
    fontSize: 0.75.rem,
    fontWeight: FontWeight.w500,
    padding: Padding.symmetric(horizontal: 0.5.rem, vertical: 0.25.rem),
    raw: {
      'border-radius': '0.375rem',
      'background': 'transparent',
      'color': 'var(--muted-foreground)',
      'line-height': '1.25rem',
    },
  ),
  css('.de-docs-theme-button[aria-pressed="true"]').styles(
    raw: {
      'background': 'var(--background)',
      'color': 'var(--foreground)',
      'box-shadow': '0 1px 2px rgb(0 0 0 / 0.06)',
    },
  ),
  css(
    '.de-docs-theme-button:hover',
  ).styles(raw: {'color': 'var(--foreground)'}),
  css('.de-docs-layout').styles(
    display: Display.grid,
    maxWidth: 96.rem,
    margin: Margin.symmetric(horizontal: Unit.auto),
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
  css('.de-docs-nav-link:hover').styles(
    raw: {'background': 'var(--accent)', 'color': 'var(--accent-foreground)'},
  ),
  css('.de-docs-main').styles(
    minWidth: Unit.zero,
    maxWidth: 64.rem,
    width: 100.percent,
    padding: Padding.symmetric(horizontal: 2.5.rem, vertical: 2.rem),
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
  css('.de-docs-pager [data-slot="card"]').styles(
    raw: {'transition': 'border-color 150ms ease, box-shadow 150ms ease'},
  ),
  css('.de-docs-pager [data-slot="card"]:hover').styles(
    raw: {
      'border-color': 'var(--ring)',
      'box-shadow': '0 6px 18px rgb(0 0 0 / 0.08)',
    },
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
  ..._shadcnFallbackStyles,
];

List<StyleRule> get _shadcnFallbackStyles => [
  css(':root').styles(
    raw: {
      'color-scheme': 'light',
      '--radius': '0.5rem',
      '--background': '#ffffff',
      '--foreground': '#111111',
      '--card': '#ffffff',
      '--card-foreground': '#111111',
      '--primary': '#171717',
      '--primary-foreground': '#fafafa',
      '--secondary': '#f5f5f5',
      '--secondary-foreground': '#171717',
      '--muted': '#f5f5f5',
      '--muted-foreground': '#737373',
      '--accent': '#f5f5f5',
      '--accent-foreground': '#171717',
      '--destructive': '#dc2626',
      '--border': '#e5e5e5',
      '--input': '#e5e5e5',
      '--ring': '#a3a3a3',
    },
  ),
  css(':root[data-theme="dark"]').styles(
    raw: {
      'color-scheme': 'dark',
      '--background': '#0a0a0a',
      '--foreground': '#fafafa',
      '--card': '#111111',
      '--card-foreground': '#fafafa',
      '--primary': '#fafafa',
      '--primary-foreground': '#171717',
      '--secondary': '#262626',
      '--secondary-foreground': '#fafafa',
      '--muted': '#262626',
      '--muted-foreground': '#a3a3a3',
      '--accent': '#262626',
      '--accent-foreground': '#fafafa',
      '--destructive': '#ef4444',
      '--border': '#262626',
      '--input': '#262626',
      '--ring': '#737373',
    },
  ),
  css('*').styles(raw: {'box-sizing': 'border-box'}),
  css('body').styles(
    margin: Margin.zero,
    raw: {
      'background': 'var(--background)',
      'color': 'var(--foreground)',
      'font-family':
          'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
  ),
  css('a').styles(raw: {'color': 'inherit'}),
  css('.min-h-screen').styles(raw: {'min-height': '100vh'}),
  css('.border').styles(raw: {'border': '1px solid var(--border)'}),
  css('.border-b').styles(raw: {'border-bottom': '1px solid var(--border)'}),
  css('.border-r').styles(raw: {'border-right': '1px solid var(--border)'}),
  css('.bg-background').styles(raw: {'background': 'var(--background)'}),
  css('.bg-background\\/95').styles(
    raw: {
      'background': 'color-mix(in srgb, var(--background) 95%, transparent)',
    },
  ),
  css('.bg-muted, .bg-secondary').styles(raw: {'background': 'var(--muted)'}),
  css('.bg-card').styles(raw: {'background': 'var(--card)'}),
  css('.text-foreground').styles(raw: {'color': 'var(--foreground)'}),
  css(
    '.text-muted-foreground',
  ).styles(raw: {'color': 'var(--muted-foreground)'}),
  css('.text-card-foreground').styles(raw: {'color': 'var(--card-foreground)'}),
  css('.text-destructive').styles(raw: {'color': 'var(--destructive)'}),
  css(
    '.text-primary-foreground',
  ).styles(raw: {'color': 'var(--primary-foreground)'}),
  css('.font-normal').styles(fontWeight: FontWeight.normal),
  css('.font-medium').styles(fontWeight: FontWeight.w500),
  css('.font-semibold').styles(fontWeight: FontWeight.w600),
  css('.tracking-tight').styles(raw: {'letter-spacing': '0'}),
  css('.rounded-md').styles(raw: {'border-radius': '0.375rem'}),
  css('.rounded-lg').styles(raw: {'border-radius': '0.5rem'}),
  css('.rounded-xl').styles(raw: {'border-radius': '0.75rem'}),
  css(
    '.px-2',
  ).styles(raw: {'padding-left': '0.5rem', 'padding-right': '0.5rem'}),
  css(
    '.px-3',
  ).styles(raw: {'padding-left': '0.75rem', 'padding-right': '0.75rem'}),
  css('.px-4').styles(raw: {'padding-left': '1rem', 'padding-right': '1rem'}),
  css(
    '.px-6',
  ).styles(raw: {'padding-left': '1.5rem', 'padding-right': '1.5rem'}),
  css(
    '.py-0\\.5',
  ).styles(raw: {'padding-top': '0.125rem', 'padding-bottom': '0.125rem'}),
  css(
    '.py-2',
  ).styles(raw: {'padding-top': '0.5rem', 'padding-bottom': '0.5rem'}),
  css(
    '.py-3',
  ).styles(raw: {'padding-top': '0.75rem', 'padding-bottom': '0.75rem'}),
  css(
    '.py-6',
  ).styles(raw: {'padding-top': '1.5rem', 'padding-bottom': '1.5rem'}),
  css('.text-xs').styles(fontSize: 0.75.rem),
  css('.text-sm').styles(fontSize: 0.875.rem),
  css('.shadow-sm').styles(raw: {'box-shadow': '0 1px 2px rgb(0 0 0 / 0.05)'}),
  css('[data-slot="badge"]').styles(
    raw: {
      'display': 'inline-flex',
      'width': 'fit-content',
      'align-items': 'center',
      'justify-content': 'center',
      'gap': '0.25rem',
      'overflow': 'hidden',
      'white-space': 'nowrap',
      'border-radius': '9999px',
      'border': '1px solid transparent',
      'padding': '0.125rem 0.5rem',
      'font-size': '0.75rem',
      'font-weight': '500',
    },
  ),
  css('[data-slot="badge"][data-variant="defaultVariant"]').styles(
    raw: {'background': 'var(--primary)', 'color': 'var(--primary-foreground)'},
  ),
  css('[data-slot="badge"][data-variant="secondary"]').styles(
    raw: {
      'background': 'var(--secondary)',
      'color': 'var(--secondary-foreground)',
    },
  ),
  css(
    '[data-slot="badge"][data-variant="destructive"]',
  ).styles(raw: {'background': 'var(--destructive)', 'color': '#ffffff'}),
  css('[data-slot="badge"][data-variant="outline"]').styles(
    raw: {'border-color': 'var(--border)', 'color': 'var(--foreground)'},
  ),
  css('[data-slot="breadcrumb-list"]').styles(
    raw: {
      'display': 'flex',
      'flex-wrap': 'wrap',
      'align-items': 'center',
      'gap': '0.375rem',
      'margin': '0',
      'padding': '0',
      'list-style': 'none',
      'font-size': '0.875rem',
      'color': 'var(--muted-foreground)',
    },
  ),
  css(
    '[data-slot="breadcrumb-item"], [data-slot="breadcrumb-separator"]',
  ).styles(
    raw: {'display': 'inline-flex', 'align-items': 'center', 'gap': '0.375rem'},
  ),
  css(
    '[data-slot="breadcrumb-link"]',
  ).styles(raw: {'text-decoration': 'none', 'transition': 'color 150ms ease'}),
  css(
    '[data-slot="breadcrumb-link"]:hover',
  ).styles(raw: {'color': 'var(--foreground)'}),
  css(
    '[data-slot="breadcrumb-page"]',
  ).styles(raw: {'color': 'var(--foreground)', 'font-weight': '400'}),
  css('[data-slot="breadcrumb-separator"] svg').styles(
    raw: {'display': 'block', 'width': '0.875rem', 'height': '0.875rem'},
  ),
  css('[data-slot="card"]').styles(
    raw: {
      'display': 'flex',
      'flex-direction': 'column',
      'gap': '1.5rem',
      'border': '1px solid var(--border)',
      'border-radius': '0.75rem',
      'background': 'var(--card)',
      'padding': '1.5rem 0',
      'color': 'var(--card-foreground)',
      'box-shadow': '0 1px 2px rgb(0 0 0 / 0.05)',
    },
  ),
  css(
    '[data-slot="card-header"]',
  ).styles(raw: {'display': 'grid', 'gap': '0.5rem', 'padding': '0 1.5rem'}),
  css(
    '[data-slot="card-title"]',
  ).styles(raw: {'font-weight': '600', 'line-height': '1'}),
  css(
    '[data-slot="card-description"]',
  ).styles(raw: {'color': 'var(--muted-foreground)', 'font-size': '0.875rem'}),
  css('[data-slot="card-content"]').styles(raw: {'padding': '0 1.5rem'}),
  css('[data-slot="alert"]').styles(
    raw: {
      'display': 'grid',
      'gap': '0.125rem',
      'width': '100%',
      'border': '1px solid var(--border)',
      'border-radius': '0.5rem',
      'background': 'var(--card)',
      'padding': '0.75rem 1rem',
      'font-size': '0.875rem',
    },
  ),
  css('[data-slot="alert"][data-variant="destructive"]').styles(
    raw: {
      'border-color': 'rgb(220 38 38 / 0.5)',
      'color': 'var(--destructive)',
    },
  ),
  css('[data-slot="alert-title"]').styles(raw: {'font-weight': '500'}),
  css(
    '[data-slot="alert-description"]',
  ).styles(raw: {'color': 'var(--muted-foreground)', 'line-height': '1.625'}),
  css('[data-slot="button"]').styles(
    raw: {
      'display': 'inline-flex',
      'align-items': 'center',
      'justify-content': 'center',
      'gap': '0.5rem',
      'height': '2.25rem',
      'border': '1px solid transparent',
      'border-radius': '0.375rem',
      'padding': '0.5rem 1rem',
      'font': 'inherit',
      'font-size': '0.875rem',
      'font-weight': '500',
      'white-space': 'nowrap',
      'cursor': 'pointer',
      'transition':
          'background 150ms ease, color 150ms ease, border-color 150ms ease',
    },
  ),
  css('[data-slot="button"][data-variant="defaultVariant"]').styles(
    raw: {'background': 'var(--primary)', 'color': 'var(--primary-foreground)'},
  ),
  css('[data-slot="button"][data-variant="secondary"]').styles(
    raw: {
      'background': 'var(--secondary)',
      'color': 'var(--secondary-foreground)',
    },
  ),
  css('[data-slot="button"][data-variant="outline"]').styles(
    raw: {
      'border-color': 'var(--border)',
      'background': 'var(--background)',
      'color': 'var(--foreground)',
    },
  ),
  css(
    '[data-slot="button"][data-variant="ghost"], '
    '[data-slot="button"][data-variant="link"]',
  ).styles(raw: {'background': 'transparent', 'color': 'var(--foreground)'}),
  css(
    '[data-slot="button"][data-variant="destructive"]',
  ).styles(raw: {'background': 'var(--destructive)', 'color': '#ffffff'}),
  css('[data-slot="button"]:hover').styles(raw: {'filter': 'brightness(0.96)'}),
  css('.de-docs-content').styles(raw: {'line-height': '1.7'}),
  css(
    '.de-docs-content h1',
  ).styles(raw: {'font-size': '2.25rem', 'line-height': '1.15'}),
  css('.de-docs-content h2').styles(
    raw: {
      'border-bottom': '1px solid var(--border)',
      'font-size': '1.75rem',
      'line-height': '1.2',
      'padding-bottom': '0.5rem',
    },
  ),
  css('.de-docs-content code').styles(
    raw: {
      'background': 'var(--muted)',
      'border-radius': '0.375rem',
      'padding': '0.15rem 0.3rem',
    },
  ),
];
