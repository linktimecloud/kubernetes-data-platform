### 1. Introduce

Spark Operator is a tool developed by Google based on Operator mode, which is used to submit Spark jobs to K8s clusters in a declarative way.

Using Spark Operator to manage Spark applications can make better use of K8s native capabilities to control and manage the life cycle of Spark applications, including application status monitoring, log acquisition, application operation control, etc., making up for the Spark on K8s solution’s integration with other types of K8s gap between loads.

### 2. Instructions

#### 2.1. Deploy

Spark Operator is a system application and is globally unique. If you need to deploy it, please contact the system administrator

#### 2.2. Practice

Through Spark Operator, users can manage the life cycle of spark applications in a way that is more in line with the concept of k8s.

Spark Operator is the only application on the system, which is temporarily not open to users. It is currently used in FM(Distributed Schedule System) spark operations.