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
package vela

import (
	"fmt"
	"path/filepath"
	
	"kdp/pkg/utils"

	log "github.com/sirupsen/logrus"
)

func VelaInstall(artifactServer, dockerRegistry, cacheDir, binDir, velaVersion string, upgrade bool) error {
	
	if upgrade {
	    log.Info("Ready to upgrade vela")
	} else {
		log.Info("Ready to install vela")
	}
	
	var osType, osArch string
	osType, err := utils.GetOsType()
	if err != nil {
	    return err
	}
	osArch, err = utils.GetOsArch()
	if err != nil {
	    return err
	}

	var velaTarBall = fmt.Sprintf("vela-v%s-%s-%s.tar.gz", velaVersion, osType, osArch)
	var velaChart = fmt.Sprintf("vela-core-%s.tgz", velaVersion)
	var velaCli = filepath.Join(binDir, "vela")

	// Download vela-cli tarball to cache dir if not exists
	var remoteTarBall = fmt.Sprintf("%s/%s", artifactServer, velaTarBall)
	err = utils.DownloadFile(remoteTarBall, cacheDir)
	if err != nil {
	    return fmt.Errorf("error downloading vela tarball: %v", err)
	}

	// Download vela-core chart to cache dir
	err = utils.DownloadFile(fmt.Sprintf("%s/%s", artifactServer, velaChart), cacheDir)
	if err != nil {
	    return fmt.Errorf("error downloading vela chart: %v", err)
	}

	// Extract vela-cli tarball
	_, err = utils.ExecCmd(
		fmt.Sprintf(
			"mkdir -p %s && tar -xzf %s --strip-components 1 -C %s %s-%s/vela", 
			binDir, filepath.Join(cacheDir, velaTarBall), binDir, osType, osArch,
		), true,
	)
	if err != nil {
	    return fmt.Errorf("error extracting vela-cli tarball: %v", err)
	}

	// Set vela-cli executable permission
	_, err = utils.ExecCmd(fmt.Sprintf("chmod +x %s", velaCli), true)
	if err != nil {
	    return fmt.Errorf("error setting vela-cli executable permission: %v", err)
	}

	// Check vela-cli version
	_, err = utils.ExecCmd(fmt.Sprintf("%s version", velaCli), true)
	if err != nil {
	    return fmt.Errorf("error executing vela-cli commands: %v", err)
	}

	rc, _ := utils.ExecCmd(fmt.Sprintf("%s system info -s kubevela-vela-core", velaCli), true)
	if ! upgrade && rc == 0 {
	    log.Info("Find existing vela-core deployment, skip vela-core installation")
		return nil
	} else {
		_, err = utils.ExecCmd(
			fmt.Sprintf(
				"%s install --yes --detail=false --file %s --set imageRegistry=%s/ --set image.pullPolicy=IfNotPresent --set replicaCount=3", 
				velaCli, filepath.Join(cacheDir, velaChart), dockerRegistry,
			), false,
		)
		if err != nil {
			if upgrade {
			    return fmt.Errorf("error upgrading vela-core: %v", err)
			} else {
				return fmt.Errorf("error installing vela-core: %v", err)
			}
		}
	}

	if upgrade {
		log.Info("Successfully upgraded vela!")
	} else {
		log.Info("Successfully installed vela!")
	}

	return nil
}

func VelaAddonLocalInstall(addons, setParameters []string, addonLocalDir , binDir string, forceReinstall bool) error {
	var addonParams = utils.ArrayJoin(setParameters, " ")
	var velaCli = filepath.Join(binDir, "vela")
	
	for _, addon := range addons {
		addonLocalPath := filepath.Join(addonLocalDir, addon)

		log.Infof("Handling addon now -> [name: %s] [path: %s] [parameters: (%s)]", addon, addonLocalPath, addonParams)
	    
		if ! forceReinstall {
			log.Infof("Checking if addon %s has already been installed", addon)
			cmd := fmt.Sprintf("%s status -n vela-system addon-%s", velaCli, addon)
			rc, _ := utils.ExecCmd(cmd, true)
			if rc == 0 {
			    log.Infof("Addon %s has already been installed, skip installing", addon)
				continue
			}
		}

		cmd := fmt.Sprintf("%s addon enable --yes --override-definitions %s %s", velaCli, addonLocalPath, addonParams)
		_, err := utils.ExecCmd(cmd, false)
		if err != nil {
			return fmt.Errorf("error installing addon %s: %v", addon, err)
		}
	}

	return nil
}

func VelaAddonLocalUpgrade(addons, setParameters []string, addonLocalDir , binDir string) error {
	var addonParams = utils.ArrayJoin(setParameters, " ")
	var velaCli = filepath.Join(binDir, "vela")
	
	for _, addon := range addons {
		addonLocalPath := filepath.Join(addonLocalDir, addon)

		log.Debugf("Handling addon name: %s, addon path: %s, set parameters: (%s)", addon, addonLocalPath, addonParams)
	    
		cmd := fmt.Sprintf("%s addon upgrade --yes --override-definitions %s %s", velaCli, addonLocalPath, addonParams)
		_, err := utils.ExecCmd(cmd, false)
		if err != nil {
			return fmt.Errorf("error installing addon %s: %v", addon, err)
		}
	}

	return nil
}
