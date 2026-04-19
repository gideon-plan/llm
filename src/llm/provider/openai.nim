{.experimental: "strictFuncs".}
## OpenAI-compatible provider.
##
## Works with OpenAI, Ollama, vLLM, Together, Groq, llama-server,
## and any other endpoint implementing the OpenAI chat completions API.

import std/strutils
import jsony

import basis/code/throw
import basis/code/choice

import llm/types
import httpc/curl_client

standard_pragmas()

raises_error(llm_err, [IOError, OSError, ValueError, Exception],
             [ReadIOEffect, WriteIOEffect, TimeEffect, RootEffect])

#=======================================================================================================================
#== TYPES ==============================================================================================================
#=======================================================================================================================

type
  OpenAIProvider* = object ## OpenAI-compatible API provider state.
    base_url*: BaseUrl
    api_key*: ApiKey
    default_model*: ModelName

type
  OAIRespMessage = object
    content: string
    reasoning: string

  OAIChoice = object
    message: OAIRespMessage
    finish_reason: string

  OAIUsage = object
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int

  OAIResponse = object
    model: string
    choices: seq[OAIChoice]
    usage: OAIUsage

#=======================================================================================================================
#== CONSTRUCTOR ========================================================================================================
#=======================================================================================================================

## Create an OpenAI provider.
proc new_openai_provider*(api_key: ApiKey;
                          model: ModelName = ModelName("gpt-4o");
                          base_url: BaseUrl = BaseUrl("https://api.openai.com/v1")): OpenAIProvider {.ok.} =
  OpenAIProvider(base_url: base_url, api_key: api_key, default_model: model)

#=======================================================================================================================
#== CHAT ===============================================================================================================
#=======================================================================================================================

proc chat*(provider: OpenAIProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request.
  var req = request
  if req.model.len == 0:
    req.model = $provider.default_model
  let body = req.toJson()
  let url = ($provider.base_url).strip(trailing = true, chars = {'/'}) & "/chat/completions"
  let headers = @[
    ("Content-Type", "application/json"),
    ("Authorization", "Bearer " & $provider.api_key),
  ]

  let cc_r = init_curl_client()
  if cc_r.is_bad:
    raise newException(LLMError, "failed to init HTTP client")
  var cc = cc_r.val
  defer: cc.close()

  let resp = cc.request(HttpRequest(
    url: url,
    meth: HttpMethod.Post,
    headers: headers,
    body: body,
    timeout: 120,
  ))
  if resp.is_bad:
    raise newException(LLMError, "HTTP request failed: " & resp.err.msg)

  let code = resp.val.status
  let resp_body = resp.val.body
  if code < 200 or code >= 300:
    var err = newException(LLMError, "HTTP " & $code & ": " & resp_body)
    err.status_code = code
    raise err

  let r = fromJson(resp_body, OAIResponse)
  if r.choices.len == 0:
    raise newException(LLMError, "no choices in response")
  let ch = r.choices[0]
  var content = ch.message.content
  if content.len == 0 and ch.message.reasoning.len > 0:
    content = ch.message.reasoning
  let model_str = if r.model.len > 0: r.model else: req.model
  let finish = if ch.finish_reason.len > 0: ch.finish_reason else: "stop"
  ChatResponse(
    content: content,
    model: model_str,
    usage: Usage(
      prompt_tokens: r.usage.prompt_tokens,
      completion_tokens: r.usage.completion_tokens,
      total_tokens: r.usage.total_tokens,
    ),
    finish_reason: finish,
  )
