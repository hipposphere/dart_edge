final class BetterAuthPermissionResult {
  const BetterAuthPermissionResult({required this.success, this.error});

  final bool success;
  final String? error;

  Map<String, Object?> toJson() => {'error': error, 'success': success};
}
