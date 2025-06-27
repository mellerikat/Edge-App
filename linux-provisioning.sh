#!/bin/bash

set -e

# Function definitions

create_user() {
    local new_user="$1"
    local password="$2"

    sudo adduser --gecos "" "$new_user" --disabled-password
    echo "$new_user:$password" | sudo chpasswd
    sudo usermod -aG edgeapp "$new_user"
}

add_edgeapp_group_to_sudoers() {
    echo "%edgeapp ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/edgeapp"
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        sudo apt update && sudo apt install -y ca-certificates curl apt-transport-https gnupg-agent software-properties-common

        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo apt install docker.io

        echo "Docker installed successfully."
    else
        echo "Docker is already installed."
    fi
}

configure_docker_daemon() {
    
    local insecure_registry=$(cat /path/to/insecure_registry_file)

    # insecure_registry 값이 "None"이면 설정 종료
    if [ "$insecure_registry" == "None" ]; then
        echo "Insecure registry is None. Skipping Docker daemon configuration."
        return
    fi

    sudo mkdir -p /etc/docker
    local daemon_file="/etc/docker/daemon.json"

    if [ -e "$daemon_file" ]; then
        # daemon.json 파일이 존재하면 기존 설정에 insecure registry 추가
        local existing_registries=$(jq -r '.["insecure-registries"]' "$daemon_file")

        if [[ $existing_registries != *"$insecure_registry"* ]]; then
            echo "Adding insecure registry $insecure_registry to existing daemon.json"
            jq '.["insecure-registries"] += ["'$insecure_registry'"]' "$daemon_file" | sudo tee "$daemon_file" > /dev/null
        else
            echo "Insecure registry $insecure_registry already exists in daemon.json"
        fi
    else
        # daemon.json 파일이 존재하지 않으면 새 설정 파일 생성
        echo "{ \"insecure-registries\" : [ \"$insecure_registry\" ] }" | sudo tee "$daemon_file" > /dev/null
    fi

    sudo systemctl restart docker
    echo "Docker daemon configured with insecure registry: $insecure_registry"
}

install_kubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mkdir -p "$HOME/.local/bin"
    mv kubectl "$HOME/.local/bin/"
    echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.bashrc"
}

install_k3s() {
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker --write-kubeconfig-mode 644 --write-kubeconfig-group users" sudo sh -
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"

    # 권한 설정: 사용자만 읽기 및 쓰기 가능, 그룹 및 다른 사용자에게는 권한 없음
    sudo chmod 600 "$HOME/.kube/config"

    export KUBECONFIG="$HOME/.kube/config"
}

install_aws_cli() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install --bin-dir "$HOME/bin" --install-dir "$HOME/lib/aws"
    echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
}

install_helm() {
    mkdir -p "$HOME/.local/bin"
    curl -LO https://get.helm.sh/helm-v3.8.0-linux-amd64.tar.gz
    tar -xzvf helm-v3.8.0-linux-amd64.tar.gz
    mv linux-amd64/helm "$HOME/.local/bin/helm"
    echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"
}

# Main script execution

read -p "Enter new username: " new_user
read -sp "Enter password for new username: " password
echo  # 비밀번호 입력 후 줄바꿈을 위해서 echo 추가

if [ -z "$new_user" ] || [ -z "$password" ];then 
    echo "Username or password cannot be empty."
    exit 1
fi

# 만약 edgeapp 그룹이 존재하지 않는다면 생성
if ! getent group edgeapp > /dev/null; then
    sudo groupadd edgeapp
fi

create_user "$new_user" "$password"
add_edgeapp_group_to_sudoers

# Docker 설치 및 설정을 현재 사용자로 실행
install_docker
configure_docker_daemon

# 이 단계에서 새로운 사용자로 스크립트 실행
sudo -i -u "$new_user" bash <<'EOF'
set -e

install_kubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mkdir -p "$HOME/.local/bin"
    mv kubectl "$HOME/.local/bin/"
    echo 'export PATH=$PATH:$HOME/.local/bin' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
    echo "kubectl installed successfully."
}

install_k3s() {
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker --write-kubeconfig-mode 644 --write-kubeconfig-group users" sudo sh -
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"

    # 권한 설정: 사용자만 읽기 및 쓰기 가능, 그룹 및 다른 사용자에게는 권한 없음
    sudo chmod 600 "$HOME/.kube/config"

    export KUBECONFIG="$HOME/.kube/config"
    echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
}

install_aws_cli() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install --bin-dir "$HOME/bin" --install-dir "$HOME/lib/aws"
    echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
}

install_helm() {
    mkdir -p "$HOME/.local/bin"
    curl -LO https://get.helm.sh/helm-v3.8.0-linux-amd64.tar.gz
    tar -xzvf helm-v3.8.0-linux-amd64.tar.gz
    mv linux-amd64/helm "$HOME/.local/bin/helm"
    echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
}

read -p "Do you want to install kubectl? (y/n): " install_kubectl_flag

if [ "\$install_kubectl_flag" == "y" ] || [ "\$install_kubectl_flag" == "Y" ]; then
    install_kubectl
else
    echo "kubectl installation skipped."
fi

install_k3s
install_aws_cli
install_helm

EOF

echo "User '$new_user' created and added to edgeapp group with the provided password."
echo "Successfully switched to user '$new_user' for installation."
exit 0