### 1. Application Description

Airflow™ is a platform created by the community to programmatically author, schedule and monitor workflows.

### 2. Quick Start

#### 2.1 Deploy

Airflow is deployed by using KDP web.

#### 2.2. Practice

##### 2.2.1 Create DAG file

Here is a simple DAG file, copy the following content to the demo.py file.

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

##### 2.2.2 Copy DAG file to airflow scheduler and worker pod

```shell
kubectl cp demo.py airflow-scheduler-7cf5ddb9c5-fql6x:/opt/airflow/dags -n kdp-data
kubectl cp demo.py airflow-worker-584b97f6cb-8gxq8:/opt/airflow/dags -n kdp-data
```

Note: When using this example, please modify `kdp-data` to your namespace, modify `airflow-scheduler-7cf5ddb9c5-fql6x` to your scheduler pod name, modify `airflow-worker-584b97f6cb-8gxq8` to your worker pod name.

##### 2.2.3 Visit airflow web

Visit airflow web by ingress address, or using kubectl port-forward, as follows:

```shell
kubectl port-forward svc/airflow-webserver -n kdp-data 8080:8080
```

Default login user/password is `admin/admin`

#### 2.2.4 View DAG and task execution

The current configured scheduler scanning frequency is 1 minute, and the demo DAG can be seen on the web page. Click the 'Trigger DAG' button on the right to trigger DAG execution.

### 3. FAQ

#### 3.1. DAG execution failed

Reasons and results:

1. Check whether the demo.py file exists in the `/opt/airflow/dags` directory of the scheduler and worker pod;
2. View the output information of scheduler and worker pod logs.

### 4. Appendix

#### 4.1. Concept

**DAG**

A DAG (Directed Acyclic Graph) is the core concept of Airflow, collecting Tasks together, organized with dependencies and relationships to say how they should run.

