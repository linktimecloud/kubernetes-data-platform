### 1. Introduction
MinIO is a high-performance, distributed object storage system that can be used to store and retrieve large amounts of data, supporting S3 API and other common cloud storage service interfaces. It supports high availability, high scalability, security, low cost and high performance. Minio is suitable for storing any number of unstructured data, such as images, videos, logs, backups and container/virtual machine images. Minio can be used to build high performance infrastructure, such as cloud native applications, DevOps and big data analysis.
### 2. Quick Start
Prerequisites:

>- Api endpoint, such as `http://minio-svc:9000` 
>- Access key, also known as user name, such as `minioUsername` 
>- Secret key, also known ad user password, such as `minioPassword`
>- The permissions of creating bucket, uploading object, downloading object, deleting object, listing object, etc.


We introduce three ways to use Minio: web console, command line and SDK.

#### 2.1 Minio web console
Minio web console is a web-based user interface for managing Minio server. It can be used to create bucket, upload object, download object, delete object, list object, etc. You need:

1. Minio account. Different accounts have different permissions. 
2. The minio console url (not the api endpoint), such as `http://minio-svc:9090` . Open a browser and enter the url then enter the username and password to log in.


#### 2.2 Minio client
Minio client is a command line tool for managing Minio server. It can be used to create bucket, upload object, download object, delete object, list object, etc.

##### 2.2.1 Install Minio client 
Install Minio client according to the given [instructions](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart).

```bash
# We use linux-amd64 as an example
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

mc --help
```

##### 2.2.2 Minio client commands
```bash
export ALIAS=<your-alias-name>
export API_ENDPOINT=<your-api-endpoint>
export ACCESS_KEY=<your-access-key>
export SECRET_KEY=<your-secret-key>
export BUCKET_NAME=<your-bucket-name>
export LOCAL_FILE_PATH=<your-local-file-path>
export OBJECT_NAME=<your-object-name>
# create an alias for the Minio server
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
# for more commands, please refer to https://min.io/docs/minio/linux/reference/minio-mc.html
```


#### 2.3 Minio client SDK (python)
Minio provides SDKs for various programming languages, such as python, java, go, etc. You can use the SDK to create bucket, upload object, download object, delete object, list object, etc.

We use python3 as an example:

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
This error usually occurs when the MinIO client is unable to connect to the server. To resolve this issue, you can try the following:

1. Check if the network connection is working properly.
2. Check if the server URL is correct.

#### 3.2 Bucket not found: <bucket_name>
This error usually occurs when the specified bucket does not exist. To resolve this issue, you can try the following:

1. Confirm if the bucket name is correct.
2. Check if the bucket exists on the MinIO server.
3. Confirm if the access key and secret key being used have permissions to access the bucket.

#### 3.3 Access denied
This error usually occurs when access is denied. To resolve this issue, you can try the following:

1. Confirm if the access key and secret key being used are correct.
2. Confirm if the access key and secret key have permissions to access the requested resource.
3. Confirm if the HTTP method used in the access request is correct.

#### 3.4 Insufficient data for block
This error usually occurs when uploading a file and there is not enough data to create a complete block. To resolve this issue, you can try the following:

1. Confirm if the MinIO server has enough disk space to store the uploaded data.
2. Configure a suitable lifecycle policy to delete expired objects and reduce unnecessary storage usage.

#### 3.5 Bucket not empty
This error usually occurs when attempting to delete a non-empty bucket. To resolve this issue, you can try the following:

1. Confirm if all objects in the bucket have been deleted.If there are still objects in the bucket, delete them before deleting the bucket.

### 4. Concepts

#### 4.1 Bucket

Bucket is a namespace in MinIO used to store objects. It is similar to a folder, but without a hierarchical structure. You can store any number of objects in a bucket. Each object has a unique name that serves as its identifier within the bucket. Object names can contain any character, except for the forward slash (/).

#### 4.2 Object
An object is the basic storage unit of MinIO. It is a file stored on the MinIO server. An object consists of data and metadata. The data is the actual content of the object, and the metadata contains information about the object, such as the object name, creation time, content type, etc.

#### 4.3 Access key and secret key
ccess Key and Secret Key are credentials used for identity verification. The Access Key is a public key used to identify the user. The Secret Key is a private key used to encrypt signature strings and verify signature strings. Access Key and Secret Key are used for identity verification between the MinIO server and the MinIO client.

#### 4.4 Erasure coding
Erasure coding is a data redundancy technique used to store data across multiple disks. It divides data into multiple data blocks and stores them on multiple disks. If any disk fails, MinIO can use the data blocks from other disks to recover the data.

