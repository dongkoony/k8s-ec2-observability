locals {
  common_tags = merge(var.default_tags, {
    Name        = var.project_name
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
  })

  k8s_sg_ingress = [
    { from_port=22,   to_port=22,   protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="SSH" },
    { from_port=6443, to_port=6443, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="K8s API" },
    { from_port=2376, to_port=2376, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="Docker daemon" },
    { from_port=8080, to_port=8080, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="HTTP" },
    { from_port=30080, to_port=30080, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="Bookinfo App" },
    { from_port=30300, to_port=30300, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="Grafana Dashboard" },
    { from_port=179,  to_port=179,  protocol="tcp", self=true,                 description="Calico BGP" },
    { from_port=0,    to_port=65535,protocol="tcp", self=true,                 description="Internal K8s TCP" },
    { from_port=0,    to_port=65535,protocol="udp", self=true,                 description="Internal K8s UDP" },
    { from_port=0,    to_port=0,    protocol="-1",  self=true,                 description="Internal ALL" }
  ]
} 