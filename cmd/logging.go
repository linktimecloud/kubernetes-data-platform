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
	"strings"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

type PlainFormatter struct {
} 

func (f *PlainFormatter) Format(entry *log.Entry) ([]byte, error) {
	var levelColor int
    switch entry.Level {
    case log.DebugLevel, log.TraceLevel:
        levelColor = 31 // gray
    case log.WarnLevel:
        levelColor = 33 // yellow
    case log.ErrorLevel, log.FatalLevel, log.PanicLevel:
        levelColor = 31 // red
    default:
        levelColor = 36 // blue
    }
	// return []byte(fmt.Sprintf("\x1b[%dm%s\x1b[0m\n", levelColor, entry.Message)), nil
	return []byte(fmt.Sprintf("[\x1b[%dm%s\x1b[0m] - %s\n", levelColor, strings.ToUpper(entry.Level.String()), entry.Message)), nil
}

func setUpLogs(cmd *cobra.Command, args []string) {
	if debug {
		log.SetLevel(log.DebugLevel)
		log.SetFormatter(&log.TextFormatter{
			FullTimestamp:          true,
			TimestampFormat:        "2006-01-02 15:04:05",
			ForceColors:            true,
		})
	} else {
		plainFormatter := new(PlainFormatter)
		log.SetFormatter(plainFormatter)
	}
}
