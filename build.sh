#!/bin/bash

# MCPHub Docker Build Script
# 独立项目构建脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="mcphub"
PROJECT_VERSION="v0.11.12"
CONTAINER_PORT=3000
HOST_PORT=3001  # 使用 3001 端口，避免与 new-api (3000) 冲突

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MCPHub Docker Build Script${NC}"
echo -e "${GREEN}  端口: ${HOST_PORT} -> ${CONTAINER_PORT}${NC}"
echo -e "${GREEN}========================================${NC}"

# 使用项目版本
echo -e "\n${YELLOW}[1/5] 项目版本信息${NC}"
echo -e "${GREEN}当前版本: ${PROJECT_VERSION}${NC}"

# 获取当前 Git commit
COMMIT="local"
if [ -d ".git" ]; then
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
fi

# 获取构建时间
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "\n${YELLOW}[2/5] 构建信息:${NC}"
echo -e "  版本号: ${GREEN}${PROJECT_VERSION}${NC}"
echo -e "  Commit: ${GREEN}${COMMIT}${NC}"
echo -e "  构建时间: ${GREEN}${BUILD_TIME}${NC}"
echo -e "  端口映射: ${GREEN}${HOST_PORT}:${CONTAINER_PORT}${NC}"

# 停止现有容器
echo -e "\n${YELLOW}[3/5] 停止现有容器...${NC}"
sudo docker stop ${PROJECT_NAME} 2>/dev/null || true
sudo docker rm ${PROJECT_NAME} 2>/dev/null || true

# 检查是否设置了代理
PROXY_ARGS=""
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo -e "${YELLOW}检测到代理设置:${NC}"
    HOST_IP=$(ip route get 1 | awk '{print $7;exit}' 2>/dev/null || hostname -I | awk '{print $1}')
    DOCKER_HTTP_PROXY=$(echo "$HTTP_PROXY" | sed "s/127\.0\.0\.1/${HOST_IP}/g" | sed "s/localhost/${HOST_IP}/g")
    DOCKER_HTTPS_PROXY=$(echo "$HTTPS_PROXY" | sed "s/127\.0\.0\.1/${HOST_IP}/g" | sed "s/localhost/${HOST_IP}/g")
    [ -n "$HTTP_PROXY" ] && echo -e "  HTTP_PROXY: ${GREEN}${DOCKER_HTTP_PROXY}${NC}"
    [ -n "$HTTPS_PROXY" ] && echo -e "  HTTPS_PROXY: ${GREEN}${DOCKER_HTTPS_PROXY}${NC}"
    PROXY_ARGS="--build-arg HTTP_PROXY=${DOCKER_HTTP_PROXY} --build-arg HTTPS_PROXY=${DOCKER_HTTPS_PROXY}"
fi

# 构建镜像 (限制资源防止服务器崩溃)
echo -e "\n${YELLOW}[4/5] 构建 Docker 镜像 (资源限制: 1GB 内存, 1 CPU)...${NC}"
sudo docker build \
    --memory=1g \
    --memory-swap=2g \
    --cpu-quota=100000 \
    ${PROXY_ARGS} \
    -t ${PROJECT_NAME}:local \
    .

# 启动容器
echo -e "\n${YELLOW}[5/5] 启动容器...${NC}"
sudo docker run -d \
    --name ${PROJECT_NAME} \
    -p ${HOST_PORT}:${CONTAINER_PORT} \
    -v $(pwd)/mcp_settings.json:/app/mcp_settings.json \
    -v $(pwd)/data:/app/data \
    --restart unless-stopped \
    --memory=512m \
    --cpus=1 \
    ${PROJECT_NAME}:local

# 等待启动
sleep 10

# 修复 powermem infer 默认值
echo -e "${YELLOW}修复 powermem infer 默认值...${NC}"
POWERMEM_PATH=$(sudo docker exec ${PROJECT_NAME} find /root/.cache -path "*/powermem/core/memory.py" 2>/dev/null | head -1)
if [ -n "$POWERMEM_PATH" ]; then
  sudo docker exec ${PROJECT_NAME} sed -i 's/infer: bool = True/infer: bool = False/' "$POWERMEM_PATH"
  echo -e "${GREEN}已修复 powermem infer 默认值为 False${NC}"
fi

# 清理旧镜像
echo -e "\n${YELLOW}清理旧镜像...${NC}"
CURRENT_IMAGE=$(sudo docker images ${PROJECT_NAME}:local -q)
DANGLING=$(sudo docker images -f "dangling=true" -q 2>/dev/null)
if [ -n "$DANGLING" ]; then
    sudo docker rmi $DANGLING 2>/dev/null || true
fi
echo -e "${GREEN}清理完成${NC}"

# 显示日志
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  构建完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}容器日志:${NC}"
sudo docker logs ${PROJECT_NAME} --tail=20

# 显示信息
echo -e "\n${YELLOW}Docker 镜像占用:${NC}"
sudo docker images ${PROJECT_NAME}:local --format "镜像: {{.Repository}}:{{.Tag}}  大小: {{.Size}}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  MCPHub 部署成功!${NC}"
echo -e "${GREEN}  访问地址: http://localhost:${HOST_PORT}${NC}"
echo -e "${GREEN}  登录账号: admin / admin123${NC}"
echo -e "${GREEN}========================================${NC}"