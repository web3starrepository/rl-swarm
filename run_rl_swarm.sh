#!/bin/bash

ROOT=$PWD

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120

# HuggingFace镜像配置
# DEFAULT_HF_ENDPOINT="https://hf-mirror.com"
# HF_ENDPOINT=${HF_ENDPOINT:-$DEFAULT_HF_ENDPOINT}
# export HF_ENDPOINT
# export HF_HOME="$HOME/.cache/huggingface"
# export PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
# export HF_DATASETS_CACHE="$HOME/.cache/huggingface/datasets"
# export TRANSFORMERS_CACHE="$HOME/.cache/huggingface/transformers"

DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}


cleanup() {
    echo -e "${YELLOW}${BOLD}[✓] 正在关闭进程...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    kill $TUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT

if [ -f "modal-login/temp-data/userData.json" ]; then
    cd modal-login

    echo -e "\n${CYAN}${BOLD}[✓] 正在通过npm安装依赖，网络速度不同可能需要几分钟...${NC}"
    npm install --legacy-peer-deps
    
    echo -e "\n${CYAN}${BOLD}[✓] 正在启动开发服务器...${NC}"
    # Ensure 'ss' is installed
    if ! command -v ss &>/dev/null; then
      echo -e "${YELLOW}[!] 未找到'ss'命令，尝试安装'iproute2'...${NC}"
      if command -v apt &>/dev/null; then
        apt update && apt install -y iproute2
      elif command -v yum &>/dev/null; then
        yum install -y iproute
      elif command -v pacman &>/dev/null; then
        pacman -Sy iproute2
      else
        echo -e "${RED}[✗] 无法安装'ss'，未找到包管理器${NC}"
        exit 1
      fi
    fi
    
    # Check if port 3000 is in use using ss
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo -e "${YELLOW}[!] 端口3000已被占用，正在结束进程: $PID${NC}"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    # Start the dev server
    PORT=3000
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    echo -e "${GREEN}${BOLD}[✓] 服务已在固定端口3000运行${NC}"
    MAX_WAIT=30  
    
    # 服务器进程检查
    if ! ps -p $SERVER_PID > /dev/null; then
        echo -e "${RED}${BOLD}[✗] 服务器进程异常退出${NC}"
        exit 1
    fi
    
    
    if [ $i -eq $MAX_WAIT ]; then
        echo -e "${RED}${BOLD}[✗] 等待服务器启动超时${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    cd ..

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "\n${CYAN}${BOLD}[✓] ORG_ID has been set to: ${BOLD}$ORG_ID\n${NC}"
else
    cd modal-login

    echo -e "\n${CYAN}${BOLD}[✓] 正在通过npm安装依赖，网络速度不同可能需要几分钟...${NC}"
    npm install --legacy-peer-deps
    
    echo -e "\n${CYAN}${BOLD}[✓] 正在启动开发服务器...${NC}"
    # Ensure 'ss' is installed
    if ! command -v ss &>/dev/null; then
      echo -e "${YELLOW}[!] 'ss' not found. Attempting to install 'iproute2'...${NC}"
      if command -v apt &>/dev/null; then
        apt update && apt install -y iproute2
      elif command -v yum &>/dev/null; then
        yum install -y iproute
      elif command -v pacman &>/dev/null; then
        pacman -Sy iproute2
      else
        echo -e "${RED}[✗] Could not install 'ss'. Package manager not found.${NC}"
        exit 1
      fi
    fi
    
    # Check if port 3000 is in use using ss
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo -e "${YELLOW}[!] Port 3000 is in use. Killing process: $PID${NC}"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    # Start the dev server
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=30  

    echo -e "\n${CYAN}${BOLD}[✓] 正在检测系统架构...${NC}"
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$ARCH" = "x86_64" ]; then
        NGROK_ARCH="amd64"
        CF_ARCH="amd64"
        echo -e "${GREEN}${BOLD}[✓] 检测到x86_64架构${NC}"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        NGROK_ARCH="arm64"
        CF_ARCH="arm64"
        echo -e "${GREEN}${BOLD}[✓] 检测到ARM64架构${NC}"
    elif [[ "$ARCH" == arm* ]]; then
        NGROK_ARCH="arm"
        CF_ARCH="arm"
        echo -e "${GREEN}${BOLD}[✓] 检测到ARM架构${NC}"
    else
        echo -e "${RED}[✗] 不支持的架构: $ARCH，请使用支持的系统${NC}"
        exit 1
    fi

    install_cloudflared() {
        if command -v cloudflared >/dev/null 2>&1; then
            echo -e "${GREEN}${BOLD}[✓] Cloudflared 已经安装.${NC}"
            return 0
        fi
        echo -e "\n${YELLOW}${BOLD}[✓] 正在安装 cloudflared...${NC}"
        CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
        wget -q --show-progress "$CF_URL" -O cloudflared
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] 下载 cloudflared 失败.${NC}"
            return 1
        fi
        chmod +x cloudflared
        mv cloudflared /usr/local/bin/
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] 无法移动 cloudflared 到 /usr/local/bin/.${NC}"
            return 1
        fi
        echo -e "${GREEN}${BOLD}[✓] Cloudflared 安装成功.${NC}"
        return 0
    }

    install_ngrok() {
        if command -v ngrok >/dev/null 2>&1; then
            echo -e "${GREEN}${BOLD}[✓] ngrok 已经安装.${NC}"
            return 0
        fi
        echo -e "${YELLOW}${BOLD}[✓] 正在安装 ngrok...${NC}"
        NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
        wget -q --show-progress "$NGROK_URL" -O ngrok.tgz
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] 下载 ngrok 失败.${NC}"
            return 1
        fi
        tar -xzf ngrok.tgz
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] 解压 ngrok 失败.${NC}"
            rm ngrok.tgz
            return 1
        fi
        mv ngrok /usr/local/bin/
        if [ $? -ne 0 ]; then
            echo -e "${RED}${BOLD}[✗] 无法移动 ngrok 到 /usr/local/bin/.${NC}"
            rm ngrok.tgz
            return 1
        fi
        rm ngrok.tgz
        echo -e "${GREEN}${BOLD}[✓] ngrok 安装成功.${NC}"
        return 0
    }

    get_url_from_method1() {
        local url=$(grep -o '"url":"https://[^"]*' ngrok_output.log 2>/dev/null | head -n1 | cut -d'"' -f4)
        echo "$url"
    }

    get_url_from_method2() {
        local url=""
        for try_port in $(seq 4040 4045); do
            if curl -s "http://localhost:$try_port/api/tunnels" >/dev/null 2>&1; then
                url=$(curl -s "http://localhost:$try_port/api/tunnels" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                if [ -n "$url" ]; then
                    break
                fi
            fi
        done
        echo "$url"
    }

    get_url_from_method3() {
        local url=$(grep -m 1 "Forwarding" ngrok_output.log 2>/dev/null | grep -o "https://[^ ]*")
        echo "$url"
    }

    get_url_from_method4() {
        kill $TUNNEL_PID 2>/dev/null || true
        sleep 3
        ngrok http --region us --log=stdout "$PORT" > ngrok_output_alt.log 2>&1 &
        TUNNEL_PID=$!
        sleep 10
        local url=$(grep -o '"url":"https://[^"]*' ngrok_output_alt.log 2>/dev/null | head -n1 | cut -d'"' -f4)
        if [ -z "$url" ]; then
            for check_port in $(seq 4040 4050); do
                if curl -s "http://localhost:$check_port/api/tunnels" >/dev/null 2>&1; then
                    url=$(curl -s "http://localhost:$check_port/api/tunnels" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                    if [ -n "$url" ]; then
                        break
                    fi
                fi
            done
        fi
        echo "$url"
    }

    start_tunnel() {
        if install_cloudflared; then
            echo -e "\n${CYAN}${BOLD}[✓] 正在启动 cloudflared 隧道...${NC}"
            cloudflared tunnel --url http://localhost:${PORT:-3000} > cloudflared_output.log 2>&1 &
            TUNNEL_PID=$!
            counter=0
            MAX_WAIT=30
            while [ $counter -lt $MAX_WAIT ]; do
                FORWARDING_URL=$(grep -o 'https://[^ ]*\.trycloudflare.com' cloudflared_output.log | head -n1)
                if [ -n "$FORWARDING_URL" ]; then
                    echo -e "${GREEN}${BOLD}[✓] Cloudflared 隧道启动成功.\n${NC}"
                    return 0
                fi
                sleep 1
                counter=$((counter + 1))
            done
            echo -e "${RED}${BOLD}[✗] 等待 cloudflared URL 超时.${NC}"
            kill $TUNNEL_PID 2>/dev/null || true
        else
            echo -e "\n${RED}${BOLD}[✗] 安装 cloudflared 失败，尝试使用 ngrok${NC}"
        fi

        if install_ngrok; then
            while true; do
                echo -e "\n${YELLOW}${BOLD}获取authtoken步骤:${NC}"
                echo "1. 访问 https://dashboard.ngrok.com 注册或登录"
                echo "2. 进入'Your Authtoken'页面: https://dashboard.ngrok.com/get-started/your-authtoken"
                echo "3. 点击眼睛图标显示您的ngrok auth token"
                echo "4. 复制token并粘贴到下方提示符"
                echo -e "\n${BOLD}请输入您的ngrok authtoken:${NC}"
                read -p "> " NGROK_TOKEN
            
                if [ -z "$NGROK_TOKEN" ]; then
                    echo -e "${RED}${BOLD}[✗] 未提供token，请输入有效token${NC}"
                    continue
                fi
                pkill -f ngrok || true
                sleep 2
            
                ngrok authtoken "$NGROK_TOKEN"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}[✓] ngrok认证成功!${NC}"
                    break
                else
                    echo -e "${RED}[✗] 认证失败，请检查token后重试${NC}"
                fi
            done

            ngrok http "$PORT" --log=stdout --log-format=json --log-level=info > ngrok_output.log 2>&1 &
            TUNNEL_PID=$!
            sleep 5

            FORWARDING_URL=$(get_url_from_method1)
            if [ -z "$FORWARDING_URL" ]; then
                FORWARDING_URL=$(get_url_from_method2)
            fi
            if [ -z "$FORWARDING_URL" ]; then
                FORWARDING_URL=$(get_url_from_method3)
            fi
            if [ -z "$FORWARDING_URL" ]; then
                FORWARDING_URL=$(get_url_from_method4)
            fi

            if [ -n "$FORWARDING_URL" ]; then
                echo -e "${GREEN}${BOLD}[✓] ngrok 隧道启动成功.${NC}"
                return 0
            else
                echo -e "${RED}${BOLD}[✗] 无法从 ngrok 获取 URL.${NC}"
                kill $TUNNEL_PID 2>/dev/null || true
            fi
        else
            echo -e "${RED}${BOLD}[✗] 安装 ngrok 失败.${NC}"
        fi

        echo -e "${RED}${BOLD}[✗] cloudflared 和 ngrok 都无法启动隧道.${NC}"
        return 1
    }

    start_tunnel
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${BOLD}[✓] 成功！请访问此网站并使用您的邮箱登录:${NC} ${CYAN}${BOLD}${FORWARDING_URL}${NC}"
    else
        echo -e "\n${BLUE}${BOLD}[✓] 别担心，您可以使用这个手动方法。请按照以下步骤操作:${NC}"
        echo "1. 在另一个标签页中打开相同的 WSL/VPS 或 GPU 服务器"
        echo "2. 在终端中粘贴此命令: ngrok http $PORT"
        echo "3. 它会显示一个类似这样的链接: https://xxxx.ngrok-free.app"
        echo "4. 访问该网站并使用您的邮箱登录，网站可能需要 30 秒才能加载"
        echo "5. 然后返回之前的标签页，您会看到一切正常运行"
    fi

    cd ..

    echo -e "\n${CYAN}${BOLD}[↻] 等待您完成登录过程...${NC}"
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 3
    done
    
    echo -e "${GREEN}${BOLD}[✓] 成功！userData.json 文件已创建。正在进行剩余设置...${NC}"
    rm -f server.log cloudflared_output.log ngrok_output.log ngrok_output_alt.log

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "\n${CYAN}${BOLD}[✓] ORG_ID 已设置为: $ORG_ID\n${NC}"

    echo -e "${CYAN}${BOLD}[✓] 等待 API 密钥激活...${NC}"
    while true; do
        STATUS=$(curl -s --noproxy localhost "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo -e "${GREEN}${BOLD}[✓] 成功！API 密钥已激活！继续进行...\n${NC}"
            break
        else
            echo "[↻] 正在等待 API 密钥激活..."
            sleep 5
        fi
    done
fi

echo -e "${CYAN}${BOLD}[✓] 正在安装所需的 Python 包，根据网络速度可能需要几分钟...${NC}"
pip install --disable-pip-version-check -q -r "$ROOT"/requirements-hivemind.txt -i $PIP_INDEX_URL > /dev/null
pip install --disable-pip-version-check -q -r "$ROOT"/requirements.txt -i $PIP_INDEX_URL > /dev/null

echo -e "${GREEN}${BOLD}>>> 太棒了，所有包都安装成功！\n${NC}"

if [ -z "$CONFIG_PATH" ]; then
    if command -v nvidia-smi &> /dev/null || [ -d "/proc/driver/nvidia" ]; then
        echo -e "${GREEN}${BOLD}[✓] 检测到 GPU，使用 GPU 配置${NC}"
        CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
        echo -e "${CYAN}${BOLD}[✓] 配置文件 : ${BOLD}$CONFIG_PATH\n${NC}"
        echo -e "${CYAN}${BOLD}[✓] 正在安装 GPU 特定的依赖，根据网络速度可能需要几分钟...${NC}"
        pip install --disable-pip-version-check -q -r "$ROOT"/requirements_gpu.txt
    else
        echo -e "${YELLOW}${BOLD}[✓] 未检测到 GPU，使用 CPU 配置${NC}"
        CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
        echo -e "${CYAN}${BOLD}[✓] 配置文件 : ${BOLD}$CONFIG_PATH\n${NC}"
    fi
fi


if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    read -p "您想要将在 RL swarm 中训练的模型推送到 Hugging Face Hub 吗？[y/N] " yn
    yn=${yn:-N}
    case $yn in
        [Yy]* ) read -p "请输入您的 Hugging Face 访问令牌: " HUGGINGFACE_ACCESS_TOKEN;;
        [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None";;
        * ) echo -e "${YELLOW}>>> 未给出答案，因此不会将模型推送到 Hugging Face Hub.${NC}" && HUGGINGFACE_ACCESS_TOKEN="None";;
    esac
fi

echo -e "\n${GREEN}${BOLD}[✓] 祝您在 swarm 中好运！您的训练会话即将开始.\n${NC}"
[ "$(uname)" = "Darwin" ] && sed -i '' -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)") || sed -i -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")
sleep 2

if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --config "$CONFIG_PATH"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH"
fi

wait
