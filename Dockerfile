# 阶段一：构建阶段
FROM golang:1.20.5 AS builder

# 设置工作目录为 /app
WORKDIR /app

# 复制Go程序文件到容器中
COPY . .

# 构建Go程序
RUN go build -o "Script-Router"

# 阶段二：运行阶段
FROM alpine:latest

# 从第一阶段中复制生成的可执行文件到当前容器
COPY --from=builder "/app/Script-Router" "/app/Script-Router"

# 暴露容器的端口号
EXPOSE 8080

# 定义启动容器时运行的命令
CMD ["/app/Script-Router"]
