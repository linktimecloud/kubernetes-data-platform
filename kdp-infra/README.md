[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# KDP-Infra helm chart

kdp-infra is the installation service for the kdp (Kubernetes Data Platform) management platform. Using the kdp-infra chart, kdp can be deployed in a Kubernetes cluster.

To pull this chart from the repository,

```bash
helm pull oci://registry-1.docker.io/linktimecloud/kdp-infra-chart --version v1.0.0-rc1
```

Other Commands,

```bash
helm show all oci://registry-1.docker.io/linktimecloud/kdp-infra-chart --version v1.0.0-rc1
helm template <my-release> oci://registry-1.docker.io/linktimecloud/kdp-infra-chart --version v1.0.0-rc1
helm install <my-release> oci://registry-1.docker.io/linktimecloud/kdp-infra-chart --version v1.0.0-rc1
helm upgrade <my-release> oci://registry-1.docker.io/linktimecloud/kdp-infra-chart --version <new-version>
```

## Prerequisites
- Kubernetes 1.23+

## Parameters

### kdp-infra parameters

| Name                                      | Description                                                                           | Value          |
| ----------------------------------------- | ------------------------------------------------------------------------------------- | -------------- |
| `image.registry`                          | Image registry                                                                        | `""`           |
| `image.repository`                        | Image repository                                                                      | `kdp-infra`    |
| `image.pullPolicy`                        | Image pull policy                                                                     | `IfNotPresent` |
| `image.tag`                               | Image tag                                                                             | `""`           |
| `image.digest`                            | Image digest                                                                          | `""`           |
| `imagePullSecrets`                        | Image pull secrets                                                                    | `[]`           |
| `nameOverride`                            | String to partially override kdp-infra.fullname                                       | `""`           |
| `fullnameOverride`                        | String to fully override kdp-infra.name                                               | `""`           |
| `serviceAccount.create`                   | Create serviceAccount                                                                 | `true`         |
| `serviceAccount.automount`                | Automatically mount a ServiceAccount's API credentials?                               | `true`         |
| `serviceAccount.annotations`              | Annotations to add to the service account                                             | `{}`           |
| `serviceAccount.name`                     | The name of the service account to use.                                               | `""`           |
| `podAnnotations`                          |                                                                                       | `{}`           |
| `podLabels`                               |                                                                                       | `{}`           |
| `service.port`                            | Service port                                                                          | `9115`         |
| `resources`                               |                                                                                       | `{}`           |
| `volumes`                                 | Volumes for the output Deployment definition                                          | `[]`           |
| `volumeMounts`                            | Volume mounts for the output Deployment definition                                    | `[]`           |
| `nodeSelector`                            | Node selector for pod assignment                                                      | `{}`           |
| `affinity`                                | Affinity for pod assignment                                                           | `{}`           |
| `livenessProbe.initialDelaySeconds`       | Initial delay seconds for the liveness probe                                          | `5`            |
| `livenessProbe.periodSeconds`             | Period seconds for the liveness probe                                                 | `10`           |
| `livenessProbe.timeoutSeconds`            | Timeout seconds for the liveness probe                                                | `1`            |
| `livenessProbe.failureThreshold`          | Failure threshold for the liveness probe                                              | `3`            |
| `livenessProbe.successThreshold`          | Success threshold for the liveness probe                                              | `1`            |
| `readinessProbe.initialDelaySeconds`      | Initial delay seconds for the readiness probe                                         | `5`            |
| `readinessProbe.periodSeconds`            | Period seconds for the readiness probe                                                | `10`           |
| `readinessProbe.timeoutSeconds`           | Timeout seconds for the readiness probe                                               | `1`            |
| `readinessProbe.failureThreshold`         | Failure threshold for the readiness probe                                             | `3`            |
| `readinessProbe.successThreshold`         | Success threshold for the readiness probe                                             | `1`            |
| `metrics.serviceMonitor.enabled`          | Enable the ServiceMonitor resource for Prometheus Operator                            | `true`         |
| `metrics.serviceMonitor.additionalLabels` | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus | `{}`           |
| `metrics.serviceMonitor.interval`         | Specify the interval at which metrics should be scraped                               | `30s`          |
| `metrics.serviceMonitor.scrapeTimeout`    | Specify the timeout after which the scrape is ended                                   | `30s`          |
