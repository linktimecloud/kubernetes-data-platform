
完整的文档可访问 [KDP 网站](https://linktimecloud.github.io/kubernetes-data-platform/README_zh.html).

## 简介

KDP(Kubernetes Data Platform) 提供了一个基于 Kubernetes 的现代化混合云原生数据平台。它能够利用 Kubernetes 的云原生能力来有效地管理数据平台。

![kdp-arch](https://linktime-public.oss-cn-qingdao.aliyuncs.com/linktime-homepage/kdp/kdp-archi-en.png)

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

## 使用方案
* 获取Kubernetes集群存储storageClass名称，更新扩展组件配置配置 persistence.storageClass
* 依据Kubernetes集群存储storageClass支持的操作, 更新扩展组件配置配置persistence.accessModes
* 依据Kubernetes集群ingress的域名，更新扩展组件配置配置global.ingress.domain
