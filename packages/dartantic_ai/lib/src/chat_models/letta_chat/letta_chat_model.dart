import 'dart:async';
import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

import '../../retry_http_client.dart';
import 'letta_chat_options.dart';

export 'letta_chat_options.dart';

/// Wrapper around the Letta Messages API.
class LettaChatModel extends ChatModel<LettaChatOptions> {
  /// Creates a [LettaChatModel] instance.
  LettaChatModel({
    required super.name,
    required this.agentId,
    required String apiKey,
    Uri? baseUrl,
    Map<String, String>? headers,
    http.Client? client,
    super.tools,
    super.temperature,
    LettaChatOptions? defaultOptions,
  }) : _apiKey = apiKey,
       _baseUrl = baseUrl ?? _defaultBaseUrl,
       _headers = headers ?? const {},
       _client = client != null
           ? RetryHttpClient(inner: client)
           : RetryHttpClient(inner: http.Client()),
       super(defaultOptions: defaultOptions ?? const LettaChatOptions()) {
    _logger.info('Creating Letta model for agent: $agentId');
  }

  static final Logger _logger = Logger('dartantic.chat.models.letta');
  static final Uri _defaultBaseUrl = Uri.parse('https://api.letta.ai');

  final String agentId;
  final String _apiKey;
  final Uri _baseUrl;
  final Map<String, String> _headers;
  final http.Client _client;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    LettaChatOptions? options,
    JsonSchema? outputSchema,
  }) async* {
    if (outputSchema != null) {
      throw UnsupportedError('Letta chat model does not support outputSchema');
    }

    final chatResult = await _sendChat(messages, options: options);
    yield* Stream.fromIterable([chatResult]);
  }

  @override
  void dispose() => _client.close();

  Future<ChatResult<ChatMessage>> _sendChat(
    List<ChatMessage> messages, {
    LettaChatOptions? options,
  }) async {
    final resolvedAgentId =
        options?.agentId ?? defaultOptions.agentId ?? agentId;

    if (resolvedAgentId.isEmpty) {
      throw ArgumentError('agentId is required for the Letta chat model');
    }

    final requestBody = jsonEncode({
      'messages': messages.map(_mapMessage).toList(),
      'stream': false,
    });

    final url = _baseUrl.resolve('/v1/agents/$resolvedAgentId/messages');
    _logger.info('Sending Letta request to $url');

    final responseFuture = _client.post(
      url,
      headers: _buildHeaders(options),
      body: requestBody,
    );

    final timeout = options?.requestTimeout ?? defaultOptions.requestTimeout;
    final response = timeout != null
        ? await responseFuture.timeout(timeout)
        : await responseFuture;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Letta request failed with status ${response.statusCode}: '
        '${response.body}',
        url,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected Letta response format', decoded);
    }

    final parsedMessages = _extractMessages(decoded);
    final modelMessages = parsedMessages
        .where((message) => message.role == ChatMessageRole.model)
        .toList();

    final output = modelMessages.isNotEmpty
        ? modelMessages.last
        : parsedMessages.isNotEmpty
        ? parsedMessages.last
        : const ChatMessage(role: ChatMessageRole.model, parts: []);

    return ChatResult<ChatMessage>(
      id: decoded['id']?.toString(),
      output: output,
      messages: modelMessages.isNotEmpty ? modelMessages : [output],
      metadata: {
        if (decoded['created_at'] != null) 'created_at': decoded['created_at'],
      },
    );
  }

  Map<String, String> _buildHeaders(LettaChatOptions? options) {
    final barePassword = options?.barePassword ?? defaultOptions.barePassword;
    final headers = <String, String>{
      'Authorization': 'Bearer $_apiKey',
      'X-BARE-PASSWORD': barePassword ?? '',
      'Content-Type': 'application/json',
    };

    headers.addAll(_headers);
    if (options?.requestHeaders != null) {
      headers.addAll(options!.requestHeaders!);
    }

    return headers;
  }

  Map<String, dynamic> _mapMessage(ChatMessage message) {
    return {
      'role': _toLettaRole(message.role),
      'content': message.text,
    };
  }

  List<ChatMessage> _extractMessages(Map<String, dynamic> payload) {
    final dynamic messagesPayload =
        payload['messages'] ?? payload['message'] ?? payload['data'];
    final messageList = <dynamic>[];

    if (messagesPayload is List) {
      messageList.addAll(messagesPayload);
    } else if (messagesPayload is Map<String, dynamic>) {
      messageList.add(messagesPayload);
    }

    return messageList
        .map(_chatMessageFromJson)
        .whereType<ChatMessage>()
        .toList();
  }

  ChatMessage? _chatMessageFromJson(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final role = payload['role']?.toString() ?? 'assistant';
    final content = _normalizeContent(payload['content']);

    return ChatMessage(
      role: _fromLettaRole(role),
      parts: [TextPart(content)],
      metadata: {
        if (payload['id'] != null) 'id': payload['id'],
      },
    );
  }

  String _normalizeContent(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      return content
          .map((item) {
            if (item is String) return item;
            if (item is Map<String, dynamic>) {
              final text = item['text'] ?? item['content'];
              if (text is String) return text;
            }
            return '';
          })
          .where((text) => text.isNotEmpty)
          .join();
    }
    if (content is Map<String, dynamic>) {
      final text = content['text'] ?? content['content'];
      if (text is String) return text;
    }
    return '';
  }

  String _toLettaRole(ChatMessageRole role) => switch (role) {
    ChatMessageRole.system => 'system',
    ChatMessageRole.user => 'user',
    ChatMessageRole.model => 'assistant',
  };

  ChatMessageRole _fromLettaRole(String role) => switch (role) {
    'system' => ChatMessageRole.system,
    'user' => ChatMessageRole.user,
    'assistant' => ChatMessageRole.model,
    _ => ChatMessageRole.model,
  };
}
