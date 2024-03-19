package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

var (
	fileCache     = make(map[string][]byte)
	fileCacheLock sync.RWMutex
)

// 获取文件内容，如果缓存中不存在，则从磁盘读取
func getFileContent(filePath string) ([]byte, error) {
	fileCacheLock.RLock()
	content, found := fileCache[filePath]
	fileCacheLock.RUnlock()

	if !found {
		// 从磁盘读取文件内容
		fileContent, err := os.ReadFile(filePath)
		if err != nil {
			return nil, err
		}

		// 更新缓存
		fileCacheLock.Lock()
		fileCache[filePath] = fileContent
		fileCacheLock.Unlock()

		return fileContent, nil
	}

	return content, nil
}

// 处理请求
func handleRequest(w http.ResponseWriter, r *http.Request) {
	requestSource := getRequestSource(r)

	// 获取请求的脚本文件名
	scriptName := filepath.Base(r.URL.Path)
	// 构建脚本文件的完整路径
	scriptPath := filepath.Join("scripts", scriptName)

	if requestSource == "curl" || requestSource == "wget" {
		// 检查是否为根路径
		if r.URL.Path == "/" {
			scriptPath = filepath.Join("scripts", "index.sh")
		}

		// 获取文件内容
		scriptContent, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusNotFound)
			_, _ = fmt.Fprint(w, "File Not Found")
			return
		}

		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", "attachment; filename="+scriptName)
		_, _ = fmt.Fprint(w, string(scriptContent))
		return
	} else if requestSource == "powershell" {
		// 检查是否为根路径
		if r.URL.Path == "/" {
			scriptPath = filepath.Join("scripts", "index.ps1")
		}
		indexContent, err := getFileContent(scriptPath)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = fmt.Fprint(w, "Internal Server Error")
			return
		}

		w.Header().Set("Content-Type", "text/plain")
		_, _ = fmt.Fprint(w, string(indexContent))
		return
	} else {
		// 如果是正常浏览器访问，则显示index.html的内容
		indexContent, err := getFileContent("index.html")
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = fmt.Fprint(w, "Internal Server Error")
			return
		}

		w.Header().Set("Content-Type", "text/html")
		_, _ = fmt.Fprint(w, string(indexContent))
	}
}

// 获取请求来源
func getRequestSource(r *http.Request) string {
	userAgent := r.Header.Get("User-Agent")
	if strings.Contains(userAgent, "curl") {
		return "curl"
	} else if strings.Contains(userAgent, "Wget") {
		return "wget"
	} else if strings.Contains(userAgent, "WindowsPowerShell") {
		return "powershell"
	}
	//fmt.Printf("User-Agent: %s\n", userAgent)
	return "browser"
}

func main() {
	http.HandleFunc("/", handleRequest)

	// 选择要监听的地址和端口
	// 建议使用其他的端口避免冲突
	addr := "0.0.0.0:8080"

	fmt.Printf("Server is listening on %s\n", addr)

	err := http.ListenAndServe(addr, nil)
	if err != nil {
		log.Fatal(err)
	}
}
