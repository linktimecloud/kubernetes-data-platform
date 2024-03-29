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
	"path/filepath"
	"os"
	"os/user"

	"github.com/spf13/cobra"
)

var (
	debug bool
	usr, _ = user.Current()
	kdpRootDir = filepath.Join(usr.HomeDir, ".kdp")
	kdpBinDir = filepath.Join(kdpRootDir, "bin")
    kdpCacheDir = filepath.Join(kdpRootDir, "cache")
    kdpSrcDir = filepath.Join(kdpRootDir, "src")
	kdpSrcDirBak = filepath.Join(kdpRootDir, ".src.bak")
	kdpInfraDir = filepath.Join(kdpSrcDir, "infra")
	kdpInfraAddons = []string{"fluxcd", "openebs", "plg-stack", "kong", "mysql", "kdp-core"}
	kdpLocalCluster = "kdp-e2e"

	// flags for install/ugprade
	repoUrl string
	repoRef string
	artifactServer string
	helmRepo string
	dockerRegistry string
	setParameters []string
	forceReinstall bool
	localMode bool
	srcUpgrade bool
	velaUpgrade bool
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "kdp",
	Short: "A CLI tool for managing Kubernetes Data Platform infrastructure.",
	Long: "A CLI tool for managing Kubernetes Data Platform infrastructure.",
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentPreRun = setUpLogs
	rootCmd.PersistentFlags().BoolVarP(&debug, "debug", "d", false, "Verbose logging")
	
	rootCmd.AddCommand(installCmd)
	rootCmd.AddCommand(upgradeCmd)
	rootCmd.AddCommand(versionCmd)
}
