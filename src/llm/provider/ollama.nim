## Ollama provider -- thin wrapper around OpenAI-compatible provider.

import std/[json, httpclient, net]

import basis/code/throw

import llm/types
import llm/provider/openai

standard_pragmas()

raises_error(llm_err, [IOError, OSError, TimeoutError, ValueError, HttpRequestError, JsonParsingError, Exception],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

#=======================================================================================================================
#== TYPES ==============================================================================================================
#=======================================================================================================================

type
  OllamaProvider* = object ## Ollama provider wrapping OpenAI-compatible API.
    inner*: OpenAIProvider

#=======================================================================================================================
#== CONSTRUCTOR ========================================================================================================
#=======================================================================================================================

## Create an Ollama provider.
proc new_ollama_provider*(model: ModelName = ModelName("llama3.2:1b");
                          base_url: BaseUrl = BaseUrl("http://localhost:11434/v1")): OllamaProvider {.ok.} =
  OllamaProvider(inner: new_openai_provider(api_key = ApiKey(""), model = model, base_url = base_url))

#=======================================================================================================================
#== CHAT ===============================================================================================================
#=======================================================================================================================

## Send a chat completion request via Ollama.
proc chat*(provider: OllamaProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  provider.inner.chat(request)
