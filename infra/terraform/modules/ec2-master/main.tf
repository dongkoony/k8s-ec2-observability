# KMS 키 상태 검증을 위한 데이터 소스 추가
data "aws_kms_key" "validate_key" {
  count  = var.kms_key_id != "" ? 1 : 0
  key_id = var.kms_key_id
}

# KMS 키 준비 확인을 위한 null_resource
resource "null_resource" "wait_for_kms" {
  count = var.kms_key_id != "" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 KMS 키 상태 검증 중..."
      for i in {1..30}; do
        STATE=$(aws kms describe-key --key-id ${var.kms_key_id} --region ${var.aws_region} --query 'KeyMetadata.KeyState' --output text 2>/dev/null || echo "ERROR")
        echo "시도 $i/30: KMS 키 상태 = $STATE"
        if [ "$STATE" = "Enabled" ]; then
          echo "✅ KMS 키가 EC2 사용 준비 완료"
          sleep 10  # 추가 안정화 대기
          exit 0
        fi
        echo "⏳ KMS 키 준비 중... (10초 후 재시도)"
        sleep 10
      done
      echo "❌ KMS 키 준비 시간 초과"
      exit 1
    EOT
  }

  depends_on = [data.aws_kms_key.validate_key]
}

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

  # KMS 키가 완전히 준비된 후에 인스턴스 생성
  depends_on = [null_resource.wait_for_kms]
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