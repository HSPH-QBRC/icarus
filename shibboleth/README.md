## Prerequisites
Install [AWS CLI](https://aws.amazon.com/cli/) and [Terraform CLI](https://www.terraform.io/downloads)

Configure AWS CLI
```shell
aws configure --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

Configure Terraform CLI
```shell
aws s3 mb s3://icarus-terraform --region us-east-2
aws s3api put-bucket-tagging --bucket icarus-terraform --tagging 'TagSet=[{Key=Project,Value=Icarus}]'

terraform init

terraform workspace new dev
```
