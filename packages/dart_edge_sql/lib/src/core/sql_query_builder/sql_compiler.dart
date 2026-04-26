part of '../sql_query_builder.dart';

final class _SqlCompiler {
  _SqlCompiler(this.dialect);

  final SqlDialect dialect;
  final StringBuffer _buffer = StringBuffer();
  final Map<String, Object?> _parameters = <String, Object?>{};
  var _parameterIndex = 0;

  void write(String value) => _buffer.write(value);

  void writeIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    _buffer.write('"$escaped"');
  }

  void writeTable(SqlTable<dynamic, dynamic, dynamic> table) {
    if (table.schema case final String schemaName) {
      writeIdentifier(schemaName);
      write('.');
    }
    writeIdentifier(table.name);
  }

  void writeColumn(SqlColumn<dynamic> column) {
    writeTable(column.table);
    write('.');
    writeIdentifier(column.name);
  }

  void writeValue(Object? value) {
    final parameterName = 'p${++_parameterIndex}';
    _parameters[parameterName] = value;
    final placeholderPrefix = switch (dialect) {
      SqlDialect.sqlite => ':',
      SqlDialect.postgres => '@',
    };
    _buffer.write('$placeholderPrefix$parameterName');
  }

  void writePredicate(SqlPredicate predicate) {
    switch (predicate) {
      case _SqlComparisonPredicate():
        writeColumn(predicate.left.asObjectColumn);
        write(' ${predicate.operator} ');
        switch (predicate.right) {
          case final SqlColumn<dynamic> column:
            writeColumn(column);
          default:
            writeValue(predicate.right);
        }
      case _SqlNullPredicate():
        writeColumn(predicate.column.asObjectColumn);
        write(predicate.isNull ? ' IS NULL' : ' IS NOT NULL');
      case _SqlInPredicate():
        if (predicate.values.isEmpty) {
          write('1 = 0');
          return;
        }
        writeColumn(predicate.column.asObjectColumn);
        write(' IN (');
        writeJoined(
          predicate.values,
          separator: ', ',
          writeElement: writeValue,
        );
        write(')');
      case _SqlCompoundPredicate():
        write('(');
        writeJoined(
          predicate.predicates,
          separator: ' ${predicate.operator} ',
          writeElement: writePredicate,
        );
        write(')');
    }
  }

  void writeJoined<T>(
    Iterable<T> values, {
    required String separator,
    required void Function(T value) writeElement,
  }) {
    var first = true;
    for (final value in values) {
      if (!first) {
        write(separator);
      }
      first = false;
      writeElement(value);
    }
  }

  SqlStatement toStatement() {
    if (_parameters.isEmpty) {
      return SqlStatement(_buffer.toString());
    }
    return SqlStatement.named(
      _buffer.toString(),
      Map<String, Object?>.unmodifiable(_parameters),
    );
  }
}

SqlSelectedColumn<dynamic> _normalizeSelectedColumn(Object value) {
  return switch (value) {
    final SqlSelectedColumn<dynamic> selected => selected,
    final SqlColumn<dynamic> column => SqlSelectedColumn<dynamic>(
      column: column,
    ),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'columns',
      'select() accepts SqlColumn or SqlSelectedColumn values only.',
    ),
  };
}

String _aliasFor(SqlColumn<dynamic> column) =>
    '${column.table.selectionPrefix}${column.name}';

sealed class _SqlSelection<TSelection> {
  const _SqlSelection();

  List<_SelectedProjection> get projections;

  TSelection map(SqlRow row);
}

final class _RawRowSelection extends _SqlSelection<SqlRow> {
  const _RawRowSelection(this.projections);

  @override
  final List<_SelectedProjection> projections;
  @override
  SqlRow map(SqlRow row) => row;
}

final class _TableSelection<TRow, TInsert, TUpdate>
    extends _SqlSelection<TRow> {
  _TableSelection(this.table);

  final SqlTable<TRow, TInsert, TUpdate> table;

  @override
  late final List<_SelectedProjection> projections = table.columns
      .map(
        (column) =>
            _SelectedProjection(column: column, alias: _aliasFor(column)),
      )
      .toList(growable: false);
  @override
  TRow map(SqlRow row) => table.mapRow(row, prefix: table.selectionPrefix);
}

final class _TableSelection2<
  TLeft,
  TLeftInsert,
  TLeftUpdate,
  TRight,
  TRightInsert,
  TRightUpdate
>
    extends _SqlSelection<SqlJoined2<TLeft, TRight>> {
  _TableSelection2(this.left, this.right);

  final SqlTable<TLeft, TLeftInsert, TLeftUpdate> left;
  final SqlTable<TRight, TRightInsert, TRightUpdate> right;

  @override
  late final List<_SelectedProjection> projections = [
    ...left.columns.map(
      (column) => _SelectedProjection(column: column, alias: _aliasFor(column)),
    ),
    ...right.columns.map(
      (column) => _SelectedProjection(column: column, alias: _aliasFor(column)),
    ),
  ];
  @override
  SqlJoined2<TLeft, TRight> map(SqlRow row) => SqlJoined2<TLeft, TRight>(
    left: left.mapRow(row, prefix: left.selectionPrefix),
    right: right.mapRow(row, prefix: right.selectionPrefix),
  );
}

final class _SelectedProjection {
  const _SelectedProjection({required this.column, required this.alias});

  final SqlColumn<dynamic> column;
  final String alias;
}

enum _SqlJoinType {
  inner('INNER JOIN'),
  left('LEFT JOIN');

  const _SqlJoinType(this.keyword);

  final String keyword;
}

final class _SqlJoin {
  const _SqlJoin({required this.type, required this.table, required this.on});

  final _SqlJoinType type;
  final SqlTable<dynamic, dynamic, dynamic> table;
  final SqlPredicate on;
}

final class _SqlComparisonPredicate extends SqlPredicate {
  const _SqlComparisonPredicate._({
    required this.left,
    required this.operator,
    required this.right,
  });

  const _SqlComparisonPredicate.value({
    required SqlColumn<dynamic> left,
    required String operator,
    required Object? value,
  }) : this._(left: left, operator: operator, right: value);

  const _SqlComparisonPredicate.column({
    required SqlColumn<dynamic> left,
    required String operator,
    required SqlColumn<dynamic> right,
  }) : this._(left: left, operator: operator, right: right);

  final SqlColumn<dynamic> left;
  final String operator;
  final Object? right;
}

final class _SqlNullPredicate extends SqlPredicate {
  const _SqlNullPredicate({required this.column, required this.isNull});

  final SqlColumn<dynamic> column;
  final bool isNull;
}

final class _SqlInPredicate extends SqlPredicate {
  const _SqlInPredicate({required this.column, required this.values});

  final SqlColumn<dynamic> column;
  final List<Object?> values;
}

final class _SqlCompoundPredicate extends SqlPredicate {
  const _SqlCompoundPredicate(this.operator, this.predicates);

  final String operator;
  final List<SqlPredicate> predicates;
}
