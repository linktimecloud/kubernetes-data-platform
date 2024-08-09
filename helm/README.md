
 Full documentation is available at [KDP Website](https://linktimecloud.github.io/kubernetes-data-platform/).

## Introduction
KDP(Kubernetes Data Platform) delivers a modern, hybrid and cloud-native data platform based on Kubernetes. It leverages the cloud-native capabilities of Kubernetes to manage data platform effectively.

![kdp-arch](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-archi-en.png)

## Highlights
* Out-of-the-box Kubernetes data platform with:
    * K8s-native integration and optimization of mainstream big data computing and storage engines
    * The standardized configuration management of big data components which simplifies the complexity of configuration dependency management of big data components
* Standardized big data application integration framework with:
    * The application delivery engine based on [OAM](https://oam.dev/) which simplifies the delivery and development of big data applications
    * Scalable application layer operation and maintenance capabilities: observability, elastic scaling, gray scale publishing, etc
* Model concept of big data cluster and application catalog:
    * Big Data cluster: Manage big data components in the form of "cluster" on K8s, providing unified life cycle management of big data applications in the same big data cluster
    * Application Catalog: Combines individual big data components into an application catalog, providing a unified management view from the application layer to the container layer


## Usage Plan
* Obtain the storageClass name of the Kubernetes cluster storage and update the extension component configuration persistence.storageClass.
* Update the extension component configuration persistence.accessModes according to the operations supported by the storageClass of the Kubernetes cluster storage.
* Update the extension component configuration global.ingress.domain according to the domain name of the Kubernetes cluster ingress.
