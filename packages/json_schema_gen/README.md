# json_schema_gen

Generates plain Dart JSON models from portable `@FromSchema` annotations.

```dart
import 'package:json_schema/json_schema.dart';

part 'user.g.dart';

const userSchema = JsonSchema.object(
  id: 'User',
  properties: {'id': JsonSchema.string()},
  required: ['id'],
);

@FromSchema(userSchema)
typedef User = _$User;
```

Add `json_schema_gen` and `build_runner` to the consuming package, then run
`dart run build_runner build`. Generated models expose schema constants plus
`fromJson`, `decode`, and `toJson` without importing Dart Edge packages.
