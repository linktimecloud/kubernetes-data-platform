### 1. Application Description

Neo4j is a high-performance, open-source, schema free graphics database specifically designed for storing and processing complex, highly interconnected datasets.

### 2. Quick Start

#### 2.1 Web Access

Ingress: `{appName}-{namespace}.kdp-e2e.io`

Default user name and password: `neo4j`/`password`

#### 2.2 Basic Cypher Query

#### Create Nodes

```cypher
CREATE (n:Person {name: 'Hakeedra', age: 30})
RETURN n

CREATE (n:Person {name: 'Terry', age: 30})
RETURN n
```

#### Create Relationships

```cypher
MATCH (a:Person {name: 'Hakeedra'}), (b:Person {name: 'Terry'})
CREATE (a)-[r:FRIENDS]->(b)
RETURN r
```

#### Select Nodes

```cypher
MATCH (n:Person)
RETURN n
```

#### Select Relationships

```cypher
MATCH (a:Person)-[r:FRIENDS]->(b:Person)
RETURN a, r, b
```

#### Update Nodes

```cypher
MATCH (n:Person {name: 'Hakeedra'})
SET n.age = 31
RETURN n
```

#### Delete Nodes

```cypher
MATCH (n:Person {name: 'Hakeedra'})
DELETE n
```

#### Delete Relationships

```cypher
MATCH (a:Person)-[r:FRIENDS]->(b:Person)
DELETE r
```

#### 2.3 Indexes and Constraints

#### Create Index

```cypher
CREATE INDEX FOR (p:Person) ON (p.name)
```

#### Show Index

```cypher
SHOW INDEXES
```

#### Delete Index

```cypher
DROP INDEX {idx_name}
```

#### Create Unique Constraint

```cypher
CREATE CONSTRAINT FOR (p:Person) REQUIRE p.name IS UNIQUE
```

#### 2.4 Performance Optimization

#### Show Query Plan

```cypher
EXPLAIN MATCH (n:Person)
RETURN n
```

#### Use Parameters

```cypher
:params {name: 'Hakeedra'}
```

```cypher
MATCH (n:Person {name: $name})
RETURN n
```

#### 2.5 Manage Databases

#### Show Database Status 

```cypher
:sysinfo
```

#### Change Password

```cypher
:server change-password
```





