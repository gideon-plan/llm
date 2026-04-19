{.experimental: "strictFuncs".}
## LLM client facade -- vendor-neutral entry point.

import basis/code/throw
import basis/code/choice

import llm/types
import llm/provider/openai
import llm/provider/anthropic
import llm/provider/ollama

standard_pragmas()

raises_error(llm_err, [IOError, OSError, ValueError, LLMError, Exception],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

#=======================================================================================================================
#== TYPES ==============================================================================================================
#=======================================================================================================================

type
  ProviderKind* {.pure.} = enum ## Supported LLM provider backends.
    OpenAI
    Anthropic
    Ollama

  LLMClient* = object ## Vendor-neutral LLM client.
    case kind*: ProviderKind
    of ProviderKind.OpenAI:
      openai*: OpenAIProvider
    of ProviderKind.Anthropic:
      anthropic_provider*: AnthropicProvider
    of ProviderKind.Ollama:
      ollama*: OllamaProvider

#=======================================================================================================================
#== CONSTRUCTORS =======================================================================================================
#=======================================================================================================================

## Create an OpenAI client.
proc new_openai_client*(api_key: ApiKey;
                        model: ModelName = ModelName("gpt-4o");
                        base_url: BaseUrl = BaseUrl("https://api.openai.com/v1")): LLMClient {.ok.} =
  LLMClient(kind: ProviderKind.OpenAI,
            openai: new_openai_provider(api_key, model, base_url))

## Create an Anthropic client.
proc new_anthropic_client*(api_key: ApiKey;
                           model: ModelName = ModelName("claude-sonnet-4-6");
                           base_url: BaseUrl = BaseUrl("https://api.anthropic.com/v1")): LLMClient {.ok.} =
  LLMClient(kind: ProviderKind.Anthropic,
            anthropic_provider: new_anthropic_provider(api_key, model, base_url))

## Create an Ollama client.
proc new_ollama_client*(model: ModelName = ModelName("llama3.2:1b");
                        base_url: BaseUrl = BaseUrl("http://localhost:11434/v1")): LLMClient {.ok.} =
  LLMClient(kind: ProviderKind.Ollama,
            ollama: new_ollama_provider(model, base_url))

proc new_custom_client*(base_url: BaseUrl; api_key: ApiKey; model: ModelName): LLMClient {.ok.} =
  ## Create a client for any OpenAI-compatible endpoint.
  LLMClient(kind: ProviderKind.OpenAI,
            openai: new_openai_provider(api_key, model, base_url))

#=======================================================================================================================
#== CHAT ===============================================================================================================
#=======================================================================================================================

proc chat*(client: LLMClient; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request to the configured provider.
  case client.kind
  of ProviderKind.OpenAI:
    client.openai.chat(request)
  of ProviderKind.Anthropic:
    client.anthropic_provider.chat(request)
  of ProviderKind.Ollama:
    client.ollama.chat(request)

proc chat*(client: LLMClient; messages: seq[Message];
           model: string = "";
           temperature: float = 0.7;
           max_tokens: int = 1024): ChatResponse {.llm_err.} =
  ## Convenience: chat with a list of messages.
  client.chat(chat_request(model, messages, temperature, max_tokens))

#=======================================================================================================================
#== COMPLETE (SINGLE-TURN CONVENIENCE) =================================================================================
#=======================================================================================================================

proc complete*(client: LLMClient; prompt: string;
               model: string = "";
               temperature: float = 0.7;
               max_tokens: int = 1024): string {.llm_err.} =
  ## Single-turn completion: send a user prompt, return the response content.
  let resp = client.chat(@[user_msg(prompt)], model, temperature, max_tokens)
  resp.content

#=======================================================================================================================
#== MAYBE OVERLOADS (NON-RAISING) ======================================================================================
#=======================================================================================================================

proc try_chat*(client: LLMClient; request: ChatRequest): Choice[ChatResponse] {.llm_err.} =
  ## Chat returning Maybe instead of raising.
  try:
    good(client.chat(request))
  except LLMError as e:
    bad[ChatResponse]("llm", e.msg)

proc try_complete*(client: LLMClient; prompt: string;
                   model: string = "";
                   temperature: float = 0.7;
                   max_tokens: int = 1024): Choice[string] {.llm_err.} =
  ## Single-turn completion returning Maybe instead of raising.
  try:
    good(client.complete(prompt, model, temperature, max_tokens))
  except LLMError as e:
    bad[string]("llm", e.msg)
