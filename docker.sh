#!/bin/bash

echo "=============================="
echo "======= INSTALL Containerd ======="
echo "=============================="

# Check OS Version
VERSION=$(cat /etc/rocky-release)


if [[ "$VERSION" == *"Rocky"* ]]; then
echo "============================"
echo "Server platform is "$VERSION
echo "============================"
else
echo "Only available Linux/Rocky"
exit 1
fi


# update & upgrade package
sudo dnf check-update

if [[ "$VERSION" == *"Rocky"* ]]; then

# Install Docker using the repository
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io dnf-plugins-core device-mapper-persistent-data lvm2 epel-release git curl wget
systemctl start docker
systemctl enable docker
systemctl enable containerd
fi

# Grant docker.sock privileges to the current user
#usermod -a -G docker $USER
#chown "$USER":"$USER" /home/"$USER"/.docker -R
#chmod g+rwx "/home/$USER/.docker" -R

#firewall configuration
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config

tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
#swap off
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

#containerd module configuration
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

#module load
modprobe overlay
modprobe br_netfilter

sysctl --system

#dependancy package installation

containerd config default > /etc/containerd/config.toml
sed -i "125s/false/true/" /etc/containerd/config.toml
systemctl restart containerd


#kubernetes repo
tee /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

<<<<<<< HEAD
# 버전에 맞게 버전 명세 변경 후 실행
dnf -y install kubelet-1.22.3 kubeadm-1.22.3 kubectl-1.22.3 --disableexcludes=kubernetes
=======
dnf -y install kubelet-1.25.8 kubeadm-1.25.8 kubectl-1.25.8 --disableexcludes=kubernetes
>>>>>>> 6ae2be077c68e91cdd372f4b3a4e8efe8236f84c

sudo systemctl enable kubelet
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
 
systemctl daemon-reload
systemctl restart docker
systemctl restart kubelet

kubeadm init --token-ttl 0 --pod-network-cidr=192.168.0.0/16 >> kubeadm-init-token.txt

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config


#####calico#####
curl https://projectcalico.docs.tigera.io/manifests/calico.yaml -O
kubectl apply -f calico.yaml


