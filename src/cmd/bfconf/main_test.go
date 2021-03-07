package main

import (
	"fmt"
	"github.com/go-akka/configuration"
	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"testing"
)

/*
Testing Plan:

Test creating empty configuration file
Test creating configuration file from initial values on command line
Test updating configuration file from command line
*/

func TestConfigurationToString(t *testing.T) {
	// Make sure that we know what the expectation is for how the configuration will be formatted.
	// This should work across platforms.
	expected := "{\r\n  hello : world\r\n}"
	cfg := configuration.ParseString(expected)
	actual := fmt.Sprintf("%v", cfg)
	assert.Equal(t, expected, actual)
}

func TestBasicConfiguration(t *testing.T) {
	expected := "file"
	cfg := configuration.ParseString(defaultconfig)
	actual := cfg.GetString("storetype")
	assert.Equal(t, expected, actual)
}

func TestSaveLoad(t *testing.T) {
	fs := afero.NewMemMapFs()
	cfg := configuration.ParseString(defaultconfig)
	saveConfig(fs, defaultfile, cfg, 0600)
	actual, err := loadConfig(fs, defaultfile)
	assert.Equal(t, err, nil)
	expected := "{\r\n  storetype : file\r\n}"
	assert.Equal(t, expected, fmt.Sprintf("%v", actual))
}

func TestUpdatingConfig(t *testing.T) {
	cfg := configuration.ParseString(defaultconfig)
	expected := "{\r\n  storetype : memory\r\n}"
	wf := cfg.AddConfig(expected, nil)
	actual := fmt.Sprintf("%v", wf)
	assert.Equal(t, expected, actual)
}