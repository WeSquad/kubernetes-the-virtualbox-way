# Kubernetes the VirtualBox way

This tutorial walks you through setting up [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) on VirtualBox machines, because not everyone wants public cloud.

In an attempt to learn the insides of Kubernetes, I started [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), but on VirtualBox machines provided by Vagrant.

Of course, I couldn't follow exactly [Kelsey's guide](https://github.com/kelseyhightower/kubernetes-the-hard-way) due to VirtualBox specific environment.

Consider this guide is an attempt at centralize specifics about running Kubernetes on VirtualBox.

I created a `Makefile` and a `Vagrantfile` for the sake of not repeating the same commands over and over when testing, but all steps of the provisioning scripts will be detailed.

# Prerequisites

As described, this guide doesn't require any cloud account, however you'll need some other tools.

## Hardware

We are going to spin up 7 VMs, and for this, it is recommended to have 16GB of memory to run comfortably.

I have managed to make it run with 8GB of memory by having only one node, but the machine was really struggling.

## VirtualBox

This guide has been written using VirtualBox v5.2.10 on a Mac.

VirtualBox requires one specific configuration though, disable DHCP server on vboxnet0.

Either with the UI, or with `VBoxManage dhcpserver remove --netname HostInterfaceNetworking-vboxnet0`.

Please start with a clean VirtualBox environment, delete any existing VM before starting to avoid conflicts.

## Vagrant

Nothing specific with Vagrant. I tested everything with v2.1.1.

## Optional

Optionally you can have `kubectl` on your host to facilitate the use of kubernetes once it's running.

Install it with your favorite package manager or get the binary as per the [official instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-via-curl).

# Assumptions

This guide assumes using the default VirtualBox host-only network called `vboxnet0` which uses the `192.168.26.0/24` subnet.

If you are using a different subnet, feel free to find and replace in all files with your subnet value.

I have only tested on a Mac. I assume you won't experience any difference running this on Linux but I have no plans to support running this on Windows for the moment.

# Topology

This Vagrant lab aims at creating a HA Kubernetes cluster over Vagrant.

7 VMs are required although you could only have one node if you are lacking RAM. These VMs are:

## HAProxy

HAProxy serves the sole purpose of load balancing the 3 `kube-apiserver` we are going to be running using simple tcp load balancing with a check.

While this works fine, the config is very basic and will need to be tweaked for a more serious environment.

HAProxy's IP address is `192.168.26.10`. The `kube-apiservers` are exposed over port 443 and HAProxy stats UI is exposed over port 9000.

## Controllers

Each of the 3 controllers will be running the following components:

  - etcd v3.3.5
  - kube-apiserver v1.10.3
  - kube-scheduler v1.10.3
  - kube-controller-manager v1.10.3

Their respective IP addresses are `192.168.26.11`, `192.168.26.12` and `192.168.26.13`.

We will get in the details later.

## Nodes

Each of the 3 nodes will be running the following components:

  - kubelet v1.10.3
  - kube-proxy v1.10.3
  - cni v0.7.1
  - containerd v1.1.0
  - flannel v0.10

Their respective IP addresses are `192.168.26.21`, `192.168.26.22` and `192.168.26.23`.

We will get in the details later.

## Network

While Kelsey's guide uses routes to achieve pod communication I prefer to use flannel to manage that.

Feel free to replace flannel's subnet `10.244.0.0/16` if you plan to use another CNI plugin or if you plan to create routes manually.

# TL;DR

```bash
git clone https://github.com/wemanity-luxembourg/kubernetes-the-virtualbox-way
cd kubernetes-the-virtualbox-way
make
```

# Getting started

## Clone this repository

Pick somewhere you like on your host and git clone https://github.com/wemanity-luxembourg/kubernetes-the-virtualbox-way.

```bash
git clone https://github.com/wemanity-luxembourg/kubernetes-the-virtualbox-way
cd kubernetes-the-virtualbox-way
```

## Getting all the bits and bobs ready

In order to save the planet from bandwidth exhaustion (and to save our time too), `make prerequisites` will download all required binaries and make tarballs that Vagrant will use when building the VMs in addition to generating all certificates.

This will take a while, so go ahead, run the command and read on.

# Prerequisites

## Certificates

Certificates are widely used inside of Kubernetes to secure communication, and provide authentication between the different components and the `kubectl` users.

To avoid the abstraction level provided by popular `cfssl`, I decided to use the good old `openssl` to generate the certificates. This is just a reminder that certificates are not magic.

Here is a table of all certificate and their use.

| Filename                        | Use                                                                                      |
|---------------------------------|------------------------------------------------------------------------------------------|
| ca-*.pem                        | used to sign all other certificates                                                      |
| admin-*.pem                     | used by `kubectl` to communicate with `kube-apiserver`                                   |
| kubernetes-*.pem                | used by `kube-apiserver` for HTTPS and for `etcd` peer communication                     |
| kube-controller-manager-*.pem   | used by `kube-controller-manager` on controllers to communicate with `kube-apiserver`    |
| service-account-*.pem           | used by `kube-controller-manager` on controllers to generate service account credentials |
| kube-scheduler-*.pem            | used by `kube-scheduler` on controllers to communicate with `kube-apiserver`             |
| kube-proxy-*.pem                | used by `kube-proxy` on nodes to communicate with kubelet and `kube-apiserver`           |
| node-1-*.pem                    | used by `kubelet` on node-1 to communicate with `kube-apiserver`                         |
| node-2-*.pem                    | used by `kubelet` on node-2 to communicate with `kube-apiserver`                         |
| node-3-*.pem                    | used by `kubelet` on node-3 to communicate with `kube-apiserver`                         |

### RootCA

The Root Certificate Authority of our Kubernetes installation. This certificate and key are used as the authority to sign all other certificates.

Needless to say, running your own PKI infrastructure implies a ton of security and good practices that won't be covered here.

This guide will leave the RootCA key on the servers, please never do that on a real environment.

```bash 
openssl req -new -newkey rsa:4096 -days 9999 -nodes -x509 -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=kubernetes-ca" -keyout ca-key.pem -out ca-crt.pem
```

This will generate:

  - The self signed RootCA certificate (`-x509`) valid for 9999 days (`-days 9999`) to `ca-crt.pem` (`-out`) with information provided in `subj`
  - The 4096 bits RSA (`-newkey rsa:4096`) key with no passphrase (`-nodes`) to `ca-key.pem` (`-keyout`)
  
Do not hesitate to amend `-subj` to your needs. As a reminder:

  - C: country
  - ST: state
  - L: city
  - O: organization
  - OU: organization unit
  - CN: common name

### Admin

This certificate will be used to login with `kubectl` later on.

```bash
openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:masters/CN=admin" -keyout admin-key.pem -out admin-csr.pem
```

This will generate:

  - The admin certificate signing request (absence of `-x509`) to `admin-csr.pem` (`-out`) with information provided in `subj`
  - The 4096 bits RSA (`-newkey rsa:4096`) key with no passphrase (`-nodes`) to `admin-key.pem` (`-keyout`)

Here, the `O` field in `-subj` is important. `O=system:masters` means this client certificate will be in the `system:masters` Kubernetes group and therefore have all cluster admin rights.

```bash
openssl x509 -req -in admin-csr.pem -out admin-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAcreateserial -sha256 -days 9999
```

This will sign (`openssl x509 -req`) the admin CSR (`-in`) with the RootCA (`-CA`, `-CAkey`) with a sha256 hash (`-sha256`) and generate the certificate `admin-crt.pem` (`-out`) valid for 9999 days (`-days 9999`)

### Proxy, Controller Manager, Scheduler and Service Account

They are based on the same principle, only with different `-subj` and `O` values, creating different users in different groups. Read the `Makefile` and see for yourself.

### Kubernetes API

This is the main `kube-apiserver` certificate. The process is similar to other certs, only the CSR needs to contain more information.

In order to create a CSR with SANs (subject alternative name), we need a custom `openssl` config. Let's copy the base `openssl` config and add the needed SANs.

```bash
cat /etc/ssl/openssl.cnf > kubernetes.cnf
echo "\n[SAN]\nsubjectAltName=DNS:kubernetes.local,DNS:kubernetes,IP:192.168.26.10,IP:192.168.26.11,IP:192.168.26.12,IP:192.168.26.13,IP:127.0.0.1,IP:10.32.0.1,DNS:kubernetes.default" >> kubernetes.cnf
```

Pay attention to the two types of SANs, DNS and IP. DNS will reference our internal DNS names, while IPs are the load balancer (`.10`), all controllers (`.1x`) and the internal cluster IP (`10.32.0.1`).

```bash
openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=kubernetes" -keyout kubernetes-key.pem -out kubernetes-csr.pem -config kubernetes.cnf -reqexts SAN
```

The CSR command structure is identical to the previous ones except that SAN extensions need to be loaded with `-reqexts SAN`. Otherwise, the CSR will not contain the SANs at all.

```bash
openssl x509 -req -extensions SAN -extfile kubernetes.cnf -in kubernetes-csr.pem -out kubernetes-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999
```

The signing command structure is identical to the previous ones except that SAN extensions need to be loaded with `-extensions SAN` and the file containing the SANs also needs to be provided with `-extfile kubernetes.cnf`.

### Nodes 

The nodes certificates are based on the same principle, but only have two SANs. Read the `Makefile` and see for yourself.

In order for the nodes to register correctly with the API using the `Node` authorization mode, it is important to follow to have:

  - the OU set to `system:nodes`
  - the CN set to `CN=system:node:any-name`

More on that matter in the [Official documentation](https://kubernetes.io/docs/reference/access-authn-authz/node/)

## Binaries

That's right, we are not going to use any package manager and we are going to download and configure each binary and service unit manually.

The `Makefile` targets `kubernetes.tgz`, `etcd.tgz`, `containerd.tgz`, `cni.tgz` will download and tar all binaries to be copied in the Vagrant VMs to save time.

## Encryption

The `encryption-config.yml` config will be used to encrypt secrets at rest. Read more in the official [documentation](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

The `Makefile` target `encryption-config.yml` will inject a randomly generated encryption key `$(shell head -c 32 /dev/urandom | base64 | tr '\/' 'x')` in the `templates/encryption-config.template`.

# Now with vagrant

By now, `make prerequisites` should have finished creating the certs and downloading all binaries.

This project is my first time using Vagrant, so the `Vagrantfile` is pretty straightforward, structured and descriptive. I am sure that the structure is easy to understand.

## HAProxy

HAProxy is configured as simple TCP load balancer. There are 3 backends (the 3 `kube-apiserver`), if their port 6443 is opened (the default HTTPS port for `kube-apiserver`), the HAProxy will forward TCP traffic to them using a round robin method. If one of the `kube-apiserver` is down, HAProxy will forward to the others available ones.

The command `vagrant up haproxy` will bring up a Debian stretch machine, install HAProxy, inject the config and start the service.

> :information_source: The `haproxy.cfg` file contains the IP addresses of the `kube-apiserver`s. If you are not running on subnet `192.168.26.0/24` you need to change the IP addresses in the `backend http_back_kube` section.

For now, you can check the stats and see the backends are all down in your browser with http://192.168.26.10:9000

## Controllers

The `file` provisioner in the `Vagrantfile` will copy on the VM the required certs, binaries, templates and config files.

You can run `vagrant up controller-1 controller-2 controller-3` while reading below.

Let's see the script step by step.

### Installing binaries

```bash
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
```

This part of the script moves all binaries in place then cleans up. Nothing to see here.

### Generating kubeconfigs

`kube-controller-manager` and `kube-scheduler` will need kubeconfigs to communicate with `kube-apiserver`.

```bash
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
```

This section generates kubeconfigs for `kube-controller-manager` and `kube-scheduler` using the certificates we generated earlier.

This is already well documented in the [Official documentation](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

### Configuring etcd

```bash
# Configure etcd
mkdir -p /etc/etcd/ssl/ /var/lib/etcd/
cp ca-crt.pem kubernetes-crt.pem kubernetes-key.pem /etc/etcd/ssl/
sed -e 's/ETCD_NAME/controller-#{i}/' -i /home/vagrant/etcd.template
sed -e "s/INTERNAL_IP/#{SUBNET}#{10 + i}/" -i /home/vagrant/etcd.template
mv /home/vagrant/etcd.template /lib/systemd/system/etcd.service
```

This script creates directories for the certs, and for etcd database, then moves the certs in the former.

Then, substitutes `ETCD_NAME` from `etcd.template` with a name dynamically generated by Vagrant, respectively `controller-1`, `controller-2` and `controller-3`. 

Secondly, it will substitute `INTERNAL_IP` for the actual IP of the node, respectively `192.168.26.11`, `192.168.26.12` and `192.168.26.13`.

> :information_source: Should you want to change the names of IPs, you will also need to amend the `--initial-cluster` parameter in the `etcd.template`.

The script them moves the processed template in `/lib/systemd/system/etcd.service` so we can enable and start it later.

Let's take a look at the processed template file for `controller-1`:

```ini
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \
  --name controller-1 \
  --cert-file=/etc/etcd/ssl/kubernetes-crt.pem \
  --key-file=/etc/etcd/ssl/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/ssl/kubernetes-crt.pem \
  --peer-key-file=/etc/etcd/ssl/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ssl/ca-crt.pem \
  --peer-trusted-ca-file=/etc/etcd/ssl/ca-crt.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://192.168.26.11:2380 \
  --listen-peer-urls https://192.168.26.11:2380 \
  --listen-client-urls https://192.168.26.11:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.26.11:2379 \
  --initial-cluster-token cluster-0 \
  --initial-cluster controller-1=https://192.168.26.11:2380,controller-2=https://192.168.26.12:2380,controller-3=https://192.168.26.13:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

There are no tricks here, only make sure IPs are on the `192.168.26` subnet. 

All configuration flags are described in the [Official documentation](https://coreos.com/etcd/docs/latest/op-guide/configuration.html).

### Configuring Kubernetes

```bash
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
```

This script moves the certs in a freshly created directory and the `encryption.yml` in `/var/lib/kubernetes` where it will be automatically processed when we run the service.

Talking about services, the `sed` command will will substitute `INTERNAL_IP` for the actual IP of the controller, respectively `192.168.26.11`, `192.168.26.12` and `192.168.26.13` in `kube-apiserver.template` then move the `kube-apiserver`, `kube-controller-manager` and `kube-scheduler` services under /lib/systemd/system/ where we can start them later.

`kube-scheduler` has a yml file config that we also move under `/var/lib/kubernetes/`.

#### kube-apiserver config

Let's see what's in the service file of controller-1:

```yml
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --advertise-address=192.168.26.11 \
  --allow-privileged=true \
  --apiserver-count=3 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/audit.log \
  --authorization-mode=Node,RBAC \
  --bind-address=192.168.26.11 \
  --client-ca-file=/var/lib/kubernetes/ssl/ca-crt.pem \
  --enable-swagger-ui=true \
  --etcd-cafile=/var/lib/kubernetes/ssl/ca-crt.pem \
  --etcd-certfile=/var/lib/kubernetes/ssl/kubernetes-crt.pem \
  --etcd-keyfile=/var/lib/kubernetes/ssl/kubernetes-key.pem \
  --etcd-servers=https://192.168.26.11:2379,https://192.168.26.12:2379,https://192.168.26.13:2379 \
  --event-ttl=1h \
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yml \
  --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP \
  --kubelet-certificate-authority=/var/lib/kubernetes/ssl/ca-crt.pem \
  --kubelet-client-certificate=/var/lib/kubernetes/ssl/kubernetes-crt.pem \
  --kubelet-client-key=/var/lib/kubernetes/ssl/kubernetes-key.pem \
  --kubelet-https=true \
  --runtime-config=api/all,admissionregistration.k8s.io/v1alpha1=true \
  --service-account-key-file=/var/lib/kubernetes/ssl/service-account-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=/var/lib/kubernetes/ssl/kubernetes-crt.pem \
  --tls-private-key-file=/var/lib/kubernetes/ssl/kubernetes-key.pem \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

There are a few important things here to make it work with VirtualBox. Due to the two network interfaces VirtualBox uses, we have to specify the IP address of the host-only network in the `--bind-address` flag instead of `0.0.0.0`. This will ensure `kube-apiserver` will never try to use the `10.0.2.15` from the NAT network.

> :information_source: Doing this will prevent accessing the api on localhost.

Another important bit of the configuration is `--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP`.

This tells `kube-apiserver` that we will first try to contact `kubelet`s wia their IP, as opposed to the default hostname. This is required because we don't have a DNS to resolve VMs name. If you do however, feel free to use `Hostname` first.

Regarding authorization, `--authorization-mode=Node,RBAC` will enable both RBAC and [Node authorization mode](https://kubernetes.io/docs/reference/access-authn-authz/node/)

As specified in the documentation, when using `Node` authorization mode, it's important to also use `NodeRestriction` in `--admission-control`.

All configuration flags are described in the [Official documentation](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)

#### kube-controller-manager config

Let's see what's in the service file of controller-1:

```yml
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --bind-address=0.0.0.0 \
  --allocate-node-cidrs=true \
  --cluster-cidr=10.244.0.0/16 \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/var/lib/kubernetes/ssl/ca-crt.pem \
  --cluster-signing-key-file=/var/lib/kubernetes/ssl/ca-key.pem \
  --leader-elect=true \
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \
  --root-ca-file=/var/lib/kubernetes/ssl/ca-crt.pem \
  --service-account-private-key-file=/var/lib/kubernetes/ssl/service-account-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --use-service-account-credentials=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Here, the binding address is not very important, but because we are going to use flannel we should specify the following flags:

  - `--allocate-node-cidrs=true`
  - `--cluster-cidr=10.244.0.0/16`

All configuration flags are described in the [Official documentation](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/)

#### kube-scheduler configuration

The service unit file for `kube-scheduler` if very straightforward and only executes `kube-scheduler` with with a specific config file. Let's have a look at it:

```yml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
```

This file only specifies the kubeconfig that `kube-scheduler` needs to talk to `kube-apiserver`. 

I couldn't find any documentation regarding options in this file, so you will have to dig in [the code](https://github.com/kubernetes/kubernetes/blob/master/pkg/apis/componentconfig/types.go) to find out all options.

### Starting the control plane services

This part of the script simply starts the services we have just configured.

```yml
# Start services
systemctl daemon-reload
systemctl enable etcd.service kube-apiserver.service kube-controller-manager.service kube-scheduler.service
systemctl start  etcd.service kube-apiserver.service kube-controller-manager.service kube-scheduler.service
```

After starting the 3 controllers, give it a minute and check the state of the services:

```bash
vagrant ssh controller-1 -c "kubectl get componentstatus"

NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
```

Rinse and repeat for all controllers.

### Deploy script for controller-3

When vagrant provisions `controller-3`, there is an extra script that is not run on all other controllers:

```yml
sleep 30
/usr/local/bin/kubectl apply -f /home/vagrant/rbac-apiserver-to-kubelet.yml
/usr/local/bin/kubectl apply -f /home/vagrant/kube-dns.yml
/usr/local/bin/kubectl apply -f /home/vagrant/kube-flannel.yml
```

This script will deploy the [DNS addon](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/), together with [flannel](https://github.com/coreos/flannel) and some RBAC roles that will allow `kube-apiserver` to talk to `kubelet`s. This is required otherwise `kubectl logs` and `kubectl exec` will return access denied.

> :information_source: You cannot simply `kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml` to install `flannel` with VirtualBox.

> This repository contains a custom flannel with an added parameter `- --iface=eth1` line 127 to make sure `flannel` binds to the correct interface.

## Nodes

The `file` provisioner in the `Vagrantfile` will copy on the VM the required certs, binaries, templates and config files.

You can run `vagrant up node-1 node-2 node-3` while reading below.

Let's see the script step by step.

### Disable swap

One of `kubelet`'s requirements is to entirely disable swap on the node. This is achieved in Debian with:

```bash
# Disable swap
sed -e "s/\(.*swap    sw.*\)/# \1/" -i /etc/fstab
swapoff -a
```

The `sed` command removes the line that mounts the swap partition to persist across reboots, while `swapoff` disables swap immediately.

### Enable netfilter and routing

In order for pods to be able to communicate across different hosts, `flannel` is not enough. 

```bash
# Enable netfilter and routing
modprobe br_netfilter
sysctl -p
sysctl net.bridge.bridge-nf-call-iptables=1
```

Nodes need to have the `br_netfilter` kernel module active and also let iptables see the bridge traffic for processing with `sysctl net.bridge.bridge-nf-call-iptables=1`.

### Install kubelet and kube-proxy dependencies

Other dependencies are requires to make `kubectl port-forward` and `kubectl exec` work.

```bash
# Install dependencies
apt-get update
apt-get install -y socat conntrack ipset libseccomp2
```

### Installing binaries

```bash
# Move binaries
tar xvzf kubernetes.tgz
tar -C / -xvzf containerd.tgz
mkdir -p /opt/cni/bin/
tar -C /opt/cni/bin/ -xvzf cni.tgz
install -m 755 /home/vagrant/kubernetes/kubectl /usr/local/bin/kubectl
install -m 744 /home/vagrant/kubernetes/kube-proxy /usr/local/bin/kube-proxy
install -m 744 /home/vagrant/kubernetes/kubelet /usr/local/bin/kubelet
rm -rf kubernetes.tgz cni.tgz containerd.tgz kubernetes
```

This part of the script moves all binaries in place then cleans up. Nothing to see here.

Note that the containerd archive contains the whole file system tree so we extract it to `/`. This provides us with a working system unit file ready to be started.

### Generating kubeconfigs

`kubelet` and `kube-proxy` will need kubeconfigs to communicate with `kube-apiserver`.

```bash
# Generate kubelet kubeconfig
kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://192.168.26.10 --kubeconfig=/var/lib/kubelet/kubeconfig
kubectl config set-credentials system:node:node-#{i} --client-certificate=node-crt.pem --client-key=node-key.pem --embed-certs=true --kubeconfig=/var/lib/kubelet/kubeconfig
kubectl config set-context default --cluster=kubernetes --user=system:node:node-#{i} --kubeconfig=/var/lib/kubelet/kubeconfig
kubectl config use-context default --kubeconfig=/var/lib/kubelet/kubeconfig

# Generate kube-proxy kubeconfig
kubectl config set-cluster kubernetes --certificate-authority=ca-crt.pem --embed-certs=true --server=https://192.168.26.10 --kubeconfig=/var/lib/kube-proxy/kubeconfig
kubectl config set-credentials kube-proxy --client-certificate=kube-proxy-crt.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=/var/lib/kube-proxy/kubeconfig
kubectl config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=/var/lib/kube-proxy/kubeconfig
kubectl config use-context default --kubeconfig=/var/lib/kube-proxy/kubeconfig
```

This section generates kubeconfigs for `kubelet` and `kube-proxy` using the certificates we generated earlier.

This is already well documented in the [Official documentation](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

### Configuring Kubernetes

```bash
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
```

This script moves the certs in a freshly created directory and creates the config directory for `containerd`.

The `sed` command will will substitute `INTERNAL_IP` for the actual IP of the node, respectively `192.168.26.21`, `192.168.26.22` and `192.168.26.23` in `kubelet.template` and `containerd-config.template` then move the `kubelet`, and `kube-proxy` services under `/lib/systemd/system/` where we can start them later.

`kube-proxy`, `kubelet` and `containerd` have a config files respectively in `/var/lib/kubelet/config.yml`, `/var/lib/kube-proxy/config.yml` and `/etc/containerd/config.toml`.

In order to make `kubelet` and `containerd` pick up the right interface, `kubelet` and `containerd` need specific options.

#### kubelet system unit config

Let's see what is in the `kubelet` service file of node-1:

```yml
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/config.yml \
  --node-ip=192.168.26.21 \
  --allow-privileged \
  --container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
  --image-pull-progress-deadline=2m \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --network-plugin=cni \
  --register-node=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

To make `kubelet` pick up the rght IP address from the two VM interfaces, it is mandatory to specify `--node-ip`.

In order to run `flannel` later on, we need to allow the `kubelet` to run privilaged containers with `--allow-privileged`.

All configuration flags are described in the [Official documentation](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)

#### kubelet config file

The `kubelet` config file doesn't contain anything node-specific.

```yml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ssl/ca-crt.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
runtimeRequestTimeout: "5m"
tlsCertFile: "/var/lib/kubernetes/ssl/node-crt.pem"
tlsPrivateKeyFile: "/var/lib/kubernetes/ssl/node-key.pem"
```

I couldn't find any documentation regarding options in this file, so you will have to dig in [the code](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/kubeletconfig/types.go) to find out all options.

#### kube-proxy configuration

Configuration of `kube-proxy` is now done exclusively in a config file.

```yml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
clientConnection:
  acceptContentTypes: ""
  burst: 10
  contentType: application/vnd.kubernetes.protobuf
  kubeconfig: /var/lib/kube-proxy/kubeconfig
  qps: 5
clusterCIDR: 10.244.0.0/16
configSyncPeriod: 15m0s
conntrack:
  max: 0
  maxPerCore: 32768
  min: 131072
  tcpCloseWaitTimeout: 1h0m0s
  tcpEstablishedTimeout: 24h0m0s
enableProfiling: false
healthzBindAddress: 0.0.0.0:10256
hostnameOverride: ""
iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: 0s
  syncPeriod: 30s
ipvs:
  minSyncPeriod: 0s
  scheduler: ""
  syncPeriod: 30s
kind: KubeProxyConfiguration
metricsBindAddress: 127.0.0.1:10249
mode: iptables
nodePortAddresses: null
oomScoreAdj: -999
portRange: ""
resourceContainer: /kube-proxy
udpIdleTimeout: 250ms
```

There is nothing specific here other than `clusterCIDR` should reflect the Pod CIDR configured before.

#### containerd configuration

```toml
[plugins.cri]
  stream_server_address = "192.168.26.21"
```

To allow `kubectl exec` to work, it is necessary to specify the streaming IP address.

### Start the services

Once everything is in place, the script will start services.

```bash
# Start services
systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy
```

# Trying it out

For convenience, create the admin kubeconfig and copy it where it belongs. Be careful not to overwrite your existing kubeconfig if you already have one.

```bash
make admin.kubeconfig
cp admin.kubeconfig ~/.kube/config
```

You can now run the [smoke test](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/13-smoke-test.md) except for gVisor which this cluster is not using yet.