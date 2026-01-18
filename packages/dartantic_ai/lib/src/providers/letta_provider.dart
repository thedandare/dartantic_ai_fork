import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import '../chat_models/letta_chat/letta_chat_model.dart';
import '../chat_models/letta_chat/letta_chat_options.dart';

/// Provider for Letta agents.
class LettaProvider
    extends
        Provider<
          LettaChatOptions,
          EmbeddingsModelOptions,
          MediaGenerationModelOptions
        > {
  /// Creates a new Letta provider instance.
  LettaProvider({
    required this.agentId,
    required String apiKey,
    Uri? baseUrl,
    Map<String, String>? headers,
  }) : super(
         apiKey: apiKey,
         name: 'letta',
         displayName: 'Letta',
         defaultModelNames: const {ModelKind.chat: 'letta-agent'},
         baseUrl: baseUrl ?? defaultBaseUrl,
         headers: headers ?? const {},
       );

  /// The Letta agent identifier.
  final String agentId;

  static final Logger _logger = Logger('dartantic.chat.providers.letta');

  /// The default base URL for the Letta API.
  static final defaultBaseUrl = Uri.parse('https://api.letta.ai');

  @override
  ChatModel<LettaChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    LettaChatOptions? options,
  }) {
    if (enableThinking) {
      throw UnsupportedError(
        'Extended thinking is not supported by the $displayName provider.',
      );
    }

    if (apiKey == null || apiKey!.isEmpty) {
      throw ArgumentError('apiKey is required for the $displayName provider');
    }

    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    _logger.info(
      'Creating Letta model: $modelName for agent: $agentId',
    );

    return LettaChatModel(
      name: modelName,
      agentId: agentId,
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
      tools: tools,
      temperature: temperature,
      defaultOptions: LettaChatOptions(
        agentId: options?.agentId ?? agentId,
        barePassword: options?.barePassword,
        requestHeaders: options?.requestHeaders,
        requestTimeout: options?.requestTimeout,
        responseFormat: options?.responseFormat,
      ),
    );
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) {
    throw UnsupportedError('$displayName does not support embeddings.');
  }

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
  }) {
    throw UnsupportedError('$displayName does not support media generation.');
  }

  @override
  Stream<ModelInfo> listModels() async* {
    yield ModelInfo(
      name: defaultModelNames[ModelKind.chat]!,
      providerName: name,
      kinds: const {ModelKind.chat},
      displayName: displayName,
      description: 'Letta agent model for $agentId',
      extra: {'agentId': agentId},
    );
  }
}
