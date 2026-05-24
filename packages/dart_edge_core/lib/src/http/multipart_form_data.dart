import 'dart:typed_data';

/// One decoded UTF-8 text field from a multipart form payload.
final class MultipartFormField {
  const MultipartFormField({required this.name, required this.value});

  /// Multipart field name from `Content-Disposition`.
  final String name;

  /// UTF-8 decoded field value.
  final String value;
}

/// One uploaded file part from a multipart form payload.
abstract interface class MultipartFile {
  /// Multipart field name from `Content-Disposition`.
  String get fieldName;

  /// Optional client-provided file name.
  String? get filename;

  /// Optional part-level content type.
  String? get contentType;

  /// Uploaded file length in bytes, when known by the runtime.
  int get length;

  /// Lazily copies the uploaded file into Dart-owned memory.
  Future<Uint8List> get bytes;

  /// Opens a stream for the uploaded file contents.
  Stream<List<int>> openRead();
}

/// Parsed multipart form-data payload.
final class MultipartFormData {
  MultipartFormData({
    required Iterable<MultipartFormField> fields,
    required Iterable<MultipartFile> files,
  }) : fields = List.unmodifiable(fields),
       files = List.unmodifiable(files);

  /// Decoded UTF-8 text fields.
  final List<MultipartFormField> fields;

  /// Uploaded file parts.
  final List<MultipartFile> files;

  /// Returns every text field value for [name].
  Iterable<String> fieldValues(String name) sync* {
    for (final field in fields) {
      if (field.name == name) {
        yield field.value;
      }
    }
  }

  /// Returns the first text field value for [name], if present.
  String? fieldValue(String name) {
    for (final value in fieldValues(name)) {
      return value;
    }
    return null;
  }

  /// Returns every file uploaded for [name].
  Iterable<MultipartFile> filesNamed(String name) sync* {
    for (final file in files) {
      if (file.fieldName == name) {
        yield file;
      }
    }
  }

  /// Returns the first file uploaded for [name], if present.
  MultipartFile? file(String name) {
    for (final file in filesNamed(name)) {
      return file;
    }
    return null;
  }
}
