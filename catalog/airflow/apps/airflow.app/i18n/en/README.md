### 1. Application Description

Airflow™ is a platform for programmatically authoring, scheduling, and monitoring workflows.

### 2. Quick Start

#### 2.1 Deployment

Airflow is deployed via the KDP web interface.

#### 2.2 Practical Usage

##### 2.2.1 Creating DAG Files

##### 2.2.3 Accessing Airflow Web via Browser

You can access the Airflow web interface through the configured ingress (http://airflow-web-kdp-data.kdp-e2e.io/home) or by using kubectl port-forward, as shown in the following command:

```shell
kubectl port-forward svc/airflow-webserver -n kdp-data 8080:8080
```

The default login username/password is admin/admin.


### 2.2.4 Configuring DAG Files

DAG files are stored in a Git repository. The default installation configuration places the DAG files in a Git repository, which you can modify to change the DAG files. Alternatively, you can fork the repository, modify the DAG files, and then commit them to the Git repository. You can also install and configure the DAG repository, branch, etc., on the KDP page and then update it.

### 2.2.4 Running DAGs

DAGs are set to a paused state by default and need to be manually started. Manually activate the DAG named `hello_airflow` by clicking the switch next to its name. This DAG runs once a day and will automatically catch up on yesterday's tasks after activation. You can also manually trigger it by clicking the `Trigger DAG` button on the right side of the `hello_airflow` DAG.

### 3. Troubleshooting Common Issues

#### 3.1. DAG Execution Failure

Causes and Troubleshooting:

- Check if the DAG code synchronization is successful by checking the logs: `kubectl logs -l component=scheduler,release=airflow -c git-sync -n kdp-data`
- Review the log output information for the scheduler and worker pods.

### 4. Appendix

#### 4.1. Concept Introduction

**DAG**

Directed Acyclic Graph, which is the basic unit for describing workflows in Airflow.