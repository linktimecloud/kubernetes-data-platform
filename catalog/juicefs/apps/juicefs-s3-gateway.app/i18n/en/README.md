### 1. Introduction
[JuiceFS S3 Gateway](https://juicefs.com/docs/zh/community/guide/gateway) is one of the supported access methods for JuiceFS, allowing the JuiceFS file system to be served over the S3 protocol, enabling applications to access files stored on JuiceFS via the S3 SDK.

In JuiceFS, files are stored in chunks as objects in the underlying object storage. JuiceFS provides various access methods including FUSE POSIX, WebDAV, S3 Gateway, CSI Driver, among which the S3 Gateway is commonly used.

### 2. Quick Start
The application relies on Minio for data storage and MySQL for metadata storage. Please ensure Minio and MySQL are installed in KDP beforehand.

#### 2.1 Access via Web UI
Open the ingress address in a browser, for example, http://juicefs-s3-gateway-kdp-data.kdp-e2e.io. Enter the default username/password (`admin/admin.password`) to log in. The default credentials are the administrator username and password set during Minio installation.

#### 2.2 Access via Minio CLI (Recommended)
To avoid compatibility issues, we recommend using the `RELEASE.2021-04-22T17-40-00Z` version of mc. You can find historical versions and different architectures of mc at [this address](https://dl.min.io/client/mc/release). Recommended version download links:
- [linux amd64](https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [mac amd64](https://dl.min.io/client/mc/release/darwin-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [mac arm64](https://dl.min.io/client/mc/release/darwin-arm64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- [windows amd64](https://dl.min.io/client/mc/release/windows-amd64/archive/mc.RELEASE.2021-04-22T17-40-00Z)
- ...


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

> Tip: You can enter any Minio pod container where the Minio CLI is already installed and execute the above commands. Adjust the endpoint with `export API_ENDPOINT=juicefs-s3-gateway:9000`, and do not use the ingress address as the cluster's internal DNS may not resolve it correctly.


#### 2.3 Access via AWS CLI
Download and install the AWS CLI from https://aws.amazon.com/cli, then proceed with the configuration:

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

