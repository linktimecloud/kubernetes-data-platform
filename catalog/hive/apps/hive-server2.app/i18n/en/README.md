### 1. Introduce

Hive Service 2 (HS2 for short) is a service mode of Hive, which provides a standard ODBC/JDBC interface, allowing other applications to connect to Hive through this interface, so as to use the data warehouse function provided by Hive. HS2 is implemented based on the Apache Thrift protocol and supports multiple programming languages, such as Java, Python, PHP, Ruby, etc.

### 2. Instructions

#### 2.1. Deploy

- Method 1: kdp interface -> application management -> application market, find "hive-server2", click "Install"

#### 2.2. Practice

##### 2.2.1. beeline

Enter the Hive Server 2 container. Taking namespace default as an example, execute the `kubectl` command to enter the hs2 pod.

```shell
kubectl exec -it hive-server2-0 -n default -- bash
```

Execute the `beeline` command.

- Replace hive-server2-host and hive-server2-port with the host and port number of Hive Server 2,such as `hive-server2-0.hive-server2.admin.svc.cluster.local:10000`
- replace username and password with the username and password required to connect to Hive 
- mytable is replaced by the name of the table to be queried

```shell
beeline -u jdbc:hive2://<hive-server2-host>:<hive-server2-port>/default;auth=noSasl -n <username> -p <password>

> select * from mytable;
```

##### 2.2.2. java example

pom.xml 

```xml
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-jdbc</artifactId>
    <version>3.1.3</version>
</dependency>
```

- Replace hive-server2-host and hive-server2-port with the host and port number of Hive Server 2, such as `hive-server2-0.hive-server2.admin.svc.cluster.local:10000`
- mytable is replaced by the name of the table to be queried

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

### 3. FAQS
Q1：Connection Refused

check：
1. Whether the HS2 service starts normally
2. Confirm whether the firewall between the client and the server is closed, and the current port is opened
3. check logs,bdos web interface->core components->hive->hive-server2->view log

Q2：Permission Denied

check：
1. Check whether the user has relevant permissions

Q3： Syntax Error

check：
1. Grammatical errors
