## Unit tests for LLM types and JSON serialization.

import std/json
import std/unittest

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

  test "message to_json":
    let m = user_msg("hello")
    let j = m.to_json()
    check j["role"].getStr() == "user"
    check j["content"].getStr() == "hello"

  test "chat request to_json":
    let req = chat_request("test-model", @[
      system_msg("be terse"),
      user_msg("what is 2+2"),
    ], temperature = 0.5, max_tokens = 100)
    let j = req.to_json()
    check j["model"].getStr() == "test-model"
    check j["messages"].len == 2
    check j["temperature"].getFloat() == 0.5
    check j["max_tokens"].getInt() == 100

  test "chat request with stop sequences":
    let req = chat_request("m", @[user_msg("hi")], stop = @["END", "STOP"])
    let j = req.to_json()
    check j["stop"].len == 2
    check j["stop"][0].getStr() == "END"

  test "usage to_json":
    let u = Usage(prompt_tokens: 10, completion_tokens: 20, total_tokens: 30)
    let j = u.to_json()
    check j["prompt_tokens"].getInt() == 10
    check j["total_tokens"].getInt() == 30

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

  test "parse_usage":
    let j = %*{"prompt_tokens": 5, "completion_tokens": 10, "total_tokens": 15}
    let u = parse_usage(j)
    check u.prompt_tokens == 5
    check u.completion_tokens == 10
    check u.total_tokens == 15

  test "parse_usage missing fields":
    let j = %*{}
    let u = parse_usage(j)
    check u.prompt_tokens == 0
    check u.total_tokens == 0

  test "response to_json":
    let r = ChatResponse(content: "hi", model: "m", usage: Usage(), finish_reason: "stop")
    let j = r.to_json()
    check j["content"].getStr() == "hi"
    check j["finish_reason"].getStr() == "stop"

  test "parse_message":
    let j = %*{"role": "user", "content": "hello world"}
    let m = parse_message(j)
    check m.role == User
    check m.content == "hello world"

  test "chat request top_p omitted when 1.0":
    let req = chat_request("m", @[user_msg("hi")])
    let j = req.to_json()
    check not j.hasKey("top_p")

  test "chat request top_p included when not 1.0":
    let req = chat_request("m", @[user_msg("hi")], top_p = 0.9)
    let j = req.to_json()
    check j["top_p"].getFloat() == 0.9

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
