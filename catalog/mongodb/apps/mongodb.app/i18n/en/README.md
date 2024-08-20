### 1. Introduction
MongoDB is a document database with the scalability and flexibility that you want with the querying and indexing that you need.

### Basic Concepts

1. Document
- The fundamental unit of data storage in MongoDB, similar to a JSON object, consisting of key-value pairs.

1. Collection
- A container for documents, analogous to a table in relational databases.

1. Database
- A physical container for collections, with a MongoDB server capable of hosting multiple databases.

1. Field
- A key-value pair within a document, used to store specific data.

1. Index
- Used to enhance query performance, supporting various types of indexes.

1. Query
- Instructions for retrieving data from MongoDB, featuring a rich query language.

1. Aggregation
- Operations for processing data records and returning computed results, offering both aggregation pipelines and map-reduce frameworks.

1. Replica Set
- A group of MongoDB servers that maintain identical data copies, providing redundancy and high availability.

1. Sharding
- The process of distributing data across multiple servers, designed to handle large volumes of data and high throughput applications.

### 2. Quick Start

#### Using Python
```python
# Connect to MongoDB server
mongosh "mongodb://localhost:27017" -u "root" -p "root.password" 

# show databases
show dbs

# Select database
use mydatabase

# Create (Insert)
db.mycollection.insertOne({
    "name": "Alice",
    "age": 30,
    "email": "alice@example.com"
})

# Read (Find)
db.mycollection.find()

# Update
db.mycollection.updateOne(
    { "name": "Alice" },
    { $set: { "age": 31 } }
)

# Delete
db.mycollection.deleteOne({ "name": "Alice" })

# Drop collection
db.mycollection.drop()

# Drop database
db.dropDatabase()

```

#### Using Command Line
Execute the following commands in the MongoDB Pod:

```bash
# Connect to MongoDB server
mongosh "mongodb://localhost:27017" -u "root" -p "root.password" 

# show databases
show dbs

# Select database
use mydatabase

# Create (Insert)
db.mycollection.insertOne({
    "name": "Alice",
    "age": 30,
    "email": "alice@example.com"
})

# Read (Find)
db.mycollection.find()

# Update
db.mycollection.updateOne(
    { "name": "Alice" },
    { $set: { "age": 31 } }
)

# Delete
db.mycollection.deleteOne({ "name": "Alice" })

# Drop collection
db.mycollection.drop()

# Drop database
db.dropDatabase()

```


### 3. FAQ

1. **How to Reduce the Number of Shards?**
   - Refer to the official MongoDB documentation on [removing shards from a cluster](https://www.mongodb.com/docs/manual/tutorial/remove-shards-from-cluster/).
   - Since shards are Kubernetes StatefulSet workloads, you need to remove the shard with the highest number, such as `mongodb-sharded-shard-<max-number>`.
   - Then adjust the number of shards in KDP (Kubernetes Deployment Platform).

2. **How to Configure Component Numbers in a Production Environment?**
   - Consult the MongoDB documentation on [production configuration for sharded cluster components](https://www.mongodb.com/docs/manual/core/sharded-cluster-components/#production-configuration).

Additional FAQs can be found at the [MongoDB FAQ](https://www.mongodb.com/docs/manual/faq/).