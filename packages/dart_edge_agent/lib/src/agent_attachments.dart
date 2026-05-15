import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_rig/dart_edge_rig.dart';

/// Convenience constructors for common agent attachments.
abstract final class AgentAttachment {
  /// Reads [file] as text and attaches it as a document.
  static Future<RigUserContent> textFile(File file, {String? mediaType}) async {
    return RigUserContent.document(
      source: RigContentSource.string(await file.readAsString()),
      mediaType: mediaType ?? _documentMediaType(file.path),
    );
  }

  /// Reads [file] as bytes and attaches it as a base64 document.
  static Future<RigUserContent> documentFile(
    File file, {
    String? mediaType,
  }) async {
    return RigUserContent.document(
      source: RigContentSource.base64(base64Encode(await file.readAsBytes())),
      mediaType: mediaType ?? _documentMediaType(file.path),
    );
  }

  /// Reads [file] as bytes and attaches it as a base64 image.
  static Future<RigUserContent> imageFile(
    File file, {
    String? mediaType,
    RigImageDetail? detail,
  }) async {
    return RigUserContent.image(
      source: RigContentSource.base64(base64Encode(await file.readAsBytes())),
      mediaType: mediaType ?? _imageMediaType(file.path),
      detail: detail,
    );
  }

  static String? _documentMediaType(String path) {
    return switch (_extension(path)) {
      'pdf' => 'pdf',
      'txt' => 'txt',
      'md' || 'markdown' => 'markdown',
      'csv' => 'csv',
      'html' || 'htm' => 'html',
      'css' => 'css',
      'xml' => 'xml',
      'js' || 'mjs' || 'cjs' => 'javascript',
      'py' => 'python',
      _ => null,
    };
  }

  static String? _imageMediaType(String path) {
    return switch (_extension(path)) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'gif' => 'gif',
      'webp' => 'webp',
      'heic' => 'heic',
      'heif' => 'heif',
      'svg' => 'svg',
      _ => null,
    };
  }

  static String _extension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }
}
