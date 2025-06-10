resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.ssh_key_name != null ? var.ssh_key_name : null

  vpc_security_group_ids = [aws_security_group.worker.id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = var.kms_key_id != "" ? true : false
    kms_key_id  = var.kms_key_id != "" ? var.kms_key_id : null
  }

  user_data = base64encode(templatefile("${path.module}/templates/worker_user_data.sh", {
    master_private_ip = var.master_private_ip
    node_index        = count.index + 1
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "worker"
  })
}

resource "aws_security_group" "worker" {
  name        = "${var.project_name}-worker"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.master_security_group_id]
    description     = "All traffic from master node"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-worker-sg"
  })
} 