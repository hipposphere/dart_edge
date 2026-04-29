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

  static const RequestBody requestBody = RequestBody.json(
    schema: schemaRef,
    decoder: fromJson,
  );

  static const ResponseSpec response = ResponseSpec.json(
    status: 201,
    schema: schemaRef,
  );

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
  const _$CreateNoteResponse({required this.notes});

  static const schemaId = "CreateNoteResponse";

  static const schemaRef = JsonSchema.ref(schemaId);

  static const RequestBody requestBody = RequestBody.json(
    schema: schemaRef,
    decoder: fromJson,
  );

  static const ResponseSpec response = ResponseSpec.json(
    status: 201,
    schema: schemaRef,
  );

  final NotesRow notes;

  @override
  Map<String, Object?> toJson() => <String, Object?>{"notes": notes.toJson()};

  static CreateNoteResponse fromJson(Object? value) {
    final json = value! as Map<String, Object?>;
    return CreateNoteResponse(
      notes: NotesRow.fromJson(
        Map<String, Object?>.from(json["notes"]! as Map),
      ),
    );
  }
}
