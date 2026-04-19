/// Wrapper that distinguishes an absent value from an explicit `null`.
///
/// This is mainly useful for update objects where omitting a field should mean
/// "leave it unchanged" while `SqlValue(null)` should mean "set it to NULL".
final class SqlValue<T> {
  const SqlValue.absent() : value = null, isPresent = false;

  const SqlValue(this.value) : isPresent = true;

  /// Wrapped value.
  final T? value;

  /// Whether a value was provided at all.
  final bool isPresent;

  @override
  String toString() => isPresent ? 'SqlValue($value)' : 'SqlValue.absent()';
}
