### 1. Introduction
Httpfs-gateway is a file system gateway based on HDFS, which provides RESTful API interfaces and supports file upload, download, deletion, renaming, moving, copying, directory creation, directory listing, and file attribute acquisition operations.
Hue usually uses Httpfs-gateway to access the HDFS file system.
### 2. Quick Start
#### 2.1 Deployment Creation
Httpfs-gateway is created and released by the system administrator, and users can use it directly.
#### 2.2 Usage Practice
##### 2.2.1 Preparation
##### 2.2.2 Usage
```shell
# HTTPFS_URL is the access address of httpfs-gateway, modify it according to the actual situation
HTTPFS_URL='http://httpfs-gateway-svc.admin.svc.cluster.local:14000'

# View the file list
curl "${HTTPFS_URL}/webhdfs/v1/?op=LISTSTATUS&user.name=root"

# Upload file
curl -i -X PUT -T /etc/hosts -H "content-type:application/octet-stream" "${HTTPFS_URL}/webhdfs/v1/hosts?op=CREATE&data=true&overwrite=true&user.name=root"

# Download file
curl "${HTTPFS_URL}/webhdfs/v1/hosts?op=OPEN&user.name=root"

# Delete file

curl -X DELETE "${HTTPFS_URL}/webhdfs/v1/hosts?op=DELETE&user.name=root"
```

### 3. Common Problem Self-check
#### 3.1. Problem Troubleshooting
Troubleshooting sequence:
1. Check whether HDFS is normal
2. Check whether the requested URL is correct and whether the requested parameters are correct


