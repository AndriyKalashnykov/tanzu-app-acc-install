.DEFAULT_GOAL := help
SHELL := /bin/bash

APP_ACC_VERSION := 0.1.0
DOCKER_REGISTRY := registry.pivotal.io
TMP_YTT_DIR := ~/acc-install-bundle

DOCKER_EXISTS	:= @printf "docker"
DOCKER_WHICH	:= $(shell which docker)
ifeq ($(strip $(DOCKER_WHICH)),)
	DOCKER_EXISTS := @echo "ERROR: docker not found. See: https://docs.docker.com/get-docker/" && exit 1
endif

CORP_LDAP_USER_EXISTS := @printf "CORP_LDAP_USER"
ifndef CORP_LDAP_USER
	CORP_LDAP_USER_EXISTS := @echo "CORP_LDAP_USER is undefined" && exit 1
endif

CORP_LDAP_PWD_EXISTS := @printf "CORP_LDAP_PWD"
ifndef CORP_LDAP_PWD
	CORP_LDAP_PWD_EXISTS := @echo "CORP_LDAP_PWD is undefined" && exit 1
endif

KUBECTL_EXISTS	:= @printf "kubectl"
KUBECTL_WHICH	:= $(shell which kubectl)
ifeq ($(strip $(KUBECTL_WHICH)),)
	KUBECTL_EXISTS := @echo "ERROR: kubectl not found. See: https://kubernetes.io/docs/tasks/tools/" && exit 1
endif

KAPP_EXISTS	:= @printf "kapp"
KAPP_WHICH	:= $(shell which kapp)
ifeq ($(strip $(KAPP_WHICH)),)
	KAPP_EXISTS := @echo "ERROR: kapp not found. See: https://carvel.dev/#whole-suite" && exit 1
endif

IMGPKG_EXISTS	:= @printf "imgpkg"
IMGPKG_WHICH	:= $(shell which imgpkg)
ifeq ($(strip $(IMGPKG_WHICH)),)
	IMGPKG_EXISTS := @echo "ERROR: imgpkg not found. See: https://carvel.dev/#whole-suite" && exit 1
endif

KBLD_EXISTS	:= @printf "kbld"
KBLD_WHICH	:= $(shell which kbld)
ifeq ($(strip $(KBLD_EXISTS)),)
	KBLD_EXISTS := @echo "ERROR: kbld not found. See: https://carvel.dev/#whole-suite" && exit 1
endif

help:
	@clear
	@echo "Usage: make COMMAND"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-9s\033[0m - %s\n", $$1, $$2}'

#check-env: @ Check environment variables and installed tools
check-env:

	@printf "Checking pre-requisites: "
	$(DOCKER_EXISTS)
	@printf " "
	$(CORP_LDAP_USER_EXISTS)
	@printf " "
	$(CORP_LDAP_PWD_EXISTS)
	@printf " "	
	$(KUBECTL_EXISTS)
	@printf " "	
	$(KAPP_EXISTS)
	@printf " "		
	$(IMGPKG_EXISTS)
	@printf " "	
	$(KBLD_EXISTS)
	@printf " "			
	@echo "- OK."	

#login: @ Login to a registry
login: check-env
	@docker login --username $$CORP_LDAP_USER@vmware.com --password $$CORP_LDAP_PWD  $$DOCKER_REGISTRY

#install: @ Install Application Accelerator for VMware Tanzu
install: check-env login
	@kapp deploy -a flux -f https://github.com/fluxcd/flux2/releases/download/v0.15.0/install.yaml --yes
#cleanupTempYTTDir	@rm -rf $(TMP_YTT_DIR)
	@imgpkg pull -b registry.pivotal.io/app-accelerator/acc-install-bundle:$(APP_ACC_VERSION) -o $(TMP_YTT_DIR)
	@tree $(TMP_YTT_DIR)
	@kubectl create namespace accelerator-system
	@kubectl create secret docker-registry acc-image-regcred -n accelerator-system --docker-server=$$DOCKER_REGISTRY --docker-username=${CORP_LDAP_USER}@vmware.com --docker-password=${CORP_LDAP_PWD} 
	@export acc_server_service_type=LoadBalancer
	@ytt -f $(TMP_YTT_DIR)/config -f $(TMP_YTT_DIR)/values.yml --data-values-env acc | kbld -f $(TMP_YTT_DIR)/.imgpkg/images.yml -f- | kapp deploy -y -n accelerator-system -a accelerator -f-
	@kubectl get -n accelerator-system pod,service

#uninstall: @ UnInstall Application Accelerator for VMware Tanzu
uninstall: check-env
	@kapp delete -a flux --yes		
	@kapp delete -a accelerator -n accelerator-system --yes

get: 
	@kubectl get gitrepositories,accelerators
	@kubectl get -n accelerator-system pod,service

add: 
	@kubectl apply -f https://raw.githubusercontent.com/AndriyKalashnykov/tanzu-app-acc-install/main/tanzu-app-acc-install.yaml	

del: 
	@kubectl delete accelerator.accelerator.tanzu.vmware.com/tanzu-app-acc-install	