# KMS 키 검증 로직 제거 - 종속성 문제 해결

# EC2 마스터 인스턴스 (종속성 문제 해결)
resource "aws_instance" "master" {
  ami                     = var.ami_id
  instance_type           = var.instance_type
  subnet_id               = var.subnet_id
  vpc_security_group_ids  = [var.security_group_id]
  key_name                = var.ssh_key_name
  disable_api_termination = false

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_id

    tags = merge(var.tags, {
      Name = "${var.project_name}-master-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-master"
    Role = "master"
  })

  # 간단한 User Data - 시스템 기본 설정만
  user_data = base64encode(file("${path.root}/../../scripts/system_settings.sh"))

  # 시스템 설정 완료 대기
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
      port        = 22
      timeout     = "5m"
    }

    inline = [
      "while [ ! -f /home/ubuntu/.system_settings_complete ]; do sleep 10; done",
      "echo '시스템 설정 완료'"
    ]
  }

  # Kubernetes 설치 스크립트 복사
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
      port        = 22
    }

    source      = "${path.root}/../../scripts/combined_settings.sh"
    destination = "/home/ubuntu/combined_settings.sh"
  }

  # Kubernetes 마스터 설정 실행
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
      port        = 22
    }

    inline = [
      "chmod +x /home/ubuntu/combined_settings.sh",
      "export NODE_ROLE=master",
      "sudo -E /home/ubuntu/combined_settings.sh",
      "echo 'Kubernetes setup completed'"
    ]
  }
}