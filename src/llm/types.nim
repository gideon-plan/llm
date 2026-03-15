## Common types for the LLM client.

import std/json

import basis/code/throw

standard_pragmas()

raises_error(llm_err, [IOError, ValueError], [])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  LLMError* = object of IOError
    ## LLM provider error.
    status_code*: int

  Role* = enum
    System = "system"
    User = "user"
    Assistant = "assistant"

  Message* = object
    role*: Role
    content*: string

  ChatRequest* = object
    model*: string
    messages*: seq[Message]
    temperature*: float
    max_tokens*: int
    top_p*: float
    stop*: seq[string]

  Usage* = object
    prompt_tokens*: int
    completion_tokens*: int
    total_tokens*: int

  ChatResponse* = object
    content*: string
    model*: string
    usage*: Usage
    finish_reason*: string

# -----------------------------------------------------------------------
# Constructors
# -----------------------------------------------------------------------

proc message*(role: Role; content: string): Message {.ok.} =
  Message(role: role, content: content)

proc system_msg*(content: string): Message {.ok.} =
  Message(role: System, content: content)

proc user_msg*(content: string): Message {.ok.} =
  Message(role: User, content: content)

proc assistant_msg*(content: string): Message {.ok.} =
  Message(role: Assistant, content: content)

proc chat_request*(model: string; messages: seq[Message];
                   temperature: float = 0.7;
                   max_tokens: int = 1024;
                   top_p: float = 1.0;
                   stop: seq[string] = @[]): ChatRequest {.ok.} =
  ChatRequest(
    model: model, messages: messages,
    temperature: temperature, max_tokens: max_tokens,
    top_p: top_p, stop: stop,
  )

# -----------------------------------------------------------------------
# JSON serialization
# -----------------------------------------------------------------------

proc to_json*(msg: Message): JsonNode {.ok.} =
  %*{"role": $msg.role, "content": msg.content}

proc to_json*(req: ChatRequest): JsonNode {.ok.} =
  var msgs = newJArray()
  for m in req.messages:
    msgs.add(m.to_json())
  var j = %*{
    "model": req.model,
    "messages": msgs,
    "temperature": req.temperature,
    "max_tokens": req.max_tokens,
  }
  if req.top_p != 1.0:
    j["top_p"] = %req.top_p
  if req.stop.len > 0:
    var stops = newJArray()
    for s in req.stop:
      stops.add(%s)
    j["stop"] = stops
  j

proc to_json*(usage: Usage): JsonNode {.ok.} =
  %*{
    "prompt_tokens": usage.prompt_tokens,
    "completion_tokens": usage.completion_tokens,
    "total_tokens": usage.total_tokens,
  }

proc to_json*(resp: ChatResponse): JsonNode {.ok.} =
  %*{
    "content": resp.content,
    "model": resp.model,
    "usage": resp.usage.to_json(),
    "finish_reason": resp.finish_reason,
  }

proc parse_role*(s: string): Role {.llm_err.} =
  case s
  of "system": System
  of "user": User
  of "assistant": Assistant
  else: raise newException(ValueError, "unknown role: " & s)

proc parse_message*(j: JsonNode): Message {.llm_err.} =
  Message(
    role: parse_role(j["role"].getStr()),
    content: j["content"].getStr(),
  )

proc parse_usage*(j: JsonNode): Usage {.ok.} =
  Usage(
    prompt_tokens: j.getOrDefault("prompt_tokens").getInt(0),
    completion_tokens: j.getOrDefault("completion_tokens").getInt(0),
    total_tokens: j.getOrDefault("total_tokens").getInt(0),
  )
