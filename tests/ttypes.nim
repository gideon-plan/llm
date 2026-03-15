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
