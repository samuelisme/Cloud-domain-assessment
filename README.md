# Cloud-domain-assessment

terraform init
terraform plan  -no-color -var-file=aws.tfvars > tfplan.txt
terraform apply -var-file=aws.tfvars -auto-approve
