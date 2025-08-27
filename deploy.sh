#!/bin/bash
# 双 GPU 部署脚本

set -e

echo "================================================"
echo "  Whisper.cpp 双 GPU 部署脚本"
echo "================================================"

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    exit 1
fi

# 检查 NVIDIA 驱动
if ! nvidia-smi &> /dev/null; then
    echo "错误: NVIDIA 驱动未安装或不可用"
    exit 1
fi

echo "检查 GPU 设备..."
nvidia-smi --list-gpus

# 创建必要的目录
echo "创建数据目录..."
mkdir -p ./audio
mkdir -p ./models

# 设置权限
chmod 755 ./audio
chmod 755 ./models

echo "构建 Docker 镜像..."
docker-compose build --no-cache

echo "停止现有容器..."
docker-compose down

echo "启动服务..."
docker-compose up -d

echo "等待服务启动..."
sleep 15

echo "检查服务状态..."
for i in {0..1}; do
    port=$((8080 + i))
    echo "检查 GPU $i 实例 (端口 $port):"
    if curl -f http://localhost:$port/health > /dev/null 2>&1; then
        echo "✓ GPU $i: Healthy"
    else
        echo "✗ GPU $i: Unhealthy"
    fi
done

echo "检查负载均衡器..."
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✓ 负载均衡器: Healthy"
else
    echo "✗ 负载均衡器: Unhealthy"
fi

echo "检查服务器状态监控..."
if curl -f http://localhost/status > /dev/null 2>&1; then
    echo "✓ 服务器状态监控: Healthy"
else
    echo "✗ 服务器状态监控: Unhealthy"
fi

echo ""
echo "================================================"
echo "部署完成！"
echo "================================================"
echo "访问信息："
echo "- GPU 0 实例: http://localhost:8080"
echo "- GPU 1 实例: http://localhost:8081" 
echo "- 负载均衡: http://localhost:80"
echo ""
echo "健康检查："
echo "- 负载均衡器: http://localhost/health"
echo "- 服务器状态: http://localhost/status"
echo ""
echo "使用示例："
echo "curl -F file=@test.wav -F response_format=srt http://localhost/inference"
echo ""
echo "查看日志："
echo "docker-compose logs -f"
echo "docker-compose logs -f whisper-gpu0"
echo "docker-compose logs -f whisper-gpu1"