// parameter.cue is used to store addon parameters.
//
// You can use these parameters in template.cue or in resources/ by 'parameter.myparam'
//
// For example, you can use parameters to allow the user to customize
// container images, ports, and etc.
parameter: {
	// +usage=NamePrefix is a prefix appended to resources
	namePrefix: *"" | string
	// +usage=Specify the image registry that the KDP application use
	registry: *"registry-cr.linktimecloud.com" | string
	// +usage=Specify the helm repository that the KDP application use
	helmURL: *"oci://registry-cr.linktimecloud.com/linktimecloud" | string
	// +usage=Specify image pull secret for your service
	imagePullSecret: *"" | string
	// +usage=Specify namespace of the application to be installed
	namespace: *"kdp-system" | string
	// +usage=Specify storage settings
	storageConfig: {
		// +usage=Storage class mapping
		storageClassMapping: {
			// +usage=The data is persisted to the worker node host
			localDisk: *"openebs-hostpath" | string
		}
	}
	// +usage=Specify MySQL common settings
	systemMysql: {
		debug: *false | bool
		// +usage=Specify mysql users authentication credentials
		users: {
			// +usage=MySQL root user
			root: {
				user:     *"root" | string
				password: *"a2RwUm9vdDEyMyo=" | string
			}
			// +usage=KDP built-in admin user
			kdpAdmin: {
				user:     *"kdpAdmin" | string
				password: *"a2RwQWRtaW4xMjMq" | string
				database: *"kdpAdmin" | string
			}
			// +usage=MySQL replication user
			repl: {
				password: *"a2RwUmVwbDEyMyo=" | string
			}
		}
	}
	// +usage=Specify the architecture of MySQL: "standalone" or "replication"
	mysqlArch: *"standalone" | "replication"
	// +usage=Specify the data volume size of MySQL
	mysqlDiskSize: *"10Gi" | string
	// +usage=Specify xtrabackup settings
	xtrabackup: {
		// +usage=Specify wheter to enable xtrabackup 
		enabled: *false | bool
		// +usage=Specify disk size for backup volume
		diskSize: *"10Gi" | string
	}
}
