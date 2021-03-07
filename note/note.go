package note

import (
	"fmt"
	"github.com/google/uuid"
	"github.com/pedersen/brainframe/dataaccess"
)

type Note struct {
	Id uuid.UUID
	MimeType string
	Body []byte
}

type NoteActions interface {
	New() Note
	Load(db *dataaccess.DocumentStore, id uuid.UUID) Note
	Save(db *dataaccess.DocumentStore, note *Note) error
	Binary() []byte
	fmt.Stringer
}
