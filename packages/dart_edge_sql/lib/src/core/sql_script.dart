import 'dart:async';
import 'dart:convert';

import 'sql_dialect.dart';
import 'sql_executor.dart';
import 'sql_statement.dart';

/// Controls how [SqlScriptPoolExtension.executeScript] handles transactions.
enum SqlScriptTransactionMode {
  /// Executes transaction-control statements exactly as they appear.
  preserve,

  /// Wraps the complete script in one transaction.
  ///
  /// Explicit transaction-control statements are rejected.
  atomic,

  /// Executes without an implicit transaction.
  ///
  /// Explicit transaction-control statements are rejected.
  none,
}

/// Current phase of a streaming SQL-script import.
enum SqlScriptPhase { reading, executing, completed, canceled }

/// Decision returned by [SqlScriptStatementHandler].
enum SqlScriptStatementAction { execute, skip }

/// One parsed SQL statement and its source location.
final class SqlScriptStatement {
  const SqlScriptStatement({
    required this.sql,
    required this.number,
    required this.byteOffset,
  });

  final String sql;
  final int number;
  final int byteOffset;

  String preview({int maxLength = 240}) {
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength)}…';
  }
}

typedef SqlScriptStatementHandler = FutureOr<SqlScriptStatementAction> Function(
  SqlScriptStatement statement,
);

/// Point-in-time progress for a streaming SQL-script import.
final class SqlScriptProgress {
  const SqlScriptProgress({
    required this.bytesRead,
    required this.totalBytes,
    required this.statementsCompleted,
    required this.phase,
    required this.elapsed,
    this.currentStatement,
  });

  final int bytesRead;
  final int? totalBytes;
  final int statementsCompleted;
  final SqlScriptPhase phase;
  final Duration elapsed;
  final SqlScriptStatement? currentStatement;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (bytesRead / total).clamp(0, 1);
  }
}

/// Result of a successfully completed SQL script.
final class SqlScriptResult {
  const SqlScriptResult({
    required this.bytesRead,
    required this.statementsCompleted,
    required this.elapsed,
  });

  final int bytesRead;
  final int statementsCompleted;
  final Duration elapsed;
}

/// A running SQL-script import.
final class SqlScriptOperation {
  const SqlScriptOperation._({
    required this.progress,
    required this.result,
    required this._cancel,
  });

  final Stream<SqlScriptProgress> progress;
  final Future<SqlScriptResult> result;
  final Future<void> Function() _cancel;

  /// Requests cancellation.
  ///
  /// The active native statement is allowed to finish; cancellation is
  /// observed before the next statement is executed.
  Future<void> cancel() => _cancel();
}

/// Base exception carrying a bounded statement preview and source location.
class SqlScriptException implements Exception {
  const SqlScriptException({
    required this.message,
    required this.statementNumber,
    required this.byteOffset,
    required this.statementPreview,
    this.cause,
  });

  final String message;
  final int statementNumber;
  final int byteOffset;
  final String statementPreview;
  final Object? cause;

  @override
  String toString() {
    final preview = statementPreview.isEmpty ? '' : ' SQL: $statementPreview';
    return 'SqlScriptException at statement $statementNumber, byte '
        '$byteOffset: $message.$preview';
  }
}

/// Raised when [SqlScriptOperation.cancel] stops an import.
final class SqlScriptCanceledException extends SqlScriptException {
  const SqlScriptCanceledException({
    required super.statementNumber,
    required super.byteOffset,
    required super.statementPreview,
  }) : super(message: 'SQL script execution was canceled');
}

/// Streaming SQL-script operations for every [SqlPool].
extension SqlScriptPoolExtension on SqlPool {
  SqlScriptOperation executeScript(
    Stream<List<int>> source, {
    SqlDialect? dialect,
    int? totalBytes,
    SqlScriptTransactionMode transactionMode =
        SqlScriptTransactionMode.preserve,
    SqlScriptStatementHandler? onStatement,
  }) {
    if (totalBytes != null && totalBytes < 0) {
      throw ArgumentError.value(
        totalBytes,
        'totalBytes',
        'Must not be negative.',
      );
    }
    if (dialect != null && dialect != this.dialect) {
      throw ArgumentError.value(
        dialect,
        'dialect',
        'Must match the pool dialect (${this.dialect.name}).',
      );
    }
    final progress = StreamController<SqlScriptProgress>.broadcast(sync: true);
    final cancellation = _SqlScriptCancellation();
    final runner = _SqlScriptRunner(
      pool: this,
      source: source,
      totalBytes: totalBytes,
      transactionMode: transactionMode,
      onStatement: onStatement,
      progress: progress,
      cancellation: cancellation,
    );
    final result = Future<SqlScriptResult>.microtask(runner.run);
    return SqlScriptOperation._(
      progress: progress.stream,
      result: result,
      cancel: cancellation.cancel,
    );
  }
}

final class _SqlScriptCancellation {
  var requested = false;

  Future<void> cancel() async {
    requested = true;
  }
}

final class _SqlScriptRunner {
  const _SqlScriptRunner({
    required this.pool,
    required this.source,
    required this.totalBytes,
    required this.transactionMode,
    required this.onStatement,
    required this.progress,
    required this.cancellation,
  });

  final SqlPool pool;
  final Stream<List<int>> source;
  final int? totalBytes;
  final SqlScriptTransactionMode transactionMode;
  final SqlScriptStatementHandler? onStatement;
  final StreamController<SqlScriptProgress> progress;
  final _SqlScriptCancellation cancellation;

  Future<SqlScriptResult> run() async {
    final stopwatch = Stopwatch()..start();
    var bytesRead = 0;
    var completed = 0;
    SqlScriptStatement? current;

    void emit(SqlScriptPhase phase) {
      if (progress.isClosed) return;
      progress.add(
        SqlScriptProgress(
          bytesRead: bytesRead,
          totalBytes: totalBytes,
          statementsCompleted: completed,
          phase: phase,
          elapsed: stopwatch.elapsed,
          currentStatement: current,
        ),
      );
    }

    Future<SqlScriptResult> consume(SqlExecutor executor) async {
      final parser = _SqlScriptParser();
      final countedSource = source.map((bytes) {
        bytesRead += bytes.length;
        emit(SqlScriptPhase.reading);
        return bytes;
      });

      Future<void> execute(SqlScriptStatement statement) async {
        current = statement;
        _throwIfCanceled(
          cancellation,
          statementNumber: statement.number,
          byteOffset: statement.byteOffset,
          preview: () => statement.preview(),
        );
        if (transactionMode != SqlScriptTransactionMode.preserve &&
            _isTransactionControl(statement.sql)) {
          throw SqlScriptException(
            message:
                'Explicit transaction control is not allowed in ${transactionMode.name} mode',
            statementNumber: statement.number,
            byteOffset: statement.byteOffset,
            statementPreview: statement.preview(),
          );
        }
        emit(SqlScriptPhase.executing);
        try {
          final action =
              await onStatement?.call(statement) ??
              SqlScriptStatementAction.execute;
          if (action == SqlScriptStatementAction.execute) {
            await executor.execute(SqlStatement(statement.sql));
          }
        } on SqlScriptException {
          rethrow;
        } on Object catch (error) {
          throw SqlScriptException(
            message: 'Could not execute SQL statement',
            statementNumber: statement.number,
            byteOffset: statement.byteOffset,
            statementPreview: statement.preview(),
            cause: error,
          );
        }
        completed++;
        current = null;
      }

      await for (final text in countedSource.transform(utf8.decoder)) {
        _throwIfCanceled(
          cancellation,
          statementNumber: completed + 1,
          byteOffset: parser.byteOffset,
          preview: () => parser.preview,
        );
        for (final parsed in parser.add(text)) {
          await execute(
            SqlScriptStatement(
              sql: parsed.sql,
              number: completed + 1,
              byteOffset: parsed.byteOffset,
            ),
          );
        }
      }
      for (final parsed in parser.close(statementNumber: completed + 1)) {
        await execute(
          SqlScriptStatement(
            sql: parsed.sql,
            number: completed + 1,
            byteOffset: parsed.byteOffset,
          ),
        );
      }
      _throwIfCanceled(
        cancellation,
        statementNumber: completed + 1,
        byteOffset: parser.byteOffset,
        preview: () => parser.preview,
      );
      return SqlScriptResult(
        bytesRead: bytesRead,
        statementsCompleted: completed,
        elapsed: stopwatch.elapsed,
      );
    }

    try {
      final result = switch (transactionMode) {
        SqlScriptTransactionMode.atomic => await pool.withTransaction(consume),
        SqlScriptTransactionMode.preserve ||
        SqlScriptTransactionMode.none => await pool.withSession(consume),
      };
      emit(SqlScriptPhase.completed);
      return result;
    } on SqlScriptCanceledException {
      emit(SqlScriptPhase.canceled);
      rethrow;
    } finally {
      stopwatch.stop();
      await progress.close();
    }
  }
}

void _throwIfCanceled(
  _SqlScriptCancellation cancellation, {
  required int statementNumber,
  required int byteOffset,
  required String Function() preview,
}) {
  if (!cancellation.requested) return;
  throw SqlScriptCanceledException(
    statementNumber: statementNumber,
    byteOffset: byteOffset,
    statementPreview: preview(),
  );
}

bool _isTransactionControl(String sql) {
  var remaining = sql.trimLeft();
  while (remaining.isNotEmpty) {
    if (remaining.startsWith('--')) {
      final newline = remaining.indexOf('\n');
      remaining = newline < 0
          ? ''
          : remaining.substring(newline + 1).trimLeft();
      continue;
    }
    if (remaining.startsWith('/*')) {
      final end = remaining.indexOf('*/', 2);
      if (end < 0) return false;
      remaining = remaining.substring(end + 2).trimLeft();
      continue;
    }
    break;
  }
  return RegExp(
    r'^(BEGIN\b|START\s+TRANSACTION\b|COMMIT\b|END\b|ROLLBACK\b|SAVEPOINT\b|RELEASE\b|SET\s+TRANSACTION\b)',
    caseSensitive: false,
  ).hasMatch(remaining);
}

final class _ParsedSqlStatement {
  const _ParsedSqlStatement(this.sql, this.byteOffset);

  final String sql;
  final int byteOffset;
}

final class _SqlScriptParser {
  final StringBuffer _statement = StringBuffer();
  String _carry = '';
  var _byteOffset = 0;
  var _statementByteOffset = 0;
  var _inSingleQuote = false;
  var _singleQuoteEscapes = false;
  var _inDoubleQuote = false;
  var _inLineComment = false;
  var _blockCommentDepth = 0;
  String? _dollarQuote;
  String? _previous;
  String? _beforePrevious;
  var _closed = false;

  int get byteOffset => _byteOffset;

  String get preview {
    final value = _statement.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.length <= 240 ? value : '${value.substring(0, 240)}…';
  }

  List<_ParsedSqlStatement> add(String chunk) {
    if (_closed) throw StateError('SQL script parser is already closed.');
    return _parse('$_carry$chunk', isFinal: false);
  }

  List<_ParsedSqlStatement> close({required int statementNumber}) {
    if (_closed) return const <_ParsedSqlStatement>[];
    _closed = true;
    final parsed = _parse(_carry, isFinal: true);
    _carry = '';
    final openConstruct = switch ((
      _inSingleQuote,
      _inDoubleQuote,
      _blockCommentDepth,
      _dollarQuote,
    )) {
      (true, _, _, _) => 'single-quoted string',
      (_, true, _, _) => 'quoted identifier',
      (_, _, > 0, _) => 'block comment',
      (_, _, _, final delimiter?) => 'dollar-quoted body $delimiter',
      _ => null,
    };
    if (openConstruct != null) {
      throw SqlScriptException(
        message: 'Unterminated $openConstruct',
        statementNumber: statementNumber + parsed.length,
        byteOffset: _statementByteOffset,
        statementPreview: preview,
      );
    }
    final trailing = _statement.toString().trim();
    if (trailing.isNotEmpty) {
      parsed.add(_ParsedSqlStatement(trailing, _statementByteOffset));
    }
    _statement.clear();
    return parsed;
  }

  List<_ParsedSqlStatement> _parse(String input, {required bool isFinal}) {
    _carry = '';
    final result = <_ParsedSqlStatement>[];
    var index = 0;
    while (index < input.length) {
      if (_dollarQuote case final delimiter?) {
        final closing = input.indexOf(delimiter, index);
        if (closing >= 0) {
          final end = closing + delimiter.length;
          _write(input.substring(index, end));
          index = end;
          _dollarQuote = null;
          continue;
        }
        final safeEnd = isFinal
            ? input.length
            : _dollarQuoteSafeEnd(input, index, delimiter);
        if (safeEnd > index) {
          _write(input.substring(index, safeEnd));
        }
        index = safeEnd;
        if (index < input.length) {
          _carry = input.substring(index);
          break;
        }
        continue;
      }

      if (_inLineComment) {
        final newline = input.indexOf('\n', index);
        final end = newline < 0 ? input.length : newline + 1;
        _write(input.substring(index, end));
        index = end;
        if (newline >= 0) _inLineComment = false;
        continue;
      }

      if (_blockCommentDepth > 0) {
        final opening = input.indexOf('/*', index);
        final closing = input.indexOf('*/', index);
        final marker = _firstMatch(opening, closing);
        if (marker < 0) {
          var safeEnd = input.length;
          if (!isFinal && safeEnd > index) {
            final last = input.codeUnitAt(safeEnd - 1);
            if (last == _slash || last == _asterisk) safeEnd--;
          }
          if (safeEnd > index) _write(input.substring(index, safeEnd));
          index = safeEnd;
          if (index < input.length) {
            _carry = input.substring(index);
            break;
          }
          continue;
        }
        final end = marker + 2;
        _write(input.substring(index, end));
        index = end;
        if (marker == opening) {
          _blockCommentDepth++;
        } else {
          _blockCommentDepth--;
        }
        continue;
      }

      if (_inSingleQuote) {
        final quote = input.indexOf("'", index);
        final escape = _singleQuoteEscapes ? input.indexOf(r'\', index) : -1;
        final marker = _firstMatch(quote, escape);
        if (marker < 0) {
          _write(input.substring(index));
          index = input.length;
          continue;
        }
        if (marker + 1 >= input.length && !isFinal) {
          if (marker > index) _write(input.substring(index, marker));
          _carry = input.substring(marker);
          break;
        }
        if (marker == escape) {
          final escapedEnd = marker + 1 + _codeUnitWidth(input, marker + 1);
          _write(input.substring(index, escapedEnd));
          index = escapedEnd;
          continue;
        }
        if (marker + 1 < input.length &&
            input.codeUnitAt(marker + 1) == _singleQuote) {
          final end = marker + 2;
          _write(input.substring(index, end));
          index = end;
          continue;
        }
        final end = marker + 1;
        _write(input.substring(index, end));
        index = end;
        _inSingleQuote = false;
        _singleQuoteEscapes = false;
        continue;
      }

      if (_inDoubleQuote) {
        final quote = input.indexOf('"', index);
        if (quote < 0) {
          _write(input.substring(index));
          index = input.length;
          continue;
        }
        if (quote + 1 >= input.length && !isFinal) {
          if (quote > index) _write(input.substring(index, quote));
          _carry = input.substring(quote);
          break;
        }
        if (quote + 1 < input.length &&
            input.codeUnitAt(quote + 1) == _doubleQuote) {
          final end = quote + 2;
          _write(input.substring(index, end));
          index = end;
          continue;
        }
        final end = quote + 1;
        _write(input.substring(index, end));
        index = end;
        _inDoubleQuote = false;
        continue;
      }

      final ordinaryEnd = _ordinarySqlEnd(input, index);
      if (ordinaryEnd > index) {
        _write(input.substring(index, ordinaryEnd));
        index = ordinaryEnd;
        continue;
      }

      final width = _codeUnitWidth(input, index);
      final char = input.substring(index, index + width);
      final next = index + width < input.length ? input[index + width] : null;

      if ((char == '-' || char == '/') && next == null && !isFinal) {
        _carry = char;
        break;
      }
      if (char == '-' && next == '-') {
        _write('--');
        index += 2;
        _inLineComment = true;
        continue;
      }
      if (char == '/' && next == '*') {
        _write('/*');
        index += 2;
        _blockCommentDepth = 1;
        continue;
      }
      if (char == "'") {
        _singleQuoteEscapes =
            (_previous == 'E' || _previous == 'e') &&
            (_beforePrevious == null || !_isIdentifierPart(_beforePrevious!));
        _inSingleQuote = true;
        _write(char);
        index += width;
        continue;
      }
      if (char == '"') {
        _inDoubleQuote = true;
        _write(char);
        index += width;
        continue;
      }
      if (char == r'$') {
        final delimiter = _readDollarDelimiter(input, index, isFinal: isFinal);
        if (delimiter == _incompleteDollarDelimiter) {
          _carry = input.substring(index);
          break;
        }
        if (delimiter != null) {
          _dollarQuote = delimiter;
          _write(delimiter);
          index += delimiter.length;
          continue;
        }
      }
      if (char == ';') {
        final sql = _statement.toString().trim();
        _byteOffset++;
        index++;
        if (sql.isNotEmpty) {
          result.add(_ParsedSqlStatement(sql, _statementByteOffset));
        }
        _statement.clear();
        _statementByteOffset = _byteOffset;
        _previous = null;
        _beforePrevious = null;
        continue;
      }
      _write(char);
      index += width;
    }
    return result;
  }

  void _write(String value) {
    if (value.isEmpty) return;
    _statement.write(value);
    _byteOffset += _utf8Length(value);
    final lastStart = _previousCodePointStart(value, value.length);
    if (lastStart > 0) {
      final beforeLastStart = _previousCodePointStart(value, lastStart);
      _beforePrevious = value.substring(beforeLastStart, lastStart);
    } else {
      _beforePrevious = _previous;
    }
    _previous = value.substring(lastStart);
  }
}

const _singleQuote = 0x27;
const _doubleQuote = 0x22;
const _dollar = 0x24;
const _semicolon = 0x3B;
const _hyphen = 0x2D;
const _slash = 0x2F;
const _asterisk = 0x2A;

int _ordinarySqlEnd(String input, int start) {
  var index = start;
  while (index < input.length) {
    final code = input.codeUnitAt(index);
    if (code == _singleQuote ||
        code == _doubleQuote ||
        code == _dollar ||
        code == _semicolon ||
        code == _hyphen ||
        code == _slash) {
      break;
    }
    index += _codeUnitWidth(input, index);
  }
  return index;
}

int _firstMatch(int left, int right) {
  if (left < 0) return right;
  if (right < 0) return left;
  return left < right ? left : right;
}

int _dollarQuoteSafeEnd(String input, int start, String delimiter) {
  final firstCandidate = (input.length - delimiter.length + 1).clamp(
    start,
    input.length,
  );
  for (var candidate = firstCandidate; candidate < input.length; candidate++) {
    final suffixLength = input.length - candidate;
    var matches = true;
    for (var offset = 0; offset < suffixLength; offset++) {
      if (input.codeUnitAt(candidate + offset) !=
          delimiter.codeUnitAt(offset)) {
        matches = false;
        break;
      }
    }
    if (matches) return candidate;
  }
  return input.length;
}

int _previousCodePointStart(String value, int end) {
  var start = end - 1;
  final code = value.codeUnitAt(start);
  if (code >= 0xDC00 &&
      code <= 0xDFFF &&
      start > 0 &&
      value.codeUnitAt(start - 1) >= 0xD800 &&
      value.codeUnitAt(start - 1) <= 0xDBFF) {
    start--;
  }
  return start;
}

const _incompleteDollarDelimiter = '<incomplete-dollar-delimiter>';

String? _readDollarDelimiter(String input, int start, {required bool isFinal}) {
  var index = start + 1;
  if (index >= input.length) return isFinal ? null : _incompleteDollarDelimiter;
  if (input[index] == r'$') return r'$$';
  if (!_isIdentifierStart(input[index])) return null;
  index++;
  while (index < input.length && _isIdentifierPart(input[index])) {
    index++;
  }
  if (index >= input.length) return isFinal ? null : _incompleteDollarDelimiter;
  if (input[index] != r'$') return null;
  return input.substring(start, index + 1);
}

bool _isIdentifierStart(String value) {
  final code = value.codeUnitAt(0);
  return value == '_' ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}

bool _isIdentifierPart(String value) {
  final code = value.codeUnitAt(0);
  return _isIdentifierStart(value) || (code >= 48 && code <= 57);
}

int _codeUnitWidth(String value, int index) {
  final code = value.codeUnitAt(index);
  if (code >= 0xD800 &&
      code <= 0xDBFF &&
      index + 1 < value.length &&
      value.codeUnitAt(index + 1) >= 0xDC00 &&
      value.codeUnitAt(index + 1) <= 0xDFFF) {
    return 2;
  }
  return 1;
}

int _utf8Length(String value) {
  var result = 0;
  for (var index = 0; index < value.length;) {
    final code = value.codeUnitAt(index);
    if (code <= 0x7F) {
      result++;
      index++;
    } else if (code <= 0x7FF) {
      result += 2;
      index++;
    } else if (code >= 0xD800 &&
        code <= 0xDBFF &&
        index + 1 < value.length &&
        value.codeUnitAt(index + 1) >= 0xDC00 &&
        value.codeUnitAt(index + 1) <= 0xDFFF) {
      result += 4;
      index += 2;
    } else {
      result += 3;
      index++;
    }
  }
  return result;
}
