# 阶段一：构建阶段
FROM golang:1.24.3 AS builder

# 设置工作目录为 /app
WORKDIR /app

# 复制Go程序文件到容器中
COPY . .

# 构建Go程序
RUN CGO_ENABLED=0 go build -o "Script-Router"

# 阶段二：运行阶段
FROM scratch

# 从第一阶段中复制生成的可执行文件和脚本到当前容器
COPY --from=builder "/app/Script-Router" "/app/Script-Router"
COPY --from=builder "/app/scripts" "/app/scripts"

# 暴露容器的端口号
EXPOSE 8080

# 定义启动容器时运行的命令
CMD ["/app/Script-Router"]