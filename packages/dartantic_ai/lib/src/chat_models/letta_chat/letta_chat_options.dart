import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';

/// Generation options to pass into the Letta Chat Model.
@immutable
class LettaChatOptions extends ChatModelOptions {
  /// Creates a new Letta chat options instance.
  const LettaChatOptions({
    this.agentId,
    this.barePassword,
    this.requestHeaders,
    this.requestTimeout,
  });

  /// Optional agent ID override per request.
  final String? agentId;

  /// Optional bare password for Letta authentication.
  final String? barePassword;

  /// Additional headers for the Letta request.
  final Map<String, String>? requestHeaders;

  /// Timeout for the Letta request.
  final Duration? requestTimeout;
}
