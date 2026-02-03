SHELL := /bin/bash

ENVIRONMENTS := dev prod sandboxy tools observability
DEFAULT_ENV := tools
TOFU_DIR := clusters
EPHEMERAL_TOFU_DIR := ephemeral-clusters/opentofu
EPHEMERAL_DIR := ephemeral-clusters/opentofu
PROXMOX_DIR := proxmox
MODULES_DIR := modules
EXTRA_ARGS ?=

CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

define HELP_MESSAGE
Fullstack.pw Infrastructure Management Commands:

OpenTofu Environment Commands:
  make plan                     - Plan changes for all environments
  make plan ENV=<environment>   - Plan changes for a specific environment
  make apply                    - Apply changes for all environments
  make apply ENV=<environment>  - Apply changes for a specific environment
  make destroy ENV=<environment>- Destroy resources in a specific environment (requires confirmation)

Proxmox VM Management (legacy):
  make proxmox-init             - Initialize OpenTofu for Proxmox
  make proxmox-plan             - Plan Proxmox VM changes
  make proxmox-apply            - Apply Proxmox VM changes
  make proxmox-import           - Import existing Proxmox VMs to state

Kubernetes Management:
  make k8s-init                 - Initialize all Kubernetes clusters with k3s
  make setup-pxe                - Set up PXE boot server for k8s nodes

Talos Cluster Management:
  make update-kubeconfigs         - Update all Talos cluster kubeconfigs in Vault
  make update-kubeconfigs ENV=<env> - Update kubeconfigs for specific environment
  make test-kubeconfig-update     - Test kubeconfig update with dry-run mode

Ephemeral Cluster Management:
  make ephemeral-init                      - Initialize OpenTofu for ephemeral clusters
  make ephemeral-plan WORKSPACE=<name>     - Plan ephemeral infrastructure
  make ephemeral-apply WORKSPACE=<name>    - Apply ephemeral infrastructure (4 phases)
  make ephemeral-destroy WORKSPACE=<name>  - Destroy ephemeral infrastructure
  make ephemeral-workspace                 - List ephemeral workspaces

Environment Management:
  make init                     - Initialize OpenTofu for all environments
  make fmt                      - Format OpenTofu files
  make validate                 - Validate OpenTofu files
  make workspace                - List all OpenTofu workspaces
  make create-workspace ENV=<env> - Create a new OpenTofu workspace

Module Management:
  make module-test MODULE=<name> - Test a specific OpenTofu module

Utilities:
  make clean                    - Clean up temporary files
  make help                     - Show this help message

Examples:
  make plan ENV=dev             - Plan changes for dev environment
  make apply ENV=sandboxy       - Apply changes to sandboxy environment
  make proxmox-apply            - Apply changes to Proxmox VMs
endef
export HELP_MESSAGE

.PHONY: help
help:
	@echo -e "$$HELP_MESSAGE"

.PHONY: init
init: install-crypto-tools
	@echo -e "${CYAN}Initializing OpenTofu for all environments...${NC}"
	@cd $(TOFU_DIR) && tofu init -reconfigure -upgrade

.PHONY: create-workspace
create-workspace:
	@if [ -z "$(ENV)" ]; then \
		echo -e "${RED}ERROR: ENV is required. Example: make create-workspace ENV=dev${NC}"; \
		exit 1; \
	fi
	@echo -e "${CYAN}Creating workspace for $(ENV)...${NC}"
	@cd $(TOFU_DIR) && tofu workspace new $(ENV)

.PHONY: workspace
workspace:
	@echo -e "${CYAN}Listing OpenTofu workspaces...${NC}"
	@cd $(TOFU_DIR) && tofu workspace list

.PHONY: plan
plan:
	@echo -e "${CYAN}Running load_secrets.py...${NC}" && cd $(TOFU_DIR) && \
		if [ -f "../python-venv/bin/activate" ]; then source ../python-venv/bin/activate; fi && \
		python3 load_secrets.py && cd ..
	@if [ -z "$(ENV)" ]; then \
		echo -e "${CYAN}Planning changes for all environments...${NC}"; \
		for env in $(ENVIRONMENTS); do \
			cd $(TOFU_DIR) && tofu workspace select $${env} || tofu workspace new $${env}; \
			echo -e "\n#########################################################" | tee -a plan.txt; \
			echo -e "##\n##   Planning changes for $${env} environment..." | tee -a plan.txt; \
			echo -e "##\n#########################################################" | tee -a plan.txt; \
			if tofu plan $(EXTRA_ARGS) -no-color -out=$${env}.tfplan 2>&1 | tee -a plan.txt; then \
				tofu show -no-color $${env}.tfplan >> plan.txt 2>&1; \
			else \
				echo -e "\n❌ OpenTofu plan failed for $${env} environment" | tee -a plan.txt; \
			fi; \
			cd ..; \
		done; \
	else \
		echo -e "${CYAN}Planning changes for $(ENV) environment...${NC}"; \
		cd $(TOFU_DIR) && tofu workspace select $(ENV) || tofu workspace new $(ENV); \
		if tofu plan $(EXTRA_ARGS) -no-color -out=$(ENV).tfplan 2>&1 | tee -a plan.txt; then \
			tofu show -no-color $(ENV).tfplan >> plan.txt 2>&1; \
		else \
			echo -e "\n❌ OpenTofu plan failed for $(ENV) environment" | tee -a plan.txt; \
		fi; \
	fi

.PHONY: apply
apply:
	@echo -e "${CYAN}Running load_secrets.py...${NC}" && cd $(TOFU_DIR) && \
		if [ -f "../python-venv/bin/activate" ]; then source ../python-venv/bin/activate; fi && \
		python3 load_secrets.py && cd ..
	@TARGET_FLAG=""; \
	if [ -n "$(TARGET)" ]; then \
		TARGET_FLAG="-target=$(TARGET)"; \
		echo -e "${YELLOW}Targeting specific resource: $(TARGET)${NC}"; \
	fi; \
	if [ -z "$(ENV)" ]; then \
		for env in $(ENVIRONMENTS); do \
			cd $(TOFU_DIR) && tofu workspace select $${env} || tofu workspace new $${env}; \
			echo -e "\n#########################################################"; \
			echo -e "##\n## Applying changes to $${env} environment..."; \
			echo -e "##\n#########################################################"; \
			if [ -f "$${env}.tfplan" ]; then \
				tofu apply $${env}.tfplan && cd .. || cd ..; \
			else \
				tofu apply $$TARGET_FLAG $(EXTRA_ARGS) -auto-approve && cd .. || cd ..; \
			fi; \
		done; \
	else \
		echo -e "${CYAN}Applying changes to $(ENV) environment...${NC}"; \
		cd $(TOFU_DIR) && tofu workspace select $(ENV); \
		if [ -f "$(ENV).tfplan" ]; then \
			tofu apply $(ENV).tfplan; \
		else \
			tofu apply $$TARGET_FLAG $(EXTRA_ARGS) -auto-approve; \
		fi; \
	fi

.PHONY: destroy
destroy:
	@if [ -z "$(ENV)" ]; then \
		echo -e "${RED}ERROR: ENV is required. Example: make destroy ENV=dev${NC}"; \
		exit 1; \
	fi
	@echo -e "${RED}WARNING: This will destroy all resources in the $(ENV) environment!${NC}"
	@echo -e "${RED}Are you absolutely sure? Type '$(ENV)' to confirm: ${NC}"
	@read confirmation; \
	if [ "$$confirmation" = "$(ENV)" ]; then \
		echo -e "${YELLOW}Destroying resources in $(ENV) environment...${NC}"; \
		cd $(TOFU_DIR) && tofu workspace select $(ENV) && tofu destroy -var="vault_token=${VAULT_TOKEN}"; \
	else \
		echo -e "${YELLOW}Destroy operation cancelled.${NC}"; \
	fi

.PHONY: fmt
fmt:
	@echo -e "${CYAN}Formatting OpenTofu files...${NC}"
	@tofu fmt -recursive

.PHONY: validate
validate:
	@echo -e "${CYAN}Validating OpenTofu files...${NC}"
	@cd $(TOFU_DIR) && tofu validate
# 	@echo -e "${CYAN}Validating Proxmox files...${NC}"
# 	@cd $(PROXMOX_DIR) && tofu validate


.PHONY: clean
clean:
	@echo -e "${CYAN}Cleaning up temporary files...${NC}"
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} +
	@find . -name ".terraform.lock.hcl" -delete


.PHONY: proxmox-init
proxmox-init:
	@echo -e "${CYAN}Initializing OpenTofu for Proxmox...${NC}"
	@cd $(PROXMOX_DIR) && tofu init

.PHONY: proxmox-plan
proxmox-plan:
	@echo -e "${CYAN}Planning Proxmox VM changes...${NC}"
	@cd $(PROXMOX_DIR) && tofu plan -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}" -out=proxmox.tfplan

.PHONY: proxmox-apply
proxmox-apply:
	@echo -e "${CYAN}Applying Proxmox VM changes...${NC}"
	@cd $(PROXMOX_DIR) && tofu apply -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}" proxmox.tfplan

.PHONY: proxmox-import
proxmox-import:
	@echo -e "${CYAN}Importing existing Proxmox VMs...${NC}"
	@cd $(PROXMOX_DIR) && tofu import -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}"


.PHONY: k8s-init
k8s-init:
	@echo -e "${CYAN}Initializing Kubernetes clusters...${NC}"
	@cd $(PROXMOX_DIR) && ansible-playbook -i k8s.ini k8s.yml

.PHONY: setup-pxe
setup-pxe:
	@echo -e "${CYAN}Setting up PXE boot server...${NC}"
	@cd $(PROXMOX_DIR) && ansible-playbook -i inventory.ini boot-server.yml

.PHONY: docs
docs:
	@echo -e "${CYAN}Generating documentation for all modules...${NC}"
	@command -v terraform-docs >/dev/null 2>&1 || { echo -e "${RED}Error: terraform-docs is not installed. Please install it first.${NC}"; exit 1; }
	@for module in $$(find $(MODULES_DIR) -type d -maxdepth 1 -mindepth 1); do \
		echo -e "Generating docs for $${module}..."; \
		cd $${module} && terraform-docs markdown . > README.md; \
	done


install-sops:
	@echo "Installing SOPS..."
	@if ! command -v sops &> /dev/null; then \
		echo "Installing SOPS..."; \
		if [ "$(shell uname)" = "Darwin" ]; then \
			brew install sops; \
		else \
			wget -O /tmp/sops.deb https://github.com/mozilla/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb && \
			sudo dpkg -i /tmp/sops.deb && \
			rm /tmp/sops.deb; \
		fi; \
	else \
		echo "SOPS is already installed."; \
	fi


install-age:
	@echo "Installing age..."
	@if ! command -v age &> /dev/null; then \
		echo "Installing age..."; \
		if [ "$(shell uname)" = "Darwin" ]; then \
			brew install age; \
		else \
			wget -O /tmp/age.tar.gz https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz && \
			tar -xzf /tmp/age.tar.gz -C /tmp && \
			sudo mv /tmp/age/age /usr/local/bin/ && \
			sudo mv /tmp/age/age-keygen /usr/local/bin/ && \
			rm -rf /tmp/age /tmp/age.tar.gz; \
		fi; \
	else \
		echo "age is already installed."; \
	fi

install-crypto-tools: install-sops install-age
	@echo "Crypto tools installation and setup complete."


.PHONY: build-kubeconfig-tool
build-kubeconfig-tool:
	@echo -e "${CYAN}Building cicd-update-kubeconfig binary...${NC}"
	@cd cicd-update-kubeconfig && go build -o ../cicd-update-kubeconfig ./cmd/cicd-update-kubeconfig
	@chmod +x cicd-update-kubeconfig
	@echo -e "${GREEN}Binary built: cicd-update-kubeconfig${NC}"


.PHONY: update-kubeconfigs
update-kubeconfigs: build-kubeconfig-tool
	@echo -e "${CYAN}Updating Talos cluster kubeconfigs in Vault...${NC}"
	@export KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config}; \
	if [ -z "$(ENV)" ]; then \
		echo -e "${CYAN}Processing all environments with Talos clusters...${NC}"; \
		for env in $(ENVIRONMENTS); do \
			cd $(TOFU_DIR) && tofu workspace select $${env}; \
			CLUSTERS=$$(tofu output -json proxmox_cluster_names 2>/dev/null | jq -r '.[]' || echo ""); \
			if [ -n "$$CLUSTERS" ]; then \
				echo -e "${GREEN}Found Talos clusters in $${env}: $$CLUSTERS${NC}"; \
				for cluster in $$CLUSTERS; do \
					KUBECONFIG=$$KUBECONFIG ../cicd-update-kubeconfig \
						--cluster-name $$cluster \
						--namespace $$cluster \
						--vault-path kv/cluster-secret-store/secrets \
						--vault-addr $(VAULT_ADDR) \
						--management-context $${env}; \
				done; \
			fi; \
			cd ..; \
		done; \
	else \
		echo -e "${CYAN}Updating kubeconfigs for $(ENV) environment...${NC}"; \
		cd $(TOFU_DIR) && tofu workspace select $(ENV); \
		CLUSTERS=$$(tofu output -json proxmox_cluster_names | jq -r '.[]'); \
		for cluster in $$CLUSTERS; do \
			KUBECONFIG=$$KUBECONFIG ../cicd-update-kubeconfig \
				--cluster-name $$cluster \
				--namespace $$cluster \
				--vault-path kv/cluster-secret-store/secrets \
				--vault-addr $(VAULT_ADDR) \
				--management-context $(ENV); \
		done; \
	fi


.PHONY: test-kubeconfig-update
test-kubeconfig-update:
	@echo -e "${CYAN}Testing kubeconfig update (dry-run mode)...${NC}"
	@PYTHON_BIN=$$(if [ -f "python-venv/bin/python3" ]; then echo "$$(pwd)/python-venv/bin/python3"; else echo "python3"; fi); \
	cd $(TOFU_DIR) && $$PYTHON_BIN scripts/update_talos_kubeconfig.py \
		--cluster-name dev \
		--namespace dev \
		--vault-path kv/cluster-secret-store/secrets \
		--vault-addr $(VAULT_ADDR) \
		--management-context tools \
		--dry-run \
		--debug


.PHONY: ephemeral-init
ephemeral-init: install-crypto-tools
	@echo -e "${CYAN}Initializing OpenTofu for ephemeral clusters...${NC}"
	@cd $(EPHEMERAL_DIR) && tofu init -reconfigure -upgrade

.PHONY: ephemeral-plan
ephemeral-plan:
	@if [ -z "$(WORKSPACE)" ]; then \
		echo -e "${RED}ERROR: WORKSPACE is required. Example: make ephemeral-plan WORKSPACE=pr-cks-backend-1${NC}"; \
		exit 1; \
	fi
	@echo -e "${CYAN}Running load_secrets.py...${NC}" && cd $(EPHEMERAL_TOFU_DIR) && \
		if [ -f "../../python-venv/bin/activate" ]; then source ../../python-venv/bin/activate; fi && \
		python3 load_secrets.py --secrets-dir ../../secrets && cd ../..
	@echo -e "${CYAN}Planning ephemeral infrastructure for $(WORKSPACE)...${NC}"
	@cd $(EPHEMERAL_DIR) && \
		tofu workspace select -or-create $(WORKSPACE)&& \
		tofu plan $(EXTRA_ARGS) -out=$(WORKSPACE).tfplan

.PHONY: ephemeral-apply
ephemeral-apply:
	@if [ -z "$(WORKSPACE)" ]; then \
		echo -e "${RED}ERROR: WORKSPACE is required. Example: make ephemeral-apply WORKSPACE=pr-cks-backend-1${NC}"; \
		exit 1; \
	fi
	@echo -e "${CYAN}Running load_secrets.py...${NC}" && cd $(EPHEMERAL_TOFU_DIR) && \
		if [ -f "../../python-venv/bin/activate" ]; then source ../../python-venv/bin/activate; fi && \
		python3 load_secrets.py --secrets-dir ../../secrets && cd ../..
	@echo -e "${CYAN}Applying ephemeral infrastructure for $(WORKSPACE) (4 phases)...${NC}"
	@KUBECONFIG_PATH=$${KUBECONFIG:-~/.kube/config}; \
	cd $(EPHEMERAL_DIR) && \
		tofu workspace select -or-create $(WORKSPACE) && \
		echo -e "${GREEN}Phase 1: Base operators without CRDs...${NC}" && \
		echo 'workload = { "$(WORKSPACE)" = ["externaldns", "cert_manager", "external_secrets"] }' > /tmp/phase.tfvars && \
		echo 'config = { "$(WORKSPACE)" = { kubernetes_context = "$(WORKSPACE)", crds_installed = false, argocd_ingress_class = "traefik", argocd_domain = "$(WORKSPACE).argocd.fullstack.pw", prometheus_namespaces = [], prometheus_memory_limit = "1024Mi", prometheus_memory_request = "256Mi", prometheus_storage_size = "2Gi", postgres_cnpg = { enable_superuser_access = true, crds_installed = false, managed_roles = [{ name = "root", login = true, replication = true }], databases = [], persistence_size = "1Gi", ingress_host = "$(WORKSPACE).postgres.fullstack.pw", use_istio = false, export_credentials_secret_name = "$(WORKSPACE)-postgres-credentials" } } }' >> /tmp/phase.tfvars && \
		echo "kubeconfig_path = \"$$KUBECONFIG_PATH\"" >> /tmp/phase.tfvars && \
		tofu apply -var-file=/tmp/phase.tfvars -auto-approve && \
		echo -e "${GREEN}Phase 2: Base operators with CRDs...${NC}" && \
		echo 'workload = { "$(WORKSPACE)" = ["externaldns", "cert_manager", "external_secrets"] }' > /tmp/phase.tfvars && \
		echo 'config = { "$(WORKSPACE)" = { kubernetes_context = "$(WORKSPACE)", crds_installed = true, argocd_ingress_class = "traefik", argocd_domain = "$(WORKSPACE).argocd.fullstack.pw", prometheus_namespaces = [], prometheus_memory_limit = "1024Mi", prometheus_memory_request = "256Mi", prometheus_storage_size = "2Gi", postgres_cnpg = { enable_superuser_access = true, crds_installed = false, managed_roles = [{ name = "root", login = true, replication = true }], databases = [], persistence_size = "1Gi", ingress_host = "$(WORKSPACE).postgres.fullstack.pw", use_istio = false, export_credentials_secret_name = "$(WORKSPACE)-postgres-credentials" } } }' >> /tmp/phase.tfvars && \
		echo "kubeconfig_path = \"$$KUBECONFIG_PATH\"" >> /tmp/phase.tfvars && \
		tofu apply -var-file=/tmp/phase.tfvars -auto-approve && \
		echo -e "${GREEN}Phase 3: All apps without postgres CRDs...${NC}" && \
		echo 'workload = { "$(WORKSPACE)" = ["externaldns", "cert_manager", "external_secrets", "argocd", "cloudnative-pg-operator", "postgres-cnpg", "observability-box"] }' > /tmp/phase.tfvars && \
		echo 'config = { "$(WORKSPACE)" = { kubernetes_context = "$(WORKSPACE)", crds_installed = true, argocd_ingress_class = "traefik", argocd_domain = "$(WORKSPACE).argocd.fullstack.pw", prometheus_namespaces = [], prometheus_memory_limit = "1024Mi", prometheus_memory_request = "256Mi", prometheus_storage_size = "2Gi", postgres_cnpg = { enable_superuser_access = true, crds_installed = false, managed_roles = [{ name = "root", login = true, replication = true }], databases = [], persistence_size = "1Gi", ingress_host = "$(WORKSPACE).postgres.fullstack.pw", use_istio = false, export_credentials_secret_name = "$(WORKSPACE)-postgres-credentials" } } }' >> /tmp/phase.tfvars && \
		echo "kubeconfig_path = \"$$KUBECONFIG_PATH\"" >> /tmp/phase.tfvars && \
		tofu apply -var-file=/tmp/phase.tfvars -auto-approve && \
		echo -e "${GREEN}Phase 4: All apps with postgres CRDs...${NC}" && \
		echo 'workload = { "$(WORKSPACE)" = ["externaldns", "cert_manager", "external_secrets", "argocd", "cloudnative-pg-operator", "postgres-cnpg", "observability-box"] }' > /tmp/phase.tfvars && \
		echo 'config = { "$(WORKSPACE)" = { kubernetes_context = "$(WORKSPACE)", crds_installed = true, argocd_ingress_class = "traefik", argocd_domain = "$(WORKSPACE).argocd.fullstack.pw", prometheus_namespaces = [], prometheus_memory_limit = "1024Mi", prometheus_memory_request = "256Mi", prometheus_storage_size = "2Gi", postgres_cnpg = { enable_superuser_access = true, crds_installed = true, managed_roles = [{ name = "root", login = true, replication = true }], databases = [], persistence_size = "1Gi", ingress_host = "$(WORKSPACE).postgres.fullstack.pw", use_istio = false, export_credentials_secret_name = "$(WORKSPACE)-postgres-credentials" } } }' >> /tmp/phase.tfvars && \
		echo "kubeconfig_path = \"$$KUBECONFIG_PATH\"" >> /tmp/phase.tfvars && \
		tofu apply -var-file=/tmp/phase.tfvars -auto-approve && \
		rm -f /tmp/phase.tfvars

.PHONY: ephemeral-destroy
ephemeral-destroy:
	@if [ -z "$(WORKSPACE)" ]; then \
		echo -e "${RED}ERROR: WORKSPACE is required. Example: make ephemeral-destroy WORKSPACE=pr-cks-backend-1${NC}"; \
		exit 1; \
	fi
	@echo -e "${RED}WARNING: This will destroy ephemeral infrastructure for $(WORKSPACE)!${NC}"
	@echo -e "${RED}Type '$(WORKSPACE)' to confirm: ${NC}"
	@read confirmation; \
	if [ "$$confirmation" = "$(WORKSPACE)" ]; then \
		echo -e "${YELLOW}Destroying ephemeral infrastructure for $(WORKSPACE)...${NC}"; \
		cd $(EPHEMERAL_DIR) && \
			tofu workspace select $(WORKSPACE) && \
			tofu destroy -auto-approve && \
			tofu workspace select default && \
			tofu workspace delete $(WORKSPACE); \
	else \
		echo -e "${YELLOW}Destroy operation cancelled.${NC}"; \
	fi

.PHONY: ephemeral-workspace
ephemeral-workspace:
	@echo -e "${CYAN}Listing ephemeral OpenTofu workspaces...${NC}"
	@cd $(EPHEMERAL_DIR) && tofu workspace list