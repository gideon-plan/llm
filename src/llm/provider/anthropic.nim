{.experimental: "strictFuncs".}
## Anthropic Messages API provider.

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
  AnthropicProvider* = object ## Anthropic Messages API provider state.
    base_url*: BaseUrl
    api_key*: ApiKey
    default_model*: ModelName
    anthropic_version*: string

type
  AnthropicMessage = object
    role: string
    content: string

  AnthropicRequest = object
    model: string
    messages: seq[AnthropicMessage]
    max_tokens: int
    system: string
    temperature: float
    top_p: float
    stop_sequences: seq[string]

  AnthropicContentBlock = object
    `type`: string
    text: string

  AnthropicUsage = object
    input_tokens: int
    output_tokens: int

  AnthropicResponse = object
    model: string
    stop_reason: string
    content: seq[AnthropicContentBlock]
    usage: AnthropicUsage

#=======================================================================================================================
#== SERIALIZATION ======================================================================================================
#=======================================================================================================================

proc dumpHook*(s: var string; v: AnthropicRequest) =
  ## Custom serialization: omit optional fields when at default values.
  s.add '{'
  s.add "\"model\":"
  s.dumpHook(v.model)
  s.add ",\"messages\":"
  s.dumpHook(v.messages)
  s.add ",\"max_tokens\":"
  s.dumpHook(v.max_tokens)
  if v.system.len > 0:
    s.add ",\"system\":"
    s.dumpHook(v.system)
  if v.temperature != 0.7:
    s.add ",\"temperature\":"
    s.dumpHook(v.temperature)
  if v.top_p != 1.0:
    s.add ",\"top_p\":"
    s.dumpHook(v.top_p)
  if v.stop_sequences.len > 0:
    s.add ",\"stop_sequences\":"
    s.dumpHook(v.stop_sequences)
  s.add '}'

#=======================================================================================================================
#== CONSTRUCTOR ========================================================================================================
#=======================================================================================================================

## Create an Anthropic provider.
proc new_anthropic_provider*(api_key: ApiKey;
                             model: ModelName = ModelName("claude-sonnet-4-6");
                             base_url: BaseUrl = BaseUrl("https://api.anthropic.com/v1");
                             version: string = "2023-06-01"): AnthropicProvider {.ok.} =
  AnthropicProvider(
    base_url: base_url, api_key: api_key,
    default_model: model, anthropic_version: version,
  )

#=======================================================================================================================
#== CHAT ===============================================================================================================
#=======================================================================================================================

proc chat*(provider: AnthropicProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request via Anthropic Messages API.
  var model = request.model
  if model.len == 0:
    model = $provider.default_model
  var system_text = ""
  var msgs: seq[AnthropicMessage]
  for m in request.messages:
    if m.role == System:
      system_text = m.content
    else:
      msgs.add(AnthropicMessage(role: $m.role, content: m.content))
  let ar = AnthropicRequest(
    model: model,
    messages: msgs,
    max_tokens: request.max_tokens,
    system: system_text,
    temperature: request.temperature,
    top_p: request.top_p,
    stop_sequences: request.stop,
  )
  let body = ar.toJson()

  let url = ($provider.base_url).strip(trailing = true, chars = {'/'}) & "/messages"
  let headers = @[
    ("Content-Type", "application/json"),
    ("x-api-key", $provider.api_key),
    ("anthropic-version", provider.anthropic_version),
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

  let r = fromJson(resp_body, AnthropicResponse)
  var content = ""
  for item in r.content:
    if item.`type` == "text":
      content.add(item.text)
  let resp_model = if r.model.len > 0: r.model else: model
  let stop_reason = if r.stop_reason.len > 0: r.stop_reason else: "end_turn"
  ChatResponse(
    content: content,
    model: resp_model,
    usage: Usage(
      prompt_tokens: r.usage.input_tokens,
      completion_tokens: r.usage.output_tokens,
      total_tokens: r.usage.input_tokens + r.usage.output_tokens,
    ),
    finish_reason: stop_reason,
  )
