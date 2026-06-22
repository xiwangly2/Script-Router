package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"mime"
	"net/http"
	"os"
	"os/signal"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	fileCache = sync.Map{}
)

// 获取文件内容，如果缓存中不存在，则从磁盘读取
func getFileContent(filePath string) ([]byte, error) {
	if content, ok := fileCache.Load(filePath); ok {
		return content.([]byte), nil
	}

	fileContent, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	fileCache.Store(filePath, fileContent)
	return fileContent, nil
}

// 处理请求
func handleRequest(w http.ResponseWriter, r *http.Request) {
	requestSource := getRequestSource(r)

	if hasParentPathSegment(r.URL.Path) {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Invalid path")
		return
	}

	cleanPath := path.Clean(r.URL.Path)

	switch requestSource {
	case "curl", "wget":
		scriptPath, scriptName := scriptTarget(cleanPath, "index.sh")
		scriptContent, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, "File Not Found")
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": scriptName}))
		_, _ = w.Write(scriptContent)
	case "powershell":
		scriptPath, _ := scriptTarget(cleanPath, "index.ps1")
		content, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, "File Not Found")
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write(content)
	default:
		content, err := getFileContent("index.html")
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, "Internal Server Error")
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write(content)
	}
}

func hasParentPathSegment(urlPath string) bool {
	for _, segment := range strings.Split(urlPath, "/") {
		if segment == ".." {
			return true
		}
	}
	return false
}

func scriptTarget(cleanPath, indexFile string) (string, string) {
	scriptName := filepath.Base(cleanPath)
	if cleanPath == "/" || cleanPath == "." {
		scriptName = indexFile
	}
	return filepath.Join("scripts", scriptName), scriptName
}

func getRequestSource(r *http.Request) string {
	agent := strings.ToLower(r.Header.Get("User-Agent"))
	switch {
	case strings.Contains(agent, "curl"):
		return "curl"
	case strings.Contains(agent, "wget"):
		return "wget"
	case strings.Contains(agent, "windowspowershell"), strings.Contains(agent, "powershell"):
		return "powershell"
	default:
		return "browser"
	}
}

func main() {
	var addr string
	flag.StringVar(&addr, "addr", "0.0.0.0:28789", "server address")
	flag.Parse()

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRequest)

	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("Server is listening on %s\n", addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("ListenAndServe error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("Shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	log.Println("Server exiting")
}
