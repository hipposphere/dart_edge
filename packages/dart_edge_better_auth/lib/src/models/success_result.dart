final class BetterAuthSuccessResult {
  const BetterAuthSuccessResult({required this.success});

  final bool success;

  Map<String, Object?> toJson() => {'success': success};
}
