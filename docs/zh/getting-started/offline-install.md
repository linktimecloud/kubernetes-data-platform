# 离线部署

[English](../../en/getting-started/offline-install.md) | 简体中文

用户可通过以下方式来实现在离线环境上部署KDP：

1）在有网区搭建 [Nexus](https://help.sonatype.com/en/sonatype-nexus-repository.html) 代理仓库和 git 私仓，并部署一个 KDP 集群：
* 搭建有网区 Nexus 代理仓库，拉取 KDP git项目并修改再推到有网区 git 私仓中
* 有网区部署KDP（可单机部署），命令行安装时所有仓库地址均指向有网区 Nexus 及 KDP git 私仓，以缓存 KDP 公网仓库中的制品

2）在离线环境搭建镜像 Nexus 仓库及 git 私仓：
* 将有网环境下的 Nexus 数据备份并恢复到离线环境下的 Nexus 仓库中
* 将 KDP 源码项目同步到离线环境 git 私仓

3）离线环境部署KDP，命令行安装时所有仓库地址均指向离线环境 Nexus 及KDP git私仓

## 详细流程

### 部署有网区 Nexus 仓库及 KDP 集群
> 本阶段将：1）在单机`192.168.0.205`上搭建 Nexus 代理仓库 2）通过 Nexus 代理仓库私有部署 KDP 以缓存所有制品

#### 创建 Nexus 自定义SSL证书
```bash
mkdir -p /opt/nexus/ssl/
cd /opt/nexus/ssl/
openssl genrsa -out 192.168.0.205.key 4096
openssl req -new -x509 -days 36500 -key 192.168.0.205.key -out 192.168.0.205.crt -subj "/C=CN/ST=Wuhan/L=Wuhan/O=linktimecloud/OU=registry/CN=192.168.0.205" -addext "subjectAltName = IP:192.168.0.205"
openssl x509 -in 192.168.0.205.crt -out 192.168.0.205.pem -outform PEM

openssl pkcs12 -export -out 192.168.0.205.pkcs12 -inkey 192.168.0.205.key -in 192.168.0.205.crt
# 输入密码password

keytool -v -importkeystore -srckeystore 192.168.0.205.pkcs12 -srcstoretype PKCS12 -destkeystore 192.168.0.205.jks -deststoretype JKS
# 输入密码password
```
> **注：需要将`/opt/nexus/ssl`目录下的所有文件分发到所有 K8s worker 节点的`/etc/ssl/certs`目录下**

#### 部署 Nexus
* 创建 Nexus 配置文件
```bash
# /opt/nexus/conf/nexus.properties
application-port-ssl=8443
application-port=8081
application-host=0.0.0.0
application-ssl-keystore-path=/opt/sonatype/nexus/etc/ssl/keystore.jks
application-ssl-keystore-type=JKS
application-ssl-keystore-password=m7nz5f1y
application-ssl-truststore-path=/etc/nexus/certs/keystore.jks
application-ssl-truststore-password=m7nz5f1y
application-ssl-truststore-type=JKS
nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-https.xml,${jetty.etc}/jetty-requestlog.xml
ssl.etc=${karaf.data}/etc/ssl
```
* 运行 Nexus 容器
```bash
chmod -R 777 /opt/nexus
docker run -d --restart=always -p 8443:8443 -p 8081:8081 -p 8082:8082 --name nexus3 -v /opt/nexus/nexus-data:/nexus-data -v /opt/nexus/ssl/192.168.0.205.jks:/opt/sonatype/nexus/etc/ssl/keystore.jks -v /opt/nexus/conf/nexus.properties:/opt/sonatype/nexus/etc/nexus-default.properties sonatype/nexus3
```
* 获取 Nexus 管理员密码
```bash
docker exec -it nexus3 cat /opt/sonatype/sonatype-work/nexus3/admin.password
```
#### 配置 KDP 公网仓库代理
* 浏览器登录 Nexus 页面：https://192.168.0.205:8443
* 添加 Docker 代理仓库
![添加docker代理仓库](images/nexus-docker-proxy.png)
* 配置 Docker Realm
![配置docker ralm](images/nexus-realms.png)
* 添加 Raw 代理仓库
![添加raw代理仓库](images/nexus-raw.png)

#### KDP 私仓准备
* 修改 fluxcd 相关代码挂载本地https证书：
  * 修改fluxcd代码文件列表:
```yaml
infra/fluxcd/resources/components/helm-controller.cue
infra/fluxcd/resources/components/source-controller.cue
```
  * 修改fluxcd代码示例:
```yaml
hostPath:[{
          name: "ca-cert-ssl"
          mountPath: "/etc/ssl/certs"
          path: "/etc/ssl/certs"
          readOnly: true
        },]
```
![volumeMounts资源添加https证书挂载](images/fluxcd-update.png)
* 代码提交到 git 私仓对应分支

#### 安装 KDP 
* 使用 KDP CLI 安装 KDP 基础设施层：
```bash
# YOUR_PRIVATE_GIT_REPO 替换为 git 私仓项目地址
# YOUR_PRIVATE_GIT_REPO_REF 替换为 git 私仓对应分支或tag
kdp install --debug \
  --artifact-server https://192.168.0.205:8443/repository/raw/vela \
  --docker-registry 192.168.0.205:8082 \
  --helm-repository oci://192.168.0.205:8082/linktimecloud/ \
  --kdp-repo https://YOUR_PRIVATE_GIT_REPO/kubernetes-data-platform.git
  --kdp-repo-ref YOUR_PRIVATE_GIT_REPO_REF
```
* 待 KDP 基础平台安装完成后，可通过 KDP 界面继续安装需要的数据组件

#### 导出 Nexus 数据
```bash
tar -czvf nexus-data.tar.gz /opt/nexus/nexus-data
```

### 部署离线环境 Nexus 代理仓库及KDP集群

后续步骤，参考上述有网区部署流程，主要包括：
1. 从有网区导出的 Nexus 数据恢复离线环境 Nexus 仓库
2. 从有网区 git 私仓创建离线环境 git 私仓
3. 部署 KDP