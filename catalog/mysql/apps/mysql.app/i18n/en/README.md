## 1. Introduction
This document aims to provide MySQL database administrators with a comprehensive operations guide to ensure the stable operation and efficient management of MySQL databases. The document covers installation, common usage, and troubleshooting aspects.

## 2. Quick Start

### Usage Instructions

MySQL installation supports two modes:

- Standalone: Single-node mode
- Replication: Master-slave mode

After installation, connection information (stored using configmap) and user information (stored using secret) will be generated. Mounting the service with connection and user information enables direct usage of MySQL.

Connection information format (the port type in the connection information is a string; if an integer type is used, conversion is needed before usage):

Connection Information:

```shell
MYSQL_HOST: xxx
MYSQL_PORT: '3306'
```

User Information:

```shell
MYSQL_PASSWORD: xxx
MYSQL_USER: xxx
```


### Usage Practices

- **Using Python Access:**

```python
import mysql.connector

# Connect to MySQL
cnx = mysql.connector.connect(user='username', password='password', host='localhost', database='database_name')

# Create a cursor
cursor = cnx.cursor()

# Execute SQL queries
cursor.execute("SELECT * FROM table_name")

# Get query results
result = cursor.fetchall()

# Close cursor and connection
cursor.close()
cnx.close()

```


- **Using Java Access:**:

```java
  import java.sql.*;
  
  // JDBC 驱动名和数据库 URL
  static final String JDBC_DRIVER = "com.mysql.jdbc.Driver";
  static final String DB_URL = "jdbc:mysql://localhost/database_name";
  
  // 数据库的用户名和密码
  static final String USER = "username";
  static final String PASS = "password";
  
  Connection conn = null;
  Statement stmt = null;
  try{
     // 注册 JDBC 驱动
     Class.forName(JDBC_DRIVER);
  
     // 打开连接
     System.out.println("连接数据库...");
     conn = DriverManager.getConnection(DB_URL,USER,PASS);
  
     // 执行查询
     System.out.println(" 实例化Statement对象...");
     stmt = conn.createStatement();
     String sql;
     sql = "SELECT id, name, age FROM table_name";
     ResultSet rs = stmt.executeQuery(sql);
  
     // 处理结果集
     while(rs.next()){
        // 获取并打印结果集数据
        int id  = rs.getInt("id");
        String name = rs.getString("name");
        int age = rs.getInt("age");
  
        // 打印结果
        System.out.print("ID: " + id);
        System.out.print(", 姓名: " + name);
        System.out.print(", 年龄: " + age);
        System.out.println();
     }
  
     // 完成后关闭
     rs.close();
     stmt.close();
     conn.close();
  }catch(SQLException se){
     // 处理 JDBC 错误
     se.printStackTrace();
  }catch(Exception e){
     // 处理 Class.forName 错误
     e.printStackTrace();
  }finally{
     // 关闭资源
     try{
        if(stmt!=null) stmt.close();
     }catch(SQLException se2){
     }// 什么都不做
     try{
        if(conn!=null) conn.close();
     }catch(SQLException se){
        se.printStackTrace();
     }// 结束 finally try
  }// 结束 try
```


## 3. Common Problems Self-Check

- **Database Connection Issues**:
  - Check the health status of MySQL Pods to ensure they are running.
  - Review the logs of Pods to check for any startup errors or exceptions.


- **Performance Issues**:
  - Analyze slow query logs to identify performance bottlenecks.
  - Verify whether indexes are being utilized correctly.


## 4. Notices

When uninstalling MySQL, the storage is not deleted for security considerations. Upon reinstallation, the installation password must be the same as the one used before uninstallation; otherwise, MySQL will fail to start.