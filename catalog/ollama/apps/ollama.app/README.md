### 1. 简介
Ollama 是一个[开源项目]()，它提供了一个强大且用户友好的平台，让您能够在本地机器上运行大型语言模型（LLMs）。

### 2. 快速开始

应用依赖 Minio 存储数据，依赖 MySQL 存储元数据。请在 KDP 提前安装 Minio 和 MySQL。

#### 2.1 使用 Web UI 访问

浏览器打开 ingress 地址，例如 http://juicefs-s3-gateway-kdp-data.kdp-e2e.io
输入默认用户名/密码（`admin/admin.password`）登录即可, 默认账号密码是安装 Minio 时设置的管理员账号密码

#### 2.2 使用 Minio CLI 访问 (推荐)

为避免兼容性问题，我们推荐采用的 mc 的版本为 `RELEASE.2021-04-22T17-40-00Z`，你可以在[这个地址](https://dl.min.io/client/mc/release)找到历史版本和不同架构的 mc, 推荐版本下载地址：
- [linux amd64](https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [mac amd64](https://dl.min.io/client/mc/release/darwin-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [mac arm64](https://dl.min.io/client/mc/release/darwin-arm64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [windows amd64](https://dl.min.io/client/mc/release/windows-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- ....


```bash
export ALIAS=jfs
# s3 gateway address
export API_ENDPOINT="http://juicefs-s3-gateway-kdp-data.kdp-e2e.io"
# minio root user and password
export ACCESS_KEY=admin
export SECRET_KEY=admin.password
# set bucket name
export BUCKET_NAME=my-bucket
# file name for upload to s3
export OBJECT_NAME=s3-test.txt
# file path for upload to s3
export LOCAL_FILE_PATH=/tmp/${OBJECT_NAME}
echo "hello world" > ${LOCAL_FILE_PATH}
# create an alias for the Minio server
mc alias set ${ALIAS} ${API_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY}
# test the Connection
mc admin info ${ALIAS}
# list all buckets
mc ls ${ALIAS}
# create a bucket
mc mb ${ALIAS}/${BUCKET_NAME}
# upload a file
mc cp ${LOCAL_FILE_PATH} ${ALIAS}/${BUCKET_NAME}/${OBJECT_NAME}
# ls all objects in the bucket
mc ls ${ALIAS}/${BUCKET_NAME}
# download a file
mc cp ${ALIAS}/${BUCKET_NAME}/${OBJECT_NAME} ${LOCAL_FILE_PATH}.download
# delete a file
mc rm ${ALIAS}/${BUCKET_NAME}/${OBJECT_NAME}
# clean up the bucket content
mc rm --recursive ${ALIAS}/${BUCKET_NAME} --force
# delete the bucket
mc rb ${ALIAS}/${BUCKET_NAME}
# delete alias
mc alias remove ${ALIAS}

```

> 提示：可以进入任意一个 minio pod 容器, 环境中已经安装 minio CLI, 可以执行上述命令。endpoint 需要调整 `export API_ENDPOINT=juicefs-s3-gateway:9000`, 不要使用 ingress 地址，集群内dns可能无法解析。


#### 2.3 使用 AWS CLI 访问

从 https://aws.amazon.com/cli 下载并安装 AWS CLI，然后进行配置：

```bash
aws configure
# Access Key ID and Secret Access Key are the same as the Minio admin username and password
AWS Access Key ID [None]: admin
AWS Secret Access Key [None]: admin.password
Default region name [None]:
Default output format [None]:

# List buckets
aws --endpoint-url http://juicefs-s3-gateway-kdp-data.kdp-e2e.io s3 ls

# List objects in bucket
aws --endpoint-url http://juicefs-s3-gateway-kdp-data.kdp-e2e.io s3 ls s3://<bucket>

```

### 2.3 API
Object API (Amazon S3 compatible):
- Go:         https://docs.min.io/docs/golang-client-quickstart-guide
- Java:       https://docs.min.io/docs/java-client-quickstart-guide
- Python:     https://docs.min.io/docs/python-client-quickstart-guide
- JavaScript: https://docs.min.io/docs/javascript-client-quickstart-guide
- .NET:       https://docs.min.io/docs/dotnet-client-quickstart-guide


### 3. FAQ

https://juicefs.com/docs/zh/community/faq

