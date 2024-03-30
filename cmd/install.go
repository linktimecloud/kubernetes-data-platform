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
	"os"
	"path/filepath"
	

	"kdp/pkg/utils"
	"kdp/pkg/vela"

	"github.com/spf13/cobra"
	log "github.com/sirupsen/logrus"
)

// installCmd represents the install command
var installCmd = &cobra.Command{
	Use:   "install",
	Short: "Install KDP infrastructure",
	Long: `Perform an install of KDP infrastructure. 
By default the install process will skip components that already been installed.`,
	
	Example: `  Install KDP infrastructure to an exisiting Kubernetes cluster:
    kdp install 
  Install KDP infrastructure in local mode(using kind to create a local K8s cluster):
    kdp install --local-mode
  Install KDP infrastructure to a specific Kubernetes namespace:
    kdp install --set namespace=<your-namespace>
  Install KDP infrastructure with specific root domain and TLS:
    kdp install --set ingress.domain=<your-ingress-domain> --set ingress.tlsSecretName=<your-ingress-tlsSecretName>`,
	
	Run: func(cmd *cobra.Command, args []string) {

		log.Info("Ready to install KDP infrastructure, this may take a few minutes...")
		log.Debug("##### Runtime Flags #####")
		log.Debugf("kdp-repo: %s", repoUrl)
		log.Debugf("kdp-repo-ref: %s", repoRef)
		log.Debugf("artifact-server: %s", artifactServer)
		log.Debugf("helm-repository: %s", helmRepo)
		log.Debugf("docker-registry: %s", dockerRegistry)
		log.Debugf("set-parameters: %v", setParameters)
		log.Debugf("force-reinstall: %v", forceReinstall)
		log.Debugf("local-mode: %v", localMode)
		log.Debug("##### ##### #####")

		if forceReinstall {
		    _, err := utils.ExecCmd(
				fmt.Sprintf(
					"rm -rf %s && mv -f %s %s || true", 
					kdpSrcDirBak, kdpSrcDir, kdpSrcDirBak,
				), true,
			)
			if err != nil {
			    log.Errorf("Failed to backup KDP source codes: %v", err)
				return
			}
		}
		err := utils.GitCloneToDir(repoUrl, repoRef, kdpSrcDir)
		if err != nil {
			log.Errorf("Error installing KDP source codes: %v", err)
		    return
		}

		if localMode {
			log.Info("Local mode is enabled, creating a local kind cluster now. Set env 'export KDP_CR_ACCESS_TOKEN=<your_token>' if using your private container registry to pull KDP OCI images.")
		    authFile := filepath.Join(kdpSrcDir, "e2e/config.json")
			if _, err := os.Stat(authFile); os.IsNotExist(err) {
				authToken := utils.GetEnv("KDP_CR_ACCESS_TOKEN", "")
				err = utils.GenRegistryAuthFile(dockerRegistry, authToken, authFile)
				if err != nil {
				    log.Error(err)
					return
				}
			}

			kindClusterConfig := filepath.Join(kdpSrcDir, "e2e/kind-cluster.yaml")
			err = utils.KindCreateCluster(kdpLocalCluster, kindClusterConfig)
			if err != nil {
			    log.Error(err)
				return
			}
		}

		err = vela.VelaInstall(artifactServer, dockerRegistry, kdpCacheDir, kdpBinDir, velaVersion, false)
		if err != nil {
			log.Errorf("Error installing KDP vela: %v", err)
		    return
		}

		reservedParams := []string{fmt.Sprintf("helmURL=%s", helmRepo), fmt.Sprintf("registry=%s", dockerRegistry)}
		mergedParams := append(reservedParams, setParameters...)
		err = vela.VelaAddonLocalInstall(kdpInfraAddons, mergedParams, kdpInfraDir, kdpBinDir, forceReinstall)
		if err != nil {
			log.Errorf("Error installing KDP vela addons: %v", err)
		    return
		}

		log.Info("KDP infrastructure has been installed successfully!")
		log.Info("You may use `kdp upgrade` to update parameters of KDP infrastructure.")

	},
}

func init() {
	installCmd.Flags().StringVar(&repoUrl, "kdp-repo", defaultKdpRepoUrl, "URL of kubernetes-data-platform git repository")
	installCmd.Flags().StringVar(&repoRef,"kdp-repo-ref", defaultKdpRepoRef, "Branch/Tag of kubernetes-data-platform git repository")
	installCmd.Flags().StringVar(&artifactServer,"artifact-server", defaultArtifactServer, "KDP artifact server URL")
	installCmd.Flags().StringVar(&helmRepo,"helm-repository", defaultHelmRepoisotry, "KDP helm repository URL")
	installCmd.Flags().StringVar(&dockerRegistry,"docker-registry", defaultDockerRegistry, "KDP docker registry URL")
	installCmd.Flags().StringArrayVar(&setParameters, "set", []string{}, "Set runtime parameters by 'key=value', for example '--set key1=value1 --set key2=value2 ...'.")
	installCmd.Flags().BoolVar(&forceReinstall,"force-reinstall", false, "Force re-install of KDP infrastructure. BE CAREFUL USING THIS FLAG AS IT WILL OVERWRITE EXISTING INSTALLATION!!!")
	installCmd.Flags().BoolVar(&localMode, "local-mode", false, "Install KDP infrastructure in local mode(generally used for development or quick start). In this mode, a kind(https://sigs.k8s.io/kind) K8s cluster will be created locally and KDP will be installed to this local K8s cluster.")
}
