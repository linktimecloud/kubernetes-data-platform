### 1. Introduction
Ollama [open-source project](https://github.com/ollama/ollama) is a user-friendly and open-source platform for running large models locally.

### 2. Quick Start

#### 2.1 Installing Models
When installing on the KDP page, the `model list` parameter defaults to an empty value. You can find the required models [here](https://ollama.com/library) and simply fill in the model name. After clicking install, the model will be automatically downloaded during the application startup phase. Typically, models are large and may take a long time to download, so please be patient (progress cannot be viewed). Alternatively, you can keep the `model list` parameter empty, install and start the application, and then manually download the model inside the container (taking `qwen:0.5b` as an example):
```shell
kubectl exec -it $(kubectl get pods -l app.kubernetes.io/name=ollama -n kdp-data -o jsonpath='{.items[0].metadata.name}') -n kdp-data -- ollama pull qwen:0.5b
```

#### 2.2 Using the REST API

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


#### 2.3 Using  Python SDK

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
Reference Documentation: [Ollama Python SDK](https://github.com/ollama/ollama-python)
Additionally, JavaScript SDK: [Ollama JS](https://github.com/ollama/ollama-js)

More usage examples: [Tutorials](https://github.com/ollama/ollama/blob/main/docs/tutorials.md)

### 3. Common Commands
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
### 4. OpenAI Compatibility
Ollama is partially compatible with the OpenAI API, allowing you to interact with Ollama using the OpenAI SDK. Refer to [OpenAI Compatibility Documentation](https://github.com/ollama/ollama/blob/main/docs/openai.md) for more details.

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

### 5. GPU Compatibility
For GPU compatibility details, please refer to the [GPU Documentation](https://github.com/ollama/ollama/blob/main/docs/gpu.md).

### 6. Custom Models

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

For more references on custom models, see [Model File Documentation](https://github.com/ollama/ollama/blob/main/docs/modelfile.md).

### 7. Custom Ollama Docker Image
If your deployment environment cannot download models, you can build a custom Ollama Docker image.

```bash
# wire Dockerfile
cat > Dockerfile << EOF
FROM ollama/ollama:latest
RUN ollama pull qwen:0.5b
EOF

docker build -t ollama-custom:1.0.0 .
docker push ollama-custom:1.0.0
```

Add the `tag` configuration in the `catalog/ollama/x-definitions/app-ollama.cue` file.

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
