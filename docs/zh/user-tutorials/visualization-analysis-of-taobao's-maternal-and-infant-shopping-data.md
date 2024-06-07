# 淘宝母婴购物数据可视化分析
简体中文 | [English](../../en/user-tutorials/exploring-data-using-airbyte-clickhouse-superset.md) 

# 1. 背景
母婴用品是淘宝的热门购物类目。随着国家二胎、三胎政策的推进，母婴类商品的销量将进一步增加。与此同时，年轻一代父母的育儿观念也发生了显著变化，推动了中国母婴电商市场的多样化发展。各大母婴品牌因此展开了更加激烈的竞争，越来越多的品牌看到了行业中的潜在商机，纷纷加入母婴电商领域，使得行业竞争愈发激烈。基于此，本项目将对“淘宝母婴购物”数据集进行可视化分析，以更好地挖掘数据洞察。

## 1.1 数据说明
本次分析数据来源于[淘宝母婴购物行为数据集]()，并在原始数据的基础上进行了字段调整，包括如下两张表：

- 用户基本信息表： tianchi_mum_baby

| 字段     | 字段说明     | 说明                                                       |
| -------- | ------------ | ---------------------------------------------------------- |
| user_id  | 用户标识     | 抽样&字段脱敏                                              |
| birthday | 婴儿出生日期 | 由user_id填写，有可能不真实，格式:YYYYMMDD                 |
| gender   | 婴儿性别     | （0 男孩，1 女孩，2性别不明），由user_id填写，有可能不真实 |

- 商品交易信息表： tianchi_mum_baby_trade_history

| 字段       | 字段说明       | 说明 |
| ---------- | -------------- | ---- |
| user_id    | 用户标识       |      |
| auction_id | 交易ID         |      |
| category_1 | 商品一级类目ID |      |
| category_1 | 商品二级类目ID |      |
| buy_amount | 购买数量       |      |
| auction_id | 订单id         |      |

## 1.2 目标
借助KDP平台的开源组件`Airbyte`、`ClickHouse`、`Superset`完成如下简单的商业分析任务，通过数据分析和可视化展示，充分挖掘数据的价值，让数据更好地为业务服务。
- 流量分析：年/季度/月/日的商品销量如何？有什么规律
- 类别分析：商品销量按照类目分类有什么规律？
- 性别分析：不同性别的婴幼儿购买行为相似吗？是否符合我们的常识呢？
- .....

## 1.3 环境说明
在KDP页面安装如下组件并完成组件的QuickStart:
- Airbyte: 数据采集
- ClickHouse: 数据ETL处理
- Superset: 数据可视化
- Airflow: 作业调度
- MySQL: Superset/Airflow 元数据库

通常在真实的项目中我们需要对作业进行调度，这里我们使用Airflow来实现作业调度。


# 2. 数据集成
我们通过平台的Airbyte组件，将数据从原始数据源（csv文件）同步到ClickHouse中。
1. 在 airbyte 中添加一个 file 类型 source, 读取`tianchi_mum_baby`
   ![](./images/airbyte06.png)
   - Source Name: `tianchi_mum_baby`
   - Dataset Name: `tianchi_mum_baby` (请勿修改)
   - URL: `https://gitee.com/linktime-cloud/example-datasets/raw/main/airbyte/tianchi_mum_baby.csv`

2. 在 airbyte 中添加一个 file 类型 source, 读取`tianchi_mum_baby_trade_history`。
    - Source Name: `tianchi_mum_baby_trade_history`
   - Dataset Name: `tianchi_mum_baby_trade_history` (请勿修改)
   - URL: `https://gitee.com/linktime-cloud/example-datasets/raw/main/airbyte/tianchi_mum_baby_trade_history.csv`
   
      
3. 在 airbyte 中添加一个 clickhouse 类型 destination。 
![](./images/airbyte03.png)
    - Host: `clickhouse`
    - Port: `8123`
    - DB Name: `default`
    - User: `default`
    - Password: `ckdba.123`

4. 在 airbyte 中添加一个 connection。 source 选择 `tianchi_mum_baby`, destination 选择 clickhouse, 使用默认配置下一步,Schedule type 配置为`Manual`，然后保存。
![](./images/airbyte05.png)

5. 在 airbyte 中添加一个 connection。 source 选择 `tianchi_mum_baby_trade_history`, destination 选择 clickhouse, 使用默认配置下一步,Schedule type 配置为`Manual`，然后保存。
   
6. 查看 airbyte 的 job 状态，如果成功，则说明数据已经成功导入到clickhouse中。
![](./images/airbyte04.png)
   
完成上述操作完成后数据已经成功导入到clickhouse中。接下来我们利用clickhouse进行数据ETL处理。

# 3 数据开发
将数据从csv文件导入到clickhouse后，对数据进行ETL处理, 供Superset进行可视化分析。
Airflow 中相关的代码如下， 具体代码参考[Github]()或者[Gitee]()。

```python
@task
 def clickhouse_upsert_userinfo():
     ...

 @task
 def clickhouse_upsert_user_purchases():
     ...

 @task
 def clickhouse_upsert_dws_user_purchases():
     ...
```

注意：通常在数仓建模中有一定的命名规范和数据分层，这里简单处理。


# 4. 作业调度
通常在真实的项目中数据是随时间变化的，因此需要通过作业调度来更新数据。关于Airflow的基本使用可以参考应用的QuickStart。

在数据开发章节中编写了Airflow Dag, 里面主要涉及两种作业的调度：
- Airbyte作业
- ClickHouse作业
Airbyte 本身是可以配置调度的，但是为了统一管理作业和处理作业之间的依赖关系，这里统一使用Airflow来调度。下面主要介绍如何通过Airflow来调度Airbyte作业。

1. 在 airflow 中添加一个 HTTP 类型 connection。 
   ![](./images/airflow03.png)
   
   - Connnection Id: `airbyte` (后续Dag中会用到该连接)
   - Connnection Type: `HTTP`
   - Host: `airbyte-airbyte-server-svc`
   - Port: `8001`

2. 在 airflow 中启用名称为`taobao_user_purchases_example`的DAG，作业是每天调度，第一次启用会补跑昨天的调度。也可以手动触发。点击DAG名称可以查看作业运行状态。
   
    > DAG 列表
   ![](./images/airflow04.png)
  
    > DAG 运行状态
   ![](./images/airflow05.png)

# 5. 数据可视化
Superset 支持 Clickhouse 数据源，我们可以通过 Superset 来可视化分析数据。建议用户先完成 KDP Superset App 的 QuickStart。

使用账号`admin`密码`admin`登录 Superset `http://superset-kdp-data.kdp-e2e.io` (注意添加本地Host解析) 页面。

## 5.1 创建图表

### 方式一：导入我们制作好的图表 （建议）
1. [下载面板](https://gitee.com/linktime-cloud/example-datasets/blob/main/superset/dashboard_export_20240521T102107.zip)
2. 导入面板
选择下载的文件导入
![](./images/superset01.png)
输入clickhouse的用户`default`的默认密码`ckdba.123`
![](./images/superset02.png)

### 方式二： 手动创建

- **添加数据链接**
依次点页面右`Settings` - `Databases Connections`- `+ Database` 添加 ClickHouse 数据源。
![](./images/superset04.png)
填写如下参数：
- HOST: `clickhouse`
- PORT: `8123`
- DATABASE NAME: `default`
- USERNAME: `default`
- PASSWORD: `ckdba.123`
- **添加DATASET**
依次点击页面上方的导航`DATASETS` - 右上方 `+ Dataset` 添加数据集。
![](./images/superset05.png)

然后参考 Superset 官方文档，制作图表

#### 流量分析
   ![](./images/superset06.png)
   - 平台的销量按季度递增，第四季度的销量达到最大值。
   - 年中/年底底月份销量较大，可能和促销相关；1月份/2月份销量最低。
  
#### 性别分析
![](./images/superset07.png)
- 男宝和女宝数量差异不大
- 男宝的购买量较女宝的购买量高出约一倍
- 男宝在各品类的购买量都大于女宝，除了`50022520`; 男宝在品类`50014815`的购买量远超女宝，且购买量超过女宝的2倍。
#### 类别分析
![](./images/superset08.png)
- 对于一级品类主要集中在三大品类
- 二级品类中比较特殊的是一级品类`50014815`中的二级品类`50018831`的销量占整个此品类 64%
  


> 机器学习
另外我们也可以同机器学习来预测用户的购买，对用户进行推荐，对于没有按照预期购买的用户，我们可以推送优惠券来吸引用户购买。 To Be Continue...
