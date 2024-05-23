### 1. 介绍
Superset 是一个快速、轻量级、直观的工具，提供了丰富的选项，使得不同技能水平的用户都能轻松地探索和可视化他们的数据，从简单的折线图到高度详细的GIS图表。

### 2. 快速开始
#### 2.1 登陆
打开 Superset 访问地址（KDP->应用目录->Superset->运行实例页面右上角->访问地址），输入安装时候填写管理员密码账号即可登录。默认账号：`admin` 密码：`admin`.
登录后可以在 Superset 应用中修改密码。

注意：如果第一次访问出现`500 Internal Server Error`错误，请稍后重试。因为Superset 启动需要时间初始化数据，需要等待后台启动完成。根据配置不同，耗时可能几分钟到十几分钟。


#### 2.2 如何创建一个 Superset Dashboard
请参考:https://superset.apache.org/docs/using-superset/creating-your-first-dashboard#creating-your-first-dashboard

### 3.FAQ

1. 启动报错
   
`sqlalchemy.exc.OperationalError: (MySQLdb._exceptions.OperationalError) (2005, "Unknown server host 'xxxxx@yyyy' (-2)")`
请检查数据库密码中是否包含`@`字符，如果包含请修改数据库密码。该报错是由于 Superset 解析 SQLAlchemy URL (dialect+driver://username:password@host:port/database) 时候错误识别 host 导致的。