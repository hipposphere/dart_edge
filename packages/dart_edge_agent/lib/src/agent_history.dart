/// Provider-neutral role for an agent history entry.
enum AgentHistoryRole {
  /// User-authored request or instruction.
  user('user'),

  /// Assistant-authored response.
  assistant('assistant'),

  /// Tool call or tool result context.
  tool('tool'),

  /// System or harness-authored context.
  system('system');

  const AgentHistoryRole(this.label);

  /// Stable label used in rendered context and JSON.
  final String label;
}

/// Provider-neutral history entry that can be replayed across models.
final class AgentHistoryEntry {
  /// Creates a history entry.
  const AgentHistoryEntry({
    required this.role,
    required this.content,
    required this.createdAt,
    this.name,
    this.metadata = const <String, Object?>{},
  });

  /// Entry role.
  final AgentHistoryRole role;

  /// Optional tool/name/source label.
  final String? name;

  /// Textual content that is safe to replay across providers.
  final String content;

  /// Entry creation timestamp.
  final DateTime createdAt;

  /// Provider-neutral metadata.
  final Map<String, Object?> metadata;

  /// Encodes this entry as JSON-compatible data.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'role': role.label,
      'name': ?name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Mutable provider-neutral agent history.
final class AgentHistory {
  /// Creates history with optional initial [entries].
  AgentHistory([Iterable<AgentHistoryEntry> entries = const []])
    : _entries = List<AgentHistoryEntry>.of(entries);

  final List<AgentHistoryEntry> _entries;

  /// Entries in insertion order.
  List<AgentHistoryEntry> get entries => List.unmodifiable(_entries);

  /// Whether this history has no entries.
  bool get isEmpty => _entries.isEmpty;

  /// Adds [entry].
  void add(AgentHistoryEntry entry) {
    if (entry.content.trim().isEmpty) {
      return;
    }
    _entries.add(entry);
  }

  /// Adds a user entry.
  void addUser(String content, {Map<String, Object?> metadata = const {}}) {
    add(
      AgentHistoryEntry(
        role: AgentHistoryRole.user,
        content: content,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  /// Adds an assistant entry.
  void addAssistant(
    String content, {
    Map<String, Object?> metadata = const {},
  }) {
    add(
      AgentHistoryEntry(
        role: AgentHistoryRole.assistant,
        content: content,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  /// Adds a tool entry.
  void addTool(
    String content, {
    String? name,
    Map<String, Object?> metadata = const {},
  }) {
    add(
      AgentHistoryEntry(
        role: AgentHistoryRole.tool,
        name: name,
        content: content,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  /// Returns a detached copy suitable for another session.
  AgentHistory snapshot() => AgentHistory(_entries);

  /// Renders history as portable text context for another provider.
  String render({int? limit}) {
    final selected = switch (limit) {
      final int value when value > 0 && value < _entries.length =>
        _entries.skip(_entries.length - value),
      _ => _entries,
    };
    return selected.map(_renderEntry).join('\n\n');
  }

  /// Encodes history as JSON-compatible data.
  List<Map<String, Object?>> toJson() {
    return [for (final entry in _entries) entry.toJson()];
  }

  static String _renderEntry(AgentHistoryEntry entry) {
    final name = entry.name == null ? '' : ' ${entry.name}';
    return '[${entry.role.label}$name]\n${entry.content}';
  }
}
