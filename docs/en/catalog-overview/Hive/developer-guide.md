# Hive Developer Guide

## Custom Functions (UDFs)

### Background Information

UDFs are categorized as shown in the table below.

| UDF Category                                    | Description                                                                                               |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| UDF（User Defined Scalar Function）        | Custom scalar functions, commonly known as UDFs. They have a one-to-one input-to-output relationship, meaning they read one line of data and output a single value.        |
| UDTF（User Defined Table-valued Function） | Custom table-valued functions, used to handle scenarios where a single function call outputs multiple lines of data. It is also the only UDF that can return multiple fields. |
| UDAF（User Defined Aggregation Function）  | Custom aggregation functions, which have a many-to-one input-to-output relationship, aggregating multiple input records into a single output value. They can be used in conjunction with SQL's GROUP BY clause. |

### Developing UDFs

Using an IDE, create a Maven project.

The basic project information is as follows; you can customize the groupId and artifactId.

```xml
<groupId>org.example</groupId>
<artifactId>hiveudf</artifactId>
<version>1.0-SNAPSHOT</version>
```

Add Maven dependencies.

```xml
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-exec</artifactId>
    <version>2.3.7</version>
    <exclusions>
        <exclusion>
          <groupId>org.pentaho</groupId>
          <artifactId>*</artifactId>
        </exclusion>
    </exclusions>
</dependency>
```

Create a class that extends the Hive UDF class.

You can customize the class name; in this example, the class name is MyUDF.

```java
package org.example;

import org.apache.hadoop.hive.ql.exec.UDF;

/**
 * Hello world!
 */
public class MyUDF extends UDF
{
    public String evaluate(final String s) {
        if (s == null) { return null; }
        return s + ":HelloWorld";
    }
}
```

Package the custom code into a JAR file.

In the directory where pom.xml is located, execute the following command to create the JAR file.


```shell
mvn clean package -DskipTests
```

In the directory where pom.xml is located, execute the following command to create the JAR file.

### Using UDFs

Copy the JAR package to any HDFS container, then enter that container. For example, using `hdfs-namenode-0` in the default namespace:

```shell
kubectl cp hiveudf-1.0-SNAPSHOT.jar default/hdfs-namenode-0:/hiveudf-1.0-SNAPSHOT.jar -c hdfs-namenode
kubectl exec -it hdfs-namenode-0 -n default -c hdfs-namenode -- bash
```

Upload the JAR package to HDFS.

```shell
hdfs dfs -put hiveudf-1.0-SNAPSHOT.jar /user/hive/warehouse/
```

You can use the command `hdfs dfs -ls /user/hive/warehouse/` to check if the upload was successful. The returned message indicating success is as follows:

```
Found 1 items
-rw-r--r--   1 xx xx 2668 2021-06-09 14:13 /user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar
```

Create a UDF function.

Refer to the [basic usage of Hive](./02-usage-basic.md#通过-beeline-方式连接-hive-server2) to enter the beeline command line.

Execute the following command to create a function using the generated JAR package.


```shell
create function myfunc as "org.example.MyUDF" using jar "hdfs:///user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar";
```


In the code, `myfunc` is the name of the UDF function, `org.example.MyUDF` is the class created during the development of the UDF, and `hdfs:///user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar` is the path where the JAR package was uploaded to HDFS.

When the following message appears, it indicates that the creation was successful.

```
Added [/private/var/folders/2s/wzzsgpn13rn8rl_0fc4xxkc00000gp/T/40608d4a-a0e1-4bf5-92e8-b875fa6a1e53_resources/hiveudf-1.0-SNAPSHOT.jar] to class path
Added resources: [hdfs:///user/hive/warehouse/myfunc/hiveudf-1.0-SNAPSHOT.jar]
```

Execute the following command to use the UDF function.

The function is used in the same way as built-in functions; simply use the function name to access it.

```sql
select myfunc("abc");
```

Return the following information.

```
OK
abc:HelloWorld
```
