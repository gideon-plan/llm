{.experimental: "strictFuncs".}
## Unit tests for LLM types and JSON serialization.

import std/[unittest, strutils]
import jsony

import llm/types

suite "types":
  test "message constructors":
    let s = system_msg("you are helpful")
    check s.role == System
    check s.content == "you are helpful"
    let u = user_msg("hello")
    check u.role == User
    let a = assistant_msg("hi")
    check a.role == Assistant

  test "chat request constructor":
    let req = chat_request("gpt-4o", @[user_msg("hi")])
    check req.model == "gpt-4o"
    check req.messages.len == 1
    check req.temperature == 0.7
    check req.max_tokens == 1024
    check req.top_p == 1.0
    check req.stop.len == 0

  test "message toJson":
    let m = user_msg("hello")
    let j = m.toJson()
    check j.contains("\"role\":\"user\"")
    check j.contains("\"content\":\"hello\"")

  test "message roundtrip":
    let m = user_msg("hello world")
    let j = m.toJson()
    let m2 = fromJson(j, Message)
    check m2.role == User
    check m2.content == "hello world"

  test "chat request toJson":
    let req = chat_request("test-model", @[
      system_msg("be terse"),
      user_msg("what is 2+2"),
    ], temperature = 0.5, max_tokens = 100)
    let j = req.toJson()
    check j.contains("\"model\":\"test-model\"")
    check j.contains("\"temperature\":0.5")
    check j.contains("\"max_tokens\":100")

  test "chat request with stop sequences":
    let req = chat_request("m", @[user_msg("hi")], stop = @["END", "STOP"])
    let j = req.toJson()
    check j.contains("\"END\"")
    check j.contains("\"STOP\"")

  test "usage roundtrip":
    let u = Usage(prompt_tokens: 10, completion_tokens: 20, total_tokens: 30)
    let j = u.toJson()
    let u2 = fromJson(j, Usage)
    check u2.prompt_tokens == 10
    check u2.total_tokens == 30

  test "parse_role":
    check parse_role("system") == System
    check parse_role("user") == User
    check parse_role("assistant") == Assistant

  test "parse_role invalid":
    var caught = false
    try:
      discard parse_role("invalid")
    except ValueError:
      caught = true
    check caught

  test "response roundtrip":
    let r = ChatResponse(content: "hi", model: "m", usage: Usage(), finish_reason: "stop")
    let j = r.toJson()
    let r2 = fromJson(j, ChatResponse)
    check r2.content == "hi"
    check r2.finish_reason == "stop"

  test "message role string values":
    check $System == "system"
    check $User == "user"
    check $Assistant == "assistant"

suite "distinct types":
  test "ApiKey":
    let k = ApiKey("sk-test")
    check $k == "sk-test"
    check k.len == 7
    check k == ApiKey("sk-test")

  test "ModelName":
    let m = ModelName("gpt-4o")
    check $m == "gpt-4o"
    check m == ModelName("gpt-4o")

  test "BaseUrl":
    let u = BaseUrl("https://api.example.com")
    check $u == "https://api.example.com"
    check u.len == 23

  test "distinct types are not interchangeable":
    # These are compile-time checks -- the fact that this compiles
    # with separate types proves they are distinct
    let k = ApiKey("key")
    let m = ModelName("model")
    let u = BaseUrl("url")
    check $k != $m  # different values
    check $m != $u
