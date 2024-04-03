# Flink Best Practices

## 1.Using Custom UDFs

To enhance the Flink program, you can add a UDF (User-Defined Function) that provides a string substring feature

```pom
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.linktimecloud</groupId>
    <artifactId>udf</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-table-common</artifactId>
            <version>1.14.4</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>

```

SubstringFunction.java file:

```java
package com.linktimecloud.udf;
import org.apache.flink.table.functions.ScalarFunction;

public class SubstringFunction extends ScalarFunction {
  public String eval(String s, Integer begin, Integer end) {
    return s.substring(begin, end);
  }
}
```

Place the packaged jar in the /opt/flink/lib directory (you can build a new image, place the jar in the image, mount it, or use StreamPark), and then use it in Flink SQL.

Usage Example:

```sql
CREATE TABLE datagen (
    f_sequence INT,
    f_random INT,
    f_random_str STRING,
    ts AS localtimestamp,
    WATERMARK FOR ts AS ts
  ) WITH (
    'connector' = 'datagen',
    -- optional options --
    'rows-per-second'='5',
    'fields.f_sequence.kind'='sequence',
    'fields.f_sequence.start'='1',
    'fields.f_sequence.end'='50000',
    'fields.f_random.min'='1',
    'fields.f_random.max'='500',
    'fields.f_random_str.length'='10'
  );

  CREATE TABLE print_table (
    f_sequence INT,
    f_random INT,
    f_random_str STRING
    ) WITH (
    'connector' = 'print'
  );

-- create function
CREATE FUNCTION SubstringFunction as 'com.linktimecloud.udf.SubstringFunction';
INSERT INTO print_table select f_sequence,f_random, SubstringFunction(f_random_str,1,3) from datagen;
```

## 2.Importing MySQL Data into Kafka

```sql
-- mysql to kafka [office test]
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'execution.checkpointing.interval' = '3s';

CREATE TABLE mysql_table (
    `id` INT,
    `name` STRING,
    PRIMARY KEY(id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '<your-mysql-host>',
    'port' = '<your-mysql-port>',
    'username' = '<your-mysql-username>',
    'password' = '<your-mysql-password>',
    'database-name' = '<your-mysql-database>',
    'table-name' = '<your-mysql-table>',
)
;

-- Currently, the Kerberos authentication keytab file is located at /opt/kerberos/kerberos-keytab/dcos.keytab
CREATE TABLE KafkaTable (
    `id` INT,
    `name` STRING,
    PRIMARY KEY(id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '<your-kafka-topic>',
    'key.format' = 'json',
    'value.format' = 'json',
    'properties.bootstrap.servers' = '<your-kafka-broker>',
    'properties.security.protocol' = 'SASL_PLAINTEXT',
    'properties.sasl.mechanism' = 'GSSAPI',
    'properties.sasl.kerberos.service.name' = 'kafka',
    'properties.sasl.jaas.config' = 'com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keytab="/opt/kerberos/kerberos-keytab/dcos.keytab" principal="dcos";'
)
;

INSERT INTO KafkaTable SELECT * FROM km_connection;

```
