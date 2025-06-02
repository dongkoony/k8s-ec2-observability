resource "aws_security_group" "k8s_sg" {
  name        = "${var.project_name}-security-group"
  vpc_id      = var.vpc_id
  description = "Security group for Kubernetes master and nodes"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", null)
      self            = lookup(ingress.value, "self", null)
      security_groups = lookup(ingress.value, "security_groups", null)
      description     = lookup(ingress.value, "description", null)
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = egress.value.protocol
      cidr_blocks     = lookup(egress.value, "cidr_blocks", null)
      self            = lookup(egress.value, "self", null)
      security_groups = lookup(egress.value, "security_groups", null)
      description     = lookup(egress.value, "description", null)
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg"
  })
} 