package dataaccess

import (
	"net/url"
	"github.com/spf13/afero"
)


func newFileStore(uri *url.URL) afero.Fs {
	var fs afero.Fs
	if uri.Scheme == "memory" {
		fs = afero.NewMemMapFs()
	} else {
		fs = afero.NewOsFs()
	}
	return fs
}