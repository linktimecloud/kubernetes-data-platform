### 1. 应用说明

Airflow™是一个以编程方式编写、调度和监控工作流的平台。

### 2. 快速入门

#### 2.1 部署创建

Airflow 通过KDP web部署。

#### 2.2 使用实践

##### 2.2.1 创建DAG文件

##### 2.2.3 浏览器访问airflow web

可通过配置的ingress(http://airflow-web-kdp-data.kdp-e2e.io/home)地址访问airflow web，或者通过kubectl port-forward 访问，以下为port-forward命令。

```shell
kubectl port-forward svc/airflow-webserver -n kdp-data 8080:8080
```

默认登陆用户/密码为 `admin/admin`

#### 2.2.4 配置DAG文件

DAG文件存放在git仓库中，默认安装配置的dag文件存放在git仓库中，你可以通过修改该文件来修改DAG文件。
你也可以自己fork该仓库，然后修改dags文件，然后提交到git仓库中, 在 KDP 页面安装配置修改 dag repo， branch 等，然后更新即可。

#### 2.2.4 运行DAG

DAG 默认是暂停状态，需要手动启动。手动激活（点击名称旁边的开关即可）名称`hello_airflow`的DAG即可，该DAG是每天运行一次，激活后会自动补跑昨天的任务。
也可以手动触发：点击`hello_airflow`DAG右边`Trigger DAG`按钮即可。


### 3. 常见问题自检

#### 3.1. DAG执行失败

原因与排查：

1. 检查 dag 代码同步是否成功，检查日志： `kubectl logs -l component=scheduler,release=airflow -c git-sync -n kdp-data`
2. 查看scheduler和worker pod 日志输出信息。

### 4. 附录

#### 4.1. 概念介绍

**DAG**

有向无循环图，是Airflow中用于描述工作流的基本单位。
