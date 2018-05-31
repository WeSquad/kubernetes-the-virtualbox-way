NUM_CONTROLLER = 3
NUM_NODE = 3

HAPROXY_CPU = 1
HAPROXY_MEM = 512

CONTROLLER_CPU = 2
CONTROLLER_MEM = 1024

NODE_CPU = 1
NODE_MEM = 1024

SUBNET = "192.168.26."

CONTROLLER_ENV = <<-SCRIPT
tee /etc/profile.d/env-vars.sh > /dev/null <<EOF
export ETCDCTL_CACERT=/etc/etcd/ssl/ca-crt.pem
export ETCDCTL_KEY=/etc/etcd/ssl/kubernetes-key.pem
export ETCDCTL_CERT=/etc/etcd/ssl/kubernetes-crt.pem
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://192.168.26.11:2379,https://192.168.26.12:2379,https://192.168.26.13:2379
EOF
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/stretch64"
  config.vm.box_check_update = true
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define "haproxy" do |haproxy|
    haproxy.vm.provision "haproxy.cfg", type: "file", source: "./haproxy.cfg", destination: "/home/vagrant/haproxy.cfg"
    haproxy.vm.provider "virtualbox" do |v|
      v.name = "haproxy"
      v.memory = HAPROXY_MEM
      v.cpus = HAPROXY_CPU
    end
    haproxy.vm.hostname = "haproxy"
    haproxy.vm.network :private_network, ip: SUBNET + "#{10}"
    haproxy.vm.provision "bootstrap", type: "shell", inline: <<-SCRIPT
      # Install haproxy
      apt-get update
      apt-get install -y haproxy
      systemctl stop haproxy
      mv /home/vagrant/haproxy.cfg /etc/haproxy/haproxy.cfg
      systemctl enable haproxy
      systemctl start haproxy
    SCRIPT
  end

  (1..NUM_CONTROLLER).each do |i|
    config.vm.define "controller-#{i}" do |controller|
      controller.vm.provision "ca-key.pem",                       type: "file", source: "./certs/ca-key.pem",                           destination: "/home/vagrant/ca-key.pem"
      controller.vm.provision "ca-crt.pem",                       type: "file", source: "./certs/ca-crt.pem",                           destination: "/home/vagrant/ca-crt.pem"
      controller.vm.provision "kubernetes-key.pem",               type: "file", source: "./certs/kubernetes-key.pem",                   destination: "/home/vagrant/kubernetes-key.pem"
      controller.vm.provision "kubernetes-crt.pem",               type: "file", source: "./certs/kubernetes-crt.pem",                   destination: "/home/vagrant/kubernetes-crt.pem"
      controller.vm.provision "kube-controller-manager-key.pem",  type: "file", source: "./certs/kube-controller-manager-key.pem",      destination: "/home/vagrant/kube-controller-manager-key.pem"
      controller.vm.provision "kube-controller-manager-crt.pem",  type: "file", source: "./certs/kube-controller-manager-crt.pem",      destination: "/home/vagrant/kube-controller-manager-crt.pem"
      controller.vm.provision "kube-scheduler-key.pem",           type: "file", source: "./certs/kube-scheduler-key.pem",               destination: "/home/vagrant/kube-scheduler-key.pem"
      controller.vm.provision "kube-scheduler-crt.pem",           type: "file", source: "./certs/kube-scheduler-crt.pem",               destination: "/home/vagrant/kube-scheduler-crt.pem"
      controller.vm.provision "service-account-key.pem",          type: "file", source: "./certs/service-account-key.pem",              destination: "/home/vagrant/service-account-key.pem"
      controller.vm.provision "service-account-crt.pem",          type: "file", source: "./certs/service-account-crt.pem",              destination: "/home/vagrant/service-account-crt.pem"
      controller.vm.provision "kubernetes.tgz",                   type: "file", source: "./kubernetes.tgz",                             destination: "/home/vagrant/kubernetes.tgz"
      controller.vm.provision "etcd.tgz",                         type: "file", source: "./etcd.tgz",                                   destination: "/home/vagrant/etcd.tgz"
      controller.vm.provision "etcd.template",                    type: "file", source: "./templates/etcd.template",                    destination: "/home/vagrant/etcd.template"
      controller.vm.provision "kube-apiserver.template",          type: "file", source: "./templates/kube-apiserver.template",          destination: "/home/vagrant/kube-apiserver.template"
      controller.vm.provision "kube-controller-manager.template", type: "file", source: "./templates/kube-controller-manager.template", destination: "/home/vagrant/kube-controller-manager.template"
      controller.vm.provision "kube-scheduler.template",          type: "file", source: "./templates/kube-scheduler.template",          destination: "/home/vagrant/kube-scheduler.template"
      controller.vm.provision "kube-scheduler-config.template",   type: "file", source: "./templates/kube-scheduler-config.template",   destination: "/home/vagrant/kube-scheduler-config.template"
      controller.vm.provision "encryption-config.yml",            type: "file", source: "./encryption-config.yml",                      destination: "/home/vagrant/encryption-config.yml"

      controller.vm.provider "virtualbox" do |v|
        v.name = "controller-#{i}"
        v.memory = CONTROLLER_MEM
        v.cpus = CONTROLLER_CPU
      end
      controller.vm.hostname = "controller-#{i}"
      controller.vm.network :private_network, ip: SUBNET + "#{10 + i}"
      controller.vm.provision "env vars", type: "shell", inline: CONTROLLER_ENV, run: "always"
      controller.vm.provision "bootstrap", type: "shell", inline: <<-SCRIPT
        sed -e "s/\(.*swap    sw.*\)/# \1/" -i /etc/fstab
        swapoff -a

        # Move binaries
        tar xvzf kubernetes.tgz
        tar xvzf etcd.tgz
        install -m 755 /home/vagrant/kubernetes/kubectl /usr/local/bin/kubectl
        install -m 744 /home/vagrant/kubernetes/kube-apiserver /usr/local/bin/kube-apiserver
        install -m 744 /home/vagrant/kubernetes/kube-controller-manager /usr/local/bin/kube-controller-manager
        install -m 744 /home/vagrant/kubernetes/kube-scheduler /usr/local/bin/kube-scheduler
        install -m 744 /home/vagrant/etcd/etcd /usr/local/bin/etcd
        install -m 755 /home/vagrant/etcd/etcdctl /usr/local/bin/etcdctl
        rm -rf kubernetes.tgz kubernetes etcd.tgz etcd

        # Generate kube-controller-manager kubeconfig
        kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://#{SUBNET}#{10 + i}:6443 --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig
        kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager-crt.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig
        kubectl config set-context default --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig
        kubectl config use-context default --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig

        # Generate kube-scheduler kubeconfig
        kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://#{SUBNET}#{10 + i}:6443 --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig
        kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler-crt.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig
        kubectl config set-context default --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig
        kubectl config use-context default --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig

        # Configure etcd
        mkdir -p /etc/etcd/ssl/ /var/lib/etcd/
        cp ca-crt.pem kubernetes-crt.pem kubernetes-key.pem /etc/etcd/ssl/
        sed -e 's/ETCD_NAME/controller-#{i}/' -i /home/vagrant/etcd.template
        sed -e "s/INTERNAL_IP/#{SUBNET}#{10 + i}/" -i /home/vagrant/etcd.template
        mv /home/vagrant/etcd.template /lib/systemd/system/etcd.service

        # Configure Kubernetes 
        mkdir -p /var/lib/kubernetes/ssl/
        mv ca-crt.pem ca-key.pem \
           kubernetes-crt.pem kubernetes-key.pem \
           kube-controller-manager-crt.pem kube-controller-manager-key.pem \
           kube-scheduler-crt.pem kube-scheduler-key.pem \
           service-account-crt.pem service-account-key.pem /var/lib/kubernetes/ssl/
        mv encryption-config.yml /var/lib/kubernetes/
        sed -e "s/INTERNAL_IP/#{SUBNET}#{10 + i}/" -i /home/vagrant/kube-apiserver.template
        mv /home/vagrant/kube-apiserver.template /lib/systemd/system/kube-apiserver.service
        mv /home/vagrant/kube-controller-manager.template /lib/systemd/system/kube-controller-manager.service
        mv /home/vagrant/kube-scheduler.template /lib/systemd/system/kube-scheduler.service
        mv /home/vagrant/kube-scheduler-config.template /var/lib/kubernetes/kube-scheduler-config.yml

        # Start services
        systemctl daemon-reload
        systemctl enable etcd.service kube-apiserver.service kube-controller-manager.service kube-scheduler.service
        systemctl start  etcd.service kube-apiserver.service kube-controller-manager.service kube-scheduler.service
      SCRIPT
    end
  end
    
  config.vm.define "controller-3" do |controller|
    controller.vm.provision "kube-dns.yml",                        type: "file", source: "./kube-dns.yml",                        destination: "/home/vagrant/kube-dns.yml"
    controller.vm.provision "kube-flannel.yml",                    type: "file", source: "./kube-flannel.yml",                    destination: "/home/vagrant/kube-flannel.yml"
    controller.vm.provision "kube-traefik-ingress-controller.yml", type: "file", source: "./kube-traefik-ingress-controller.yml", destination: "/home/vagrant/kube-traefik-ingress-controller.yml"
    controller.vm.provision "rbac-apiserver-to-kubelet.yml",       type: "file", source: "./rbac-apiserver-to-kubelet.yml",       destination: "/home/vagrant/rbac-apiserver-to-kubelet.yml"
    controller.vm.provision "rbac-admin-service-account.yml",      type: "file", source: "./rbac-admin-service-account.yml",      destination: "/home/vagrant/rbac-admin-service-account.yml"
    controller.vm.provision "rbac-traefik-service-account.yml",    type: "file", source: "./rbac-traefik-service-account.yml",    destination: "/home/vagrant/rbac-traefik-service-account.yml"
    controller.vm.provision "ingress-kubernetes-dashboard.yml",    type: "file", source: "./ingress-kubernetes-dashboard.yml",    destination: "/home/vagrant/ingress-kubernetes-dashboard.yml"
    controller.vm.provision "ingress-traefik-dashboard.yml",       type: "file", source: "./ingress-traefik-dashboard.yml",       destination: "/home/vagrant/ingress-traefik-dashboard.yml"
    controller.vm.provision "traefik-key.pem",                     type: "file", source: "./certs/traefik-key.pem",               destination: "/home/vagrant/traefik-key.pem"
    controller.vm.provision "traefik-crt.pem",                     type: "file", source: "./certs/traefik-crt.pem",               destination: "/home/vagrant/traefik-crt.pem"

    controller.vm.provision "deploy", type: "shell", inline: <<-SCRIPT
      sleep 30
      kubectl -n kube-system create secret tls traefik-tls-cert --key=/home/vagrant/traefik-key.pem --cert=/home/vagrant/traefik-crt.pem

      kubectl apply -f /home/vagrant/rbac-apiserver-to-kubelet.yml
      kubectl apply -f /home/vagrant/rbac-admin-service-account.yml
      kubectl apply -f /home/vagrant/rbac-traefik-service-account.yml

      kubectl apply -f /home/vagrant/kube-flannel.yml
      kubectl apply -f /home/vagrant/kube-dns.yml
      kubectl apply -f /home/vagrant/kube-traefik-ingress-controller.yml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

      kubectl apply -f /home/vagrant/ingress-kubernetes-dashboard.yml
      kubectl apply -f /home/vagrant/ingress-traefik-dashboard.yml
      rm -rf /home/vagrant/*
    SCRIPT
  end
  
  (1..NUM_NODE).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.provision "ca-crt.pem",                 type: "file", source: "./certs/ca-crt.pem",                     destination: "/home/vagrant/ca-crt.pem"
      node.vm.provision "node-#{i}-key.pem",          type: "file", source: "./certs/node-#{i}-key.pem",              destination: "/home/vagrant/node-key.pem"
      node.vm.provision "node-#{i}-crt.pem",          type: "file", source: "./certs/node-#{i}-crt.pem",              destination: "/home/vagrant/node-crt.pem"
      node.vm.provision "kube-proxy-key.pem",         type: "file", source: "./certs/kube-proxy-key.pem",             destination: "/home/vagrant/kube-proxy-key.pem"
      node.vm.provision "kube-proxy-crt.pem",         type: "file", source: "./certs/kube-proxy-crt.pem",             destination: "/home/vagrant/kube-proxy-crt.pem"
      node.vm.provision "kubernetes.tgz",             type: "file", source: "./kubernetes.tgz",                       destination: "/home/vagrant/kubernetes.tgz"
      node.vm.provision "containerd.tgz",             type: "file", source: "./containerd.tgz",                       destination: "/home/vagrant/containerd.tgz"
      node.vm.provision "cni.tgz",                    type: "file", source: "./cni.tgz",                              destination: "/home/vagrant/cni.tgz"
      node.vm.provision "kube-proxy.template",        type: "file", source: "./templates/kube-proxy.template",        destination: "/home/vagrant/kube-proxy.template"
      node.vm.provision "kube-proxy-config.template", type: "file", source: "./templates/kube-proxy-config.template", destination: "/home/vagrant/kube-proxy-config.template"
      node.vm.provision "kubelet.template",           type: "file", source: "./templates/kubelet.template",           destination: "/home/vagrant/kubelet.template"
      node.vm.provision "kubelet-config.template",    type: "file", source: "./templates/kubelet-config.template",    destination: "/home/vagrant/kubelet-config.template"
      node.vm.provision "containerd-config.template", type: "file", source: "./templates/containerd-config.template", destination: "/home/vagrant/containerd-config.template"
      node.vm.provider "virtualbox" do |v|
        v.name = "node-#{i}"
        v.memory = NODE_MEM
        v.cpus = NODE_CPU
      end
      node.vm.hostname = "node-#{i}"
      node.vm.network :private_network, ip: SUBNET + "#{20 + i}"
      node.vm.provision "bootstrap", type: "shell", inline: <<-SCRIPT
        # Disable swap
        sed -e "s/\(.*swap    sw.*\)/# \1/" -i /etc/fstab
        swapoff -a

        # Enable netfilter and routing
        modprobe br_netfilter
        sysctl -p
        sysctl net.bridge.bridge-nf-call-iptables=1

        # Install dependencies
        apt-get update
        apt-get install -y socat conntrack ipset libseccomp2

        # Move binaries
        tar xvzf kubernetes.tgz
        tar -C / -xvzf containerd.tgz
        mkdir -p /opt/cni/bin/
        tar -C /opt/cni/bin/ -xvzf cni.tgz
        install -m 755 /home/vagrant/kubernetes/kubectl /usr/local/bin/kubectl
        install -m 744 /home/vagrant/kubernetes/kube-proxy /usr/local/bin/kube-proxy
        install -m 744 /home/vagrant/kubernetes/kubelet /usr/local/bin/kubelet
        rm -rf kubernetes.tgz cni.tgz containerd.tgz kubernetes

        # Generate kubelet kubeconfig
        kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://192.168.26.10:6443 --kubeconfig=/var/lib/kubelet/kubeconfig
        kubectl config set-credentials system:node:node-#{i} --client-certificate=node-crt.pem --client-key=node-key.pem --embed-certs=true --kubeconfig=/var/lib/kubelet/kubeconfig
        kubectl config set-context default --cluster=kubernetes --user=system:node:node-#{i} --kubeconfig=/var/lib/kubelet/kubeconfig
        kubectl config use-context default --kubeconfig=/var/lib/kubelet/kubeconfig

        # Generate kube-proxy kubeconfig
        kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://192.168.26.10:6443 --kubeconfig=/var/lib/kube-proxy/kubeconfig
        kubectl config set-credentials kube-proxy --client-certificate=kube-proxy-crt.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=/var/lib/kube-proxy/kubeconfig
        kubectl config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=/var/lib/kube-proxy/kubeconfig
        kubectl config use-context default --kubeconfig=/var/lib/kube-proxy/kubeconfig

        # Configure Kubernetes 
        mkdir -p /var/lib/kubernetes/ssl/ /etc/containerd/
        mv ca-crt.pem kube-proxy-crt.pem kube-proxy-key.pem node-crt.pem node-key.pem /var/lib/kubernetes/ssl/
        sed -e "s/INTERNAL_IP/#{SUBNET}#{20 + i}/" -i /home/vagrant/kubelet.template
        sed -e "s/INTERNAL_IP/#{SUBNET}#{20 + i}/" -i /home/vagrant/containerd-config.template
        mv /home/vagrant/kubelet.template /lib/systemd/system/kubelet.service
        mv /home/vagrant/kubelet-config.template /var/lib/kubelet/config.yml
        mv /home/vagrant/kube-proxy.template /lib/systemd/system/kube-proxy.service
        mv /home/vagrant/kube-proxy-config.template /var/lib/kube-proxy/config.yml
        mv /home/vagrant/containerd-config.template /etc/containerd/config.toml
        
        # Start services
        systemctl daemon-reload
        systemctl enable containerd kubelet kube-proxy
        systemctl start containerd kubelet kube-proxy
      SCRIPT
    end
  end
end
