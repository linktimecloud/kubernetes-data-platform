### 1. 应用说明

Spark Operator是Google基于Operator模式开发的一款的工具, 用于通过声明式的方式向K8s集群提交Spark作业。

使用Spark Operator管理Spark应用,能更好的利用K8s原生能力控制和管理Spark应用的生命周期,包括应用状态监控、日志获取、应用运行控制等,弥补Spark on K8s方案在集成K8s上与其他类型的负载之间存在的差距。

### 2. 快速入门

#### 2.1. 部署创建

Spark Operator是系统应用，是全局唯一的，如果需要部署请联系系统管理员

#### 2.2. 使用说明

通过Spark Operator，用户可以使用更加符合k8s理念的方式来管理spark应用的生命周期。

将以下内容保存到文件 sparkApp.yaml

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: kdp-data
spec:
  type: Scala
  mode: cluster
  image: spark:scala
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: local:///opt/spark/examples/jars/spark-examples_2.12-3.3.0.jar
```

然后执行 `kubectl apply -f sparkApp.yaml`

更多信息详见 Spark on k8s operator [用户指南](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator/blob/master/docs/user-guide.md)。

