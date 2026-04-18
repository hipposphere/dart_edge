/// Contract for values that know how to serialize themselves as JSON-friendly
/// Dart objects.
abstract interface class JsonEncodable {
  /// Converts this value into a JSON-friendly representation.
  Object? toJson();
}
