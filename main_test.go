package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func setupTestFiles(t *testing.T) {
	t.Helper()

	t.Chdir(t.TempDir())
	fileCache = sync.Map{}

	if err := os.Mkdir("scripts", 0o755); err != nil {
		t.Fatal(err)
	}

	files := map[string]string{
		"index.html":                          "<html>home</html>",
		filepath.Join("scripts", "index.sh"):  "echo shell",
		filepath.Join("scripts", "index.ps1"): "Write-Output powershell",
		filepath.Join("scripts", "arch.sh"):   "uname -m",
	}

	for name, content := range files {
		if err := os.WriteFile(name, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestHandleRequestRoutesByUserAgent(t *testing.T) {
	setupTestFiles(t)

	tests := []struct {
		name            string
		target          string
		userAgent       string
		wantStatus      int
		wantBody        string
		wantContentType string
		wantDisposition string
	}{
		{
			name:            "curl root returns shell index",
			target:          "/",
			userAgent:       "curl/8.0.1",
			wantStatus:      http.StatusOK,
			wantBody:        "echo shell",
			wantContentType: "application/octet-stream",
			wantDisposition: "attachment; filename=index.sh",
		},
		{
			name:            "wget lookup is case insensitive",
			target:          "/arch.sh",
			userAgent:       "wget/1.21",
			wantStatus:      http.StatusOK,
			wantBody:        "uname -m",
			wantContentType: "application/octet-stream",
		},
		{
			name:            "powershell root returns ps1 index",
			target:          "/",
			userAgent:       "WindowsPowerShell/7.4",
			wantStatus:      http.StatusOK,
			wantBody:        "Write-Output powershell",
			wantContentType: "text/plain",
		},
		{
			name:            "browser returns html",
			target:          "/anything",
			userAgent:       "Mozilla/5.0",
			wantStatus:      http.StatusOK,
			wantBody:        "<html>home</html>",
			wantContentType: "text/html; charset=utf-8",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tt.target, nil)
			req.Header.Set("User-Agent", tt.userAgent)
			rec := httptest.NewRecorder()

			handleRequest(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tt.wantStatus)
			}
			if rec.Body.String() != tt.wantBody {
				t.Fatalf("body = %q, want %q", rec.Body.String(), tt.wantBody)
			}
			if got := rec.Header().Get("Content-Type"); got != tt.wantContentType {
				t.Fatalf("content-type = %q, want %q", got, tt.wantContentType)
			}
			if tt.wantDisposition != "" {
				if got := rec.Header().Get("Content-Disposition"); got != tt.wantDisposition {
					t.Fatalf("content-disposition = %q, want %q", got, tt.wantDisposition)
				}
			}
		})
	}
}

func TestHandleRequestRejectsParentPath(t *testing.T) {
	setupTestFiles(t)

	for _, target := range []string{"/../arch.sh", "/%2e%2e/arch.sh"} {
		t.Run(target, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, target, nil)
			req.Header.Set("User-Agent", "curl/8.0.1")
			rec := httptest.NewRecorder()

			handleRequest(rec, req)

			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
			}
			if !strings.Contains(rec.Body.String(), "Invalid path") {
				t.Fatalf("body = %q, want invalid path message", rec.Body.String())
			}
		})
	}
}

func TestHandleRequestReturnsNotFoundForMissingScripts(t *testing.T) {
	setupTestFiles(t)

	for _, userAgent := range []string{"curl/8.0.1", "WindowsPowerShell/7.4"} {
		t.Run(userAgent, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/missing.sh", nil)
			req.Header.Set("User-Agent", userAgent)
			rec := httptest.NewRecorder()

			handleRequest(rec, req)

			if rec.Code != http.StatusNotFound {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusNotFound)
			}
		})
	}
}
