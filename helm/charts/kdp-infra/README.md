[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# KDP helm chart

kdp is the installation service for the kdp (Kubernetes Data Platform) management platform. Using the kdp chart, kdp can be deployed in a Kubernetes cluster.

To pull this chart from the repository,

```bash
helm pull oci://registry-1.docker.io/linktimecloud/kdp-chart --version 1.0.0-rc1
```

Other Commands,

```bash
helm show all oci://registry-1.docker.io/linktimecloud/kdp --version 1.0.0-rc1
helm template <my-release> oci://registry-1.docker.io/linktimecloud/kdp --version 1.0.0-rc1
helm install <my-release> oci://registry-1.docker.io/linktimecloud/kdp --version 1.0.0-rc1
helm upgrade <my-release> oci://registry-1.docker.io/linktimecloud/kdp --version <new-version>
```

## Prerequisites
- Kubernetes 1.23+

## Parameters

### Global parameters

| Name                           | Description                 | Value        |
| ------------------------------ | --------------------------- | ------------ |
| `global.ingress.class`         | Ingress class               | `kong`       |
| `global.ingress.domain`        | Domain name for ingress     | `kdp-e2e.io` |
| `global.ingress.tlsSecretName` | TLS secret name for ingress | `""`         |

### kdp parameters

| Name                                      | Description                                                                           | Value                                                                     |
| ----------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `image.registry`                          | Image registry                                                                        | `od-registry.linktimecloud.com`                                           |
| `image.repository`                        | Image repository                                                                      | `kdp`                                                                     |
| `image.pullPolicy`                        | Image pull policy                                                                     | `Always`                                                                  |
| `image.tag`                               | Image tag                                                                             | `""`                                                                      |
| `image.digest`                            | Image digest                                                                          | `sha256:5e00383433dbe9d05807dfa67cacad03cf0248960868bcc61d6c86e2876dacbf` |
| `imagePullSecrets`                        | Image pull secrets                                                                    | `[]`                                                                      |
| `nameOverride`                            | String to partially override kdp.fullname                                             | `""`                                                                      |
| `fullnameOverride`                        | String to fully override kdp.name                                                     | `""`                                                                      |
| `serviceAccount.create`                   | Create serviceAccount                                                                 | `true`                                                                    |
| `serviceAccount.automount`                | Automatically mount a ServiceAccount's API credentials?                               | `true`                                                                    |
| `serviceAccount.annotations`              | Annotations to add to the service account                                             | `{}`                                                                      |
| `serviceAccount.name`                     | The name of the service account to use.                                               | `""`                                                                      |
| `podAnnotations`                          |                                                                                       | `{}`                                                                      |
| `podLabels`                               |                                                                                       | `{}`                                                                      |
| `service.port`                            | Service port                                                                          | `9115`                                                                    |
| `resources`                               |                                                                                       | `{}`                                                                      |
| `volumes`                                 | Volumes for the output Deployment definition                                          | `[]`                                                                      |
| `volumeMounts`                            | Volume mounts for the output Deployment definition                                    | `[]`                                                                      |
| `nodeSelector`                            | Node selector for pod assignment                                                      | `{}`                                                                      |
| `affinity`                                | Affinity for pod assignment                                                           | `{}`                                                                      |
| `livenessProbe.initialDelaySeconds`       | Initial delay seconds for the liveness probe                                          | `5`                                                                       |
| `livenessProbe.periodSeconds`             | Period seconds for the liveness probe                                                 | `10`                                                                      |
| `livenessProbe.timeoutSeconds`            | Timeout seconds for the liveness probe                                                | `1`                                                                       |
| `livenessProbe.failureThreshold`          | Failure threshold for the liveness probe                                              | `3`                                                                       |
| `livenessProbe.successThreshold`          | Success threshold for the liveness probe                                              | `1`                                                                       |
| `readinessProbe.initialDelaySeconds`      | Initial delay seconds for the readiness probe                                         | `5`                                                                       |
| `readinessProbe.periodSeconds`            | Period seconds for the readiness probe                                                | `10`                                                                      |
| `readinessProbe.timeoutSeconds`           | Timeout seconds for the readiness probe                                               | `1`                                                                       |
| `readinessProbe.failureThreshold`         | Failure threshold for the readiness probe                                             | `3`                                                                       |
| `readinessProbe.successThreshold`         | Success threshold for the readiness probe                                             | `1`                                                                       |
| `metrics.serviceMonitor.enabled`          | Enable the ServiceMonitor resource for Prometheus Operator                            | `true`                                                                    |
| `metrics.serviceMonitor.additionalLabels` | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus | `{}`                                                                      |
| `metrics.serviceMonitor.interval`         | Specify the interval at which metrics should be scraped                               | `30s`                                                                     |
| `persistence.enabled`                     | Enable persistence using Persistent Volume Claims                                     | `true`                                                                    |
| `persistence.storageClass`                | PVC Storage Class for MinIO&reg; data volume                                          | `default`                                                                 |
| `persistence.accessModes`                 | PVC Access Modes for MinIO&reg; data volume                                           | `["ReadWriteOnce"]`                                                       |
| `persistence.size`                        | PVC Storage Request for MinIO&reg; data volume                                        | `1Gi`                                                                     |
| `persistence.annotations`                 | Annotations for the PVC                                                               | `{}`                                                                      |
| `installConfig.kdpRepo`                   | kdp repo url                                                                          | `https://gitee.com/linktime-cloud/kubernetes-data-platform.git`           |
| `installConfig.kdpRepoRef`                | kdp repo ref                                                                          | `release-1.2`                                                             |
| `installConfig.setParameters`             | setParameters                                                                         | `[]`                                                                      |
