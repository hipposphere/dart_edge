/// Controls how an incremental audio session retains bytes until it is sealed.
///
/// Spooling is temporary buffering only. It does not configure permanent
/// recording storage or worker-pool scheduling.
sealed class AudioSpoolPolicy {
  const AudioSpoolPolicy();

  /// Retains all audio in bounded native memory.
  const factory AudioSpoolPolicy.memory({required int maxBytes}) =
      MemoryAudioSpoolPolicy;

  /// Selects an enabled spool backend while enforcing a single hard ceiling.
  ///
  /// Currently only native memory is enabled, so this behaves like [memory]
  /// with [maxBytes] as its ceiling. [preferredMemoryBytes] reserves the point
  /// at which a future implementation may select another explicitly enabled
  /// backend. It never implicitly enables disk writes.
  const factory AudioSpoolPolicy.adaptive({
    required int preferredMemoryBytes,
    required int maxBytes,
  }) = AdaptiveAudioSpoolPolicy;

  /// Maximum number of audio bytes accepted by one session.
  int get maxBytes;
}

/// A spool policy that retains all audio in bounded native memory.
final class MemoryAudioSpoolPolicy extends AudioSpoolPolicy {
  const MemoryAudioSpoolPolicy({required this.maxBytes});

  @override
  final int maxBytes;
}

/// A spool policy that may choose among explicitly enabled backends.
///
/// Native memory is the only enabled backend today. Additional tiers can be
/// introduced later without changing the session API or silently enabling
/// disk access.
final class AdaptiveAudioSpoolPolicy extends AudioSpoolPolicy {
  const AdaptiveAudioSpoolPolicy({
    required this.preferredMemoryBytes,
    required this.maxBytes,
  });

  /// Preferred upper bound for memory before considering another enabled tier.
  final int preferredMemoryBytes;

  @override
  final int maxBytes;
}
