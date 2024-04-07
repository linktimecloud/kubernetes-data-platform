# Developer Guide

## Infrastructure layer

KDP infrastructure layer  mainly includes the OAM engine, KDP backend service stack and KDP frontend service, specifically:
* OAM engine： [KubeVela](https://kubevela.io/), [FluxCD](https://fluxcd.io/)
* Built-in generic components (can be replaced by existing services)：OpenEBS, PLG(Prometheus/Loki/Grafana), Kong Ingress, MySQL
* Self-developed backend services：[KDP OAM Operator](https://github.com/linktimecloud/kdp-oam-operator), [KDP Catalog Manager](https://github.com/linktimecloud/kdp-catalog-manager)
* Self-developed frontend service：[KDP UX](https://github.com/linktimecloud/kdp-ux)
* Command-line tool：KDP CLI（source codes located in the `cmd` and `pkg` directories）

The application delivery declaration of KDP infrastructure is located in the `infra` directory and the delivery format is KubeVela Addon. About KubeVela Addon development in detail, please refer to [Addons](https://kubevela.io/docs/platform-engineers/addon/intro/).

## Application layer

The application delivery declaration of KDP core components is located in the `catalog` directory, which organizes the monolithic applications under the same subsystem by the application directory. The specification of component integration can be referred to:
```
catalog/hdfs/
├── README.md                       # catalog description
├── apps                            # application sub-directory
│   ├── hdfs.app                    # application hdfs
│   │   ├── README.md               # application hdfs: app description
│   │   ├── app.yaml                # application hdfs: app default configs
│   │   ├── i18n                    # application hdfs: internationalization
│   │   │   └── en
│   │   │       └── README.md
│   │   └── metadata.yaml           # application hdfs: app metadata
│   └── httpfs-gateway.app          # application httpfs-gw
│       ├── README.md               # application httpfs-gw: app description
│       ├── app.yaml                # application httpfs-gw: app default configs
│       ├── i18n                    # application httpfs-gw: internationalization
│       │   └── en
│       │       └── README.md
│       └── metadata.yaml           # application httpfs-gw: app metadata
├── i18n                            # catalog description internationalization
│   └── en
│       └── README.md
├── metadata.yaml                   # catalog metadata
└── x-definitions                   # catalog capability models
    ├── app-hdfs.cue                # hdfs app model
    ├── app-httpfs.cue              # httpfs-gw app model
    ├── setting-hdfs.cue            # hdfs config model
    └── setting-httpfs.cue          # httpfs-gw config model
```

About `x-definitions ` design principle and development guidance, please refer to [KDP OAM Operator] (https://github.com/linktimecloud/kdp-oam-operator/tree/main/docs).

## Building & Packaging
* For building packages for both infrastructure and application layer, please refer to the `Makefile` in the project root
* When buildings are finished, artifacts will be pushed to a self-hosted OCI-based registry, including images and helm charts
* When deploy KDP, you may specify to pull images and charts from a self-hosted repository, which needs to proxy both the self-hosted OCI-based registry for pushing and the KDP public repository `registry-cr.linktimecloud.com`. [Sonatype Nexus Repository](https://help.sonatype.com/en/sonatype-nexus-repository.html) is recommended for this purpose as it provides a `group` type of repository that can proxy multiple repositories.