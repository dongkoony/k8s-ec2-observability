# k8s-observability-platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-623CE4?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Shell](https://img.shields.io/badge/Shell-121011?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Calico](https://img.shields.io/badge/Calico-FCB92B?style=flat&logo=projectcalico&logoColor=black)](https://www.projectcalico.org/)
[![Linkerd](https://img.shields.io/badge/Linkerd-24A3E0?style=flat&logo=linkerd&logoColor=white)](https://linkerd.io/)
[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat&logo=grafana&logoColor=white)](https://grafana.com/)
[![Jaeger](https://img.shields.io/badge/Jaeger-000000?style=flat&logo=jaeger-tracing&logoColor=white)](https://www.jaegertracing.io/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Makefile](https://img.shields.io/badge/Makefile-000000?style=flat&logo=make&logoColor=white)](https://www.gnu.org/software/make/)

Self-Managed Kubernetes 클러스터 위에 Linkerd 기반 서비스 메시와  
Prometheus/Grafana/Jaeger 관찰성 스택을 통합 구성하는 데모용 인프라·배포 플랫폼입니다.

---

## 🚀 빠른 시작

1. **레포지토리 클론**  
   ```bash
   git clone https://github.com/your-org/k8s-observability-platform.git
   cd k8s-observability-platform
    ```


2. **인프라 프로비저닝 (Dev 환경)**

   ```bash
   git checkout infra/dev
   make infra-apply
   ```

   * Terraform이 VPC, 보안 그룹, EC2(마스터·워커) 인스턴스를 생성합니다.
   * 완료되면 출력된 퍼블릭 IP로 각 EC2에 SSH 접속하세요.

3. **클러스터 부트스트랩**
   각 EC2 인스턴스에 접속하여:

   ```bash
   sudo bash scripts/common-bootstrap.sh
   # Master 노드에서
   sudo bash scripts/master-bootstrap.sh
   # Worker 노드에서 (각 워커마다)
   sudo bash scripts/worker-bootstrap.sh
   ```

4. **서비스 메시 & 관찰성 스택 배포**

   ```bash
   git checkout main
   make deploy-observability
   ```

   * Linkerd Control Plane, Viz(Prometheus/Grafana), Jaeger가 차례로 배포됩니다.
   * `linkerd viz dashboard` 로 대시보드를 확인하세요.

---

## 📁 저장소 구조

```text
k8s-observability-platform/
├── README.md                          # 프로젝트 개요·빠른 시작 가이드
├── LICENSE                            # MIT 라이선스
├── docs/
│   ├── architecture.md                # 아키텍처 다이어그램·컴포넌트 설명
│   └── requirements.md                # 시스템 요구사항·리소스 스펙
├── infra/
│   └── terraform/
│       ├── provider.tf                # AWS 프로바이더 설정 (ap-northeast-2)
│       ├── variables.tf               # 변수 정의 (인스턴스 타입·수량 등)
│       ├── outputs.tf                 # 출력값 정의 (퍼블릭 IP·SG 등)
│       ├── modules/
│       │   ├── ec2-master/            # 마스터용 모듈 (User Data로 kubeadm init)
│       │   └── ec2-worker/            # 워커용 모듈 (User Data로 kubeadm join)
│       └── terraform.tfvars.example   # 샘플 tfvars 파일
├── scripts/
│   ├── common-bootstrap.sh            # Docker·kubeadm 설치 공통 스크립트
│   ├── master-bootstrap.sh            # kubeadm init + Calico CNI 적용
│   └── worker-bootstrap.sh            # kubeadm join 스크립트
├── manifests/
│   ├── linkerd/
│   │   ├── install-control-plane.yml  # Linkerd Control Plane 설치
│   │   ├── install-viz.yml            # Linkerd Viz (Prometheus/Grafana)
│   │   └── install-jaeger.yml         # Jaeger Operator 연동
│   ├── observability/                 # Prometheus·Grafana·Jaeger 커스터마이징
│   └── applications/
│       ├── emojivoto.yml              # 샘플 앱 배포 (네임스페이스 레이블링)
│       └── traffic-split.yml          # SMI TrafficSplit 예시
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml         # PR 시 자동 `terraform plan`
│       ├── terraform-apply.yml        # main merge 시 `terraform apply`
│       └── deploy-observability.yml   # 매니페스트 자동 배포 워크플로우
└── Makefile                           # `make infra-apply`, `make deploy-observability` 등
```

---

## 🔧 요구사항

* AWS 계정 (ap-northeast-2 권장)
* Terraform ≥ v1.3.0
* EC2 인스턴스 최소 사양: t3.medium (2 vCPU, 4 GB RAM)
* SSH 키 페어 및 보안 그룹 설정

---

## ⚙️ 워크플로우

1. **인프라 변경** (`infra/dev` → `infra/stage` → `infra/prod`)
2. **매니페스트 개발** (`feature/*` 브랜치 → `main` 머지 시 자동 배포)
3. **모니터링 및 검증**

   * Linkerd Viz Dashboard
   * Grafana 대시보드
   * Jaeger Tracing UI

---

## 🤝 Contributing

1. Fork & Clone
2. `feature/<기능>` 브랜치 생성
3. 코드·문서 수정 → 커밋 → PR
4. 리뷰 후 머지

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
