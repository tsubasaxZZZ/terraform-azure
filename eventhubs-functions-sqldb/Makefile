
.PHONY: plan
plan:
	terraform plan -out tfplan -var-file terraform.tfvars

.PHONY: apply
apply:
	terraform apply "tfplan"

.PHONY: all
all: plan apply