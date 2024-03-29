### 1. Description

Schema Registry is a service for managing and storing metadata of Avro, JSON schema and Protobuf schema types. It stores historical versions of all schemas according to a specific policy, provides multiple compatibility settings, and allows setting and limiting schema extensions based on configured compatibility settings. It provides the serializer of the Kafka client for easy integration with Kafka.

Schema Registry allows different producers and consumers to share and verify Schema in a centralized way to ensure data compatibility and consistency. When the producer sends the data to Kafka, the Schema used to serialize the data is stored in the Schema Registry. In this way, when consumers read data, they can obtain the Schema through the Schema Registry and deserialize the data correctly.

Schema Registry provides a simple and reliable way to manage and coordinate data transmitted in Kafka to ensure data consistency.

### 2. Quick Start

#### 2.1. Use by kafka manager

##### 2.1.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that the schema registry has been deployed.

##### 2.1.2. Schema registry usage

**create schema**

1. Log in KDP kafka manager

2. Click the schema registry on the left, and click the "Create a Subject" button at the bottom right of the page

3. Enter the schema name in name, enter the following content in Schema and click "Create" in the lower right corner to create

 ```json
    {
     "type": "record",
     "name": "KdpUser",
     "namespace": "com.Kdp.example",
     "fields": [
        {
         "name": "name",
         "type": "string"
        },
        {
         "name": "favorite_number",
         "type": [
           "int",
           "null"
          ]
        },
        {
         "name": "favorite_color",
         "type": [
           "string",
           "null"
          ]
        }
      ]
    }
 ```

4. Check whether the created schema is successful.

**Modify schema**

1. Log in to the KDP kafka manager.
2. Click the schema registry on the left, and click the view button on the right of the schema.
3. After modifying the information in Latest Schema, click Update to save.

**delete schema**

1. Log in to the KDP kafka manager.
2. Click the schema registry on the left, and click the delete button on the right of the schema.



#### 2.2. Use via restful api

##### 2.2.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that the schema registry has been deployed.

##### 2.2.2. Resource preparation

- In KDP Big Data Cluster Management - Cluster Information - Application Usage Configuration, get the host and port in schema-registry.

##### 2.2.3. Schema registry usage

```shell
# set env
export schema_registry_address=【The schema registry address obtained in 2.2.2】
export schema_registry_port=【schema registry port obtained in 2.2.2】

# Register a new version of a schema under the subject "Kafka-key"
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "{\"type\": \"string\"}"}' \
     http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-key/versions
   {"id":1}

# Register a new version of a schema under the subject "Kafka-value"
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "{\"type\": \"string\"}"}' \
      http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions
   {"id":1}

# List all subjects
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects
   ["Kafka-value","Kafka-key"]

# List all schema versions registered under the subject "Kafka-value"
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions
   [1]

# Fetch a schema by globally unique id 1
curl -X GET http://${schema_registry_address}:${schema_registry_port}/schemas/ids/1
   {"schema":"\"string\""}

# Fetch version 1 of the schema registered under subject "Kafka-value"
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/1
   {"subject":"Kafka-value","version":1,"id":1,"schema":"\"string\""}

# Fetch the most recently registered schema under subject "Kafka-value"
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/latest
   {"subject":"Kafka-value","version":1,"id":1,"schema":"\"string\""}

# Delete version 3 of the schema registered under subject "Kafka-value"
curl -X DELETE http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/3
   3

# Check whether a schema has been registered under subject "Kafka-key"
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "{\"type\": \"string\"}"}' \
     http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-key
   {"subject":"Kafka-key","version":1,"id":1,"schema":"\"string\""}

# Test compatibility of a schema with the latest schema under subject "Kafka-value"
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "{\"type\": \"string\"}"}' \
     http://${schema_registry_address}:${schema_registry_port}/compatibility/subjects/Kafka-value/versions/latest
   {"is_compatible":true}

# Get top level config
curl -X GET http://${schema_registry_address}:${schema_registry_port}/config
   {"compatibilityLevel":"BACKWARD"}

# Update compatibility requirements under the subject "Kafka-value"
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"compatibility": "BACKWARD"}' \
     http://${schema_registry_address}:${schema_registry_port}/config/Kafka-value
   {"compatibility":"BACKWARD"}
```

### 3. Frequently Asked Questions

#### 1. The schema registry cannot be updated

Reason and troubleshooting:

1. Set the compatibilityLevel to "BACKWARD": If backward compatibility is set, the new version of the schema must be compatible with the old version when updating, otherwise it cannot be updated.