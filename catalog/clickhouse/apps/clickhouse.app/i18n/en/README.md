### 1. Application Description
ClickHouse is a high-performance, column-oriented SQL database management system (DBMS) for online analytical processing (OLAP). 

### 2. Quick Start

#### 2.1 Deployment Creation
KDP interface -> Application Management -> App Market, find "clickhouse", click "Install".

#### 2.2 Practical Use

##### 2.2.1 Usage Method (Shell)
Use `kubectl` to enter any clickhouse container.

```shell
kubectl exec -it clickhouse-shard0-0 -n kdp-data -c clickhouse -- bash
```

```shell
# Enter the clickhouse-client. <user> and <password> need to be replaced with real credentials.
clickhouse-client --user <user> --password <password>

# Execute SQL
show databases;
show tables;
```

For more examples, please refer to the [official tutorial](https://clickhouse.com/docs/en/getting-started/tutorial).