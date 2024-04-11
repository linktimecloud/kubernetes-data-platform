<p align="left">
<img height="96" src="https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-logo.png" />
</p>

![Tests](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/unit-test.yml/badge.svg)
![Build](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/ci-build.yml/badge.svg)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Releases](https://img.shields.io/github/release/linktimecloud/kubernetes-data-platform/all.svg?style=flat-square)](https://github.com/linktimecloud/kubernetes-data-platform/releases)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/linktimecloud/kubernetes-data-platform/total)
![GitHub Repo stars](https://img.shields.io/github/stars/linktimecloud/kubernetes-data-platform)
![GitHub forks](https://img.shields.io/github/forks/linktimecloud/kubernetes-data-platform)

English | [简体中文](./README_zh.md)

Full documentation is available at [KDP Website](https://linktimecloud.github.io/kubernetes-data-platform/).

## Introduction
KDP(Kubernetes Data Platform) delivers a modern, hybrid and cloud-native data platform based on Kubernetes. It leverages the cloud-native capabilities of Kubernetes to manage data platform effectively.

<p align="left">
<img width="800" height="600" src="https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-archi-en.png" />
</p>

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

## Getting Started
* [Overview](./docs/en/getting-started/overview.md)
* [Quick Start](./docs/en/getting-started/quick-start.md)
* [Advanced Installation](./docs/en/getting-started/advanced-install.md)
* [Catalog Overview](./docs/en/catalog-overview/catalogs.md)
* [Scene Tutorials](./docs/en/user-tutorials/tutorials.md)

## Community
We look forward to your contributions and suggestions! The easiest way to contribute is to participate in discussions on the Github Issues/Discussion.

Reach out with any questions you may have and we'll make sure to answer them as soon as possible.
* [Wechat Group](https://www.wechat.com/en): add broker wechat to invite you into the communication group.
  <p align="left">
  <img width="128" height="128" src="https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-broker-wechat.png" />
  </p>
* [DingTalk Group](https://www.dingtalk.com/en): search for the public group no. `82250000662`

## Contributing
Check out [Developer Guide](docs/en/developer-guide/developer-guide.md) to see how to develop with KDP.

## Code of Conduct
KDP adopts [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/).
