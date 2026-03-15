## Ollama provider -- thin wrapper around OpenAI-compatible provider.

import std/json
import std/httpclient
import std/net

import basis/code/throw

import llm/types
import llm/provider/openai

standard_pragmas()

raises_error(llm_err, [IOError, OSError, TimeoutError, ValueError, HttpRequestError, JsonParsingError],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  OllamaProvider* = object
    inner*: OpenAIProvider

# -----------------------------------------------------------------------
# Constructor
# -----------------------------------------------------------------------

proc new_ollama_provider*(model: string = "llama3.2:1b";
                          base_url: string = "http://localhost:11434/v1"): OllamaProvider {.ok.} =
  OllamaProvider(inner: new_openai_provider(api_key = "", model = model, base_url = base_url))

# -----------------------------------------------------------------------
# Chat
# -----------------------------------------------------------------------

proc chat*(provider: OllamaProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  provider.inner.chat(request)
