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

	"github.com/spf13/cobra"
)

var CliVersion string
var CliGoVersion string
var CliGitCommit string
var CliBuiltAt string
var CliOSArch string

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print CLI build version",
	Long: "Print CLI build version.",

	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("%-15s %s\n", "CLI version:", CliVersion)
		fmt.Printf("%-15s %s\n", "Go version:", CliGoVersion)
		fmt.Printf("%-15s %s\n", "Git commit:", CliGitCommit)
		fmt.Printf("%-15s %s\n", "Built at:", CliBuiltAt)
		fmt.Printf("%-15s %s\n", "OS/Arch:", CliOSArch)
	},
}

func init() {}
