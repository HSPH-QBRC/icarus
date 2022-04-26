## Vagrant

Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads)

### Set up a Vagrant VM
```shell
cd webserver
vagrant up
```
Open http://localhost:8080/ in a web browser

## AWS

Install [AWS CLI](https://aws.amazon.com/cli/) and [Terraform CLI](https://www.terraform.io/downloads)

### Configure AWS CLI
```shell
aws configure --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

### Download secrets
```shell
mkdir webserver/deployment/secrets
aws s3 cp s3://icarus-terraform/keys webserver/deployment/secrets --recursive 
```

### Configure Terraform CLI
Note that workspace name will be used for naming resources
```shell
cd webserver/deployment/terraform
terraform init
terraform workspace new dev
terraform apply
```
Open https://covid.ivyplus.net/ in a web browser

### Miscellaneous
SSH into the web server instance:
```shell
ssh -i webserver/deployment/secrets/icarus-admin.pem centos@<web_instance_ip>
```

### Initial setup
Only required once to boostrap
```shell
aws s3 mb s3://icarus-terraform --region us-east-2
aws s3api put-bucket-tagging --bucket icarus-terraform --tagging 'TagSet=[{Key=Project,Value=Icarus}]'
```
Generate or retrieve the secrets from backup and copy to `s3://icarus-terraform/keys`
