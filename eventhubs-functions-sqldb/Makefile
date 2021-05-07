
.PHONY: plan
plan:
	terraform plan -out tfplan -var-file terraform.tfvars

.PHONY: apply
apply:
	terraform apply "tfplan"

.PHONY: destroy
destroy:
	terraform destroy -var-file terraform.tfvars

.PHONY: all
all: plan apply
