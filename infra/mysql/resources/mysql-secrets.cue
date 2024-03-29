package main

_mysqlSecrets: [
	{
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name:      "mysql-secret-private"
			namespace: "\(parameter.namespace)"
		}
		type: "Opaque"
		data: {
			"mysql-root-password":        "\(parameter.systemMysql.users.root.password)"
			"mysql-replication-password": "\(parameter.systemMysql.users.repl.password)"
			"mysql-password":             "\(parameter.systemMysql.users.kdpAdmin.password)"
		}
	},
]
