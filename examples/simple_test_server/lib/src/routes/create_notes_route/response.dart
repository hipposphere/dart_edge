import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:simple_test_db_models/simple_test_db_models.dart';

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

  static const schemaId = 'CreateNoteResponse';

  static const schemaRef = JsonSchema.ref(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{'notes': NotesRow.schemaRef},
    required: <String>['notes'],
    additionalProperties: false,
  );

  final NotesRow notes;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'notes': notes.toJson()};
}
