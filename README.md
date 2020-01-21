lxc-k8s-provision
===


What ?
---

Setup a single control-plane kubernetes cluster, with kubeadm through lxc. Pods are running Ubuntu 18.04

Why ?
---

Dunno, why not ?


How ?
--- 

Prerequisite: Install lxc, lxc and kubectl

Activate the required kernel modules
```
sudo modprobe br_netfilter
```

Create the master node:
- Create a container
```
lxc launch images:ubuntu/18.04 master
```
- Setup a master node with the [master script](master.sh)
```
lxc file push master.sh master/ && lxc exec master /master.sh
```
- Install kubeadm on the master node
```
lxc exec master -- kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=Swap
```
- Retrieve kubectl config
```
mkdir -p ~/.kube && [ -f  ~/.kube/config ] && cp ~/.kube/config ~/.kube/config.bak;lxc file pull master/etc/kubernetes/admin.conf ~/.kube/config
```
- Deploy [flannel network add-on](https://github.com/coreos/flannel)
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
```

For each worker node:
- Create a container
```
lxc launch images:ubuntu/18.04 <worker-name>
```
- Setup worker nodes with the [worker script](worker.sh)
```
lxc file push worker.sh <worker-name>/ && lxc exec <worker-name> /worker.sh
```
- Join the cluster with the worker
```
lxc exec <worker-name> -- `lxc exec master -- kubeadm token create --print-join-command | grep kubeadm` --ignore-preflight-errors=Swap
```