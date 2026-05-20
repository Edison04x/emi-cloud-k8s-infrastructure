#!/bin/bash

# ==============================================================================
# SCRIPT: k8s-installer.sh
# DESCRIPCION: Aprovisionamiento y configuración automática de nuevos nodos 
#              (Master/Worker) e integración desatendida al clúster K8s.
# AUTORES: Edison, Izan, Marc (EMI Cloud)
# ==============================================================================

# 0. Comprobación de privilegios de ejecución
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Este script requiere privilegios de superusuario. Ejecútalo con sudo."
  exit 1
fi

# Variables globales
KCONFIG="--kubeconfig /etc/kubernetes/admin.conf"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

echo "======================================================"
echo "[INFO] INICIANDO ASISTENTE DE PROVISIONAMIENTO DE NODOS"
echo "======================================================"

# --- 1. RECOPILACIÓN DE DATOS ---
read -p "-> IP del nuevo nodo destino: " NODE_IP
read -p "-> Usuario de administración temporal: " NODE_USER
read -s -p "-> Contraseña temporal de SSH: " NODE_PASS
echo -e "\n"

echo "Selecciona el rol objetivo para el nodo:"
echo "1) Worker Node (Carga de trabajo)"
echo "2) Control Plane / Master Node (Gestión)"
read -p "Opción [1 o 2]: " NODE_ROLE

if [ "$NODE_ROLE" == "1" ]; then
    ROLE_NAME="WORKER"
    PREFIX="worker"
elif [ "$NODE_ROLE" == "2" ]; then
    ROLE_NAME="MASTER"
    PREFIX="master"
else
    echo "[ERROR] Selección no válida. Abortando."
    exit 1
fi

# --- 2. CÁLCULO DINÁMICO DE NOMENCLATURA ---
echo "[INFO] Calculando siguiente secuencia de hostname disponible..."

LAST_NUM=$(kubectl $KCONFIG get nodes --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "^${PREFIX}-" | sed "s/^${PREFIX}-//" | sort -n | tail -1)

if [ -z "$LAST_NUM" ]; then
    NEXT_NUM=1
else
    NEXT_NUM=$((10#$LAST_NUM + 1))
fi

NEW_HOSTNAME=$(printf "%s-%02d" "$PREFIX" "$NEXT_NUM")
echo "[INFO] El nodo será registrado en el clúster como: $NEW_HOSTNAME"

# --- 3. SEGURIDAD Y TOKEN DE UNIÓN ---
export SSHPASS=$NODE_PASS

echo "[INFO] Verificando estado del nodo $NODE_IP..."
K8S_STATUS=$(sshpass -e ssh $SSH_OPTS $NODE_USER@$NODE_IP "[ -d /etc/kubernetes/pki ] || [ -d /var/lib/etcd ] && echo 'DIRTY' || echo 'CLEAN'" 2>/dev/null)

if [ "$K8S_STATUS" == "DIRTY" ]; then
    echo "[WARN] Se han detectado configuraciones previas de Kubernetes en el nodo destino."
    echo "[WARN] Ejecuta 'kubeadm reset' en la máquina destino antes de aprovisionar."
    exit 1
fi

echo "[INFO] Generando token de autenticación de corta duración..."
if [ "$ROLE_NAME" == "WORKER" ]; then
    JOIN_CMD=$(kubeadm $KCONFIG token create --print-join-command 2>/dev/null)
else
    CERT_KEY=$(kubeadm $KCONFIG init phase upload-certs --upload-certs 2>/dev/null | tail -n 1)
    BASE_JOIN=$(kubeadm $KCONFIG token create --print-join-command 2>/dev/null)
    JOIN_CMD="$BASE_JOIN --control-plane --certificate-key $CERT_KEY"
fi

# --- 4. INSTALACIÓN Y CONFIGURACIÓN REMOTA ---
echo "[INFO] Inyectando claves SSH y configurando permisos de sudoers..."
sshpass -e ssh $SSH_OPTS $NODE_USER@$NODE_IP "mkdir -p ~/.ssh"
sshpass -e ssh-copy-id $SSH_OPTS $NODE_USER@$NODE_IP >/dev/null 2>&1
sshpass -e ssh $SSH_OPTS $NODE_USER@$NODE_IP "echo '$NODE_PASS' | sudo -S sh -c 'echo \"$NODE_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/99_k8s_$NODE_USER'"

echo "[INFO] Ejecutando rutinas de aprovisionamiento en $NEW_HOSTNAME (esto puede tardar unos minutos)..."

ssh $SSH_OPTS $NODE_USER@$NODE_IP << EOF
    set -e
    
    # Configuracion Base del Sistema
    sudo hostnamectl set-hostname $NEW_HOSTNAME
    sudo sed -i "s/127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Carga de Modulos del Kernel
    sudo modprobe overlay && sudo modprobe br_netfilter

    # Tuning de Red para K8s
    cat <<EOM | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOM
    sudo sysctl --system >/dev/null 2>&1

    # Container Runtime (Containerd) y Storage Utilities
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y containerd.io nfs-common >/dev/null 2>&1
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd

    # Repositorios e Instalacion de Kube Tools
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y kubelet kubeadm kubectl >/dev/null 2>&1
    sudo apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1
    sudo systemctl enable --now kubelet >/dev/null 2>&1

    # Bootstraping del Nodo
    echo "[INFO] Requisitos cumplidos. Ejecutando integracion al plano de control..."
    sudo ${JOIN_CMD} > /dev/null

    if [ "${ROLE_NAME}" == "MASTER" ]; then
        mkdir -p \$HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
        sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
    fi
EOF

echo "======================================================"
echo "[SUCCESS] Aprovisionamiento completado con éxito."
echo "[INFO] El nodo $NEW_HOSTNAME forma ahora parte de la topología."
echo "======================================================"