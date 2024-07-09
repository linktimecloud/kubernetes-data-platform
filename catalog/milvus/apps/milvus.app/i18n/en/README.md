### 1. Application Description

Milvus is a cloud native vector database that has the characteristics of high availability, high performance, and easy scalability, used for real-time recall of massive vector data.

### 2. Quick Start

#### 2.1 Deployment

Milvus is deployed through KDP web and relies on Kafka and Minio. The dependent services need to be installed first.

There are two modes for running Milvus: Standalone and Cluster, default is standalone.
These two modes share the same features. You can choose a mode that best fits your dataset size, traffic data, and more. For now, Milvus standalone cannot be upgraded "online" to Milvus cluster.

#### 2.2 Practical Usage

##### 2.2.1 Get Collection

Milvus svc：milvus.kdp-data.svc.cluster.local:19530

ingress: http://milvus-kdp-data.kdp-e2e.io

Or through kubectl port-forward for testing:

```shell
kubectl port-forward svc/milvus -n kdp-data 19530:19530
```

attu ingress：http://milvus-attu-kdp-data.kdp-data.svc.cluster.local

#### 2.2.2 Using Milvus_CLI

##### Install Milvus_CLI

refer：[Install Milvus_CLI](https://milvus.io/docs/install_cli.md)

Prerequisites: `Python >= 3.8.5`

install milvus-cli by pip

```python
pip install milvus-cli
```

##### Use Milvus_CLI

1. Enter Milvus_CLI

```shell
    milvus_cli
```

2. Connect to Milvus server

   Connect Milvus using port forward method here, refer to 2.2.1 for connection information.

```shell
    connect -uri http://localhost:19530/
```

3. Database operation

```shell
    create database -db test"
    
    list databases
    
    use database -db test
    
    delete database -db test
```

4. Collection operation

```shell
    # collection basic operation
    create collection -c car -f id:INT64:primary_field -f vector:FLOAT_VECTOR:128 -f color:INT64:color -f brand:ARRAY:64:VARCHAR:128 -p id -A -desc car_collection
    
    list collections
    
    show collection -c car
    
    delete collection -c car
    
    # partition operation
    create partition -c car -p new_partition -d test_add_partition
    
    list partitions -c car
    
    drop partition -c car -p new_partition
    
    # index operation，notice：milvus_cli v0.4.3 creating index is an interactive operation that requires specifying index parameters separately
    milvus_cli > create index
    Collection name (car): car
    The name of the field to create an index for (id, vector, color, brand): vector
    Index name: vector_idx
    Index type (FLAT, IVF_FLAT, IVF_SQ8, IVF_PQ, RNSG, HNSW, ANNOY, AUTOINDEX, DISKANN, GPU_IVF_FLAT, GPU_IVF_PQ, SCANN, STL_SORT, Trie, ) []: IVF_FLAT
    Vector Index metric type (L2, IP, HAMMING, TANIMOTO, COSINE, ) []: L2
    Index params nlist: 1024
    
    list index -c car
    
    show index -c car -in vector_idx
    
    # alias
    create alias -c car -a carAlias1
    
    delete alias -a carAlias1
```

5. Data operation

```shell
    # notice: `import` is used in the document, but milvus cli v0.4.3 uses `insert`
    insert -c car 'https://raw.githubusercontent.com/linktimecloud/example-datasets/milvus/data/car.sample.100.csv'
    
    # load to RAM
    load collection -c car
    
    # milvus_cli v0.4.3 querying is an interactive operation that requires specifying query parameters separately
    milvus_cli > query
    Collection name (car): car
    Query: id in [ 450544538979460758, 450544538979460759, 450544538979460761 ]
    ...
    
    # release from RAM
    release collection -c car
```

#### 2.2.3 Using Milvus API

Refer to official documents.

-  [PyMilvus](https://github.com/milvus-io/pymilvus)
-  [Node.js SDK](https://github.com/milvus-io/milvus-sdk-node)
-  [Go SDK](https://github.com/milvus-io/milvus-sdk-go)
-  [Java SDK](https://github.com/milvus-io/milvus-sdk-java)
-  [Restful API](https://milvus.io/api-reference/restful/v2.4.x/About.md)
