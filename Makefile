# Makefile for fullstack.pw infrastructure management
# This Makefile provides commands to manage infrastructure across multiple environments

# Default shell for make
SHELL := /bin/bash

# Configuration
ENVIRONMENTS := dev stg prod sandbox tools
DEFAULT_ENV := sandbox
TERRAFORM_DIR := clusters
PROXMOX_DIR := proxmox
MODULES_DIR := modules

# Colors for pretty output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Help message
define HELP_MESSAGE
Fullstack.pw Infrastructure Management Commands:

Terraform Environment Commands:
  make plan                     - Plan changes for all environments
  make plan ENV=<environment>   - Plan changes for a specific environment
  make apply                    - Apply changes for all environments
  make apply ENV=<environment>  - Apply changes for a specific environment
  make destroy ENV=<environment>- Destroy resources in a specific environment (requires confirmation)

Proxmox VM Management:
  make proxmox-init             - Initialize Terraform for Proxmox
  make proxmox-plan             - Plan Proxmox VM changes
  make proxmox-apply            - Apply Proxmox VM changes
  make proxmox-import           - Import existing Proxmox VMs to Terraform state

Kubernetes Management:
  make k8s-init                 - Initialize all Kubernetes clusters with k3s
  make setup-pxe                - Set up PXE boot server for k8s nodes

Environment Management:
  make init                     - Initialize Terraform for all environments
  make fmt                      - Format Terraform files
  make validate                 - Validate Terraform files
  make workspace                - List all Terraform workspaces
  make create-workspace ENV=<env> - Create a new Terraform workspace

Module Management:
  make module-test MODULE=<name> - Test a specific Terraform module

Utilities:
  make clean                    - Clean up temporary files
  make help                     - Show this help message

Examples:
  make plan ENV=dev             - Plan changes for dev environment
  make apply ENV=sandbox        - Apply changes to sandbox environment
  make proxmox-apply            - Apply changes to Proxmox VMs
endef
export HELP_MESSAGE

# Default target
.PHONY: help
help:
	@echo -e "$$HELP_MESSAGE"

# Initialize Terraform for clusters
.PHONY: init
init:
	@echo -e "${CYAN}Initializing Terraform for all environments...${NC}"
	@cd $(TERRAFORM_DIR) && terraform init

# Create a new workspace
.PHONY: create-workspace
create-workspace:
	@if [ -z "$(ENV)" ]; then \
		echo -e "${RED}ERROR: ENV is required. Example: make create-workspace ENV=dev${NC}"; \
		exit 1; \
	fi
	@echo -e "${CYAN}Creating workspace for $(ENV)...${NC}"
	@cd $(TERRAFORM_DIR) && terraform workspace new $(ENV)

# List workspaces
.PHONY: workspace
workspace:
	@echo -e "${CYAN}Listing Terraform workspaces...${NC}"
	@cd $(TERRAFORM_DIR) && terraform workspace list

# Plan changes for all environments or a specific one
.PHONY: plan
plan:
	@if [ -z "$(ENV)" ]; then \
		echo -e "${CYAN}Planning changes for all environments...${NC}"; \
		for env in $(ENVIRONMENTS); do \
			echo -e "\n#########################################################" | tee -a plan.txt; \
			echo -e "##\n##   Planning changes for $${env} environment..." | tee -a plan.txt; \
			echo -e "##\n#########################################################" | tee -a plan.txt; \
			cd $(TERRAFORM_DIR) && terraform workspace select $${env} && terraform plan -no-color -out=$${env}.tfplan && terraform show -no-color $${env}.tfplan >> plan.txt && cd ..; \
		done; \
	else \
		echo -e "${CYAN}Planning changes for $(ENV) environment...${NC}"; \
		cd $(TERRAFORM_DIR) && terraform workspace select $(ENV) && terraform plan -no-color -out=$(ENV).tfplan && terraform show -no-color $(ENV).tfplan >> plan.txt; \
	fi

# Apply changes for all environments or a specific one
.PHONY: apply
apply:
	@if [ -z "$(ENV)" ]; then \
		echo -e "${YELLOW}Are you sure you want to apply changes to ALL environments? [y/N] ${NC}"; \
		read answer; \
		if [ "$${answer}" = "y" ] || [ "$${answer}" = "Y" ]; then \
			for env in $(ENVIRONMENTS); do \
				echo -e "\n#########################################################" | tee -a plan.txt; \
				echo -e "##\n## Applying changes to $${env} environment..." | tee -a plan.txt; \
				echo -e "##\n#########################################################" | tee -a plan.txt; \
				cd $(TERRAFORM_DIR) && terraform workspace select $${env} || terraform workspace new $${env}; \
				if [ -f "$${env}.tfplan" ]; then \
					terraform apply $${env}.tfplan && cd ..; \
				else \
					terraform apply -auto-approve && cd ..; \
				fi; \
			done; \
		else \
			echo -e "${YELLOW}Operation cancelled.${NC}"; \
		fi; \
	else \
		echo -e "${CYAN}Applying changes to $(ENV) environment...${NC}"; \
		cd $(TERRAFORM_DIR) && terraform workspace select $(ENV); \
		if [ -f "$(ENV).tfplan" ]; then \
			terraform apply $(ENV).tfplan; \
		else \
			terraform apply -var="vault_token=${VAULT_TOKEN}"; \
		fi; \
	fi

# Destroy resources in a specific environment
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
		cd $(TERRAFORM_DIR) && terraform workspace select $(ENV) && terraform destroy -var="vault_token=${VAULT_TOKEN}"; \
	else \
		echo -e "${YELLOW}Destroy operation cancelled.${NC}"; \
	fi

# Format Terraform files
.PHONY: fmt
fmt:
	@echo -e "${CYAN}Formatting Terraform files...${NC}"
	@terraform fmt -recursive

# Validate Terraform configuration
.PHONY: validate
validate:
	@echo -e "${CYAN}Validating Terraform files...${NC}"
	@cd $(TERRAFORM_DIR) && terraform validate
	@echo -e "${CYAN}Validating Proxmox files...${NC}"
	@cd $(PROXMOX_DIR) && terraform validate

# Clean up temporary files
.PHONY: clean
clean:
	@echo -e "${CYAN}Cleaning up temporary files...${NC}"
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} +
	@find . -name ".terraform.lock.hcl" -delete

# Proxmox VM management
.PHONY: proxmox-init
proxmox-init:
	@echo -e "${CYAN}Initializing Terraform for Proxmox...${NC}"
	@cd $(PROXMOX_DIR) && terraform init

.PHONY: proxmox-plan
proxmox-plan:
	@echo -e "${CYAN}Planning Proxmox VM changes...${NC}"
	@cd $(PROXMOX_DIR) && terraform plan -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}" -out=proxmox.tfplan

.PHONY: proxmox-apply
proxmox-apply:
	@echo -e "${CYAN}Applying Proxmox VM changes...${NC}"
	@cd $(PROXMOX_DIR) && terraform apply -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}" proxmox.tfplan

.PHONY: proxmox-import
proxmox-import:
	@echo -e "${CYAN}Importing existing Proxmox VMs...${NC}"
	@cd $(PROXMOX_DIR) && terraform import -var="PROXMOX_PASSWORD=${PROXMOX_PASSWORD}"

# Kubernetes management
.PHONY: k8s-init
k8s-init:
	@echo -e "${CYAN}Initializing Kubernetes clusters...${NC}"
	@cd $(PROXMOX_DIR) && ansible-playbook -i k8s.ini k8s.yml

.PHONY: setup-pxe
setup-pxe:
	@echo -e "${CYAN}Setting up PXE boot server...${NC}"
	@cd $(PROXMOX_DIR) && ansible-playbook -i inventory.ini boot-server.yml

# Test a specific module
.PHONY: module-test
module-test:
	@if [ -z "$(MODULE)" ]; then \
		echo -e "${RED}ERROR: MODULE is required. Example: make module-test MODULE=externaldns${NC}"; \
		exit 1; \
	fi
	@echo -e "${CYAN}Testing module $(MODULE)...${NC}"
	@cd $(MODULES_DIR)/$(MODULE) && terraform init && terraform validate

# Generate documentation for all modules
.PHONY: docs
docs:
	@echo -e "${CYAN}Generating documentation for all modules...${NC}"
	@command -v terraform-docs >/dev/null 2>&1 || { echo -e "${RED}Error: terraform-docs is not installed. Please install it first.${NC}"; exit 1; }
	@for module in $$(find $(MODULES_DIR) -type d -maxdepth 1 -mindepth 1); do \
		echo -e "Generating docs for $${module}..."; \
		cd $${module} && terraform-docs markdown . > README.md; \
	done
