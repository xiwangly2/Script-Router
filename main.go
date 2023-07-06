package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
)

// 处理请求
func handleRequest(w http.ResponseWriter, r *http.Request) {
	requestSource := getRequestSource(r)

	if requestSource == "curl" || requestSource == "wget" {
		// 如果是通过curl或wget访问，则输出shell文件
		scriptContent, err := ioutil.ReadFile("scripts/index.sh")
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, "Internal Server Error")
			return
		}

		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", "attachment; filename=shell.sh")
		fmt.Fprint(w, string(scriptContent))
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

	// 选择要监听的地址和端口
	addr := "0.0.0.0:8080"

	fmt.Printf("Server is listening on %s\n", addr)

	err := http.ListenAndServe(addr, nil)
	if err != nil {
		log.Fatal(err)
	}
}
