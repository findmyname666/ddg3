package web

import (
	"io/fs"
	"net/http"
	"testing"
)

func TestSecureFileSystem_BlocksHiddenFiles(t *testing.T) {
	sfs := secureFileSystem{fs: http.Dir(".")}

	tests := []struct {
		name    string
		path    string
		wantErr bool
		errType error
	}{
		{
			name:    "blocks .git directory",
			path:    "/.git/config",
			wantErr: true,
			errType: fs.ErrNotExist,
		},
		{
			name:    "blocks .env file",
			path:    "/.env",
			wantErr: true,
			errType: fs.ErrNotExist,
		},
		{
			name:    "blocks .htpasswd file",
			path:    "/.htpasswd",
			wantErr: true,
			errType: fs.ErrNotExist,
		},
		{
			name:    "blocks hidden file in subdirectory",
			path:    "/subdir/.secret",
			wantErr: true,
			errType: fs.ErrNotExist,
		},
		{
			name:    "allows normal files",
			path:    "/server.go",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := sfs.Open(tt.path)
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error for path %s, got nil", tt.path)
				}
				if tt.errType != nil && err != tt.errType {
					t.Errorf("expected error type %v, got %v", tt.errType, err)
				}
			} else if err != nil {
				t.Errorf("unexpected error for path %s: %v", tt.path, err)
			}
		})
	}
}

func TestSecureFileSystem_BlocksDirectoryTraversal(t *testing.T) {
	sfs := secureFileSystem{fs: http.Dir(".")}

	tests := []struct {
		name    string
		path    string
		wantErr bool
	}{
		{
			name:    "blocks parent directory traversal",
			path:    "/../../../etc/passwd",
			wantErr: true,
		},
		{
			name:    "blocks relative path with ..",
			path:    "/subdir/../../../secret",
			wantErr: true,
		},
		{
			name:    "allows normal paths",
			path:    "/server.go",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := sfs.Open(tt.path)
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error for path %s, got nil", tt.path)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error for path %s: %v", tt.path, err)
				}
			}
		})
	}
}

func TestContainsHiddenPath(t *testing.T) {
	tests := []struct {
		name string
		path string
		want bool
	}{
		{
			name: "detects .git",
			path: "/.git/config",
			want: true,
		},
		{
			name: "detects .env",
			path: "/.env",
			want: true,
		},
		{
			name: "detects hidden in subdirectory",
			path: "/public/.htaccess",
			want: true,
		},
		{
			name: "allows normal files",
			path: "/style.css",
			want: false,
		},
		{
			name: "allows files with dots in name",
			path: "/jquery.min.js",
			want: false,
		},
		{
			name: "allows current directory",
			path: "/./file.txt",
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := containsHiddenPath(tt.path)
			if got != tt.want {
				t.Errorf("containsHiddenPath(%q) = %v, want %v", tt.path, got, tt.want)
			}
		})
	}
}
