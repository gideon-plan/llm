{.experimental: "strictFuncs".}
## Common types for the LLM client.

import std/json

import basis/code/throw

standard_pragmas()

raises_error(llm_err, [IOError, ValueError], [])

#=======================================================================================================================
#== TYPES ==============================================================================================================
#=======================================================================================================================

type
  ApiKey* = distinct string    ## API key for LLM provider authentication.
  ModelName* = distinct string ## LLM model identifier.
  BaseUrl* = distinct string   ## Base URL for LLM provider endpoint.

func `$`*(v: ApiKey): string {.borrow.}     ## Stringify ApiKey.
func `$`*(v: ModelName): string {.borrow.}  ## Stringify ModelName.
func `$`*(v: BaseUrl): string {.borrow.}    ## Stringify BaseUrl.
func `==`*(a, b: ApiKey): bool {.borrow.}   ## Compare ApiKeys.
func `==`*(a, b: ModelName): bool {.borrow.} ## Compare ModelNames.
func `==`*(a, b: BaseUrl): bool {.borrow.}  ## Compare BaseUrls.
func len*(v: ApiKey): int {.borrow.}        ## Length of ApiKey string.
func len*(v: ModelName): int {.borrow.}     ## Length of ModelName string.
func len*(v: BaseUrl): int {.borrow.}       ## Length of BaseUrl string.

type
  LLMError* = object of IOError
    ## LLM provider error.
    status_code*: int

  Role* = enum ## Chat message role.

    System = "system"
    User = "user"
    Assistant = "assistant"

  Message* = object ## A single chat message with role and content.
    role*: Role
    content*: string

  ChatRequest* = object ## Chat completion request parameters.
    model*: string
    messages*: seq[Message]
    temperature*: float
    max_tokens*: int
    top_p*: float
    stop*: seq[string]

  Usage* = object ## Token usage statistics from a completion.
    prompt_tokens*: int
    completion_tokens*: int
    total_tokens*: int

  ChatResponse* = object ## Chat completion response.
    content*: string
    model*: string
    usage*: Usage
    finish_reason*: string

#=======================================================================================================================
#== CONSTRUCTORS =======================================================================================================
#=======================================================================================================================

## Create a message with the given role and content.
proc message*(role: Role; content: string): Message {.ok.} =
  Message(role: role, content: content)

## Create a system message.
proc system_msg*(content: string): Message {.ok.} =
  Message(role: System, content: content)

## Create a user message.
proc user_msg*(content: string): Message {.ok.} =
  Message(role: User, content: content)

## Create an assistant message.
proc assistant_msg*(content: string): Message {.ok.} =
  Message(role: Assistant, content: content)

## Build a chat completion request.
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

#=======================================================================================================================
#== JSON SERIALIZATION =================================================================================================
#=======================================================================================================================

## Serialize a Message to JSON.
proc to_json*(msg: Message): JsonNode {.ok.} =
  %*{"role": $msg.role, "content": msg.content}

## Serialize a ChatRequest to JSON.
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

## Serialize Usage to JSON.
proc to_json*(usage: Usage): JsonNode {.ok.} =
  %*{
    "prompt_tokens": usage.prompt_tokens,
    "completion_tokens": usage.completion_tokens,
    "total_tokens": usage.total_tokens,
  }

## Serialize a ChatResponse to JSON.
proc to_json*(resp: ChatResponse): JsonNode {.ok.} =
  %*{
    "content": resp.content,
    "model": resp.model,
    "usage": resp.usage.to_json(),
    "finish_reason": resp.finish_reason,
  }

## Parse a string into a Role enum value.
proc parse_role*(s: string): Role {.llm_err.} =
  case s
  of "system": System
  of "user": User
  of "assistant": Assistant
  else: raise newException(ValueError, "unknown role: " & s)

## Parse a JSON node into a Message.
proc parse_message*(j: JsonNode): Message {.llm_err.} =
  Message(
    role: parse_role(j["role"].getStr()),
    content: j["content"].getStr(),
  )

## Parse a JSON node into Usage statistics.
proc parse_usage*(j: JsonNode): Usage {.ok.} =
  Usage(
    prompt_tokens: j.getOrDefault("prompt_tokens").getInt(0),
    completion_tokens: j.getOrDefault("completion_tokens").getInt(0),
    total_tokens: j.getOrDefault("total_tokens").getInt(0),
  )
