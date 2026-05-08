/// Configuration for creating a native-backed S3 client.
final class S3ClientConfig {
  static const defaultEndpointRegion = 'us-east-1';

  const S3ClientConfig({
    this.region,
    this.endpoint,
    this.accessKeyId,
    this.secretAccessKey,
    this.sessionToken,
    this.forcePathStyle = false,
    this.allowHttp = false,
  });

  final String? region;
  final String? endpoint;
  final String? accessKeyId;
  final String? secretAccessKey;
  final String? sessionToken;
  final bool forcePathStyle;
  final bool allowHttp;

  /// Region passed to the native S3 client after applying client defaults.
  ///
  /// S3-compatible endpoints still need a SigV4 signing region. When an
  /// explicit endpoint is configured without a region, default to the common
  /// local/S3-compatible region value.
  String? get resolvedRegion {
    if (region != null) {
      return region;
    }
    if (endpoint != null && endpoint!.isNotEmpty) {
      return defaultEndpointRegion;
    }
    return null;
  }

  /// Returns a config object with client-level defaults applied.
  S3ClientConfig resolveDefaults() {
    final effectiveRegion = resolvedRegion;
    if (effectiveRegion == region) {
      return this;
    }
    return S3ClientConfig(
      region: effectiveRegion,
      endpoint: endpoint,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      sessionToken: sessionToken,
      forcePathStyle: forcePathStyle,
      allowHttp: allowHttp,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (resolvedRegion != null) 'region': resolvedRegion,
      'endpoint': endpoint,
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'sessionToken': sessionToken,
      'forcePathStyle': forcePathStyle,
      'allowHttp': allowHttp,
    };
  }
}
