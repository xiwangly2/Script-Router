# 在PVE的VNC操作，以便后续直接粘贴命令
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && /etc/init.d/ssh reload
# 找到局域网IP，供SSH连接
ip a


hostnamectl set-hostname xxx

# 连接并进入SSH
swapoff -a && sed -i '/ swap /d' /etc/fstab
rm -f /etc/machine-id /var/lib/dbus/machine-id
systemd-machine-id-setup
reboot

# 重连SSH
apt-get update
apt-get install -y \
  apt-transport-https ca-certificates curl gnupg sudo \
  iproute2 bridge-utils iptables conntrack ebtables \
  containerd \
  jq open-iscsi
# k8s更高版本不再需要docker
# curl -sSo get_docker.sh https://get.docker.com
# chmod +x get_docker.sh
# bash /get_docker.sh
# rm get_docker.sh

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

apt-get update
apt-get install -y kubectl kubeadm kubelet helm
apt-mark hold kubelet kubeadm kubectl

modprobe overlay
modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
EOF
sysctl --system

systemctl restart containerd
systemctl enable containerd

modprobe dm_crypt
systemctl enable --now iscsid

# 控制平面

kubeadm init --cri-socket=unix:///var/run/containerd/containerd.sock --pod-network-cidr=10.96.0.0/16

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/tigera-operator.yaml
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/custom-resources.yaml \
  | sed 's|^\([[:space:]]*cidr:\).*|\1 10.96.0.0/16|' \
  | kubectl create -f -

# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubeadm token create --print-join-command

# 工作节点
# kubeadm join 192.168.61.191:6443 --token k994lf.w5l2g0rzif2nl8eu --discovery-token-ca-cert-hash sha256:df46331fe0a3f397d6a3406ed618299321d98f1de3c501ec0f91e7254872c0aa

