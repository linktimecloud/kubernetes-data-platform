# Hive 开发指南

## 自定义函数（UDF）

### 背景信息

UDF分类如下表。

| UDF分类                                    | 描述                                                                                               |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| UDF（User Defined Scalar Function）        | 自定义标量函数，通常称为UDF。其输入与输出是一对一的关系，即读入一行数据，写出一条输出值。          |
| UDTF（User Defined Table-valued Function） | 自定义表值函数，用来解决一次函数调用输出多行数据场景的，也是唯一一个可以返回多个字段的自定义函数。 |
| UDAF（User Defined Aggregation Function）  | 自定义聚合函数，其输入与输出是多对一的关系，即将多条输入记录聚合成一条输出值，可以与SQL中的Group By语句联合使用。 |

### 开发UDF

使用IDE，创建Maven工程。

工程基本信息如下，您可以自定义groupId和artifactId。

```xml
<groupId>org.example</groupId>
<artifactId>hiveudf</artifactId>
<version>1.0-SNAPSHOT</version>
```

添加pom依赖。

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

创建一个类，继承Hive UDF类。

类名您可以自定义，本文示例中类名为MyUDF。

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

将自定义的代码打成JAR包。

在pom.xml所在目录，执行如下命令制作JAR包。

```shell
mvn clean package -DskipTests
```

target目录下会出现hiveudf-1.0-SNAPSHOT.jar的JAR包，即代表完成了UDF开发工作。

### 使用UDF

将 JAR包拷贝到任意hdfs容器，然后进入该容器。以 namespace default内的 hdfs-namenode-0 为例

```shell
kubectl cp hiveudf-1.0-SNAPSHOT.jar default/hdfs-namenode-0:/hiveudf-1.0-SNAPSHOT.jar -c hdfs-namenode
kubectl exec -it hdfs-namenode-0 -n default -c hdfs-namenode -- bash
```

上传JAR包至HDFS。

```shell
hdfs dfs -put hiveudf-1.0-SNAPSHOT.jar /user/hive/warehouse/
```

您可以通过 `hdfs dfs -ls /user/hive/warehouse/` 命令，查看是否上传成功。待返回信息如下所示表示上传成功。

```
Found 1 items
-rw-r--r--   1 xx xx 2668 2021-06-09 14:13 /user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar
```

创建UDF函数。

参考[Hive 基础使用](./02-usage-basic.md#通过-beeline-方式连接-hive-server2)进入beeline命令行。

执行以下命令，应用生成的JAR包创建函数。

```shell
create function myfunc as "org.example.MyUDF" using jar "hdfs:///user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar";
```

代码中的`myfunc`是UDF函数的名称，`org.example.MyUDF`是开发UDF中创建的类，`hdfs:///user/hive/warehouse/hiveudf-1.0-SNAPSHOT.jar`为上传JAR包到HDFS的路径。

当出现以下信息时，表示创建成功。

```
Added [/private/var/folders/2s/wzzsgpn13rn8rl_0fc4xxkc00000gp/T/40608d4a-a0e1-4bf5-92e8-b875fa6a1e53_resources/hiveudf-1.0-SNAPSHOT.jar] to class path
Added resources: [hdfs:///user/hive/warehouse/myfunc/hiveudf-1.0-SNAPSHOT.jar]
```

执行以下命令，使用UDF函数。

该函数与内置函数使用方式一样，直接使用函数名称即可访问。

```sql
select myfunc("abc");
```

返回如下信息。

```
OK
abc:HelloWorld
```
