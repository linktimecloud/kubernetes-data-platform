### 1. 应用说明

Apache ZooKeeper是一个分布式的开源协调服务，它提供了一组简单的API来管理和协调分布式应用程序。ZooKeeper主要用于解决分布式应用程序中的命名、配置管理、状态同步等问题。它可以帮助开发人员构建可靠、高性能、分布式系统，同时还具有高可用性和容错性。

### 2. 快速入门

#### 2.1 部署创建

Zookeeper 由系统管理员创建发布，用户可直接使用。

#### 2.2 使用实践

##### 2.2.1 使用方式(Shell)

通过 `kubectl` 进入任意 zookeeper 容器。

```shell
kubectl exec -it zookeeper-0 -n kdp-data -c zookeeper -- bash
```

```shell
# 进入 zkCli
zkCli.sh

# 查看节点
ls /

# 创建永久节点
create /test "test"

# 创建顺序永久节点
create -s /test "test"

# 创建临时节点
create -e /test "test"

# 创建顺序临时节点
create -s -e /test "test"

# 查看节点
get /test

# 删除节点
delete /test
```

##### 2.2.1 使用方式(java)
    
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

```xml
<dependency>
   <groupId>org.apache.zookeeper</groupId>
   <artifactId>zookeeper</artifactId>
   <version>3.8.3</version>
</dependency>
```

### 3. 附录

#### 3.1. 概念介绍

**持久节点**

这类节点被创建后，就会一直存在于Zk服务器上。直到手动删除。如果客户端与Zk服务器断开连接，这类节点不会被删除。

**持久顺序节点**

它的基本特性同持久节点，不同在于增加了顺序性。并且Zk会为这类节点自动添加一个单调递增的后缀，作为这个节点的名称。

**临时节点**

临时节点的生命周期与客户端的会话绑定，一旦客户端会话失效（非TCP连接断开），那么这个节点就会被自动清理掉。zk规定临时节点只能作为叶子节点。

**临时顺序节点**

基本特性同临时节点，添加了顺序的特性。
