### 1. 简介
Ollama [开源项目](https://github.com/ollama/ollama) 是一个简单易用且开源的本地大模型运行平台。

### 2. 快速开始

#### 2.1 安装模型
在 KDP 页面安装的时候`模型列表`参数默认是空值，可以在[这里](https://ollama.com/library)找到需要的模型，填写模型名称即可，点击安装后会在应用启动阶段自动下载模型。通常模型比较大，下载时间较长，请耐心等待(无法查看进度)。或者保持`模型列表`参数是空值，安装启动后进入容器手动下载(以下载`qwen:0.5b`为例)：
`kubectl exec -it $(kubectl get pods -l app.kubernetes.io/name=ollama -n kdp-data -o jsonpath='{.items[0].metadata.name}') -n kdp-data -- ollama pull qwen:0.5b`

#### 2.2 使用 REST API

```bash

export ollama_endpoint=http://ollama-kdp-data.kdp-e2e.io
export ollama_model=qwen:0.5b

curl ${ollama_endpoint}/api/generate -d '{
  "model": "'"${ollama_model}"'",
  "prompt": "Why is the sky blue?"
}'

```
高级参数：https://github.com/ollama/ollama/blob/main/docs/api.md#generate-request-with-options
更多请参考： https://github.com/ollama/ollama/blob/main/docs/api.md


#### 2.3 使用 Python SDK

- Install

```sh
# Python version >= 3.8
pip install ollama
```

- Usage

```python
import ollama
response = ollama.chat(model='qwen:0.5b', messages=[
  {
    'role': 'user',
    'content': 'Why is the sky blue?',
  },
])
print(response['message']['content'])
```
参考文档：https://github.com/ollama/ollama-python
另外 JavaScript SDK：https://github.com/ollama/ollama-js


更多使用示例：https://github.com/ollama/ollama/blob/main/docs/tutorials.md

### 3. 常用命令
```bash
export ollama_model=qwen:0.5b
# download model
ollama pull ${ollama_model}
# list models
ollama list 
# run model
ollama run ${ollama_model}
# list running models
ollama ps
# delete model
ollama rm ${ollama_model}

```
### 4. Open AI 兼容性
Ollama 部分兼容 OpenAI API，您可以使用 OpenAI SDK 与 Ollama 进行交互。参考 https://github.com/ollama/ollama/blob/main/docs/openai.md

```py
from openai import OpenAI

client = OpenAI(
    base_url='http://ollama-kdp-data.kdp-e2e.io/v1/',

    # required but ignored
    api_key='ollama',
)

chat_completion = client.chat.completions.create(
    messages=[
        {
            'role': 'user',
            'content': 'Say this is a test',
        }
    ],
    model='qwen:0.5b',
)
```

### 5. GPU 兼容性
https://github.com/ollama/ollama/blob/main/docs/gpu.md


### 6. 自定义模型

```bash
# download model
ollama pull qwen:0.5b

# create model file
cat > Modelfile << EOF
FROM qwen:0.5b
# set the temperature to 1 [higher is more creative, lower is more coherent]
PARAMETER temperature 1
# set the system message
SYSTEM """
You are Mario from Super Mario Bros. Answer as Mario, the assistant, only.
"""
EOF

# build model
ollama create mario -f ./Modelfile

# run model
ollama run mario
>>> hi
Hello! It's your friend Mario.
```

更多参考： https://github.com/ollama/ollama/blob/main/docs/modelfile.md 


### 7. 自定义 Ollama docker image
如果部署环境无法下载模型，可以构建自定义 Ollama docker image。

```bash
# wire Dockerfile
cat > Dockerfile << EOF
FROM ollama/ollama:latest
RUN ollama pull qwen:0.5b
EOF

docker build -t ollama-custom:1.0.0 .
docker push ollama-custom:1.0.0
```
在`catalog/ollama/x-definitions/app-ollama.cue`文件中新增`tag`配置

```cue
values: {
	image: {
	    repository: "\(_imageRegistry)ollama/ollama"
        // use custom image
        tag: "ollama-custom:1.0.0"
	}
    ....
}
```

### 7. FAQ
https://github.com/ollama/ollama/blob/main/docs/faq.md
