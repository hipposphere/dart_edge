// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_params.dart';

// **************************************************************************
// DartEdgeHttpServerBuilderGenerator
// **************************************************************************

// ignore_for_file: unused_element, unused_field
final class _$IdParams<T extends String> implements JsonEncodable {
  const _$IdParams({required this.id});

  factory _$IdParams.decode(Object? value) {
    return _$IdParams<T>.fromJson(readJsonObject(value));
  }

  factory _$IdParams.fromJson(Map<String, Object?> json) {
    return IdParams<T>(id: json["id"]! as T);
  }

  static const schemaId = 'IdParams';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const RequestBody requestBody = RequestBody.json(schema: schemaRef);

  static const ResponseSpec response = ResponseSpec.json(
    status: 200,
    schema: schemaRef,
  );

  final T id;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{"id": id};
  }
}
