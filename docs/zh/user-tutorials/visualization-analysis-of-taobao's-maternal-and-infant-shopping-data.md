# 淘宝母婴购物数据可视化分析
简体中文 | [English](../../en/user-tutorials/exploring-data-using-airbyte-clickhouse-superset.md) 

# 1. 背景
母婴用品是淘宝的热门购物类目，随着国家鼓励二胎、三胎政策的推进，会进一步促进了母婴类目商品的销量。与此年轻一代父母的育儿观念也发生了较大的变化，因此中国母婴电商市场发展形态也越来越多样化。随之引起各大母婴品牌更加激烈的争夺，越来越多的母婴品牌管窥到行业潜在的商机，纷纷加入母婴电商，行业竞争越来越激烈。本项目会基于“淘宝母婴购物”数据集进行可视化分析，帮助开发者更好地做出数据洞察。

## 1.1 数据说明
本次分析数据来源于[淘宝母婴购物行为数据集]()，并在原始数据的基础上进行了字段调整，包括如下两张表：

- 用户基本信息表： tianchi_mum_baby

| 字段      | 字段说明       | 说明                                           |
|-----------|----------------|------------------------------------------------|
| user_id   | 用户标识       | 抽样&字段脱敏                                  |
| birthday  | 婴儿出生日期   | 由user_id填写，有可能不真实，格式:YYYYMMDD   |
| gender    | 婴儿性别       | （0 男孩，1 女孩，2性别不明），由user_id填写，有可能不真实 |

- 商品交易信息表： tianchi_mum_baby_trade_history

| 字段         | 字段说明       | 说明                    |
|--------------|----------------|-------------------------|
| user_id      | 用户标识       |                         |
| auction_id   | 交易ID         |                         |
| category_1   | 商品一级类目ID |                         |
| category_1   | 商品二级类目ID |                         |
| buy_amount   | 购买数量       |                         |
| auction_id   | 订单id         |        |

## 1.2 目标
借助KDP平台的开源组件`Airbyte`、`ClickHouse`、`Superset`完成如下简单的商业分析任务，通过数据分析和可视化展示，充分挖掘数据的价值，让数据更好地为业务服务。
- 流量分析：年/季度/月/日的商品销量如何？有什么规律
- 类别分析：商品销量按照类目分类有什么规律？哪些类目的商品更有价值？
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


# 2. 数据采集
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
    - Host: `clickhouse.kdp-data.svc.cluster.local`
    - Port: `8123`
    - DB Name: `default`
    - User: `default`
    - Password: `ckdba.123`

4. 在 airbyte 中添加一个 connection。 source 选择 `tianchi_mum_baby`, destination 选择 clickhouse, 使用默认配置下一步,Schedule type 配置为`Manual`，然后保存。
![](./images/airbyte05.png)
   
5. 查看 airbyte 的 job 状态，如果成功，则说明数据已经成功导入到clickhouse中。
![](./images/airbyte04.png)
   
完成上述操作后即完成了ELT(Extract Load Transform)中的EL, 接下使用clickhouse完成Transform。

# 3 数据ETL

```sql
-- Drop the old table if it exists
DROP TABLE IF EXISTS default.user_info;

-- Define the new table structure
CREATE TABLE default.user_info
(
    user_id   Int64,
    gender    String,
    birthday  Date
)
    ENGINE = MergeTree
        ORDER BY user_id;

-- Insert data into the new table from the JSON, adjusting the gender field
INSERT INTO default.user_info
SELECT JSONExtractInt(_airbyte_data, 'user_id') AS user_id,
       CASE JSONExtractInt(_airbyte_data, 'gender')
           WHEN 0 THEN 'Male'  -- Boy
           WHEN 1 THEN 'Female'  -- Girl
           ELSE 'Unknown'  -- Unknown gender
       END AS gender,
       parseDateTimeBestEffortOrNull(nullIf(JSONExtractString(_airbyte_data, 'birthday'), '')) AS birthday
FROM airbyte_internal.default_raw__stream_tianchi_mum_baby;
```

```sql
-- Drop the old table if it exists
DROP TABLE IF EXISTS default.user_purchases;

-- Define the new table structure
CREATE TABLE default.user_purchases
(
    user_id     Int64,
    auction_id  Int64,
    buy_mount   Int32,
    day         Date,
    category_1  Int64,
    category_2  Int64
)
    ENGINE = MergeTree
        ORDER BY user_id;

-- Insert data into the new table from the JSON
INSERT INTO default.user_purchases
SELECT JSONExtractInt(_airbyte_data, 'user_id') AS user_id,
       JSONExtractInt(_airbyte_data, 'auction_id') AS auction_id,
       JSONExtractInt(_airbyte_data, 'buy_mount') AS buy_mount,
       parseDateTimeBestEffortOrNull(nullIf(JSONExtractString(_airbyte_data, 'day'), '')) AS day,
       JSONExtractInt(_airbyte_data, 'category_1') AS category_1,
       JSONExtractInt(_airbyte_data, 'category_2') AS category_2
FROM airbyte_internal.default_raw__stream_tianchi_mum_baby_trade_history;
```

```sql
-- Drop the old wide table if it exists
DROP TABLE IF EXISTS default.user_info_purchases;

-- Define the new wide table structure
CREATE TABLE default.user_info_purchases
(
    user_id      Int64,
    auction_id   Int64,
    buy_mount    Int32,
    day          Date,
    category_1   Int64,
    category_2   Int64,
    gender       String,
    birthday     Date
)
    ENGINE = MergeTree
        ORDER BY user_id;

-- Insert data into the new wide table by left joining user_purchases and user_info
INSERT INTO default.user_info_purchases
SELECT
    up.user_id,
    up.auction_id,
    up.buy_mount,
    up.day,
    up.category_1,
    up.category_2,
    ui.gender,
    ui.birthday
FROM default.user_purchases AS up
LEFT JOIN default.user_info AS ui
ON up.user_id = ui.user_id;
```
注意：通常在数仓建模中有一定的命名规范和数据分层，这里简单处理。


# 4. 作业调度
通常在真实的项目中数据是随时间变化的，因此需要通过作业调度来更新数据。
关于Airflow的基本使用可以参考应用的QuickStart。

4.1 作业说明




# 5. 数据可视化
