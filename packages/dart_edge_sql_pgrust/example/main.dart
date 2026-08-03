import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pgrust/dart_edge_sql_pgrust.dart';

Future<void> main() async {
  final database = await PgrustDatabase.temporary();
  final pool = database.asPostgresPool();

  try {
    final result = await pool.execute(sql("SELECT 'pg' || 'rust' AS database"));
    print(result.single.read<String>('database'));
  } finally {
    await pool.close();
  }
}
