ENCRYPTION_KEY := $(shell head -c 32 /dev/urandom | base64 | tr '\/' 'x')
ETCD_VERSION := v3.3.5
KUBERNETES_VERSION := v1.10.3
CONTAINERD_VERSION := 1.1.0
CNI_VERSION := v0.7.1

default: vagrant

.PHONY: prerequisites vagrant clean clean-all

prerequisites: certs/.done kubernetes.tgz etcd.tgz containerd.tgz cni.tgz encryption-config.yml

vagrant: prerequisites kubernetes.tgz etcd.tgz containerd.tgz cni.tgz encryption-config.yml
	vagrant up haproxy controller-1 controller-2 controller-3 node-1 node-2 node-3

certs/.done:
	make -C certs

kubernetes.tgz:
	mkdir -p ./kubernetes
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-apiserver -o ./kubernetes/kube-apiserver
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-controller-manager -o ./kubernetes/kube-controller-manager
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-scheduler -o ./kubernetes/kube-scheduler
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-proxy -o ./kubernetes/kube-proxy
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubelet -o ./kubernetes/kubelet
	curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o ./kubernetes/kubectl
	tar cvzf kubernetes.tgz ./kubernetes
	rm -rf ./kubernetes

etcd.tgz:
	mkdir -p ./etcd
	curl -sL https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz | tar xz --strip 1 -C ./etcd etcd*/etcd etcd*/etcdctl
	tar cvzf etcd.tgz ./etcd
	rm -rf ./etcd

containerd.tgz:
	curl -sL https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz -o containerd.tgz

cni.tgz:
	curl -sL https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz -o cni.tgz

encryption-config.yml:
	sed -e 's/ENCRYPTION_KEY/${ENCRYPTION_KEY}/' ./templates/encryption-config.template > ./encryption-config.yml

admin.kubeconfig: certs
	kubectl config set-cluster kubernetes --certificate-authority=./certs/ca-crt.pem --embed-certs=true --server=https://192.168.26.10:6443 --kubeconfig=admin.kubeconfig
	kubectl config set-credentials kubernetes-admin --client-certificate=./certs/admin-crt.pem --client-key=./certs/admin-key.pem --embed-certs=true --kubeconfig=admin.kubeconfig
	kubectl config set-context default --cluster=kubernetes --user=kubernetes-admin --kubeconfig=admin.kubeconfig
	kubectl config use-context default --kubeconfig=admin.kubeconfig
	echo "Copy the admin.kubeconfig to ~/.kube/config"

admin.token: admin.kubeconfig
	kubectl get secret -n kube-system $$(kubectl get sa -n kube-system admin -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -D > admin.token

clean:
	vagrant destroy -f haproxy controller-1 controller-2 controller-3 node-1 node-2 node-3

clean-all: clean
	rm -rf ./kubernetes.tgz ./etcd.tgz ./cni.tgz ./containerd.tgz ./encryption-config.yml ./admin.kubeconfig
	make -C certs clean
