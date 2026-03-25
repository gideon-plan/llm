## Anthropic Messages API provider.

import std/[json, strutils]

import basis/code/throw
import basis/code/choice

import llm/types
import httpc/curl_client

standard_pragmas()

raises_error(llm_err, [IOError, OSError, ValueError, JsonParsingError, Exception],
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
  var msgs = newJArray()
  for m in request.messages:
    if m.role == System:
      system_text = m.content
    else:
      msgs.add(%*{"role": $m.role, "content": m.content})
  var body = %*{
    "model": model,
    "messages": msgs,
    "max_tokens": request.max_tokens,
  }
  if system_text.len > 0:
    body["system"] = %system_text
  if request.temperature != 0.7:
    body["temperature"] = %request.temperature
  if request.top_p != 1.0:
    body["top_p"] = %request.top_p
  if request.stop.len > 0:
    var stops = newJArray()
    for s in request.stop:
      stops.add(%s)
    body["stop_sequences"] = stops

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
    meth: hmPost,
    headers: headers,
    body: $body,
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
  let j = parseJson(resp_body)
  var content = ""
  if j.hasKey("content"):
    for item in j["content"]:
      if item.getOrDefault("type").getStr() == "text":
        content.add(item["text"].getStr())
  let usage = if j.hasKey("usage"):
    Usage(
      prompt_tokens: j["usage"].getOrDefault("input_tokens").getInt(0),
      completion_tokens: j["usage"].getOrDefault("output_tokens").getInt(0),
      total_tokens: j["usage"].getOrDefault("input_tokens").getInt(0) +
                    j["usage"].getOrDefault("output_tokens").getInt(0),
    )
  else:
    Usage()
  ChatResponse(
    content: content,
    model: j.getOrDefault("model").getStr(model),
    usage: usage,
    finish_reason: j.getOrDefault("stop_reason").getStr("end_turn"),
  )
