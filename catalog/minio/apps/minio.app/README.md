### 1. 介绍
MinIO是一个高性能、分布式对象存储系统，可用于存储和检索大量数据，支持S3 API和其他常见的云存储服务接口。它具有高可用性、高可扩展性、安全性、低成本和高性能等特性。Minio 适用于存储任意数量的非结构化数据，例如图像、视频、日志、备份和容器/虚拟机镜像。Minio 可用于构建高性能基础架构，例如云原生应用程序、DevOps 和大数据分析。

### 2. 快速开始
前提条件：

>- 可访问 api endpoint，例如 `http://minio-svc:9000`
>- 拥有访问密钥（Access key），也称为用户名，例如 `minioUsername`
>- 拥有密钥（Secret key），也称为用户密码，例如 `minioPassword`
>- 账号有创建 bucket、上传对象、下载对象、删除对象、列出对象等权限

我们介绍三种使用 Minio 的方法：web 控制台、命令行和 SDK。

#### 2.1 Minio web 控制台
Minio web 控制台是一个基于 web 的用户界面，用于管理 Minio 服务器。它可以用于创建 bucket、上传对象、下载对象、删除对象、列出对象等。您需要：
  
1. Minio账户。不同的账户具有不同的权限。
2. Minio 控制台 url（不是 api endpoint），例如 `http://minio-svc:9090` 。打开浏览器并输入 url，然后输入用户名和密码登录。

#### 2.2 Minio 客户端
Minio 客户端是一个用于管理 Minio 服务器的命令行工具。它可以用于创建 bucket、上传对象、下载对象、删除对象、列出对象等。

#### 2.2.1 安装 Minio 客户端
根据给定的[说明](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart)安装 Minio 客户端。

```bash
# We use linux-amd64 as an example
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/
mc --help
```
#### 2.2.2 Minio 客户端命令
```bash

export ALIAS=local
export API_ENDPOINT=http://localhost:9000
#  minio default root user and password, change to your minio root user and password
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

# for more commands, please refer to https://min.io/docs/minio/linux/reference/minio-mc.html
```

#### 2.3 Minio 客户端 SDK (python)
Minio 提供了各种编程语言的 SDK，例如 python、java、go 等。您可以使用 SDK 创建 bucket、上传对象、下载对象、删除对象、列出对象等。

我们以 python3 为例：

```python
from minio import Minio
from minio.error import ResponseError

MINIO_ENDPOINT = "<your-api-endpoint>"
ACCESS_KEY = "<your-access-key>"
SECTET_KEY = "<your-secret-key>"
BUCKET_NAME = "<your-bucket-name>"
LOCAL_FILE_PATH = "<your-local-file-path>"

minioClient = Minio(MINIO_ENDPOINT, access_key=ACCESS_KEY, secret_key=SECTET_KEY, secure=False)
# create the bucket if it does not exist
exists = minioClient.bucket_exists(BUCKET_NAME)
if not exists:
    try:
        minioClient.make_bucket(BUCKET_NAME)
        print("Bucket created successfully")
    except ResponseError as err:
        print(err)
else:
    print("Bucket already exists")

# upload the file
try:
    minioClient.fput_object(BUCKET_NAME, LOCAL_FILE_PATH, LOCAL_FILE_PATH)
    print("File uploaded successfully")
except ResponseError as err:
    print(err)

# download the file
try:
    data = minioClient.get_object(BUCKET_NAME, LOCAL_FILE_PATH)
    with open(LOCAL_FILE_PATH, 'wb') as file_data:
        for d in data.stream(32*1024):
            file_data.write(d)
    print("File downloaded successfully")
except ResponseError as err:
    print(err)

# delete the file
try:
    minioClient.remove_object(BUCKET_NAME, LOCAL_FILE_PATH)
    print("File deleted successfully")
except ResponseError as err:
    print(err)

# delete the bucket
try:
    minioClient.remove_bucket(BUCKET_NAME)
    print("Bucket deleted successfully")
except ResponseError as err:
    print(err)
```
 For other languages, please refer to the [official documentation](https://min.io/docs/minio/linux/developers/minio-drivers.html).

### 3. FQA
#### 3.1 Unable to access the server: <server_url>
此错误通常发生在 MinIO 客户端无法连接到服务器时。要解决此问题，您可以尝试以下操作：

1. 检查网络连接是否正常工作。
2. 检查服务器 URL 是否正确。

#### 3.2 Bucket not found: <bucket_name>
此错误通常发生在指定的 bucket 不存在时。要解决此问题，您可以尝试以下操作：

1. 确认 bucket 名称是否正确。
2. 检查 bucket 是否存在于 MinIO 服务器上。
3. 确认正在使用的访问密钥和密钥是否具有访问 bucket 的权限。

#### 3.3 Access denied
此错误通常发生在访问被拒绝时。要解决此问题，您可以尝试以下操作：

1. 确认正在使用的访问密钥和密钥是否正确。
2. 确认正在使用的访问密钥和密钥是否具有访问请求的资源的权限。
  
#### 3.4 Insufficient data for block
此错误通常发生在上传文件时，没有足够的数据来创建完整的块时。要解决此问题，您可以尝试以下操作：

1. 确认 MinIO 服务器是否有足够的磁盘空间来存储上传的数据。
2. 配置合适生命周期策略以删除过期的对象， 减少不不必要的存储使用。

#### 3.5 Bucket not empty
此错误通常发生在尝试删除非空 bucket 时。要解决此问题，您可以尝试以下操作：

1. 确认 bucket 中的所有对象是否已被删除。 如果 bucket 中仍然有对象，请在删除 bucket 之前删除它们。

### 4. 概念
#### 4.1 Bucket
Bucket 是 MinIO 中的命名空间，用于存储对象。它类似于文件夹，但没有层次结构。您可以在 bucket 中存储任意数量的对象。每个对象都有一个唯一的名称，该名称是对象在 bucket 中的标识符。对象名称可以包含任何字符，但不能包含斜杠（/）。

#### 4.2 Object
Object 是 MinIO 中的基本存储单元。它类似于文件。对象由数据和元数据组成。数据是对象的内容。元数据是有关对象的数据，例如对象名称、大小、创建日期和内容类型（MIME 类型）等。

#### 4.3 Access Key 和 Secret Key
Access Key 和 Secret Key 是用于验证身份的凭据。Access Key 是用于标识用户的公开密钥。Secret Key 是用于加密签名字符串和验证签名字符串的私钥。Access Key 和 Secret Key 用于 MinIO 服务器和 MinIO 客户端之间的身份验证。

#### 4.4 Erasure coding
Erasure coding 是一种数据冗余技术，用于在多个磁盘上存储数据。它将数据分成多个数据块，并将这些数据块存储在多个磁盘上。如果任何磁盘损坏，MinIO 可以使用其他磁盘中的数据块来恢复数据。

