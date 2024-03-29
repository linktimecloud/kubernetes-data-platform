### 1. 应用说明

Hive Server 2（简称HS2）是Hive的一种服务模式，它提供了一个标准的ODBC/JDBC接口，可以让其他的应用程序通过这个接口连接到Hive，从而使用Hive提供的数据仓库功能。HS2是基于Apache Thrift协议实现的，支持多种编程语言，如Java、Python、PHP、Ruby等。

### 2. 快速入门

#### 2.1. 部署创建

kdp界面->应用管理->应用市场，找到"hive-server2",点击“安装”即可

#### 2.2. 使用实践

##### 2.2.1. beeline

进入 Hive Server 2 容器。

```shell
kubectl exec -it hive-server2-0 -n kdp-data -c hive-server2 -- bash
```

进入 `beeline`。

```shell
beeline -u 'jdbc:hive2://hive-server2-0.hive-server2:10000/;auth=noSasl' -n root

> select * from mytable;
```

示例 `hql` 语句。

```sql
CREATE TABLE IF NOT EXISTS employee (
 id int,
 name string,
 age int,
 gender string )
 COMMENT 'Employee Table'
 ROW FORMAT DELIMITED
 FIELDS TERMINATED BY ',';

INSERT INTO employee values(7,'scott',23,'M');

SELECT * FROM employee;
```

**注意**：

hive-server2 的默认 spark 配置中开启了 `eventLog`，保存路径为 `hdfs:///historyservice`。在执行 INSERT 语句前要在 HDFS 中创建路径。请参考 HDFS 用户手册执行 `mkdir` 命令：

```shell
hdfs dfs -mkdir /historyservice
```

##### 2.2.2. java示例

pom.xml添加依赖
```
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-jdbc</artifactId>
    <version>3.1.3</version>
</dependency>
```

- hive-server2-host和hive-server2-port替换为Hive Server 2所在的主机和端口号，比如 `hive-server2-0.hive-server2.admin.svc.cluster.local:10000`
- mytable替换为要查询的表名

```java
import java.sql.*;

public class HiveJdbcClient {

  private static String driverName = "org.apache.hive.jdbc.HiveDriver";

  public static void main(String[] args) throws SQLException {

    Connection con = null;
    Statement stmt = null;
    ResultSet res = null;

    try {
      Class.forName(driverName);
      con = DriverManager.getConnection("jdbc:hive2://<hive-server2-host>:<hive-server2-port>/default;auth=noSasl", "", "");
      stmt = con.createStatement();
      String query = "SELECT * FROM mytable";
      res = stmt.executeQuery(query);

      while (res.next()) {
        System.out.println(res.getString(1) + "\t" + res.getString(2));
      }

    } catch (ClassNotFoundException e) {
      e.printStackTrace();
    } finally {
      try {
        if (res != null) {
          res.close();
        }
        if (stmt != null) {
          stmt.close();
        }
        if (con != null) {
          con.close();
        }
      } catch (SQLException e) {
        e.printStackTrace();
      }
    }
  }
}


```

### 3. 常见问题自检
问题一：HS2连接时出现“Connection Refused”

排查：
1. HS2服务是否正常启动
2. 确认客户端和服务端之间的防火墙是否关闭，且开放了当前端口
3. 查看日志，bdos web界面->核心组件->hive->kdp-hs2->查看日志

问题二：执行语句时出现“Permission Denied”

排查：
1. 查看用户是否有相关权限

问题三： 执行查询语句时出现“Syntax Error”

排查：
1. 语法错误


