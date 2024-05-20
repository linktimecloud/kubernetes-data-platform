### 1. 应用说明

ClickHouse是一个用于联机分析(OLAP)的列式数据库管理系统(DBMS)。

### 2. 快速入门

#### 2.1 部署创建

kdp界面->应用管理->应用市场，找到 "clickhouse"，点击“安装”。

#### 2.2 使用实践

##### 2.2.1 使用方式(Shell)

通过 `kubectl` 进入任意 clickhouse 容器。

```shell
kubectl exec -it clickhouse-shard0-0 -n kdp-data -c clickhouse -- bash
```

```shell
# 进入 clickhouse-client。<user> 和 <password> 需要替换成真实账密。
clickhouse-client --user <user> --password <password>

# 执行 SQL
show databases;
show tables;
```

更多示例请参考[官方教程](https://clickhouse.com/docs/zh/getting-started/tutorial)。