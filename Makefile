#!/usr/bin/env make

.PHONY: run_website stop_website install_kind \
		create_kind_cluster install_kubectl \
		create_docker_registry connect_registry_to_kind_network \
		connect_registry_to_kind create_kind_cluster_with_registry \
		delete_kind_cluster delete_kind_cluster_with_registry \
		delete_docker_registry create_deployment \
		create_service create_ingress ingress_controller_setup

run_website:
	docker build -t explorecalifornia.com . && \
		docker run -p 5000:80 -d --name explorecalifornia.com --rm explorecalifornia.com

stop_website:
	docker stop explorecalifornia.com

install_kind:
	curl --location --output ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.20.0/kind-linux-amd64
	chmod +x ./kind

install_kubectl:
	brew install kubectl || true;

create_docker_registry:
	if ! docker ps | grep -q 'local-registry'; \
	then docker run -d -p 5000:5000 --name local-registry --restart=always registry:2; \
	else echo "---> local-registry is already running. There's nothing to do here."; \
	fi

delete_docker_registry:
	docker stop local-registry && docker rm local-registry

connect_registry_to_kind_network: create_docker_registry
	docker tag explorecalifornia.com localhost:5000/explorecalifornia.com
	docker push localhost:5000/explorecalifornia.com
	docker network connect kind local-registry || true;

connect_registry_to_kind: connect_registry_to_kind_network
	kubectl apply -f ./kind_configmap.yaml;

create_kind_cluster: install_kind install_kubectl
	kind create cluster --image=kindest/node:v1.27.3 --name explorecalifornia.com --config ./kind_config.yaml || true && \
	kubectl get nodes

create_kind_cluster_with_registry:
	$(MAKE) create_kind_cluster && $(MAKE) connect_registry_to_kind && \
	$(MAKE) create_deployment && $(MAKE) create_service && $(MAKE) create_ingress

delete_kind_cluster: install_kind install_kubectl
	kind delete cluster --name explorecalifornia.com
	kind get clusters

delete_kind_cluster_with_registry: 
	$(MAKE) delete_kind_cluster && $(MAKE) delete_docker_registry

create_deployment:
	kubectl apply -f deployment.yaml

create_service:
	kubectl apply -f service.yaml

create_ingress: ingress_controller_setup
	kubectl apply -f ingress.yaml

ingress_controller_setup:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx \
	--for=condition=ready pod \
	--selector=app.kubernetes.io/component=controller \
	--timeout=90s
