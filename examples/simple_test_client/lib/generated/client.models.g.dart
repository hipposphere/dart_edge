// GENERATED CODE - DO NOT MODIFY BY HAND.

part of 'client.g.dart';

final class CreateNoteResponse implements JsonEncodable {
  const CreateNoteResponse({required this.notes});

  factory CreateNoteResponse.fromJson(Object? value) {
    final json = Map<String, Object?>.from(value! as Map);
    return CreateNoteResponse(
      notes: NotesRow.fromJson(
        Map<String, Object?>.from(json['notes']! as Map),
      ),
    );
  }

  final NotesRow notes;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'notes': notes.toJson()};
  }
}
