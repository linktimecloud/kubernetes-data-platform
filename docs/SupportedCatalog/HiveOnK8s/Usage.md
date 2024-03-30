# Hive 组件使用

## 连接方式

### 通过 Beeline 方式连接 Hive Server2

#### 环境准备

准备一个 hive 客户端的 pod。在本地新建一个 yaml 文件，比如 hive-client.yaml，填入以下内容。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hive-client
  namespace: default
  labels:
    app: hive-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hive-client
  template:
    metadata:
      labels:
        app: hive-client
    spec:
      volumes:
        - name: hive-config
          configMap:
            name: hive-server2-context
            defaultMode: 420
        - name: hdfs-config
          configMap:
            name: hdfs-config
            defaultMode: 420
        - name: kerberos-config
          configMap:
            name: krb5-config
            defaultMode: 420
        - name: user-keytab
          persistentVolumeClaim:
            claimName: home-keytab-data-pvc
      containers:
        - name: hive-client
          image: od-registry.linktimecloud.com/ltc-hms:3.1.3-1.17
          command:
            - tail
            - '-f'
            - /dev/null
          env: []
          resources:
            limits:
              cpu: '2'
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 512Mi
          volumeMounts:
            - name: hive-config
              readOnly: true
              mountPath: /opt/hive/conf/hive-site.xml
              subPath: hive-site.xml
            - name: hdfs-config
              readOnly: true
              mountPath: /opt/hive/conf/core-site.xml
              subPath: core-site.xml
            - name: hdfs-config
              readOnly: true
              mountPath: /opt/hive/conf/hdfs-site.xml
              subPath: hdfs-site.xml
            - name: kerberos-config
              readOnly: true
              mountPath: /etc/krb5.conf
              subPath: krb5.conf
            - name: user-keytab
              readOnly: true
              mountPath: /keytab
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: devregistry
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - hive-client
              topologyKey: kubernetes.io/hostname

```

注意事项：

- namespace 设为 hdfs/hive-metastore/hive-server2 所在集群
- image 使用 hive-metastore 的镜像
- configmap `hive-server2-context` 是包含了 `hive-site.xml` 的 hive server2 配置
- configmap `hdfs-config` 是包含了 `core-site.xml` 和 `hdfs-site.xml` 的 HDFS 配置
- configmap `krb5-config` 是包含了 `krb5.conf` 的 KDC 配置
- pvc `home-keytab-data-pvc` 中有用户的 keytab

如果集群没有开启 Kerberos，可以删除上面的 KDC/keytab 的 volumes/volumeMounts

执行 `kubectl apply -f hive-client.yaml`，这样就创建了一个 hive 客户端 pod。

以 namespace default 为例，执行 `kubectl` 命令进入 hive 客户端 pod

```shell
kubectl exec -it hive-client -n default -- bash
```

#### 以高可用方式连接

多个 hive-server2 实例会将服务地址注册到 zookeeper 中，客户端可以从 zookeeper 获得一个随机地址。

如果开启了 Kerberos，先执行 kinit，再执行 beeline 连接

```shell
kinit -kt /keytab/user1/user1.keytab user1
beeline -u 'jdbc:hive2://zookeeper:2181/;serviceDiscoveryMode=zookeeper;zooKeeperNamespace=default_hiveserver2/server;principal=hive/_HOST@BDOS.CLOUD'
```

如果没有开启 Kerberos，可以直接以 root 用户身份连接

```shell
beeline -u 'jdbc:hive2://zookeeper:2181/;serviceDiscoveryMode=zookeeper;zooKeeperNamespace=default_hiveserver2/server' -n root
```

> **注意**：上面的 beeline 连接串中的 `zooKeeperNamespace` 要填的值是 **\<namespace\>**_hiveserver2/server。如果 namespace 是 `admin`，那么要替换为 zooKeeperNamespace = **admin**_hiveserver2/server

#### 连接指定 Hive Server2 实例

也可以连接一个指定的 hive-server2 实例。

```shell
开启 Kerberos
beeline -u 'jdbc:hive2://hive-server2-0.hive-server2:10000/;principal=hive/_HOST@BDOS.CLOUD'
# 关闭 Kerberos
beeline -u 'jdbc:hive2://hive-server2-0.hive-server2:10000/' -n root
```

### 通过 Java 连接 Hive Server2

在 pom.xml 文件中配置项目依赖（hadoop-common 和 hive-jdbc）。本示例新增的项目依赖如下所示。

```xml
<dependencies>
  <dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-jdbc</artifactId>
    <version>3.1.3</version>
  </dependency>
  <dependency>
    <groupId>org.apache.hadoop</groupId>
    <artifactId>hadoop-common</artifactId>
    <version>3.1.1</version>
  </dependency>
</dependencies>
```

编写代码，连接 HiveServer2 并操作 Hive 表数据。示例代码如下所示。

```java
import java.sql.*;

public class App
{
    private static String driverName = "org.apache.hive.jdbc.HiveDriver";

    public static void main(String[] args) throws SQLException {

        try {
            Class.forName(driverName);
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }

        Connection con = DriverManager.getConnection(
            "jdbc:hive2://hive-server2-0.hive-server2:10000", "root", "");

        Statement stmt = con.createStatement();

        String sql = "select * from sample_tbl limit 10";
        ResultSet res = stmt.executeQuery(sql);

        while (res.next()) {
            System.out.println(res.getString(1) + "\t" + res.getString(2));
        }

    }
}
```
