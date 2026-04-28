// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route.dart';

// **************************************************************************
// DartEdgeHttpServerBuilderGenerator
// **************************************************************************

// ignore_for_file: unused_element, unused_field

final class _$CreateNoteBody implements JsonEncodable {
  const _$CreateNoteBody({
    this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    this.createdAt,
  });

  static const schemaId = "NotesInsert";

  static const schemaRef = JsonSchema.ref(schemaId);

  static RequestBody get requestBody =>
      RequestBody.json(schema: schemaRef, decoder: fromJson);

  static ResponseSpec response({int status = 200}) =>
      ResponseSpec.json(status: status, schema: schemaRef);

  final int? id;

  final String title;

  final String body;

  final int ownerId;

  final String? createdAt;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "id": id,
    "title": title,
    "body": body,
    "owner_id": ownerId,
    "created_at": createdAt,
  };

  static CreateNoteBody fromJson(Object? value) {
    final json = value! as Map<String, Object?>;
    return CreateNoteBody(
      id: json["id"] as int?,
      title: json["title"]! as String,
      body: json["body"]! as String,
      ownerId: json["owner_id"]! as int,
      createdAt: json["created_at"] as String?,
    );
  }
}

final class _$CreateNoteResponse implements JsonEncodable {
  const _$CreateNoteResponse({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.createdAt,
  });

  static const schemaId = "CreateNoteResponse";

  static const schemaRef = JsonSchema.ref(schemaId);

  static RequestBody get requestBody =>
      RequestBody.json(schema: schemaRef, decoder: fromJson);

  static ResponseSpec response({int status = 200}) =>
      ResponseSpec.json(status: status, schema: schemaRef);

  final int? id;

  final String title;

  final String body;

  final int ownerId;

  final String createdAt;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "id": id,
    "title": title,
    "body": body,
    "owner_id": ownerId,
    "created_at": createdAt,
  };

  static CreateNoteResponse fromJson(Object? value) {
    final json = value! as Map<String, Object?>;
    return CreateNoteResponse(
      id: json["id"] as int?,
      title: json["title"]! as String,
      body: json["body"]! as String,
      ownerId: json["owner_id"]! as int,
      createdAt: json["created_at"]! as String,
    );
  }
}
