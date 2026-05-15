/// Provider-agnostic prompt message role.
enum RigPromptRole {
  system('system'),
  user('user'),
  assistant('assistant');

  const RigPromptRole(this.jsonName);

  /// Role value expected by Rig's message JSON shape.
  final String jsonName;
}

/// Provider-agnostic prompt envelope.
final class RigPrompt {
  /// Creates a prompt from ordered role-tagged messages.
  const RigPrompt(this.messages);

  /// Ordered prompt messages. The final message is sent as the active prompt;
  /// previous messages are sent as chat history when the provider supports it.
  final List<RigPromptMessage> messages;

  /// Encodes this prompt in Dart Edge's provider-agnostic prompt shape.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }
}

/// Role-tagged prompt message for models that accept rich content.
sealed class RigPromptMessage {
  const RigPromptMessage._(this.role);

  /// Creates a system instruction message.
  const factory RigPromptMessage.system(String content) = RigSystemMessage;

  /// Creates a user message from one or more content blocks.
  const factory RigPromptMessage.user(List<RigUserContent> content) =
      RigUserMessage;

  /// Creates an assistant message from one or more content blocks.
  const factory RigPromptMessage.assistant(
    List<RigAssistantContent> content, {
    String? id,
  }) = RigAssistantMessage;

  /// Message role.
  final RigPromptRole role;

  /// Encodes this message in Rig's provider-agnostic message shape.
  Map<String, Object?> toJson();
}

/// System instruction prompt message.
final class RigSystemMessage extends RigPromptMessage {
  const RigSystemMessage(this.content) : super._(RigPromptRole.system);

  /// System instruction text.
  final String content;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.jsonName,
    'content': content,
  };
}

/// User prompt message.
final class RigUserMessage extends RigPromptMessage {
  const RigUserMessage(this.content) : super._(RigPromptRole.user);

  /// User content items.
  final List<RigUserContent> content;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.jsonName,
    'content': content.map((item) => item.toJson()).toList(),
  };
}

/// Assistant prompt message.
final class RigAssistantMessage extends RigPromptMessage {
  const RigAssistantMessage(this.content, {this.id})
    : super._(RigPromptRole.assistant);

  /// Provider-assigned assistant message ID, when available.
  final String? id;

  /// Assistant content items.
  final List<RigAssistantContent> content;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.jsonName,
    'id': id,
    'content': content.map((item) => item.toJson()).toList(),
  };
}

/// A source for an attachment or media item.
final class RigContentSource {
  const RigContentSource._(this.type, this.value);

  /// URL-backed content.
  const RigContentSource.url(String value) : this._('url', value);

  /// Base64-backed content.
  const RigContentSource.base64(String value) : this._('base64', value);

  /// Provider-side uploaded file identifier.
  const RigContentSource.fileId(String value) : this._('fileId', value);

  /// String-backed content, mostly useful for text documents.
  const RigContentSource.string(String value) : this._('string', value);

  /// Rig source type.
  final String type;

  /// Source value.
  final String value;

  /// Encodes this source in Rig's `DocumentSourceKind` shape.
  Map<String, Object?> toJson() {
    return <String, Object?>{'type': type, 'value': value};
  }
}

/// A user content item.
sealed class RigUserContent {
  const RigUserContent();

  /// Plain text content.
  const factory RigUserContent.text(String text) = RigTextContent;

  /// Image content.
  const factory RigUserContent.image({
    required RigContentSource source,
    String? mediaType,
    RigImageDetail? detail,
  }) = RigImageContent;

  /// Document content.
  const factory RigUserContent.document({
    required RigContentSource source,
    String? mediaType,
  }) = RigDocumentContent;

  /// Audio content.
  const factory RigUserContent.audio({
    required RigContentSource source,
    String? mediaType,
  }) = RigAudioContent;

  /// Video content.
  const factory RigUserContent.video({
    required RigContentSource source,
    String? mediaType,
  }) = RigVideoContent;

  /// Encodes this content item in Rig's `UserContent` shape.
  Map<String, Object?> toJson();
}

/// An assistant content item.
sealed class RigAssistantContent {
  const RigAssistantContent();

  /// Plain text content.
  const factory RigAssistantContent.text(String text) = RigAssistantTextContent;

  /// Encodes this content item in Rig's `AssistantContent` shape.
  Map<String, Object?> toJson();
}

/// Image detail preference.
enum RigImageDetail {
  low('low'),
  high('high'),
  auto('auto');

  const RigImageDetail(this.jsonName);

  /// Provider JSON value.
  final String jsonName;
}

/// Plain text user content.
final class RigTextContent extends RigUserContent {
  /// Creates text content.
  const RigTextContent(this.text);

  /// Text value.
  final String text;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'text',
    'text': text,
  };
}

/// Plain text assistant content.
final class RigAssistantTextContent extends RigAssistantContent {
  /// Creates text content.
  const RigAssistantTextContent(this.text);

  /// Text value.
  final String text;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'text',
    'text': text,
  };
}

/// Image user content.
final class RigImageContent extends RigUserContent {
  /// Creates image content.
  const RigImageContent({required this.source, this.mediaType, this.detail});

  /// Image source.
  final RigContentSource source;

  /// Rig image media type, for example `png`, `jpeg`, or `webp`.
  final String? mediaType;

  /// Provider-specific image detail preference.
  final RigImageDetail? detail;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'image',
    'data': source.toJson(),
    'media_type': ?mediaType,
    'detail': ?detail?.jsonName,
  };
}

/// Document user content.
final class RigDocumentContent extends RigUserContent {
  /// Creates document content.
  const RigDocumentContent({required this.source, this.mediaType});

  /// Document source.
  final RigContentSource source;

  /// Rig document media type, for example `pdf`, `txt`, `markdown`, or `csv`.
  final String? mediaType;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'document',
    'data': source.toJson(),
    'media_type': ?mediaType,
  };
}

/// Audio user content.
final class RigAudioContent extends RigUserContent {
  /// Creates audio content.
  const RigAudioContent({required this.source, this.mediaType});

  /// Audio source.
  final RigContentSource source;

  /// Rig audio media type, for example `mp3`, `wav`, or `m4a`.
  final String? mediaType;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'audio',
    'data': source.toJson(),
    'media_type': ?mediaType,
  };
}

/// Video user content.
final class RigVideoContent extends RigUserContent {
  /// Creates video content.
  const RigVideoContent({required this.source, this.mediaType});

  /// Video source.
  final RigContentSource source;

  /// Rig video media type, for example `mp4`, `mov`, or `webm`.
  final String? mediaType;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'video',
    'data': source.toJson(),
    'media_type': ?mediaType,
  };
}
