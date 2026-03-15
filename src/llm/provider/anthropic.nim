## Anthropic Messages API provider.

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
  AnthropicProvider* = object
    base_url*: string
    api_key*: string
    default_model*: string
    anthropic_version*: string

# -----------------------------------------------------------------------
# Constructor
# -----------------------------------------------------------------------

proc new_anthropic_provider*(api_key: string;
                             model: string = "claude-sonnet-4-6";
                             base_url: string = "https://api.anthropic.com/v1";
                             version: string = "2023-06-01"): AnthropicProvider {.ok.} =
  AnthropicProvider(
    base_url: base_url, api_key: api_key,
    default_model: model, anthropic_version: version,
  )

# -----------------------------------------------------------------------
# Chat
# -----------------------------------------------------------------------

proc chat*(provider: AnthropicProvider; request: ChatRequest): ChatResponse {.llm_err.} =
  ## Send a chat completion request via Anthropic Messages API.
  var model = request.model
  if model.len == 0:
    model = provider.default_model
  # Extract system message (Anthropic uses a separate "system" field)
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
  let client = newHttpClient()
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "x-api-key": provider.api_key,
    "anthropic-version": provider.anthropic_version,
  })
  let url = provider.base_url.strip(trailing = true, chars = {'/'}) & "/messages"
  let resp = client.request(url, httpMethod = HttpPost, body = $body)
  let code = resp.code.int
  let resp_body = resp.body
  if code < 200 or code >= 300:
    var err = newException(LLMError, "HTTP " & $code & ": " & resp_body)
    err.status_code = code
    raise err
  let j = parseJson(resp_body)
  # Extract content from content blocks
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
