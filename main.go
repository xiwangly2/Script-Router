package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
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

	cleanPath := path.Clean(r.URL.Path)
	if strings.Contains(cleanPath, "..") {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Invalid path")
		return
	}

	scriptName := filepath.Base(cleanPath)
	scriptPath := filepath.Join("scripts", scriptName)

	switch requestSource {
	case "curl", "wget":
		if cleanPath == "/" {
			scriptPath = filepath.Join("scripts", "index.sh")
		}
		scriptContent, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, "File Not Found")
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", "attachment; filename="+scriptName)
		w.Write(scriptContent)
	case "powershell":
		if cleanPath == "/" {
			scriptPath = filepath.Join("scripts", "index.ps1")
		}
		content, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, "Internal Server Error")
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write(content)
	default:
		content, err := getFileContent("index.html")
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, "Internal Server Error")
			return
		}
		w.Header().Set("Content-Type", "text/html")
		w.Write(content)
	}
}

func getRequestSource(r *http.Request) string {
	agent := r.Header.Get("User-Agent")
	switch {
	case strings.Contains(agent, "curl"):
		return "curl"
	case strings.Contains(agent, "Wget"):
		return "wget"
	case strings.Contains(agent, "WindowsPowerShell"):
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
