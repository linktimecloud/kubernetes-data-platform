# 开发指南

## 基础设施层

KDP 基础设施层主要包括 OAM 引擎，KDP 后端服务栈和 KDP 前端服务，具体为：
* OAM 引擎： [KubeVela](https://kubevela.io/), [FluxCD](https://fluxcd.io/)
* 内置通用组件（可使用已有服务代替）：OpenEBS, PLG(Prometheus/Loki/Grafana), Kong Ingress, MySQL
* 自研后端服务：[KDP OAM Operator](https://github.com/linktimecloud/kdp-oam-operator), [KDP Catalog Manager](https://github.com/linktimecloud/kdp-catalog-manager)
* 自研前端服务：[KDP UX](https://github.com/linktimecloud/kdp-ux)
* 命令行工具：KDP CLI（代码位于`cmd`和`pkg`目录下）

基础平台的应用交付声明位于`infra`目录下，交付格式为 KubeVela Addon 。关于 KubeVela Addon 开发的详细介绍，请参考 [自定义插件](https://kubevela.io/docs/platform-engineers/addon/intro/)。

## 应用组件层

KDP 核心组件的应用交付声明位于`catalog`目录下，以应用目录为单位将同一个子系统下的单体应用组织起来，组件集成的规范可参考：
```
catalog/hdfs/
├── README.md                       # 应用目录说明
├── apps                            # 子应用目录
│   ├── hdfs.app                    # 子应用 hdfs
│   │   ├── README.md               # 子应用 hdfs ：应用说明
│   │   ├── app.yaml                # 子应用 hdfs ：应用默认配置
│   │   ├── i18n                    # 子应用 hdfs ：国际化
│   │   │   └── en
│   │   │       └── README.md
│   │   └── metadata.yaml           # 子应用 hdfs：应用元数据
│   └── httpfs-gateway.app          # 子应用 httpfs-gw
│       ├── README.md               # 子应用 httpfs-gw ：应用说明
│       ├── app.yaml                # 子应用 httpfs-gw ：应用默认配置
│       ├── i18n                    # 子应用 httpfs-gw ：国际化
│       │   └── en
│       │       └── README.md
│       └── metadata.yaml           # 子应用 httpfs-gw ：应用元数据
├── i18n                            # 应用目录国际化
│   └── en
│       └── README.md
├── metadata.yaml                   # 应用目录元数据
└── x-definitions                   # 应用目录能力模型
    ├── app-hdfs.cue                # 子应用 hdfs 应用模型
    ├── app-httpfs.cue              # 子应用 httpfs-gw 应用模型
    ├── setting-hdfs.cue            # 子应用 hdfs 配置模型
    └── setting-httpfs.cue          # 子应用 httpfs-gw 配置模型
```

关于`x-definitions`的设计原理及开发指导，请参考[KDP OAM Operator](https://github.com/linktimecloud/kdp-oam-operator/tree/main/docs)。

## 打包构建
* 基础平台或应用组件的打包构建，均可参考项目根目录下的`Makefile`
* 构建完的制品推送到自建的 OCI-based registry，包括镜像和 helm charts
* 部署时，可指定从自建仓库拉取制品，自建仓库需要同时代理用于构建上传的自建 OCI-based registry 和 KDP 公网仓库`registry-cr.linktimecloud.com`。推荐使用 [Sonatype Nexus Repository](https://help.sonatype.com/en/sonatype-nexus-repository.html) 提供的`group`类型仓库来实现同时代理多个仓库