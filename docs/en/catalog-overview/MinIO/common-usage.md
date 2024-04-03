# MinIO Component Usage

## Connection Methods

### MinIO Web Console

The MinIO Web Console is a web-based user interface for managing MinIO servers. It can be used to create buckets, upload objects, download objects, delete objects, list objects, and more:
  
1. A MinIO account. The administrator account is provided during installation.
2. The MinIO Console URL. Obtain the URL from the 'Access Address' in the application instance details page and log in with your username and password.

### MinIO Client
The MinIO Client is a command-line tool for managing MinIO servers. It can be used to create buckets, upload objects, download objects, delete objects, list objects, and more.

#### Installing the MinIO Client
Install the MinIO Client according to the [instructions](https://min.io/docs/MinIO/linux/reference/MinIO-mc.html#quickstart).

```bash
# We use linux-amd64 as an example
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/MinIO-binaries/mc

chmod +x $HOME/MinIO-binaries/mc
export PATH=$PATH:$HOME/MinIO-binaries/
mc --help
```

#### Common Client Commands
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

### MinIO Client SDK (Python)

MinIO provides SDKs for various programming languages, such as Python, Java, Go, and more. You can use the SDK to create buckets, upload objects, download objects, delete objects, list objects, and more.

Let's take Python 3 as an example:

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

If using other languages, refer to the [documentation](https://min.io/docs/MinIO/linux/developers/MinIO-drivers.html).

## Performance Tuning

Typically, the system will automatically configure Erasure Code to ensure data reliability. However, Erasure Code increases storage usage. If the reliability requirements for data are not high, you can use the REDUCED_REDUNDANCY (RRS) class to reduce storage usage. By default, RRS has a parity block EC:1, similar to disk RAID 5.

Reference code in Go language (other languages can refer to the SDK):

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
