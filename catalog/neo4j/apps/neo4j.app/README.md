### 1. 应用说明

Neo4j 是一个高性能的、开源的、无模式的图形数据库，专门用于存储和处理复杂的、高度互联的数据集。

### 2. 快速入门

#### 2.1 Web 访问

Ingress: `{appName}-{namespace}.kdp-e2e.io` 

默认用户名密码：`neo4j`/`password`

#### 2.2 基本 Cypher 查询

#### 创建节点

```cypher
CREATE (n:Person {name: 'Hakeedra', age: 30})
RETURN n

CREATE (n:Person {name: 'Terry', age: 30})
RETURN n
```

#### 创建关系

```cypher
MATCH (a:Person {name: 'Hakeedra'}), (b:Person {name: 'Terry'})
CREATE (a)-[r:FRIENDS]->(b)
RETURN r
```

#### 查询节点

```cypher
MATCH (n:Person)
RETURN n
```

#### 查询关系

```cypher
MATCH (a:Person)-[r:FRIENDS]->(b:Person)
RETURN a, r, b
```

#### 更新节点

```cypher
MATCH (n:Person {name: 'Hakeedra'})
SET n.age = 31
RETURN n
```

#### 删除节点

```cypher
MATCH (n:Person {name: 'Hakeedra'})
DELETE n
```

#### 删除关系

```cypher
MATCH (a:Person)-[r:FRIENDS]->(b:Person)
DELETE r
```

#### 2.3 索引和约束

#### 创建索引

```cypher
CREATE INDEX FOR (p:Person) ON (p.name)
```

#### 查看索引

```cypher
SHOW INDEXES
```

#### 删除索引

```cypher
DROP INDEX {idx_name}
```

#### 创建唯一约束

```cypher
CREATE CONSTRAINT FOR (p:Person) REQUIRE p.name IS UNIQUE
```

#### 2.4 性能优化

#### 查看查询计划

```cypher
EXPLAIN MATCH (n:Person)
RETURN n
```

#### 使用参数

```cypher
:params {name: 'Hakeedra'}
```

```cypher
MATCH (n:Person {name: $name})
RETURN n
```

#### 2.5 管理数据库

#### 查看数据库状态

```cypher
:sysinfo
```

#### 更改密码

```cypher
:server change-password
```
