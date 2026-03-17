## OpenAI-compatible provider.
##
## Works with OpenAI, Ollama, vLLM, Together, Groq, llama-server,
## and any other endpoint implementing the OpenAI chat completions API.

import std/json
import std/httpclient
import std/net
import std/strutils

import basis/code/throw

import llm/types

standard_pragmas()

raises_error(llm_err, [IOError, OSError, TimeoutError, ValueError, HttpRequestError, JsonParsingError],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  OpenAIProvider* = object
    base_url*: BaseUrl
    api_key*: ApiKey
    default_model*: ModelName

# -----------------------------------------------------------------------
# Constructor
# -----------------------------------------------------------------------

proc new_openai_provider*(api_key: ApiKey;
                          model: ModelName = ModelName("gpt-4o");
                          base_url: BaseUrl = BaseUrl("https://api.openai.com/v1")): OpenAIProvider {.ok.} =
  OpenAIProvider(base_url: base_url, api_key: api_key, default_model: model)

# -----------------------------------------------------------------------
# Chat
# -----------------------------------------------------------------------

proc chat*(provider: OpenAIProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request.
  var req = request
  if req.model.len == 0:
    req.model = $provider.default_model
  let body = req.to_json()
  let client = newHttpClient()
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Authorization": "Bearer " & $provider.api_key,
  })
  let url = ($provider.base_url).strip(trailing = true, chars = {'/'}) & "/chat/completions"
  let resp = client.request(url, httpMethod = HttpPost, body = $body)
  let code = resp.code.int
  let resp_body = resp.body
  if code < 200 or code >= 300:
    var err = newException(LLMError, "HTTP " & $code & ": " & resp_body)
    err.status_code = code
    raise err
  let j = parseJson(resp_body)
  let choices = j["choices"]
  if choices.len == 0:
    raise newException(LLMError, "no choices in response")
  let choice = choices[0]
  let msg = choice["message"]
  let usage = if j.hasKey("usage"): parse_usage(j["usage"]) else: Usage()
  let finish = choice.getOrDefault("finish_reason").getStr("stop")
  # Some thinking models (qwen3.5, glm) return content in "reasoning" field
  var content = msg["content"].getStr("")
  if content.len == 0 and msg.hasKey("reasoning"):
    content = msg["reasoning"].getStr("")
  ChatResponse(
    content: content,
    model: j.getOrDefault("model").getStr(req.model),
    usage: usage,
    finish_reason: finish,
  )
