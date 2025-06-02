## Kubernetes Installation Script (combined_settings.sh)
[![EN](https://img.shields.io/badge/lang-en-blue.svg)](README-en.md) 
[![KR](https://img.shields.io/badge/lang-kr-red.svg)](README.md)

This script automates the installation and configuration of Kubernetes v1.31 and Calico CNI v3.28.0 on AWS EC2 instances.

### Key Components

#### 1. Environment Variables
```bash
# Kubernetes version: v1.31.0
# Calico CNI version: v3.28.0
# Pod CIDR: 10.244.0.0/16
# Service CIDR: 10.96.0.0/12
```

#### 2. System Requirements
- Minimum CPU cores: 2
- Minimum Memory: 2GB
- Required ports: 6443, 10250, 10251, 10252, 2379, 2380

### Main Features

#### 1. Network Configuration
- Kernel module setup (overlay, br_netfilter)
- System network parameter configuration
- Automatic Calico CNI installation and setup

#### 2. Container Runtime Installation
- Docker installation and configuration
- Containerd optimization
- SystemdCgroup activation

#### 3. Kubernetes Installation
- Installation of kubelet, kubeadm, kubectl
- Version pinning for stability
- Automatic version management

#### 4. Master Node Configuration
- Cluster initialization via kubeadm
- API server endpoint configuration
- Automatic kubeconfig setup

#### 5. CNI Configuration
- Automatic Calico CNI installation
- Network policy setup
- Pod network configuration

### Usage Instructions (Manual Installation)

1. **Set Script Execution Permissions**
```bash
chmod +x combined_settings.sh
```

2. **Master Node Installation**
```bash
export NODE_ROLE=master
sudo -E ./combined_settings.sh
```

3. **Worker Node Installation**
```bash
export NODE_ROLE=worker
export MASTER_PRIVATE_IP=<master_node_IP>
sudo -E ./combined_settings.sh
```

### Feature Details

#### Automatic Validation and Error Handling
- Automatic system requirements validation
- Automatic rollback on installation errors
- Detailed logging (/home/ubuntu/combined_settings.log)

#### CNI Installation and Verification
- Automatic Calico Operator installation
- CNI component status monitoring
- Automatic network policy configuration

#### Cluster Join Automation
- Automatic join token generation
- Worker node join automation
- Security settings configuration

### Precautions
1. Verify AWS EC2 instance requirements before script execution
2. Complete master node installation before worker node setup
3. Verify required ports are open in security groups
4. Ensure sufficient disk space (minimum 20GB recommended)

### Troubleshooting
- Check log file: `/home/ubuntu/combined_settings.log`
- Verify CNI status: `kubectl get pods -n calico-system`
- Check node status: `kubectl get nodes`

This script is designed to run automatically through Terraform but can also be executed manually.