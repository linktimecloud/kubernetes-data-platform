## 1. 应用说明

本文档旨在为 MySQL 数据库管理员提供一份全面的运维指南，以确保 MySQL 数据库的稳定运行和高效管理。文档覆盖了安装、使用常见问题处理等方面的内容。

## 2. 快速入门

### 2.1 使用说明
mysql 安装支持2中模式:  

- standalone: 单机模式
- replication: 主备模式  

安装完成后会生成连接信息(使用configmap存储)、用户信息(使用secrect存储)，服务挂载连接信息和用户信息就可以直接使用mysql了
连接信息格式(连接信息中端口类型为字符串，如使用整数类型需在使用前转换)

连接信息:

```shell
MYSQL_HOST: xxx
MYSQL_PORT: '3306'
```

用户信息:

```shell
MYSQL_PASSWORD: xxx
MYSQL_USER: xxx
```



### 2.2 使用实践

- **使用Python接入**:

```python
  import mysql.connector

  # 连接 MySQL
  cnx = mysql.connector.connect(user='username', password='password', host='localhost', database='database_name')

  # 创建游标
  cursor = cnx.cursor()

  # 执行 SQL 查询
  cursor.execute("SELECT * FROM table_name")

  # 获取查询结果
  result = cursor.fetchall()

  # 关闭游标和连接
  cursor.close()
  cnx.close()
```

- **使用Java接入**:

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

## 3. 常见问题自检

- **数据库连接问题**：
  - 检查MySQL Pod的健康状态，确保它们处于运行状态。
  - 查看Pod的日志以检查是否有任何启动错误或异常。


- **性能问题**：
  - 分析慢查询日志，找出性能瓶颈。
  - 检查索引是否正确使用。


## 4. 注意事项

mysql在使用后卸载，基于安全性考虑不会删除存储，再次安装时安装密码需填写卸载前使用的密码，否则mysql无法启动
