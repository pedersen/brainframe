package main

import (
	_ "embed"
	"fmt"
	"github.com/go-akka/configuration"
	"github.com/spf13/afero"
	"os"
)

//go:embed default-config.conf
var defaultconfig string

const defaultfile = ".brainframe.config"

func saveConfig(fs afero.Fs, filename string, config *configuration.Config, perm os.FileMode) error {
	return afero.WriteFile(
		fs,
		filename,
		[]byte(fmt.Sprintf("%v", config)),
		perm,
	)
}

func loadConfig(fs afero.Fs, filename string) (*configuration.Config, error){
	configcontents, err := afero.ReadFile(fs, filename)
	if (err != nil) {
		return nil, err
	}
	return configuration.ParseString(string(configcontents)), nil
}

func main() {
	//
}
