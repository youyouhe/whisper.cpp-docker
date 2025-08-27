#!/bin/bash
# 双 GPU 监控脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

while true; do
    clear
    echo "================================================"
    echo "  Whisper.cpp 双 GPU 监控 - $(date)"
    echo "================================================"
    echo ""
    
    # GPU 信息
    echo -e "${YELLOW}GPU 状态:${NC}"
    nvidia-smi --query-gpu=name,memory.used,memory.total,temperature.gpu,utilization.gpu \
        --format=csv,noheader,nounits | while IFS=, read -r name mem_used mem_total temp util; do
        mem_used_mb=${mem_used%?*}
        mem_total_mb=${mem_total%?*}
        mem_percent=$((mem_used_mb * 100 / mem_total_mb))
        echo -e "  $name: ${GREEN}${util}%${NC} | ${YELLOW}${mem_used_mb}/${mem_total_mb}MB (${mem_percent}%)${NC} | ${BLUE}${temp}°C${NC}"
    done
    echo ""
    
    # 容器状态
    echo -e "${YELLOW}容器状态:${NC}"
    docker ps --filter "name=whisper" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # 健康检查
    echo -e "${YELLOW}服务健康状态:${NC}"
    for i in {0..1}; do
        port=$((8080 + i))
        if curl -f http://localhost:$port/health > /dev/null 2>&1; then
            echo -e "  GPU $i (端口 $port): ${GREEN}✓ Healthy${NC}"
        else
            echo -e "  GPU $i (端口 $port): ${RED}✗ Unhealthy${NC}"
        fi
    done
    
    # 负载均衡器
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo -e "  负载均衡器: ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  负载均衡器: ${RED}✗ Unhealthy${NC}"
    fi
    echo ""
    
    # 系统信息
    echo -e "${YELLOW}系统信息:${NC}"
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)% id.*/\1%/')
    mem_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    disk_usage=$(df -h / | awk 'NR==2{print $5}')
    uptime_info=$(uptime -p)
    
    echo -e "  CPU 使用: ${cpu_usage}"
    echo -e "  内存使用: ${mem_usage}"
    echo -e "  磁盘使用: ${disk_usage}"
    echo -e "  系统运行: ${uptime_info}"
    echo ""
    
    # 网络连接
    echo -e "${YELLOW}网络连接:${NC}"
    echo "  活跃连接:"
    netstat -tn | grep ":808" | awk '{print "  " $4 ":" $5 " $6}' | head -10
    echo ""
    
    # 最后日志
    echo -e "${YELLOW}最近日志:${NC}"
    echo "  whisper-gpu0:"
    docker-compose logs --tail=2 whisper-gpu0 2>/dev/null | while read line; do
        echo "    $line"
    done
    echo ""
    echo "  whisper-gpu1:"
    docker-compose logs --tail=2 whisper-gpu1 2>/dev/null | while read line; do
        echo "    $line"
    done
    echo ""
    
    echo -e "${YELLOW}提示:${NC}"
    echo "  - 按 Ctrl+C 退出监控"
    echo "  - 测试服务: curl -F file=@test.wav -F response_format=srt http://localhost/inference"
    echo "  - 查看完整日志: docker-compose logs -f"
    echo "  - 重启服务: docker-compose restart"
    echo ""
    
    sleep 5
done