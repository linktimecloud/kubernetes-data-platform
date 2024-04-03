# Hive Component Usage

## Connection Methods

### Connecting to Hive Server2 via Beeline

#### Environment Preparation

Prepare a pod for the Hive client. Create a new YAML file locally, for example, hive-client.yaml, and fill in the following content.

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

Notes:

- Set the namespace to where the `hdfs/hive-metastore/hive-server2` cluster is located.
- image use hive-metastore image
- configmap `hive-server2-context` contains the Hive Server2 configuration including `hive-site.xml`.
- configmap `hdfs-config` contains the HDFS configuration including `core-site.xml` and `hdfs-site.xml`.
- configmap `krb5-config` contains the KDC configuration including `krb5.conf`.
- pvc `home-keytab-data-pvc` contains the user's keytab.

If Kerberos is not enabled in the cluster, you can remove the `volumes/volumeMounts` for KDC/keytab.

Execute `kubectl apply -f hive-client.yaml` to create a Hive client pod.

For example, in the default namespace, execute the kubectl command to enter the Hive client pod.

```shell
kubectl exec -it hive-client -n default -- bash
```

#### Connecting in High Availability Mode

Multiple instances of hive-server2 will register their service addresses to ZooKeeper, and clients can obtain a random address from ZooKeeper.

If Kerberos is enabled, first execute kinit, then connect with Beeline.

```shell
kinit -kt /keytab/user1/user1.keytab user1
beeline -u 'jdbc:hive2://zookeeper:2181/;serviceDiscoveryMode=zookeeper;zooKeeperNamespace=default_hiveserver2/server;principal=hive/_HOST@BDOS.CLOUD'
```

If Kerberos is not enabled, you can connect directly as the root user.

```shell
beeline -u 'jdbc:hive2://zookeeper:2181/;serviceDiscoveryMode=zookeeper;zooKeeperNamespace=default_hiveserver2/server' -n root
```

> **Note**：The value to fill in for zooKeeperNamespace in the above Beeline connection string is <namespace>_hiveserver2/server. If the namespace is admin, then it should be replaced with `zooKeeperNamespace = admin_hiveserver2/server`.


#### Connecting to a Specific Hive Server2 Instance

You can also connect to a specific instance of hive-server2.

```shell
With Kerberos enabled:
beeline -u 'jdbc:hive2://hive-server2-0.hive-server2:10000/;principal=hive/_HOST@BDOS.CLOUD'
# Without Kerberos enabled:
beeline -u 'jdbc:hive2://hive-server2-0.hive-server2:10000/' -n root
```

### Connecting to Hive Server2 via Java

Configure project dependencies (hadoop-common and hive-jdbc) in the pom.xml file. The additional project dependencies for this example are as follows.

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

Write code to connect to HiveServer2 and manipulate Hive table data. The example code is as follows.

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
