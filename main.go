package main

import (
	"fmt"
	"net/http"
	"strings"
)

// 处理请求
func handleRequest(w http.ResponseWriter, r *http.Request) {
	requestSource := getRequestSource(r)

	if requestSource == "curl" || requestSource == "wget" {
		// 如果是通过curl或wget访问，则输出shell文件
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", "attachment; filename=shell.sh")
		fmt.Fprint(w, "# 在这里写入你的shell脚本内容")
		return
	}

	// 如果是正常浏览器访问，则显示正常的页面
	fmt.Fprint(w, "<h1>Hello, World!</h1>")
	// 在这里编写你的页面内容
	// ...
}

// 获取请求来源
func getRequestSource(r *http.Request) string {
	userAgent := r.Header.Get("User-Agent")
	if strings.Contains(userAgent, "curl") {
		return "curl"
	} else if strings.Contains(userAgent, "Wget") {
		return "wget"
	}
	return "browser"
}

func main() {
	http.HandleFunc("/", handleRequest)
	http.ListenAndServe(":8080", nil)
}
