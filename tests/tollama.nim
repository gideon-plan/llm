## Integration test for Ollama provider (requires local Ollama running).

import std/unittest

import llm/types
import llm/client

suite "ollama integration":
  test "chat with local model":
    let c = new_ollama_client("qwen3.5:0.8b")
    let resp = c.chat(@[user_msg("Say hi")], max_tokens = 16)
    check resp.content.len > 0
    check resp.finish_reason.len > 0

  test "complete convenience":
    let c = new_ollama_client("qwen3.5:0.8b")
    let text = c.complete("Say yes", max_tokens = 16)
    check text.len > 0

  test "system message":
    let c = new_ollama_client("qwen3.5:0.8b")
    let resp = c.chat(@[
      system_msg("Reply with one word only."),
      user_msg("ping"),
    ], max_tokens = 16)
    check resp.content.len > 0
