import 'openai_compat_ai_service.dart';

/// Groq is just an OpenAI-compatible endpoint with known defaults, so the
/// whole implementation lives in [OpenAiCompatAiService].
class GroqAiService extends OpenAiCompatAiService {
  GroqAiService({
    required super.apiKey,
    super.client,
    super.training,
    String? textModel,
    String? visionModel,
  }) : super(
          baseUrl: 'https://api.groq.com/openai/v1',
          textModel: textModel ?? 'llama-3.3-70b-versatile',
          visionModel:
              visionModel ?? 'meta-llama/llama-4-scout-17b-16e-instruct',
        );
}
