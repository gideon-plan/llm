{.experimental: "strictFuncs".}
## Common types for the LLM client.

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
#== ROLE SERIALIZATION =================================================================================================
#=======================================================================================================================

## Parse a string into a Role enum value.
proc parse_role*(s: string): Role {.llm_err.} =
  case s
  of "system": System
  of "user": User
  of "assistant": Assistant
  else: raise newException(ValueError, "unknown role: " & s)

proc enumHook*(s: string; v: var Role) {.raises: [IOError, ValueError].} =
  ## jsony enum hook: deserialize Role from its string value.
  v = parse_role(s)
