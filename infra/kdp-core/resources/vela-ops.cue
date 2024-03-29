package main

_WFName: "vela-workflow-reconcile"

_velaOps: {
	name: parameter.namePrefix + "vela-ops"
	type: "k8s-objects"
	properties: 
		objects: [
			{
				apiVersion: "batch/v1"
				kind:       "CronJob"
				metadata: {
					name: parameter.namePrefix + _WFName
					namespace: "vela-system"
					labels: {
						app: parameter.namePrefix + _WFName
					}
				}
				spec: {
					concurrencyPolicy: "Forbid"
					ttlSecondsAfterFinished: 30
					schedule: "*/5 * * * *"
					jobTemplate: {
						spec: {
							template: {
								spec: {
									containers: [{
										name: _WFName
										command: ["/bin/sh", "-c", "vela ls -A|grep -E 'runningWorkflow'|awk '{print $1,$2}'|grep -v '[├─]'|xargs -n2 sh -c 'echo \"    \"$0/$1;vela workflow restart $1 -n $0 || true'"]
										image: "\(parameter.registry)/oamdev/vela-cli:v1.9.9"
										imagePullPolicy: "IfNotPresent"
									}]
									imagePullSecrets: [{
										name: "\(parameter.imagePullSecret)"
									}]
									restartPolicy: "OnFailure"
									serviceAccountName: "kubevela-vela-core"
								}
							}
						}
					}
				}
			}
		]
}