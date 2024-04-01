# Zookeeper 组件使用

## 连接方式

通过 `kubectl` 进入任意 zookeeper 容器。例如进入 namespace default 内的 zookeeper 容器：

```shell
kubectl exec -it zookeeper-0 -n default -c zookeeper -- bash
```

进入 zookeeper cli

```shell
zkCli.sh
```

连接成功后，即可输入help显示所有命令。
