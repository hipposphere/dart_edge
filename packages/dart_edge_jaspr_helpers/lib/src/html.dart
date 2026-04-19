import 'package:jaspr/dom.dart' show Styles;
import 'package:jaspr/jaspr.dart' show Component;

const String defaultFontStack =
    '-apple-system, BlinkMacSystemFont, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

Component htmlElement(
  String tag, {
  Styles? styles,
  Map<String, String>? attributes,
  List<Component> children = const <Component>[],
}) {
  return Component.element(
    tag: tag,
    styles: styles,
    attributes: attributes,
    children: children,
  );
}

Component textNode(String value) => Component.text(value);

Styles rawStyles(Map<String, String> raw) => Styles(raw: raw);

Component paragraph(
  String text, {
  required String color,
  String margin = '0',
  String fontSize = '16px',
  String fontWeight = '400',
  String lineHeight = '1.65',
}) {
  return htmlElement(
    'p',
    styles: rawStyles({
      'margin': margin,
      'color': color,
      'font-size': fontSize,
      'font-weight': fontWeight,
      'line-height': lineHeight,
    }),
    children: [textNode(text)],
  );
}

Component heading(
  String tag,
  String text, {
  required String color,
  String margin = '0',
  String fontSize = '40px',
  String fontWeight = '720',
  String lineHeight = '1.08',
  String letterSpacing = '-0.04em',
}) {
  return htmlElement(
    tag,
    styles: rawStyles({
      'margin': margin,
      'color': color,
      'font-size': fontSize,
      'font-weight': fontWeight,
      'line-height': lineHeight,
      'letter-spacing': letterSpacing,
    }),
    children: [textNode(text)],
  );
}

Component labelText(
  String text, {
  required String color,
  String margin = '0',
  String fontSize = '12px',
  String fontWeight = '700',
  String letterSpacing = '0.14em',
  String textTransform = 'uppercase',
}) {
  return htmlElement(
    'div',
    styles: rawStyles({
      'margin': margin,
      'color': color,
      'font-size': fontSize,
      'font-weight': fontWeight,
      'letter-spacing': letterSpacing,
      'text-transform': textTransform,
    }),
    children: [textNode(text)],
  );
}

Component spacer(String height) {
  return htmlElement(
    'div',
    styles: rawStyles({
      'height': height,
      'line-height': height,
      'font-size': '1px',
    }),
  );
}
