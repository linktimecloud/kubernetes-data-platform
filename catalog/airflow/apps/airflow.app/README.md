### 1. 应用说明

Airflow™是一个以编程方式编写、调度和监控工作流的平台。

### 2. 快速入门

#### 2.1 部署创建

Airflow 通过KDP web部署。

#### 2.2 使用实践

##### 2.2.1 创建DAG文件

以下为一个简单的 DAG 文件，将以下内容复制到文件 demo.py 中。

```python
from datetime import datetime

from airflow import DAG
from airflow.decorators import task
from airflow.operators.bash import BashOperator

with DAG(dag_id="demo", start_date=datetime(2024, 5, 20), schedule="0 0 * * *") as dag:

    hello = BashOperator(task_id="hello", bash_command="echo hello")

    @task()
    def airflow():
        print("airflow")

    hello >> airflow()
```

##### 2.2.2 将 demo.py 文件通过kubectl 拷贝到airflow scheduler和worker pod 中

```shell
kubectl cp demo.py airflow-scheduler-7cf5ddb9c5-fql6x:/opt/airflow/dags -n kdp-data
kubectl cp demo.py airflow-worker-584b97f6cb-8gxq8:/opt/airflow/dags -n kdp-data
```

注意：使用时请修改 `kdp-data` 为你的 namespace，修改 `airflow-scheduler-7cf5ddb9c5-fql6x` 为你的 scheduler pod 名称，修改 `airflow-worker-584b97f6cb-8gxq8` 为你的 worker pod 名称。

##### 2.2.3 浏览器访问airflow web

可通过配置的ingress地址访问airflow web，或者通过kubectl port-forward 访问，以下为port-forward命令。

```shell
kubectl port-forward svc/airflow-webserver -n kdp-data 8080:8080
```

默认登陆用户/密码为 `admin/admin`

#### 2.2.4 查看DAG以及任务执行

当前配置的scheduler扫描频率为1分钟，在web页面可见demo DAG，点击右侧 `Trigger DAG` 按钮，即可触发DAG执行。

### 3. 常见问题自检

#### 3.1. DAG执行失败

原因与排查：

1. 检查scheduler和worker pod 中 `/opt/airflow/dags` 目录下是否均存在 demo.py 文件；
2. 查看scheduler和worker pod 日志输出信息。

### 4. 附录

#### 4.1. 概念介绍

**DAG**

有向无循环图，是Airflow中用于描述工作流的基本单位。
