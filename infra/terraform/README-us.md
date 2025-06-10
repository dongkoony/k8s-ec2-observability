# AWS Credentials Setup Guide

[![English](https://img.shields.io/badge/Language-English-blue.svg?style=flat-square)](README-us.md)
[![한국어](https://img.shields.io/badge/Language-한국어-red.svg?style=flat-square)](README-kr.md)

[![Terraform](https://img.shields.io/badge/Terraform-v1.5.0+-623CE4?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/)
[![IAM](https://img.shields.io/badge/AWS-IAM-yellow?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/iam/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

## IAM Configuration Diagram
```mermaid
graph TD
    A[AWS Root Account] -->|Create IAM User| B[terraform-developer]
    A -->|Create IAM Role| C[Terraform-Execution-Role]
    
    subgraph "User Permission Setup"
        B -->|Add Inline Policy| D[TerraformDeveloper-AssumeRolePolicy]
        D -->|Permissions| E["sts:AssumeRole</br>iam:GetRole"]
    end
    
    subgraph "Role Permission Setup"
        C -->|Attach Managed Policy| F[AmazonDynamoDBFullAccess_v2]
        C -->|Trust Relationship| G["Principal Config</br>(Root + terraform-developer)"]
    end
    
    subgraph "Credential Usage"
        B -->|AssumeRole| C
        C -->|Issue Temporary Credentials| H[Execute Terraform Tasks]
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#bfb,stroke:#333,stroke-width:2px
    style H fill:#feb,stroke:#333,stroke-width:2px
```

## Credential Setup Process
1. Start with AWS Root Account
2. Create terraform-developer IAM User
3. Create Terraform-Execution-Role IAM Role
4. Grant Role assumption policy to User
5. Attach required permission policies to Role
6. Configure trust relationship for Role assumption
7. Execute Terraform tasks using temporary credentials 