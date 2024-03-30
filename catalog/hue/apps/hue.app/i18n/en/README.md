### 1. Introduction
Hue is a Web-based Apache Hadoop analysis tool. It supports SQL editing and execution, browsing HDFS, browsing and editing Hive tables, etc.

### 2. Quick Start

#### 2.1 Login
Use the account `root` to log in to the Hue login page (do not use other accounts to log in, otherwise it may cause permission issues), no password is required.

#### 2.2 HDFS Operations
Note: If you use the `root` user, you need to create a directory in HDFS in advance (you can execute the reference command `hdfs dfs -mkdir -p /user/root` in the hdfs pod container), otherwise you will not be able to access the page normally.

After logging in, you can find the "Files" tab in the left navigation bar to browse the HDFS file system. You can also rename, upload, download, and delete files.

#### 2.3 Hive Operations
After logging in, you can find the "Tables" tab in the left navigation bar to browse the Hive table. You can use the SQL editor to execute SQL statements and explore data through SQL. If you have delete and modify permissions, you can also delete and modify them through SQL.

```sql
use default;
-- Create a table
CREATE TABLE my_table (
  id INT,
  name STRING,
  age INT
);
 
-- Query the table
SELECT * FROM my_table;
 
-- Insert data
INSERT INTO my_table VALUES (1, 'John', 25);
INSERT INTO my_table VALUES (2, 'Alice', 30);
 
-- Query the table
SELECT * FROM my_table;
 
-- Delete the table
DROP TABLE my_table;

```


