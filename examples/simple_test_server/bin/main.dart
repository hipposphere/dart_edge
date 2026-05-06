import 'package:simple_test_server/server.dart';

Future<void> main() async {
  final server = await buildServer();
  await server.listen(port: 3100);
  print('Server is running on http://localhost:3100');
}
