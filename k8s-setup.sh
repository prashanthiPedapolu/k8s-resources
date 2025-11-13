#!/bin/bash

set -e

echo "=== Disabling Swap ==="
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "=== Loading Kernel Modules ==="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "=== Applying Sysctl Params ==="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "=== Installing Dependencies ==="
apt-get update -y 
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo "=== Adding Docker GPG Key ==="
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "=== Adding Docker Repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing containerd ==="
apt-get update -y
apt-get install -y containerd.io

echo "=== Configuring containerd ==="
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

echo "containerd Cgroup Driver:"
grep -i SystemdCgroup /etc/containerd/config.toml

echo "=== Restarting containerd ==="
systemctl restart containerd
systemctl enable containerd

echo "=== Adding Kubernetes APT Repository ==="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "=== Installing Kubernetes Components (kubelet, kubeadm, kubectl) ==="
apt-get update
apt-get install -y kubelet kubeadm kubectl

echo "=== Holding Kubernetes Versions ==="
apt-mark hold kubelet kubeadm kubectl

echo "=== Enabling and Starting Kubelet ==="
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

echo "=== SETUP COMPLETED SUCCESSFULLY ==="
