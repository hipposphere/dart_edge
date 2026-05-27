final class BetterAuthApiException implements Exception {
  const BetterAuthApiException({
    required this.status,
    required this.code,
    required this.message,
  });

  final int status;
  final String code;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'message': message};

  @override
  String toString() => 'BetterAuthApiException($status, $code, $message)';
}
