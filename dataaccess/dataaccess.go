package dataaccess

import (
	"github.com/google/uuid"
	"github.com/spf13/afero"
	"net/url"
)

type DocumentStorageMethod int

const (
	FileStore DocumentStorageMethod = iota
	MemoryStore = iota
)

type DocumentStore struct {
	Method DocumentStorageMethod
	Uri *url.URL
	fs afero.Fs
}

type DocumentDb interface {
	New(method DocumentStorageMethod, uri string) DocumentStore
	Load(uuid uuid.UUID) (mimetype string, body []byte)
	Save(uuid uuid.UUID, mimetype string, body []byte) error
}

func New(method DocumentStorageMethod, uri string) (db DocumentStore, err error) {
	db.Method = method
	db.Uri, err = url.Parse(uri)
	if err != nil {
		return
	}
	switch db.Method {
	case FileStore, MemoryStore:
		db.fs = newFileStore(db.Uri)
	}
	return
}