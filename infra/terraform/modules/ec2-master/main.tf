resource "aws_instance" "master" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.ssh_key_name != null ? var.ssh_key_name : null

  vpc_security_group_ids = [aws_security_group.master.id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = var.kms_key_id != "" ? true : false
    kms_key_id  = var.kms_key_id != "" ? var.kms_key_id : null
  }

  user_data = base64encode(templatefile("${path.module}/templates/master_user_data.sh", {
    node_role = "master"
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-master"
    Role = "master"
  })
}

resource "aws_security_group" "master" {
  name        = "${var.project_name}-master"
  description = "Security group for Kubernetes master node"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API server"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-master-sg"
  })
} 