/// Локальний слот OpenAI-ключа (дзеркало бекенд `AiApiKey`).
///
/// Скопіюй цей файл як `ai_api_key.dart` і встав свій ключ.
const String kAiApiKey = String.fromEnvironment(
  'OPENAI_API_KEY',
  defaultValue: '',
);
