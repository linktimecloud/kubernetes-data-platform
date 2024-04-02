![KDP](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-logo-black.png)

![Tests](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/unit-test.yml/badge.svg)
![Build](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/ci-build.yml/badge.svg)
![GitHub Repo stars](https://img.shields.io/github/stars/linktimecloud/kubernetes-data-platform)
![GitHub forks](https://img.shields.io/github/forks/linktimecloud/kubernetes-data-platform)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/linktimecloud/kubernetes-data-platform/total)
[![Releases](https://img.shields.io/github/release/linktimecloud/kubernetes-data-platform/all.svg?style=flat-square)](https://github.com/linktimecloud/kubernetes-data-platform/releases)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# Kubernetes Data Platform

English | [简体中文](./README_zh.md)
<br>

## Introduction
KDP(Kubernetes Data Platform) delivers a modern, hybrid and cloud-native data platform based on Kubernetes. It leverages the cloud-native capabilities of Kubernetes to manage data platform effectively.

![KDP](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-archi-en.png)

## Highlights
* 开箱即用的 Kubernetes 大数据平台
  * 主流大数据计算、存储引擎的 K8s 化改造及优化
  * 大数据组件的标准化配置管理，简化了大数据组件配置依赖管理的复杂性
* 提供标准化的大数据应用集成框架
  * 基于[OAM](https://oam.dev/)的应用交付引擎，简化大数据应用的交付和开发
  * 可扩展的应用层运维能力：可观测性、弹性伸缩、灰度发布等
* 大数据集群及应用目录的模型概念
  * 大数据集群：在K8s上以“集群”的形式管理大数据组件，提供同一个大数据集群下大数据应用统一的生命周期管理
  * 应用目录：将相关的单体大数据组件组合成一个应用目录，提供从应用层到容器层的统一管理视图

## Getting Started
* [Overview](./docs/en/getting-started/overview.md)
* [Quick Start](./docs/en/getting-started/quick-start.md)
* [Advanced Installation](./docs/en/getting-started/advanced-install.md)

## Documentation
Full documentation is available at [KDP Website](https://linktimecloud.github.io/kubrenetes-data-platform)

## Community
We look forward to your contributions and suggestions! The easiest way to contribute is to participate in discussions on the Github Issues/Discussion.

Reach out with any questions you may have and we'll make sure to answer them as soon as possible.
* [DingTalk Group](https://www.dingtalk.com/en): `abcdefg`
* [Wechat Group](https://www.wechat.com/en): `abcdefg`

## Contributing
Check out [Deverloper Guide](docs/en/developer-guide/developer-guide.md) to see how to develop with KDP.

## Code of Conduct
KDP adopts [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/).
