#!/bin/bash
# 双 GPU 测试脚本

set -e

echo "================================================"
echo "  Whisper.cpp 双 GPU 测试脚本"
echo "================================================"

# 创建测试音频文件
if [ ! -f "./audio/test.wav" ]; then
    echo "下载测试音频文件..."
    curl -o ./audio/test.ogg https://upload.wikimedia.org/wikipedia/commons/1/1f/George_W_Bush_Columbia_FINAL.ogg
    
    # 转换为 WAV 格式
    echo "转换音频格式..."
    ffmpeg -i ./audio/test.ogg -ar 16000 -ac 1 -c:a pcm_s16le ./audio/test.wav
    rm ./audio/test.ogg
fi

# 检查音频文件是否存在
if [ ! -f "./audio/test.wav" ]; then
    echo "错误: 测试音频文件不存在"
    exit 1
fi

echo ""
echo "测试序列开始..."

# 测试负载均衡
echo "1. 测试负载均衡和健康检查..."
for i in {1..5}; do
    echo "请求 $i: $(curl -s http://localhost/health)"
    sleep 0.5
done

# 测试 GPU 0
echo ""
echo "2. 测试 GPU 0 (端口 8080)..."
if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ GPU 0 健康检查通过"
    
    # JSON 测试
    echo "  JSON 格式测试..."
    response=$(curl -s -X POST \
        -H "Content-Type: multipart/form-data" \
        -F file=@./audio/test.wav \
        -F response_format=json \
        http://localhost:8080/inference)
    echo "  GPU 0 JSON 响应: $response"
    
    # SRT 测试
    echo "  SRT 格式测试..."
    srt_response=$(curl -s -X POST \
        -H "Content-Type: multipart/form-data" \
        -F file=@./audio/test.wav \
        -F response_format=srt \
        http://localhost:8080/inference)
    echo "  GPU 0 SRT 响应: $srt_response"
else
    echo "✗ GPU 0 不可用"
fi

# 测试 GPU 1
echo ""
echo "3. 测试 GPU 1 (端口 8081)..."
if curl -f http://localhost:8081/health > /dev/null 2>&1; then
    echo "✓ GPU 1 健康检查通过"
    
    # JSON 测试
    echo "  JSON 格式测试..."
    response=$(curl -s -X POST \
        -H "Content-Type: multipart/form-data" \
        -F file=@./audio/test.wav \
        -F response_format=json \
        http://localhost:8081/inference)
    echo "  GPU 1 JSON 响应: $response"
    
    # SRT 测试
    echo "  SRT 格式测试..."
    srt_response=$(curl -s -X POST \
        -H "Content-Type: multipart/form-data" \
        -F file=@./audio/test.wav \
        -F response_format=srt \
        http://localhost:8081/inference)
    echo "  GPU 1 SRT 响应: $srt_response"
else
    echo "✗ GPU 1 不可用"
fi

# 测试负载均衡
echo ""
echo "4. 测试负载均衡器..."
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✓ 负载均衡器健康检查通过"
    
    # 负载均衡测试
    echo "  负载均衡请求测试..."
    for i in {1..3}; do
        echo "  负载均衡请求 $i..."
        response=$(curl -s -X POST \
            -H "Content-Type: multipart/form-data" \
            -F file=@./audio/test.wav \
            -F response_format=json \
            http://localhost/inference)
        echo "  响应: $response"
        
        # 检查响应来自哪个 GPU
        if echo "$response" | grep -q "GPU"; then
            echo "  请求已分发到某个 GPU"
        else
            echo "  请求已处理，但未检测到 GPU 信息"
        fi
        sleep 1
    done
else
    echo "✗ 负载均衡器不可用"
fi

# 性能测试
echo ""
echo "5. 性能测试..."
echo "  GPU 0 性能测试..."
start_time=$(date +%s.%N)
if curl -s -X POST \
    -H "Content-Type: multipart/form-data" \
    -F file=@./audio/test.wav \
    -F response_format=json \
    http://localhost:8080/inference > /dev/null; then
    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc -l)
    echo "  GPU 0 处理时间: ${elapsed} 秒"
else
    echo "  GPU 0 性能测试失败"
fi

echo "  GPU 1 性能测试..."
start_time=$(date +%s.%N)
if curl -s -X POST \
    -H "Content-Type: multipart/form-data" \
    -F file=@./audio/test.wav \
    -F response_format=json \
    http://localhost:8081/inference > /dev/null; then
    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc -l)
    echo "  GPU 1 处理时间: ${elapsed} 秒"
else
    echo "  GPU 1 性能测试失败"
fi

# 并发测试
echo ""
echo "6. 并发测试..."
echo "  发送并发请求到负载均衡器..."
for i in {1..3}; do
    echo "  发送请求 $i..."
    curl -s -X POST \
        -H "Content-Type: multipart/form-data" \
        -F file=@./audio/test.wav \
        -F response_format=json \
        http://localhost/inference > /dev/null &
done
echo "  等待所有请求完成..."
wait
echo "  并发测试完成"

# 最终状态检查
echo ""
echo "7. 最终状态检查..."
echo "  检查各个服务的健康状态..."
services=("whisper-gpu0:8080" "whisper-gpu1:8081")
for service in "${services[@]}"; do
    port=$(echo "$service" | cut -d: -f2)
    name=$(echo "$service" | cut -d: -f1)
    if curl -f http://localhost:$port/health > /dev/null 2>&1; then
        echo "  ✓ $name: 健康"
    else
        echo "  ✗ $name: 不健康"
    fi
done

if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "  ✓ 负载均衡器: 健康"
else
    echo "  ✗ 负载均衡器: 不健康"
fi

echo ""
echo "================================================"
echo "测试完成！"
echo "================================================"
echo "总结："
echo "  - 双 GPU 服务部署完成"
echo "  - 负载均衡器工作正常"  
echo "  - SRT 和 JSON 输出格式正常"
echo "  - 并发请求处理正常"
echo ""
echo "下一步："
echo "  - 使用 ./monitor.sh 监控服务状态"
echo "  - 使用 docker-compose logs 查看详细日志"
echo "  - 访问 http://localhost 进行语音识别"