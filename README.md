# llm

Vendor-neutral LLM client for Nim. Supports OpenAI, Anthropic, and Ollama via HTTP. Includes Maybe[T,E] non-raising API variants.

## Install

```
nimble install
```

## Usage

```nim
import llm

let client = new_ollama_client()
let resp = client.chat(@[user_msg("Hello")])
```

## License

Proprietary
