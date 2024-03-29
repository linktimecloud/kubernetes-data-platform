### 1. 应用说明

Httpfs-gateway 是一个基于 HDFS 的文件系统网关，提供了 RESTful API 接口，支持文件的上传、下载、删除、重命名、移动、复制、创建目录、列举目录、获取文件属性等操作。
通常 Hue 会使用 Httpfs-gateway 来访问 HDFS 文件系统。

### 2. 快速入门

#### 2.1 部署创建

Httpfs-gateway 由系统管理员创建发布，用户可直接使用。

#### 2.2 使用实践

##### 2.2.1 准备工作

##### 2.2.2 使用方式

```shell
# HTTPFS_URL 为 httpfs-gateway 的访问地址, 根据实际修改
HTTPFS_URL='http://httpfs-gateway-svc.admin.svc.cluster.local:14000'

# 查看文件列表
curl "${HTTPFS_URL}/webhdfs/v1/?op=LISTSTATUS&user.name=root"

# 上传文件
curl -i -X PUT -T /etc/hosts -H "content-type:application/octet-stream" "${HTTPFS_URL}/webhdfs/v1/hosts?op=CREATE&data=true&overwrite=true&user.name=root"

# 下载文件
curl "${HTTPFS_URL}/webhdfs/v1/hosts?op=OPEN&user.name=root"

# 删除文件
curl -X DELETE "${HTTPFS_URL}/webhdfs/v1/hosts?op=DELETE&user.name=root"
```

### 3. 常见问题自检

#### 3.1. 问题排查

排查顺序：

1. 检查HDFS是否正常
2. 检查请求的url是否正确，请求的参数是否正确


