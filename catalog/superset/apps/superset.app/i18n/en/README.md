### 1. Introduction
Superset is a fast, lightweight, and intuitive tool that offers a rich set of options, making it easy for users of varying skill levels to explore and visualize their data, from simple line charts to highly detailed GIS maps.

### 2. Quick Start
#### 2.1 Login
Access the Superset URL (KDP->Application Catalog->Superset->Running Instance Page Top Right->Access URL), enter the administrator username and password you set during installation to log in. The default username is: `admin` and the default password is: `admin`.
After logging in, you can change your password within the Superset application.

Note: If you encounter a `500 Internal Server Error` upon first access, please try again later. Superset requires time to initialize data upon startup, and you need to wait for the backend to complete its startup process. Depending on the configuration, this may take from a few minutes to over ten minutes.

#### 2.2 How to Create a Superset Dashboard
Please refer to: https://superset.apache.org/docs/using-superset/creating-your-first-dashboard#creating-your-first-dashboard

### 3.FQA

1. Startup Error
`sqlalchemy.exc.OperationalError: (MySQLdb._exceptions.OperationalError) (2005, "Unknown server host 'xxxxx@yyyy' (-2)")`
Please verify whether the database password includes the @ character. If it does, you should update the database password. This error arises because Superset misinterprets the host when parsing the SQLAlchemy URL (dialect+driver://username:password@host:port/database).