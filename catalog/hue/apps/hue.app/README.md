### 1. 介绍
Hue 是一个基于 Web 的 Apache Hadoop 分析工具。它支持 SQL 编辑和执行、浏览 HDFS、浏览和编辑 Hive 表等功能。


### 2. 快速开始

#### 2.1 登陆
在 Hue 登录页面使用账号`root`登录即可（请勿使用其他账号登录，否则可能会导致权限问题），无需密码。

#### 2.2 HDFS 操作
注意：如果使用`root`用户需要提前在 HDFS 中创建目录（可在 hdfs pod 容器内执行参考命令 `hdfs dfs -mkdir -p /user/root`），否则无法正常访问页面。 

登陆后可以在左侧导航栏中找到 "Files" 选项卡，即可浏览 HDFS 文件系统。也可以重命名，上传，下载，删除文件。

#### 2.3 Hive 操作
登陆后可以在左侧导航栏中找到 "Tables" 选项卡，即可浏览 Hive 表。可以使用 SQL 编辑器执行 SQL 语句，通过SQL来探索数据。如果有删除和修改权限，也可以通过SQL进行删除和修改操作。

```sql
use default;
-- 创建表
CREATE TABLE my_table (
  id INT,
  name STRING,
  age INT
);
 
-- 查询表
SELECT * FROM my_table;
 
-- 插入数据
INSERT INTO my_table VALUES (1, 'John', 25);
INSERT INTO my_table VALUES (2, 'Alice', 30);
 
-- 查询表
SELECT * FROM my_table;
 
-- 删除表
DROP TABLE my_table;

```




