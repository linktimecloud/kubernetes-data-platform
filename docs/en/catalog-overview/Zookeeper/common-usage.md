# Zookeeper Component Usage

## Connection Method

To connect, use `kubectl` to enter any zookeeper container. For example, to enter the zookeeper container in the default namespace:

```shell
kubectl exec -it zookeeper-0 -n default -c zookeeper -- bash
```

Enter the zookeeper cli:

```shell
zkCli.sh
```

After a successful connection, you can input 'help' to display all available commands.


