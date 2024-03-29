/*
Copyright © 2024 LINKTIMECLOUD <admin@linktime.cloud>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package cmd

import (
	"fmt"

	"kdp/pkg/utils"
	"kdp/pkg/vela"

	"github.com/spf13/cobra"
	log "github.com/sirupsen/logrus"
)

// upgradeCmd represents the upgrade command
var upgradeCmd = &cobra.Command{
	Use:   "upgrade",
	Short: "Upgrade KDP infrastructure",
	Long: `Perform an upgrade of KDP infrastructure. 
This is the common action to update parameters of KDP infrastructure components.`,

	Example: `  Upgrade runtime parameters:
    kdp upgrade --set key1=value1 --set key2=value2 ...
  Upgrade runtime parameters and KDP vela:
    kdp upgrade --vela-upgrade --set key1=value1 --set key2=value2 ...
  Upgrade runtime parameters and KDP source codes:
    kdp upgrade --src-upgrade --set key1=value1 --set key2=value2 ...`,
	
	Run: func(cmd *cobra.Command, args []string) {
		
		log.Info("Ready to upgrade KDP infrastructure, this may take a few minutes...")
		log.Debug("##### Runtime Flags #####")
		log.Debugf("kdp-repo: %s", repoUrl)
		log.Debugf("kdp-repo-ref: %s", repoRef)
		log.Debugf("artifact-server: %s", artifactServer)
		log.Debugf("helm-repository: %s", helmRepo)
		log.Debugf("docker-registry: %s", dockerRegistry)
		log.Debugf("set-parameters: %v", setParameters)
		log.Debugf("src-upgrade: %v", srcUpgrade)
		log.Debugf("vela-upgrade: %v", velaUpgrade)
		log.Debug("##### ##### #####")

		if srcUpgrade {
		    _, err := utils.ExecCmd(
				fmt.Sprintf(
					"rm -rf %s && mv -f %s %s", 
					kdpSrcDirBak, kdpSrcDir, kdpSrcDirBak,
				), true,
			)
			if err != nil {
			    log.Errorf("Failed to backup KDP source codes: %v", err)
				return
			}
			err = utils.GitCloneToDir(repoUrl, repoRef, kdpSrcDir)
			if err != nil {
				log.Errorf("Error upgrading KDP source codes: %v", err)
				return
			}
		}
		
		if velaUpgrade {
		    err := vela.VelaInstall(artifactServer, dockerRegistry, kdpCacheDir, kdpBinDir, velaVersion, true)
			if err != nil {
				log.Errorf("Error upgrading KDP vela: %v", err)
				return
			}
		}
		
		reservedParams := []string{fmt.Sprintf("helmURL=%s", helmRepo), fmt.Sprintf("registry=%s", dockerRegistry)}
		mergedParams := append(reservedParams, setParameters...)
		err := vela.VelaAddonLocalUpgrade(kdpInfraAddons, mergedParams, kdpInfraDir, kdpBinDir)
		if err != nil {
			log.Errorf("Error upgrading KDP vela addons: %v", err)
		    return
		}

		log.Info("KDP infrastructure has been upraded successfully!")

	},
}

func init() {
	upgradeCmd.Flags().StringVar(&repoUrl, "kdp-repo", defaultKdpRepoUrl, "URL of kubernetes-data-platform git repository")
	upgradeCmd.Flags().StringVar(&repoRef,"kdp-repo-ref", defaultKdpRepoRef, "Branch/Tag of kubernetes-data-platform git repository")
	upgradeCmd.Flags().StringVar(&artifactServer,"artifact-server", defaultArtifactServer, "KDP artifact server URL")
	upgradeCmd.Flags().StringVar(&helmRepo,"helm-repository", defaultHelmRepoisotry, "KDP helm repository URL")
	upgradeCmd.Flags().StringVar(&dockerRegistry,"docker-registry", defaultDockerRegistry, "KDP docker registry URL")
	upgradeCmd.Flags().BoolVar(&srcUpgrade,"src-upgrade", false, "Perform an upgrade of KDP source codes, by default it will not be upgraded")
	upgradeCmd.Flags().BoolVar(&velaUpgrade,"vela-upgrade", false, "Perform an upgrade of KDP vela, by default it will not be upgraded")
	upgradeCmd.Flags().StringArrayVar(&setParameters, "set", []string{}, "Set runtime parameters by 'key=value', for example '--set key1=value1 --set key2=value2 ...'. The specified parameters will be merged with existing runtime parameters.")
}
