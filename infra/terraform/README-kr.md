# AWS 자격 증명 설정 가이드

[![English](https://img.shields.io/badge/Language-English-blue.svg?style=flat-square)](README-us.md)
[![한국어](https://img.shields.io/badge/Language-한국어-red.svg?style=flat-square)](README-kr.md)

[![Terraform](https://img.shields.io/badge/Terraform-v1.5.0+-623CE4?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/)
[![IAM](https://img.shields.io/badge/AWS-IAM-yellow?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/iam/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

## IAM 구성 다이어그램
```mermaid
graph TD
    A[AWS Root 계정] -->|IAM 사용자 생성| B[terraform-developer]
    A -->|IAM Role 생성| C[Terraform-Execution-Role]
    
    subgraph "사용자 권한 설정"
        B -->|인라인 정책 추가| D[TerraformDeveloper-AssumeRolePolicy]
        D -->|권한| E["sts:AssumeRole</br>iam:GetRole"]
    end
    
    subgraph "Role 권한 설정"
        C -->|관리형 정책 연결| F[AmazonDynamoDBFullAccess_v2]
        C -->|신뢰 관계 설정| G["Principal 설정</br>(Root + terraform-developer)"]
    end
    
    subgraph "자격 증명 사용"
        B -->|AssumeRole| C
        C -->|임시 자격 증명 발급| H[Terraform 작업 수행]
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#bfb,stroke:#333,stroke-width:2px
    style H fill:#feb,stroke:#333,stroke-width:2px
```

## 자격 증명 설정 프로세스
1. AWS Root 계정에서 시작
2. terraform-developer IAM 사용자 생성
3. Terraform-Execution-Role IAM Role 생성
4. 사용자에게 Role 수임을 위한 정책 부여
5. Role에 필요한 권한 정책 연결
6. 신뢰 관계를 통한 Role 수임 권한 설정
7. 임시 자격 증명을 사용한 Terraform 작업 수행 