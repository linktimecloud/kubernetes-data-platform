### 1. Application introduction

Apache ZooKeeper is a distributed open-source coordination service that provides a set of simple APIs for managing and coordinating distributed applications. ZooKeeper is primarily used to solve problems such as naming, configuration management, and state synchronization in distributed applications. It can help developers build reliable, high-performance, distributed systems while also being highly available and fault-tolerant.

### 2. Quick start

#### 2.1 Deployment creation

Zookeeper is created and published by system administrators, and users can use it directly.

#### 2.2 Usage practice

##### 2.2.1 Usage mode (Shell)

Enter any Zookeeper container using `kubectl`. For example, to enter a Zookeeper container in the namespace default:

```shell
kubectl exec -it zookeeper-0 -n default -c zookeeper -- bash
```

```shell
# Enter zkCli
zkCli.sh

# View node
ls /

# Create permanent node
create /test "test"

# Create sequential permanent node
create -s /test "test"

# Create temporary node
create -e /test "test"

# Create sequential temporary node
create -s -e /test "test"

# View node
get /test

# Delete node
delete /test
```

##### 2.2.1 Usage mode (java)

```java
public class ZookeeperTest {
    public static void main(String[] args) throws Exception {
        ZooKeeper zk = new ZooKeeper("zookeeper.admin.svc.cluster.local:2181", 3000, new Watcher() {
            @Override
            public void process(WatchedEvent event) {
                System.out.println("event:" + event);
            }
        });
        
        String path = zk.create("/test1", "test".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT);
        System.out.println(new String(zk.getData(path, false, null)));
        zk.delete(path, -1);

        path = zk.create("/test2", "test".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT_SEQUENTIAL);
        System.out.println(new String(zk.getData(path, false, null)));
        zk.delete(path, -1);

        path = zk.create("/test3", "test".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.EPHEMERAL);
        System.out.println(new String(zk.getData(path, false, null)));

        path = zk.create("/test4", "test".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.EPHEMERAL_SEQUENTIAL);
        System.out.println(new String(zk.getData(path, false, null)));
    }
}
```

### 3. Appendix

#### 3.1. Concept

**PERSISTENT Node**

Once nodes of this type created, they will persist on the Zk server until they are manually deleted. If the client disconnects from the Zk server, nodes of this type will not be deleted.

**PERSISTENT_SEQUENTIAL Node**

Its basic feature is the same as a persistent node, but it has an additional feature of sequential ordering. Zk automatically adds a monotonically increasing suffix to the name of this type of node as its identifier.

**EPHEMERAL Node**

The lifespan of an ephemeral node is bound to the client's session. Once the client session becomes invalid (not due to a TCP connection disconnect), the ephemeral node is automatically removed. Zk specifies that ephemeral nodes can only be used as leaf nodes.

**EPHEMERAL_SEQUENTIAL Node**

The basic feature is the same as an ephemeral node, with the addition of sequential ordering.
