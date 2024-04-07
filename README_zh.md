![KDP](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-logo.png)

![Tests](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/unit-test.yml/badge.svg)
![Build](https://github.com/linktimecloud/kubernetes-data-platform/actions/workflows/ci-build.yml/badge.svg)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Releases](https://img.shields.io/github/release/linktimecloud/kubernetes-data-platform/all.svg?style=flat-square)](https://github.com/linktimecloud/kubernetes-data-platform/releases)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/linktimecloud/kubernetes-data-platform/total)
![GitHub Repo stars](https://img.shields.io/github/stars/linktimecloud/kubernetes-data-platform)
![GitHub forks](https://img.shields.io/github/forks/linktimecloud/kubernetes-data-platform)

[English](./README.md) | 简体中文

完整的文档可访问 [KDP 网站](https://linktimecloud.github.io/kubernetes-data-platform/).

## 简介
KDP(Kubernetes Data Platform) 提供了一个基于 Kubernetes 的现代化混合云原生数据平台。它能够利用 Kubernetes 的云原生能力来有效地管理数据平台。

![KDP](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-archi.png)

## 亮点
* 开箱即用的 Kubernetes 大数据平台：
  * 主流大数据计算、存储引擎的 K8s 化改造及优化
  * 大数据组件的标准化配置管理，简化了大数据组件配置依赖管理的复杂性
* 提供标准化的大数据应用集成框架：
  * 基于[OAM](https://oam.dev/)的应用交付引擎，简化大数据应用的交付和开发
  * 可扩展的应用层运维能力：可观测性、弹性伸缩、灰度发布等
* 大数据集群及应用目录的模型概念：
  * 大数据集群：在K8s上以“集群”的形式管理大数据组件，提供同一个大数据集群下大数据应用统一的生命周期管理
  * 应用目录：将相关的单体大数据组件组合成一个应用目录，提供从应用层到容器层的统一管理视图

## 入门
* [概述](./docs/zh/getting-started/overview.md)
* [快速启动](./docs/zh/getting-started/quick-start.md)
* [高级安装](./docs/zh/getting-started/advanced-install.md)
* [应用目录](./docs/zh/catalog-overview/catalogs.md)
* [场景教程](./docs/zh/user-tutorials/tutorials.md)

## 社区

我们期待您的贡献和建议!最简单的贡献方式是参与Github议题/讨论的讨论。
如果您有任何问题，请与我们联系，我们将确保尽快为您解答。
* [钉钉群](https://www.dingtalk.com/): `PLACEHOLDER`
* [微信群](https://www.wechat.com/): `PLACEHOLDER`

## 贡献
参考[开发者指南](docs/zh/developer-guide/developer-guide.md)，了解如何开发及贡献 KDP。

## 规范
KDP 采纳了 [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/).
