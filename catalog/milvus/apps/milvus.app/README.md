### 1. 应用说明

Milvus 是一款云原生向量数据库，它具备高可用、高性能、易拓展的特点，用于海量向量数据的实时召回。

### 2. 快速入门

#### 2.1 部署创建

Milvus 通过KDP web部署，依赖Kafka和Minio，需先安装依赖服务。

Milvus 支持两种部署模式：standalone 模式和cluster 模式，默认为 standalone。
这两种模式具有相同的功能。您可以选择最适合您的数据集大小、流量数据等的模式。目前，Milvus单机版无法“在线”升级到Milvus集群。

#### 2.2 使用实践

##### 2.2.1 获取连接信息

集群内Milvus svc地址：milvus.kdp-data.svc.cluster.local:19530

集群外访问可通过配置的ingress(http://milvus-kdp-data.kdp-e2e.io)地址或者通过kubectl port-forward 访问，以下为port-forward命令。

```shell
kubectl port-forward svc/milvus -n kdp-data 19530:19530
```

attu ingress地址：http://milvus-attu-kdp-data.kdp-data.svc.cluster.local

#### 2.2.2 使用 Milvus_CLI

##### 安装 Milvus_CLI

参考文档：[Install Milvus_CLI](https://milvus.io/docs/install_cli.md)

前提条件：`Python >= 3.8.5`

通过pip 安装milvus-cli

```python
pip install milvus-cli
```

##### 使用 Milvus_CLI

1. 进入Milvus_CLI

    ```shell
    milvus-cli
    ```

2. 连接到Milvus

    此处使用port-forward方式连接 Milvus，参考2.2.1 获取连接信息。

    ```shell
    connect -uri http://localhost:19530/
    ```

3. Database 相关操作

    ```shell
    create database -db test"
    
    list databases
    
    use database -db test
    
    delete database -db test
    ```

4. Collection 相关操作

    ```shell
    # 基本操作
    create collection -c car -f id:INT64:primary_field -f vector:FLOAT_VECTOR:128 -f color:INT64:color -f brand:ARRAY:64:VARCHAR:128 -p id -A -desc car_collection
    
    list collections
    
    show collection -c car
    
    delete collection -c car
    
    # partition 操作
    create partition -c car -p new_partition -d test_add_partition
    
    list partitions -c car
    
    drop partition -c car -p new_partition
    
    # 索引操作，注意：milvus_cli v0.4.3 创建索引为交互式操作，需要分别指定索引参数
    milvus_cli > create index
    Collection name (car): car
    The name of the field to create an index for (id, vector, color, brand): vector
    Index name: vector_idx
    Index type (FLAT, IVF_FLAT, IVF_SQ8, IVF_PQ, RNSG, HNSW, ANNOY, AUTOINDEX, DISKANN, GPU_IVF_FLAT, GPU_IVF_PQ, SCANN, STL_SORT, Trie, ) []: IVF_FLAT
    Vector Index metric type (L2, IP, HAMMING, TANIMOTO, COSINE, ) []: L2
    Index params nlist: 1024
    
    list index -c car
    
    show index -c car -in vector_idx
    
    # 别名
    create alias -c car -a carAlias1
    
    delete alias -a carAlias1
    ```

5. 数据操作

    ```shell
    # 注意：文档中使用import，但milvus-cli v0.4.3 使用insert
    insert -c car 'https://raw.githubusercontent.com/linktimecloud/example-datasets/milvus/data/car.sample.100.csv'
    
    # 加载到内存
    load collection -c car
    
    # milvus_cli v0.4.3 query为交互式操作，需要分别指定参数
    milvus_cli > query
    Collection name (car): car
    Query: id in [ 450544538979460758, 450544538979460759, 450544538979460761 ]
    ...
    
    # 释放
    release collection -c car
    ```

#### 2.2.3 使用 Milvus API

参考官方文档

-  [PyMilvus](https://github.com/milvus-io/pymilvus)
-  [Node.js SDK](https://github.com/milvus-io/milvus-sdk-node)
-  [Go SDK](https://github.com/milvus-io/milvus-sdk-go)
-  [Java SDK](https://github.com/milvus-io/milvus-sdk-java)
-  [Restful API](https://milvus.io/api-reference/restful/v2.4.x/About.md)
