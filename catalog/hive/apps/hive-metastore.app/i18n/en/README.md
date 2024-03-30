### 1. Introduce

Hive Metastore(HMS) is a metadata storage system for managing metadata information of Hive tables, partitions, and columns, including table names, structures, storage locations, and data formats. Hive Metastore can store these metadata information in a variety of different back-end databases, such as MySQL, Oracle, PostgreSQL, etc. Hive Metastore can be deployed independently.

### 2. Instructions

#### 2.1. Deploy

Hive Metastore is a system application and is globally unique. If you need to deploy it, please contact the system administrator

#### 2.2. Practice

##### 2.2.1. HSQL
After the HMS service is deployed, enter the HMS container via the `kubectl` command, and then execute the `hive` command.

```shell
cd /opt/hive/bin
./hive

```
Through the following commands, you can perform metadata-related operations.

###### create table

```sql
CREATE TABLE mytable (
  id INT,
  name STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ',';
```

###### view table metadata

This command will display the table creation statement and all its metadata information, including the table name, structure, storage location, data format, etc.

```sql
SHOW CREATE TABLE mytable;
```

##### 2.2.2. java

pom.xml

```xml
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-metastore</artifactId>
    <version>3.1.3</version>
</dependency>
```

> HMS_THRIFT_URL is replaced by the thrift address of hms

```java
package com.wdlily.hive;

import lombok.extern.slf4j.Slf4j;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hive.conf.HiveConf;
import org.apache.hadoop.hive.metastore.IMetaStoreClient;
import org.apache.hadoop.hive.metastore.RetryingMetaStoreClient;
import org.apache.hadoop.hive.metastore.api.MetaException;

@Slf4j
public class HMSClient {

    private static final String HMS_THRIFT_URL = "thrift://hive-metastore-svc.admin.svc.cluster.local:9083";

    public static void main(String[] args) throws Exception {

        HiveConf conf = new HiveConf();
        conf.getAllProperties();
        conf.set(HiveConf.ConfVars.METASTOREURIS.varname, HMS_THRIFT_URL);

        IMetaStoreClient client = init(conf);

        System.out.println("===========dbs=============");
        client.getAllDatabases().forEach(System.out::println);

        System.out.println("==========tables==============");
        client.getAllTables("metrics").forEach(System.out::println);

    }

    private static IMetaStoreClient init(HiveConf conf) throws MetaException {
        try {
            return RetryingMetaStoreClient.getProxy(conf, false);
        } catch (MetaException e) {
            throw e;
        }
    }

}
```

### 3. FAQS
Q1：HMS cannot be started

check：
1. check hive-site.xml and database connection information of HMS to ensure that the database has been correctly installed and configured.
2. check logs,bdos web interface->core components->hive->hive-metastore->view log

Q2：Failed to create table

check：
1. Check whether the user has relevant permissions


Q3：Hive table metadata is lost

check：
1. Check whether the metadata storage backend database is normal
2. Whether the metadata information of the table exists in the database, and whether there is a backup



