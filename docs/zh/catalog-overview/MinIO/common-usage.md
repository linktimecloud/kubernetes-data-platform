# MinIO 组件使用

## 连接方式

### MinIO Web 控制台
MinIO Web 控制台是一个基于 Web 的用户界面，用于管理 MinIO 服务器。它可以用于创建 bucket、上传对象、下载对象、删除对象、列出对象等。您需要：
  
1. MinIO账户。安装时管理员账号。
2. MinIO 控制台 url。在应用实例详情页「访问地址」中获取 url 地址，输入用户名和密码登录。

### MinIO 客户端
MinIO 客户端是一个用于管理 MinIO 服务器的命令行工具。它可以用于创建 bucket、上传对象、下载对象、删除对象、列出对象等。

#### 安装 MinIO 客户端
根据[说明](https://min.io/docs/MinIO/linux/reference/MinIO-mc.html#quickstart)安装 MinIO 客户端。

```bash
# We use linux-amd64 as an example
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/MinIO-binaries/mc

chmod +x $HOME/MinIO-binaries/mc
export PATH=$PATH:$HOME/MinIO-binaries/
mc --help
```

#### 客户端命常用命令
```bash
export ALIAS=<your-alias-name>
export API_ENDPOINT=<your-api-endpoint>
export ACCESS_KEY=<your-access-key>
export SECRET_KEY=<your-secret-key>
export BUCKET_NAME=<your-bucket-name>
export LOCAL_FILE_PATH=<your-local-file-path>
export OBJECT_NAME=<your-object-name>
# create an alias for the MinIO server
mc alias set $ALIAS $API_ENDPOINT $ACCESS_KEY $SECRET_KEY
# test the Connection
mc admin info $ALIAS
# list all buckets
mc ls $ALIAS
# create a bucket
mc mb $ALIAS/$BUCKET_NAME
# upload a file
mc cp $LOCAL_FILE_PATH $ALIAS/$BUCKET_NAME
# ls all objects in the bucket
mc ls $ALIAS/$BUCKET_NAME
# download a file
mc cp $ALIAS/$BUCKET_NAME/$OBJECT_NAME $LOCAL_FILE_PATH
# delete a file
mc rm $ALIAS/$BUCKET_NAME/$OBJECT_NAME
# clean up the bucket content
mc rm --recursive $ALIAS/$BUCKET_NAME
# delete the bucket
mc rb $ALIAS/$BUCKET_NAME
# for more commands, please refer to https://min.io/docs/MinIO/linux/reference/MinIO-mc.html
```

### MinIO 客户端 SDK (python)

MinIO 提供了各种编程语言的 SDK，例如 python、java、go 等。您可以使用 SDK 创建 bucket、上传对象、下载对象、删除对象、列出对象等。

我们以 python3 为例：

```python
from MinIO import MinIO
from MinIO.error import ResponseError

MinIO_ENDPOINT = "<your-api-endpoint>"
ACCESS_KEY = "<your-access-key>"
SECTET_KEY = "<your-secret-key>"
BUCKET_NAME = "<your-bucket-name>"
LOCAL_FILE_PATH = "<your-local-file-path>"

MinIOClient = MinIO(MinIO_ENDPOINT, access_key=ACCESS_KEY, secret_key=SECTET_KEY, secure=False)
# create the bucket if it does not exist
exists = MinIOClient.bucket_exists(BUCKET_NAME)
if not exists:
    try:
        MinIOClient.make_bucket(BUCKET_NAME)
        print("Bucket created successfully")
    except ResponseError as err:
        print(err)
else:
    print("Bucket already exists")

# upload the file
try:
    MinIOClient.fput_object(BUCKET_NAME, LOCAL_FILE_PATH, LOCAL_FILE_PATH)
    print("File uploaded successfully")
except ResponseError as err:
    print(err)

# download the file
try:
    data = MinIOClient.get_object(BUCKET_NAME, LOCAL_FILE_PATH)
    with open(LOCAL_FILE_PATH, 'wb') as file_data:
        for d in data.stream(32*1024):
            file_data.write(d)
    print("File downloaded successfully")
except ResponseError as err:
    print(err)

# delete the file
try:
    MinIOClient.remove_object(BUCKET_NAME, LOCAL_FILE_PATH)
    print("File deleted successfully")
except ResponseError as err:
    print(err)

# delete the bucket
try:
    MinIOClient.remove_bucket(BUCKET_NAME)
    print("Bucket deleted successfully")
except ResponseError as err:
    print(err)
```

若使用其他语言，参考 [official documentation](https://min.io/docs/MinIO/linux/developers/MinIO-drivers.html).

## 性能调优

通常系统会自动配置纠删码（Erasure Code）配置，以保证数据的可靠性，但是纠删码会增加存储的使用，如果对数据的可靠性要求不高，可以使用 REDUCED_REDUNDANCY Class（RRS），减少存储使用。默认情况下，RRS的校验块EC:1，类似磁盘RAID 5。

参考代码go语言(其他语言可以参考SDK)

```go
s3Client, err := minio.New("localhost:9000", "YOUR-ACCESSKEYID", "YOUR-SECRETACCESSKEY", true)
if err != nil {
 log.Fatalln(err)
}

object, err := os.Open("my-testfile")
if err != nil {
 log.Fatalln(err)
}
defer object.Close()
objectStat, err := object.Stat()
if err != nil {
 log.Fatalln(err)
}

n, err := s3Client.PutObject("my-bucketname", "my-objectname", object, objectStat.Size(), minio.PutObjectOptions{ContentType: "application/octet-stream", StorageClass: "REDUCED_REDUNDANCY"})
if err != nil {
 log.Fatalln(err)
}
log.Println("Uploaded", "my-objectname", " of size: ", n, "Successfully.")
```
