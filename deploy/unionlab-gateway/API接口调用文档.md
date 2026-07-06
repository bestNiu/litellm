# UnionLab Gateway 模型接口调用文档

> 本文档说明如何通过 UnionLab Gateway（OpenAI 兼容网关，底层基于 LiteLLM）调用各类模型能力。
> 所有接口均与 **OpenAI API 协议兼容**，可直接使用 OpenAI 官方 SDK / cURL / 任意 HTTP 客户端调用。

---

## 一、接入信息

| 项目 | 值 |
|------|------|
| Base URL | `http://ai-gateway.union-laboratory.com` |
| 鉴权方式 | HTTP Header：`Authorization: Bearer <API_KEY>` |
| API_KEY | 使用网关下发的 Key（`sk-...`），本文示例统一写作 `$API_KEY` |
| 内容类型 | `Content-Type: application/json`（图片/音频上传除外） |
| 兼容协议 | OpenAI Chat Completions / Embeddings / Images / Audio / Rerank |

> **安全提示**：请勿在客户端代码或公开仓库中硬编码 Key，建议通过环境变量注入。

### 通用调用方式

**方式 1：OpenAI Python SDK**

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://ai-gateway.union-laboratory.com",
    api_key="sk-你的Key",
)
```

**方式 2：cURL**

```bash
export API_KEY="sk-你的Key"
export BASE_URL="http://ai-gateway.union-laboratory.com"
```

### 查询可用模型

```bash
curl $BASE_URL/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

---

## 二、模型能力总览

| 能力类别 | 接口路径 | mode | 代表模型 |
|----------|----------|------|----------|
| 文本对话 / 智能体 | `/v1/chat/completions` | chat | `qwen3.7-max`、`deepseek-v4-pro`、`gpt-5.5`、`gpt-5.4` |
| 深度推理（思考） | `/v1/chat/completions` | chat | `qwen3-max-2026-01-23`、`o4-mini`、`grok-4.3` |
| 视觉理解（图生文） | `/v1/chat/completions` | chat（vision） | `qwen3-vl-plus`、`gpt-4o`、`qwen3.7-plus` |
| 联网搜索 | `/v1/chat/completions` | chat（web_search） | `qwen3.6-flash`、`gpt-5.4`、`qwen3.5-omni-plus` |
| 全模态（文/图/音/视频输入） | `/v1/chat/completions` | chat（omni） | `qwen3.5-omni-plus`、`qwen3.5-omni-flash` |
| 图片生成 | `/v1/images/generations` | image_generation | `qwen-image-2.0`、`wan2.7-image-pro`、`gpt-image-2` |
| 语音合成 TTS | `/v1/audio/speech` | audio_speech | `gpt-4o-mini-tts`、`tts-1-hd` |
| 语音识别 ASR | `/v1/audio/transcriptions` | audio_transcription | `gpt-4o-transcribe`、`whisper-1` |
| 文本向量化 Embedding | `/v1/embeddings` | embedding | `text-embedding-v4`、`text-embedding-3-large` |
| 语义重排序 Rerank | `/v1/rerank` | rerank | `qwen3-rerank` |
| 视频生成 | `/v1/chat/completions` | chat（异步） | `wan2.7-i2v-2026-04-25`、`happyhorse-1.1-t2v` |

> **命名约定**：请始终使用上表中的 `model_name`（如 `qwen3.7-max`）作为 `model` 参数值。
> 名称中带 `-fallback` 后缀的为自动容灾通道，**请勿直接调用**。

---

## 三、文本对话（Chat Completions）

最核心的能力，适用于聊天、问答、总结、代码生成、智能体等场景。

### 3.1 基础请求

```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.7-max",
    "messages": [
      {"role": "system", "content": "你是一个专业的助手。"},
      {"role": "user", "content": "用一句话介绍量子计算。"}
    ],
    "temperature": 0.7,
    "max_tokens": 1024
  }'
```

Python：

```python
resp = client.chat.completions.create(
    model="qwen3.7-max",
    messages=[
        {"role": "system", "content": "你是一个专业的助手。"},
        {"role": "user", "content": "用一句话介绍量子计算。"},
    ],
    temperature=0.7,
)
print(resp.choices[0].message.content)
```

### 3.2 流式输出（SSE）

设置 `"stream": true`，服务端以 Server-Sent Events 逐块返回。

```python
stream = client.chat.completions.create(
    model="qwen3.7-max",
    messages=[{"role": "user", "content": "写一首关于秋天的短诗"}],
    stream=True,
)
for chunk in stream:
    delta = chunk.choices[0].delta.content
    if delta:
        print(delta, end="", flush=True)
```

### 3.3 常用参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `model` | string | 模型名，必填 |
| `messages` | array | 对话消息列表，必填 |
| `temperature` | float | 采样温度 0~2，越大越发散 |
| `top_p` | float | 核采样，与 temperature 二选一调节 |
| `max_tokens` | int | 最大输出 token 数 |
| `stream` | bool | 是否流式输出 |
| `stop` | string/array | 停止词 |
| `tools` / `tool_choice` | array/string | 函数调用（见第四节） |

---

## 四、函数调用 / 工具调用（Function Calling）

支持 `supports_function_calling` 的模型（几乎全部 chat 模型）可让模型输出结构化的工具调用请求。

```python
tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "查询指定城市的天气",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "城市名"}
            },
            "required": ["city"],
        },
    },
}]

resp = client.chat.completions.create(
    model="qwen3.7-max",
    messages=[{"role": "user", "content": "北京今天天气怎么样？"}],
    tools=tools,
    tool_choice="auto",
)

# 模型返回要调用的工具与参数
tool_call = resp.choices[0].message.tool_calls[0]
print(tool_call.function.name)       # get_weather
print(tool_call.function.arguments)  # {"city": "北京"}
```

**完整回环**：拿到 `tool_call` 后本地执行函数，把结果以 `role: "tool"` 追加进 `messages`，再次请求模型即可得到最终自然语言回答。

```python
messages.append(resp.choices[0].message)  # 模型的工具调用消息
messages.append({
    "role": "tool",
    "tool_call_id": tool_call.id,
    "content": '{"temperature": "25°C", "condition": "晴"}',
})
final = client.chat.completions.create(model="qwen3.7-max", messages=messages, tools=tools)
print(final.choices[0].message.content)
```

> 支持并行工具调用的模型（`supports_parallel_function_calling`）可在一次响应中返回多个 `tool_calls`。

---

## 五、深度推理（Reasoning / 思考）

支持 `supports_reasoning` 的模型（如 `qwen3-max-2026-01-23`、`o4-mini`、`deepseek-v4-pro`）可开启思维链推理，适合数学、逻辑、复杂规划。

```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-max-2026-01-23",
    "messages": [
      {"role": "user", "content": "一个水池有进水管和出水管，进水管2小时注满，出水管3小时放空，同时打开几小时注满？"}
    ],
    "reasoning_effort": "high"
  }'
```

- `reasoning_effort`：可选 `low` / `medium` / `high`，控制思考深度（OpenAI o 系列 / GPT-5 系列支持）。
- 部分模型会在响应中返回 `reasoning_content`（思考过程）字段，最终答案仍在 `content` 中。

---

## 六、视觉理解（图片输入 / 多模态对话）

支持 `supports_vision` 的模型（`qwen3-vl-plus`、`qwen3-vl-flash`、`gpt-4o`、`qwen3.7-plus` 等）可理解图片。

图片通过 `image_url` 传入，支持公网 URL 或 base64 Data URI。

```python
resp = client.chat.completions.create(
    model="qwen3-vl-plus",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "这张图片里有什么？请详细描述。"},
            {"type": "image_url", "image_url": {
                "url": "https://example.com/photo.jpg"
            }},
        ],
    }],
)
print(resp.choices[0].message.content)
```

**base64 方式（本地图片）**：

```python
import base64
with open("photo.jpg", "rb") as f:
    b64 = base64.b64encode(f.read()).decode()

image_url = {"url": f"data:image/jpeg;base64,{b64}"}
```

---

## 七、联网搜索（Web Search）

支持 `supports_web_search` 的模型可实时检索互联网信息。网关已内置 Tavily 搜索工具，Azure 系列模型会自动拦截并注入搜索结果。

```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4",
    "messages": [
      {"role": "user", "content": "帮我查一下最近的 AI 行业新闻"}
    ],
    "web_search_options": {}
  }'
```

- 阿里百炼系（`qwen3.6-flash`、`qwen3.5-omni-plus` 等）可通过 `enable_search` 或 `web_search_options` 开启。
- Azure 系（`gpt-5.4`、`gpt-4o` 等）由网关自动通过 Tavily 完成检索，无需额外配置搜索源。

---

## 八、全模态（Omni：文/图/音/视频输入，文/音输出）

`qwen3.5-omni-plus` / `qwen3.5-omni-flash` 支持同时输入文本、图片、音频、视频，并可输出文本或音频，256K 上下文。

```python
resp = client.chat.completions.create(
    model="qwen3.5-omni-plus",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "请听这段音频并总结内容"},
            {"type": "input_audio", "input_audio": {
                "data": "<base64音频>", "format": "wav"
            }},
        ],
    }],
    modalities=["text"],  # 若需音频回复可用 ["text", "audio"]
)
print(resp.choices[0].message.content)
```

---

## 九、图片生成（Image Generation）

接口路径 `/v1/images/generations`，`mode` 为 `image_generation`。

| 模型 | 说明 |
|------|------|
| `qwen-image-2.0` | 融合生成与编辑，更快更强 |
| `wan2.7-image-pro` | 复杂指令遵循强，支持 4K |
| `z-image-turbo` | 高性价比，照片级 |
| `gpt-image-2` / `gpt-image-1.5` | OpenAI SOTA 生成与编辑 |
| `dall-e-3` | 经典 DALL·E 3 |

```bash
curl $BASE_URL/v1/images/generations \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-image-2.0",
    "prompt": "一只戴着宇航头盔的橘猫，漂浮在星空中，写实风格",
    "n": 1,
    "size": "1024x1024"
  }'
```

Python：

```python
img = client.images.generate(
    model="qwen-image-2.0",
    prompt="一只戴着宇航头盔的橘猫，漂浮在星空中",
    n=1,
    size="1024x1024",
)
print(img.data[0].url)  # 或 img.data[0].b64_json
```

---

## 十、语音合成（TTS）

接口路径 `/v1/audio/speech`，`mode` 为 `audio_speech`。模型：`gpt-4o-mini-tts`、`tts-1-hd`、`tts-1`。

```bash
curl $BASE_URL/v1/audio/speech \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini-tts",
    "input": "你好，欢迎使用 UnionLab 网关。",
    "voice": "alloy",
    "response_format": "mp3"
  }' --output speech.mp3
```

Python：

```python
resp = client.audio.speech.create(
    model="gpt-4o-mini-tts",
    voice="alloy",
    input="你好，欢迎使用 UnionLab 网关。",
)
resp.stream_to_file("speech.mp3")
```

> 阿里 `qwen3-tts-flash`（chat 模式，`supports_audio_output`）走 `/v1/chat/completions`，通过 `modalities=["audio"]` 返回音频。

---

## 十一、语音识别（ASR / Transcription）

接口路径 `/v1/audio/transcriptions`，`mode` 为 `audio_transcription`。模型：`gpt-4o-transcribe`、`gpt-4o-mini-transcribe`、`whisper-1`。

```bash
curl $BASE_URL/v1/audio/transcriptions \
  -H "Authorization: Bearer $API_KEY" \
  -F "model=gpt-4o-transcribe" \
  -F "file=@audio.mp3"
```

Python：

```python
with open("audio.mp3", "rb") as f:
    resp = client.audio.transcriptions.create(
        model="gpt-4o-transcribe",
        file=f,
    )
print(resp.text)
```

> 阿里 `qwen3-asr-flash`、`fun-asr`（chat 模式，`supports_audio_input`）走 `/v1/chat/completions`，将音频作为 `input_audio` 传入。

---

## 十二、文本向量化（Embeddings）

接口路径 `/v1/embeddings`，用于 RAG、语义检索、聚类。

| 模型 | 维度 | 说明 |
|------|------|------|
| `text-embedding-v4` | 64~2048（可配置） | Qwen3 旗舰，支持稀疏向量、instruct |
| `text-embedding-3-large` | 3072 | 精度最高 |
| `text-embedding-3-small` | 1536 | 性价比最高 |

```bash
curl $BASE_URL/v1/embeddings \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "text-embedding-v4",
    "input": ["今天天气不错", "人工智能改变世界"]
  }'
```

Python：

```python
resp = client.embeddings.create(
    model="text-embedding-v4",
    input=["今天天气不错", "人工智能改变世界"],
)
print(len(resp.data[0].embedding))  # 向量维度
```

---

## 十三、语义重排序（Rerank）

接口路径 `/v1/rerank`，模型 `qwen3-rerank`，用于 RAG 精排，对候选文档按与 query 的相关性重新排序。

```bash
curl $BASE_URL/v1/rerank \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-rerank",
    "query": "如何申请年假？",
    "documents": [
      "年假需提前三天在系统提交申请。",
      "报销流程见财务手册第五章。",
      "员工每年享有带薪年假。"
    ],
    "top_n": 2
  }'
```

返回结果包含每个文档的 `relevance_score` 与排序后的 `index`。

---

## 十四、视频生成

阿里视频模型（`wan2.7-i2v-2026-04-25` 图生视频、`happyhorse-1.1-t2v` 文生视频、`wan2.7-videoedit` 视频编辑）在网关中以 chat 模式接入，通常为**异步任务**：提交请求后返回任务 ID，轮询获取结果视频 URL。

```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "happyhorse-1.1-t2v",
    "messages": [
      {"role": "user", "content": "生成一段5秒视频：海浪拍打沙滩，夕阳西下"}
    ]
  }'
```

> 视频生成计费按秒计（720P/1080P 费率不同），生成耗时较长，建议客户端设置较长超时并做异步轮询。

---

## 十五、错误码与容灾

### 常见 HTTP 状态码

| 状态码 | 含义 | 处理建议 |
|--------|------|----------|
| `401` | 鉴权失败 | 检查 `Authorization` Header 与 Key |
| `404` | 模型不存在 | 核对 `model` 名称是否在模型列表中 |
| `429` | 触发限流 | 退避重试（指数退避） |
| `400` | 参数错误 | 检查请求体 JSON 结构与必填字段 |
| `500/503` | 上游异常 | 网关会自动切换 fallback，可稍后重试 |

### 自动容灾（Fallback）

网关已配置主备切换，调用方**无感知**、无需改代码：

- `deepseek-v4-pro` / `deepseek-v4-flash`：百炼主 → Azure 备
- `gpt-5.4` / `gpt-5.4-mini` / `gpt-4o` 等：Azure 主 → OpenAI 备
- `text-embedding-3-large/small`：Azure 主 → OpenAI 备

始终调用**主模型名**即可，网关会在主通道异常时自动切换到备用通道（最多 3 次）。

---

## 十六、模型选型速查

| 场景 | 推荐模型 |
|------|----------|
| 通用旗舰 / 智能体 | `qwen3.7-max`、`gpt-5.5`、`gpt-5.4` |
| 高性价比日常对话 | `qwen3.6-flash`、`gpt-5.4-mini`、`deepseek-v4-flash` |
| 复杂推理 / 数学 | `qwen3-max-2026-01-23`、`o4-mini` |
| 图片理解 | `qwen3-vl-plus`、`gpt-4o` |
| 全模态交互 | `qwen3.5-omni-plus` |
| 图片生成 | `qwen-image-2.0`、`gpt-image-2` |
| RAG 向量化 | `text-embedding-v4` |
| RAG 精排 | `qwen3-rerank` |
| 语音合成 | `gpt-4o-mini-tts` |
| 语音识别 | `gpt-4o-transcribe` |
| 私有化部署 | `qwen3-30b-a3b`、`qwen3-32b-gptq-int4` |

---

> 更多协议细节参考 OpenAI 官方 API 文档及 LiteLLM 文档：https://docs.litellm.ai/
