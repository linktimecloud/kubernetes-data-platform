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
package utils

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"archive/tar"
	"compress/gzip"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/user"
	"os/exec"
	"path/filepath"
	"regexp"
	"text/template"
	"runtime"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
	"github.com/go-git/go-git/v5/plumbing/transport"
	gitssh "github.com/go-git/go-git/v5/plumbing/transport/ssh"
	githttp "github.com/go-git/go-git/v5/plumbing/transport/http"
	log "github.com/sirupsen/logrus"
)

var usr, _ = user.Current()

func ArrayJoin(arr []string, delimeter string) string {
	return strings.Join([]string(arr), delimeter)
 }

func DownloadFile(url string, targetDir string) error {
	log.Debugf("Downloading file %s to %s", url, targetDir)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("failed to create target directory: %v", err)
	}

	client := &http.Client{}
	resp, err := client.Head(url)
	if err != nil {
		return fmt.Errorf("failed to fetch headers of remote file: %s", err)
	}
	defer resp.Body.Close()

	remoteModTime, err := time.Parse(time.RFC1123, resp.Header.Get("Last-Modified"))
	if err != nil {
		return fmt.Errorf("failed to stat remote file: %s", err)
	}

	localFilePath := filepath.Join(targetDir, filepath.Base(url))
	if _, err := os.Stat(localFilePath); !os.IsNotExist(err) {
		localFileInfo, err := os.Stat(localFilePath)
		if err != nil {
			return fmt.Errorf("failed to stat local file: %s", err)
		}

		if !remoteModTime.Before(localFileInfo.ModTime()) {
			if err := os.Remove(localFilePath); err != nil {
				return fmt.Errorf("failed to remove local file: %s", err)
			}
		}
	}

	if _, err := os.Stat(localFilePath); os.IsNotExist(err) {
		resp, err = client.Get(url)
		if err != nil {
			return fmt.Errorf("failed to download file: %s", err)
		}
		defer resp.Body.Close()
		
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return fmt.Errorf("failed to read response body: %s", err)
		}

		if err := ioutil.WriteFile(localFilePath, body, 0644); err != nil {
			return fmt.Errorf("failed to write to local file: %s", err)
		}
	}

	return nil
}

func ExecCmd(cmdStr string, suppressStdout bool) (int, error) {
    cmd := exec.Command("sh", "-c", cmdStr)
	log.Debugf("Exec command: %s", cmdStr)

	if ! suppressStdout {
		var stdoutBuf bytes.Buffer
	    // var stdoutBuf, stderrBuf bytes.Buffer
		cmd.Stdout = io.MultiWriter(os.Stdout, &stdoutBuf)
		cmd.Stderr = cmd.Stdout
		// cmd.Stderr = io.MultiWriter(os.Stderr, &stderrBuf)
	}

	err := cmd.Start()
	if err != nil {
		return 1, fmt.Errorf("failed to start command: %v", err)
	}
	
	err = cmd.Wait()
	if err != nil {
		return 1, fmt.Errorf("failed to wait command: %v", err)
	}
	
	return 0, nil
}

func ExtractTarGZ(tarBallFile, targetDir, pathInTar string) error {
	// create targetDir if not exists
	if _, err := os.Stat(targetDir); os.IsNotExist(err) {
	    err := os.MkdirAll(targetDir, 0755)
	    if err != nil {
	        return fmt.Errorf("failed to create target directory: %v", err)
	    }
	}

	// open tar.gz file
    file, err := os.Open(tarBallFile)
	if err != nil {
		return fmt.Errorf("failed to open file %s: %v", tarBallFile, err)
	}
	defer file.Close()

	// create gzip reader
	reader, err := gzip.NewReader(file)
	if err != nil {
		return fmt.Errorf("failed to create gzip reader: %v", err)
	}
	defer reader.Close()

	// create tar reader and copy files to target directory
	tarReader := tar.NewReader(reader)
	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read tar entry: %v", err)
		}

		if pathInTar != "" && !strings.HasPrefix(header.Name, pathInTar) {
			continue
		}

		switch header.Typeflag {
			case tar.TypeDir:
				if _, err := os.Stat(filepath.Join(targetDir, filepath.Base(header.Name))); os.IsNotExist(err) {
					err := os.MkdirAll(filepath.Join(targetDir, filepath.Base(header.Name)), 0755)
					if err != nil {
						return fmt.Errorf("failed to create directory: %v", err)
					}
				}
			case tar.TypeReg:
				targetFile, err := os.Create(filepath.Join(targetDir, filepath.Base(header.Name)))
				if err != nil {
				    return fmt.Errorf("failed to create target file: %v", err)
				}
				defer targetFile.Close()
				if _, err := io.Copy(targetFile, tarReader); err != nil {
				    return fmt.Errorf("failed to write target file: %v", err)
				}
			default:
				return fmt.Errorf("unsupported tar entry type: %v in : %v", header.Typeflag, header.Name)
		}
	}

	return nil
}

func GetEnv(key, fallback string) string {
    value := os.Getenv(key)
    if len(value) == 0 {
        return fallback
    }
    return value
}

func GitCloneSSHAuth(privateSshKeyFile string) transport.AuthMethod {
	sshKey, _ := ioutil.ReadFile(privateSshKeyFile)
	signer, _ := ssh.ParsePrivateKey([]byte(sshKey))
	var auth = &gitssh.PublicKeys{
		User: "git", 
		Signer: signer,
		HostKeyCallbackHelper: gitssh.HostKeyCallbackHelper{
			HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		},
	}
	return auth
}

func GitCloneHTTPAuth(username, password string) transport.AuthMethod {
	var auth = &githttp.BasicAuth{
		Username: username,
		Password: password,
	}
	return auth
}

func GitCloneToDir(repoUrl, repoRef, targetDir string) error {
	var auth transport.AuthMethod
	log.Debugf("Cloning git repo %s to %s", repoUrl, targetDir)
	
	if _, err := os.Stat(targetDir); !os.IsNotExist(err) {
		_, err := git.PlainOpen(targetDir)
		if err != nil {
			os.RemoveAll(targetDir)
		} else {
			log.Debugf("Git repo is already cloned, just skip.")
		}
	}

	if _, err := os.Stat(targetDir); os.IsNotExist(err) {
		err = os.MkdirAll(targetDir, 0755)
		if err != nil {
			return err
		}

		authType := ValidateRepoAuthType(repoUrl)
		switch authType {
		case "ssh":
			log.Info("Using SSH auth method for git clone")
			auth = GitCloneSSHAuth(usr.HomeDir + "/.ssh/id_rsa")
		case "http":
			log.Info("Using HTTP auth method for git clone. Set env 'export KDP_SRC_ACCESS_TOKEN=<your_token>' if using your private fork to pull KDP source codes.")
			gitAccessToken := GetEnv("KDP_SRC_ACCESS_TOKEN", "")
			auth = GitCloneHTTPAuth("anybody", gitAccessToken)
		default:
			log.Info("Using NO auth method for git clone")
			auth = nil
		}

		_, err = git.PlainClone(targetDir, false, &git.CloneOptions{
			URL:      		repoUrl,
			Progress: 		os.Stdout,
			Auth:			auth,
			ReferenceName: 	plumbing.ReferenceName(repoRef),
		})
		if err != nil {
			return err
		} else {
			log.Debugf("Git repo has been cloned successfully!")
		}
	}

	return nil
}

func GenRegistryAuthFile(registry, authToken, authFile string) error {
	// define a template for registry auth `config.json`
	tmpl := `{
		"auths": {
			"{{.Registry}}": {
				"auth": "{{.AuthToken}}"
			}
		}
	}`
	// render template
	var buf bytes.Buffer
	err := template.Must(template.New("config").Parse(tmpl)).Execute(&buf, map[string]interface{}{
	    "Registry": registry,
		"AuthToken": authToken,
	})
	if err != nil {
	    return fmt.Errorf("failed to render registry auth template: %v", err)
	}
	// write file
	err = ioutil.WriteFile(authFile, buf.Bytes(), 0644)
	if err != nil {
	    return fmt.Errorf("failed to write registry auth file: %v", err)
	}

    return nil
}

func GenRegistryAuthToken(username, password string) string {
	return base64.StdEncoding.EncodeToString([]byte(username + ":" + password))
}

func GetOsType() (string, error) {
    var osType string

	switch runtime.GOOS {
	case "darwin":
		osType = "darwin"
	case "linux":
		osType = "linux"
	default:
		return "", fmt.Errorf("unsupported operating system, only support darwin and linux")
	}

	return osType, nil
}

func GetOsArch() (string, error) {
	var osArch string

	switch runtime.GOARCH {
	case "amd64":
		osArch = "amd64"
	case "arm64":
		osArch = "arm64"
	default:
		return "", fmt.Errorf("unsupported architecture, only support amd64 and arm64")
	}

	return osArch, nil
}

func checkKindCommand () error {
    if _, err := exec.LookPath("kind"); err != nil {
        return fmt.Errorf("kind command not found, please install kind first")
    }
	return nil
}

func KindCreateCluster(clusterName, clusterConfig string) error {
    err := checkKindCommand()
	if err != nil {
	    return err
	}

	if rc, _ := ExecCmd(
		fmt.Sprintf("kind get clusters | grep %s", clusterName),
		true,
	); rc == 0 {
	    log.Infof("Kind cluster '%s' already exists, skip creating kind cluster", clusterName)
		return nil
	}
	
	if rc, err := ExecCmd(
		fmt.Sprintf("kind create cluster --wait 600s --config %s", clusterConfig),
		false,
	); rc != 0 {
	    return fmt.Errorf("failed to create kind cluster: %v", err)
	}
	
	log.Infof("Kind cluster has been created successfully!")
	return nil
}

func KindDeleteCluster(clusterName string) error {
	err := checkKindCommand()
	if err != nil {
	    return err
	}

	if rc, err := ExecCmd(
		fmt.Sprintf("kind delete cluster -n %s", clusterName),
		false,
	); rc != 0 {
	    return fmt.Errorf("failed to delete kind cluster: %v", err)
	}

	log.Debugf("Kind cluster has been deleted successfully!")
	return nil
}

func ValidateRepoAuthType(repoUrl string) string {
	regexSSH := regexp.MustCompile(`^(git@([a-zA-Z0-9.-]+)/*([a-zA-Z0-9-]+)*/*([a-zA-Z0-9-]+):([a-zA-Z0-9-]+)*/*([a-zA-Z0-9-]+).git|)$`)
	regexHTTP := regexp.MustCompile(`^(https?://([a-zA-Z0-9.-]+)/([a-zA-Z0-9-]+)/*([a-zA-Z0-9-]+)*/*([a-zA-Z0-9-]+).git)$`)

	if regexSSH.MatchString(repoUrl) {
		return "ssh"
	} else if regexHTTP.MatchString(repoUrl) {
		return "http"
	} else {
		return "unkown"
	}
}

func ValidateDockerRegistryAuth(registry, username, password string) error {
	req, err := http.NewRequest("HEAD", fmt.Sprintf("https://%s/v2/", registry), nil)
	if err != nil {
		return fmt.Errorf("Error creating request: %v", err)
	}

	req.SetBasicAuth(username, password)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("Error making request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Failed to authenticate docker registry '%s' , status code: %d", registry, resp.StatusCode)
	}

	log.Debugf("Successfully authenticated to docker registry <%s>", registry)

	return nil
}