default: all

.PHONY: all clean

all: ca-crt.pem admin-crt.pem kubernetes-crt.pem kube-controller-manager-crt.pem kube-scheduler-crt.pem service-account-crt.pem kube-proxy-crt.pem node-1-crt.pem node-2-crt.pem node-3-crt.pem .done

.done:
	touch .done

ca-crt.pem:
	# Generate a new 4096 bits RSA key and self signed certificate 
	openssl req -new -newkey rsa:4096 -days 9999 -nodes -x509 -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=kubernetes-ca" -keyout ca-key.pem -out ca-crt.pem

admin-crt.pem: ca-crt.pem
	# Generate a new 4096 bits RSA key and CSR for admin user 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:masters/CN=admin" -keyout admin-key.pem -out admin-csr.pem
	# Sign the admin CSR and generate cert
	openssl x509 -req -in admin-csr.pem -out admin-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAcreateserial -sha256 -days 9999

kube-proxy-crt.pem: ca-crt.pem
	# Generate a new 4096 bits RSA key and CSR for kube-proxy 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:node-proxier/CN=system:kube-proxy" -keyout kube-proxy-key.pem -out kube-proxy-csr.pem
	# Sign the kube-proxy CSR and generate cert
	openssl x509 -req -in kube-proxy-csr.pem -out kube-proxy-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

kube-controller-manager-crt.pem: ca-crt.pem
	# Generate a new 4096 bits RSA key and CSR for kube-controller-manager 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:kube-controller-manager/CN=system:kube-controller-manager" -keyout kube-controller-manager-key.pem -out kube-controller-manager-csr.pem
	# Sign the kube-controller-manager CSR and generate cert
	openssl x509 -req -in kube-controller-manager-csr.pem -out kube-controller-manager-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

kube-scheduler-crt.pem: ca-crt.pem
	# Generate a new 4096 bits RSA key and CSR for kube-scheduler 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:kube-scheduler/CN=system:kube-scheduler" -keyout kube-scheduler-key.pem -out kube-scheduler-csr.pem
	# Sign the kube-scheduler CSR and generate cert
	openssl x509 -req -in kube-scheduler-csr.pem -out kube-scheduler-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

service-account-crt.pem: ca-crt.pem
	# Generate a new 4096 bits RSA key and CSR for service-account 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=service-accounts" -keyout service-account-key.pem -out service-account-csr.pem
	# Sign the service-account CSR and generate cert
	openssl x509 -req -in service-account-csr.pem -out service-account-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

kubernetes.cnf:
	cat /etc/ssl/openssl.cnf > kubernetes.cnf
	echo "\n[SAN]\nsubjectAltName=DNS:kubernetes.local,DNS:kubernetes,IP:192.168.26.10,IP:192.168.26.11,IP:192.168.26.12,IP:192.168.26.13,IP:127.0.0.1,IP:10.32.0.1,DNS:kubernetes.default" >> kubernetes.cnf

kubernetes-crt.pem: ca-crt.pem kubernetes.cnf
	# Generate a new 4096 bits RSA key and CSR for kubernetes API
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=kubernetes" -keyout kubernetes-key.pem -out kubernetes-csr.pem -config kubernetes.cnf -reqexts SAN
	# Sign the kube-proxy CSR and generate cert
	openssl x509 -req -extensions SAN -extfile kubernetes.cnf -in kubernetes-csr.pem -out kubernetes-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

traefik.cnf:
	cat /etc/ssl/openssl.cnf > traefik.cnf
	echo "\n[SAN]\nsubjectAltName=DNS:traefik.local,DNS:dashboard.local" >> traefik.cnf

traefik-crt.pem: ca-crt.pem traefik.cnf
	# Generate a new 4096 bits RSA key and CSR for kubernetes API
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=kubernetes/CN=traefik" -keyout traefik-key.pem -out traefik-csr.pem -config traefik.cnf -reqexts SAN
	# Sign the kube-proxy CSR and generate cert
	openssl x509 -req -extensions SAN -extfile traefik.cnf -in traefik-csr.pem -out traefik-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

node-1.cnf:
	cat /etc/ssl/openssl.cnf > node-1.cnf
	echo "\n[SAN]\nsubjectAltName=DNS:node-1,IP:192.168.26.21" >> node-1.cnf

node-2.cnf:
	cat /etc/ssl/openssl.cnf > node-2.cnf
	echo "\n[SAN]\nsubjectAltName=DNS:node-2,IP:192.168.26.22" >> node-2.cnf

node-3.cnf:
	cat /etc/ssl/openssl.cnf > node-3.cnf
	echo "\n[SAN]\nsubjectAltName=DNS:node-3,IP:192.168.26.23" >> node-3.cnf

node-1-crt.pem: ca-crt.pem node-1.cnf
	# Generate a new 4096 bits RSA key and CSR for kubelets 
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:nodes/CN=system:node:node-1" -keyout node-1-key.pem -out node-1-csr.pem -config node-1.cnf -reqexts SAN
	# Sign the admin CSR and generate cert
	openssl x509 -req -extensions SAN -extfile node-1.cnf -in node-1-csr.pem -out node-1-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

node-2-crt.pem: ca-crt.pem node-2.cnf
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:nodes/CN=system:node:node-2" -keyout node-2-key.pem -out node-2-csr.pem -config node-2.cnf -reqexts SAN
	openssl x509 -req -extensions SAN -extfile node-2.cnf -in node-2-csr.pem -out node-2-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

node-3-crt.pem: ca-crt.pem node-3.cnf
	openssl req -new -newkey rsa:4096 -nodes -subj "/C=LU/ST=Luxembourg/L=Luxembourg/O=system:nodes/CN=system:node:node-3" -keyout node-3-key.pem -out node-3-csr.pem -config node-3.cnf -reqexts SAN
	openssl x509 -req -extensions SAN -extfile node-3.cnf -in node-3-csr.pem -out node-3-crt.pem -CA ca-crt.pem -CAkey ca-key.pem -CAserial ca-crt.srl -sha256 -days 9999

clean:
	rm *.cnf *.pem *.srl .done