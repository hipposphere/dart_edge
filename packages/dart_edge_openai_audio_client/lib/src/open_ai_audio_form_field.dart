/// One additional multipart text field.
///
/// A list is used instead of a map so callers can repeat fields supported by
/// a provider, such as timestamp granularities.
final class OpenAiAudioFormField {
  const OpenAiAudioFormField(this.name, this.value);

  final String name;
  final String value;
}
