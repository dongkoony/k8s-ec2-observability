# KMS 키 검증 로직 제거 - 종속성 문제 해결

# EC2 워커 인스턴스 (종속성 문제 해결)
resource "aws_instance" "worker" {
  count                   = var.worker_count
  ami                     = var.ami_id
  instance_type           = var.instance_type
  subnet_id               = var.subnet_id
  vpc_security_group_ids  = [aws_security_group.worker.id]
  key_name                = var.ssh_key_name
  disable_api_termination = false

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = var.kms_key_id != null && var.kms_key_id != "" ? true : false
    kms_key_id  = var.kms_key_id != null && var.kms_key_id != "" ? var.kms_key_id : null

    tags = merge(var.tags, {
      Name = "${var.project_name}-worker-${count.index + 1}-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "worker-node${count.index + 1}"
  })

  user_data = base64encode(file("${path.root}/../../scripts/system_settings.sh"))

  # 시스템 설정 완료 대기
  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      port                = 22
      bastion_host        = var.master_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
      bastion_port        = 22
      timeout             = "5m"
    }

    inline = [
      "sudo mkdir -p /home/ubuntu/.ssh",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh",
      "sudo chmod 700 /home/ubuntu/.ssh",
      "while [ ! -f /home/ubuntu/.system_settings_complete ]; do sleep 10; done",
      "echo '시스템 설정 완료'"
    ]
  }

  # SSH 키 복사
  provisioner "file" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      port                = 22
      bastion_host        = var.master_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
      bastion_port        = 22
    }

    source      = var.private_key_path
    destination = "/home/ubuntu/.ssh/k8s-key.pem"
  }

  # combined_settings.sh 스크립트 복사
  provisioner "file" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      port                = 22
      bastion_host        = var.master_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
      bastion_port        = 22
    }

    source      = "${path.root}/../../scripts/combined_settings.sh"
    destination = "/home/ubuntu/combined_settings.sh"
  }

  # worker_setup.sh 스크립트 복사
  provisioner "file" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      port                = 22
      bastion_host        = var.master_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
      bastion_port        = 22
    }

    source      = "${path.root}/../../scripts/worker_setup.sh"
    destination = "/home/ubuntu/worker_setup.sh"
  }

  # 워커 노드 설정 실행
  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      port                = 22
      bastion_host        = var.master_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
      bastion_port        = 22
    }

    inline = [
      "chmod +x /home/ubuntu/worker_setup.sh",
      "/home/ubuntu/worker_setup.sh '${var.master_private_ip}' '${count.index + 1}'"
    ]
  }

  depends_on = [var.master_instance]
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

  # 내부 통신을 위한 모든 트래픽 허용
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Internal communication"
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
