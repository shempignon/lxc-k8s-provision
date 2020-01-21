#!/usr/bin/env bash

set -eux

apt-get update && \
  apt-get install --assume-yes --quiet iptables \
    arptables \
    ebtables \
    iptables-persistent \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update && \
  apt-get install --assume-yes --quiet \
    containerd.io=1.2.10-3 \
    docker-ce=5:19.03.4~3-0~ubuntu-$(lsb_release -cs) \
    docker-ce-cli=5:19.03.4~3-0~ubuntu-$(lsb_release -cs) \
    kubelet \
    kubeadm \
    kubectl

apt-mark hold kubelet kubeadm kubectl

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

echo 'Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"' >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl restart docker
systemctl restart kubelet

kubeadm config images pull

iptables -A INPUT -p tcp --match multiport --dports 6443,2379,2380,10250:10252 -j ACCEPT
ip6tables -A INPUT -p tcp --match multiport --dports 6443,2379,2380,10250:10252 -j ACCEPT

mkdir -p /etc/iptables

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

