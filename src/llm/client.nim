## LLM client facade -- vendor-neutral entry point.

import std/json
import std/httpclient
import std/net

import basis/code/throw

import llm/types
import llm/provider/openai
import llm/provider/anthropic
import llm/provider/ollama

standard_pragmas()

raises_error(llm_err, [IOError, OSError, TimeoutError, ValueError, HttpRequestError, JsonParsingError, LLMError],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  ProviderKind* = enum
    pkOpenAI
    pkAnthropic
    pkOllama

  LLMClient* = object
    case kind*: ProviderKind
    of pkOpenAI:
      openai*: OpenAIProvider
    of pkAnthropic:
      anthropic_provider*: AnthropicProvider
    of pkOllama:
      ollama*: OllamaProvider

# -----------------------------------------------------------------------
# Constructors
# -----------------------------------------------------------------------

proc new_openai_client*(api_key: ApiKey;
                        model: ModelName = ModelName("gpt-4o");
                        base_url: BaseUrl = BaseUrl("https://api.openai.com/v1")): LLMClient {.ok.} =
  LLMClient(kind: pkOpenAI,
            openai: new_openai_provider(api_key, model, base_url))

proc new_anthropic_client*(api_key: ApiKey;
                           model: ModelName = ModelName("claude-sonnet-4-6");
                           base_url: BaseUrl = BaseUrl("https://api.anthropic.com/v1")): LLMClient {.ok.} =
  LLMClient(kind: pkAnthropic,
            anthropic_provider: new_anthropic_provider(api_key, model, base_url))

proc new_ollama_client*(model: ModelName = ModelName("llama3.2:1b");
                        base_url: BaseUrl = BaseUrl("http://localhost:11434/v1")): LLMClient {.ok.} =
  LLMClient(kind: pkOllama,
            ollama: new_ollama_provider(model, base_url))

proc new_custom_client*(base_url: BaseUrl; api_key: ApiKey; model: ModelName): LLMClient {.ok.} =
  ## Create a client for any OpenAI-compatible endpoint.
  LLMClient(kind: pkOpenAI,
            openai: new_openai_provider(api_key, model, base_url))

# -----------------------------------------------------------------------
# Chat
# -----------------------------------------------------------------------

proc chat*(client: LLMClient; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request to the configured provider.
  case client.kind
  of pkOpenAI:
    client.openai.chat(request)
  of pkAnthropic:
    client.anthropic_provider.chat(request)
  of pkOllama:
    client.ollama.chat(request)

proc chat*(client: LLMClient; messages: seq[Message];
           model: string = "";
           temperature: float = 0.7;
           max_tokens: int = 1024): ChatResponse {.llm_err.} =
  ## Convenience: chat with a list of messages.
  client.chat(chat_request(model, messages, temperature, max_tokens))

# -----------------------------------------------------------------------
# Complete (single-turn convenience)
# -----------------------------------------------------------------------

proc complete*(client: LLMClient; prompt: string;
               model: string = "";
               temperature: float = 0.7;
               max_tokens: int = 1024): string {.llm_err.} =
  ## Single-turn completion: send a user prompt, return the response content.
  let resp = client.chat(@[user_msg(prompt)], model, temperature, max_tokens)
  resp.content
