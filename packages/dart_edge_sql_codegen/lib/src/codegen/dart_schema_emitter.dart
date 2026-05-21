import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../introspection/introspected_database.dart';
import 'sql_codegen_config.dart';

part 'dart_schema_emitter/emission.dart';
part 'dart_schema_emitter/libraries.dart';
part 'dart_schema_emitter/enum_models.dart';
part 'dart_schema_emitter/table_models.dart';
part 'dart_schema_emitter/routine_models.dart';
part 'dart_schema_emitter/json_mapping.dart';
part 'dart_schema_emitter/code_builder_helpers.dart';
part 'dart_schema_emitter/naming.dart';
