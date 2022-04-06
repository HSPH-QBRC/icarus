resource "aws_instance" "web" {
  # CentOS Stream 8 https://www.centos.org/download/aws-images/
  ami                         = "ami-045b0a05944af45c1"
  instance_type               = "t3.micro"
  monitoring                  = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_server.id]
  ebs_optimized               = true
  key_name                    = var.ssh_key_pair_name
  volume_tags                 = local.tags
  user_data_replace_on_change = true
  root_block_device {
    volume_type = "gp3"
  }
  provisioner "file" {
    source      = "../secrets/config.ini"
    destination = "${local.secrets_dir}/config.ini"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-encrypt-cert.pem"
    destination = "${local.secrets_dir}/sp-encrypt-cert.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-encrypt-key.pem"
    destination = "${local.secrets_dir}/sp-encrypt-key.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-signing-cert.pem"
    destination = "${local.secrets_dir}/sp-signing-cert.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-signing-key.pem"
    destination = "${local.secrets_dir}/sp-signing-key.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  user_data = <<-EOT
  #!/usr/bin/bash -ex

  # install Puppet and other dependencies
  /usr/bin/dnf -y install https://yum.puppet.com/puppet7-release-el-8.noarch.rpm
  /usr/bin/dnf -y install git puppet-agent ruby

  # configure Icarus
  export PROJECT_ROOT=/srv/icarus
  /usr/bin/mkdir $PROJECT_ROOT
  /usr/bin/chown centos:centos $PROJECT_ROOT
  /usr/bin/su -c "/usr/bin/git clone https://github.com/HSPH-QBRC/icarus.git $PROJECT_ROOT" centos
  /usr/bin/su -c "cd $PROJECT_ROOT && /usr/bin/git checkout -q ${var.git_commit}" centos

  # install librarian-puppet and Puppet modules
  /usr/bin/gem install librarian-puppet -v 3.0.1 --no-document
  # need to set $HOME: https://github.com/rodjek/librarian-puppet/issues/258
  export HOME=/root
  /usr/local/bin/librarian-puppet config path /opt/puppetlabs/puppet/modules --global
  /usr/local/bin/librarian-puppet config tmp /tmp --global
  PATH=/opt/puppetlabs/bin:$PATH
  cd $PROJECT_ROOT/webserver/deployment/puppet && /usr/local/bin/librarian-puppet install

  # run Puppet
  export FACTER_SITE_URL="${var.site_url}"
  export FACTER_SECRETS_DIR="${local.secrets_dir}"
  /opt/puppetlabs/bin/puppet apply $PROJECT_ROOT/webserver/deployment/puppet/manifests/site.pp
  EOT
}
