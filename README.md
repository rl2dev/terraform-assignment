# Terraform Assignment — Multi-VPC ECS Architecture

This project provisions a **multi-VPC AWS architecture** with an **Internet VPC** and a **Workload VPC** connected via **Transit Gateway**. Traffic from the internet reaches an **internet-facing ALB**, is routed through the TGW to an internal **Network Load Balancer (NLB)**, then to an internal **Application Load Balancer (ALB)** that fronts **ECS Fargate** tasks running an echoserver container.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Data Flow](#data-flow)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Modules](#modules)
- [Usage](#usage)
- [Outputs](#outputs)
- [Customization](#customization)
- [Cleanup](#cleanup)

---

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                     INTERNET VPC (10.0.0.0/16)               │
                    │  ┌─────────────┐     ┌─────────────────────────────────────┐ │
  Internet          │  │  Gateway    │     │  Public Subnets (gateway-a/b)       │ │
      │             │  │  ALB        │     │  • NAT GW (single)                  │ │
      ▼             │  │  (public)   │     └─────────────────────────────────────┘ │
                    │  └──────┬──────┘                    │                        │
                    │         │                            │                        │
                    │         │  Target: NLB ENI IPs       │  TGW attachment       │
                    │         │  (cross-VPC via TGW)       │  (internet-tgw-subnet)│
                    │         ▼                            ▼                        │
                    │  ┌─────────────────────────────────────────────────────────┐ │
                    │  │         Transit Gateway (TGW)                           │ │
                    └──┼─────────────────────────────────────────────────────────┼─┘
                       │                                                         │
                    ┌──┼─────────────────────────────────────────────────────────┼─┐
                    │  │              WORKLOAD VPC (10.1.0.0/16)                 │  │
                    │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │  │
                    │  │  │  Web NLB    │  │  Web ALB    │  │  ECS Fargate     │  │  │
                    │  │  │  (internal) │──│  (internal) │──│  echoserver      │  │  │
                    │  │  └─────────────┘  └─────────────┘  └─────────────────┘  │  │
                    │  │  workload-web   workload-web      workload-app-a/b      │  │
                    │  │  subnet-a/b     subnet-a/b        (private)              │  │
                    │  │                                                          │  │
                    │  │  TGW attachment: workload-tgw-subnet                     │  │
                    └──┴──────────────────────────────────────────────────────────┘
```

- **Region:** `ap-southeast-1` (Singapore)
- **Internet VPC:** Public gateways, NAT, and an internet-facing ALB that targets the Workload NLB’s ENI IPs (cross-VPC via TGW).
- **Workload VPC:** Private subnets only (no NAT). Internal NLB → ALB → ECS Fargate (echoserver on port 8080).

---

## Data Flow

1. **Internet** → **Gateway ALB** (Internet VPC, public subnets) on HTTP/80 (and HTTPS/443 allowed by SG).
2. **Gateway ALB** target group uses **IP targets**: the private IPs of the **Workload NLB’s ENIs** in the workload VPC. Traffic reaches those IPs via **Transit Gateway** (Internet VPC → TGW → Workload VPC).
3. **Workload NLB** (internal, TCP 80) forwards to its target group, which has the **Workload ALB** as target (ALB as NLB target).
4. **Workload ALB** (internal, HTTP 80) forwards to its target group, where **ECS Fargate** tasks (echoserver on 8080) are registered.
5. **ECS** runs the echoserver container; ALB performs path/health checks and load balancing.

---

## Prerequisites

- **Terraform** ≥ 1.3
- **AWS CLI** configured with credentials for the target account/region
- **AWS Provider** ~> 5.0 (defined in `terraform.tf`)

---

## Project Structure

```
.
├── main.tf              # Root module: VPCs, TGW, NLB, ALBs, ECS
├── terraform.tf         # Provider and version constraints
├── outputs.tf           # Root outputs (ALB/NLB DNS names)
├── README.md            # This file
└── modules/
    ├── transit_gateway/ # TGW, attachments, route tables, VPC routes
    ├── web_nlb/         # Internal NLB (targets Workload ALB)
    ├── web_alb/         # Internal ALB (targets ECS), attached to NLB TG
    ├── gateway_alb/     # Internet-facing ALB (targets NLB ENI IPs)
    └── ecs/             # ECS cluster, Fargate service, echoserver task
```

---

## Modules

### 1. `transit_gateway` (`./modules/transit_gateway`)

Connects the Internet VPC and Workload VPC via a single Transit Gateway.

| Responsibility | Details |
|----------------|--------|
| **Transit Gateway** | One TGW with a custom route table. |
| **Attachments** | Internet VPC (private subnet) and Workload VPC (workload-tgw subnet). |
| **Routing** | TGW: default (0.0.0.0/0) → Internet VPC attachment; Workload VPC CIDR → Workload VPC attachment. |
| **VPC routes** | Internet VPC public route tables: route to Workload VPC CIDR via TGW. Workload VPC private route tables: default route (0.0.0.0/0) via TGW. |

**Inputs**

| Name | Description |
|------|-------------|
| `internet_vpc_id` | Internet VPC ID. |
| `internet_vpc_private_subnet_ids` | Private subnet IDs in Internet VPC for TGW attachment. |
| `internet_vpc_public_route_table_ids` | Public route table IDs (for route to workload). |
| `workload_vpc_id` | Workload VPC ID. |
| `workload_vpc_cidr` | Workload VPC CIDR. |
| `workload_vpc_private_subnet_ids` | Private subnet IDs in Workload VPC for TGW. |
| `workload_vpc_private_route_table_ids` | Private route table IDs (for default route via TGW). |
| `tgw_description` | (Optional) TGW description. |

**Outputs:** `transit_gateway_id`, `transit_gateway_arn`, `internet_vpc_attachment_id`, `workload_vpc_attachment_id`.

---

### 2. `web_nlb` (`./modules/web_nlb`)

Internal **Network Load Balancer** in the Workload VPC. Listens on TCP 80 and forwards to a target group whose target is the **Workload ALB**.

| Responsibility | Details |
|----------------|--------|
| **NLB** | Internal, network type, in first two private subnets. |
| **Target group** | `target_type = "alb"`, health check HTTP `/`, matcher 200–399. |
| **Listener** | TCP 80 → target group. |

**Inputs**

| Name | Description |
|------|-------------|
| `vpc_id` | Workload VPC ID. |
| `private_subnet_ids` | Private subnet IDs (first two used). |
| `nlb_name` | (Optional) NLB name. |

**Outputs:** `nlb_id`, `nlb_arn`, `nlb_name`, `nlb_tg_arn`, `nlb_dns_name`.

---

### 3. `web_alb` (`./modules/web_alb`)

Internal **Application Load Balancer** in the Workload VPC. Receives traffic from the NLB and forwards to ECS tasks.

| Responsibility | Details |
|----------------|--------|
| **ALB** | Internal, in first two private subnets, with a security group allowing 10.0.0.0/8 on port 80 (for TGW/origin). |
| **Target group** | IP targets, port 8080, HTTP health check `/` on 8080, matcher 200. |
| **Listener** | HTTP 80 → ECS target group. |
| **NLB → ALB** | Registers this ALB with the NLB target group (so NLB forwards to ALB). |

**Inputs**

| Name | Description |
|------|-------------|
| `vpc_id` | Workload VPC ID. |
| `private_subnet_ids` | Private subnet IDs (first two used). |
| `nlb_tg_arn` | NLB target group ARN (this ALB is attached to it). |
| `alb_name` | (Optional) ALB name. |
| `target_group_name` | (Optional) ALB target group name. |

**Outputs:** `alb_id`, `alb_arn`, `alb_target_group_arn`, `alb_security_group_id`, `alb_dns_name`.

---

### 4. `gateway_alb` (`./modules/gateway_alb`)

**Internet-facing** Application Load Balancer in the Internet VPC. Targets the Workload NLB by registering the **NLB’s ENI private IPs** as IP targets (cross-VPC via TGW).

| Responsibility | Details |
|----------------|--------|
| **ALB** | Public, in Internet VPC public subnets. SG: ingress 80/443 from 0.0.0.0/0. |
| **Target group** | IP type; targets = NLB ENI private IPs in workload web subnets (resolved via data sources). |
| **Listener** | HTTP 80 → that target group. |

**Inputs**

| Name | Description |
|------|-------------|
| `internet_vpc_id` | Internet VPC ID. |
| `internet_public_subnet_ids` | Public subnet IDs for the ALB. |
| `workload_vpc_private_subnet_ids` | First two workload private subnets (for ENI lookup per AZ). |
| `workload_nlb_name` | Workload NLB name (for ENI filter). |
| `alb_name` | (Optional) ALB name. |
| `target_group_name` | (Optional) Target group name. |

**Outputs:** `alb_id`, `alb_arn`, `alb_dns_name`, `target_group_arn`.

---

### 5. `ecs` (`./modules/ecs`)

**ECS cluster** with a **Fargate** service running the **echoserver** image. The service is attached to the Workload ALB target group.

| Responsibility | Details |
|----------------|--------|
| **Cluster** | One ECS cluster; Fargate as capacity provider. |
| **Service** | echoserver, 256 CPU / 512 MiB, `awsvpc`, in app subnets, no public IP. |
| **Task** | Single container: echoserver on port 8080; CloudWatch Logs; execution role with `AmazonECSTaskExecutionRolePolicy`. |
| **Security** | ECS SG allows ingress from Workload ALB SG on container port 8080. |
| **Load balancing** | Service registers with Workload ALB target group (container port 8080). |

**Inputs**

| Name | Description |
|------|-------------|
| `vpc_id` | Workload VPC ID. |
| `app_subnet_ids` | Private subnets for ECS (e.g. workload-app-subnet-a/b). |
| `workload_alb_target_group_arn` | Workload ALB target group ARN. |
| `workload_alb_security_group_id` | Workload ALB SG (for ECS ingress). |
| `cluster_name` | (Optional) ECS cluster name. |
| `service_name` | (Optional) ECS service name. |
| `log_group_name` | (Optional) CloudWatch log group. |
| `container_image` | (Optional) Echoserver image. |
| `container_port` | (Optional) Container port (default 8080). |
| `desired_count` | (Optional) Desired task count. |
| `aws_region` | (Optional) AWS region. |

**Outputs:** `cluster_id`, `cluster_name`, `service_name`, `execution_role_arn`.

---

## Usage

1. **Clone and enter the project**
   ```bash
   cd /path/to/terraform-assignment
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review the plan**
   ```bash
   terraform plan
   ```

4. **Apply**
   ```bash
   terraform apply
   ```

5. **Get the public endpoint**  
   After apply, use the `internet_alb_dns` output. Open in a browser or curl:
   ```bash
   terraform output internet_alb_dns
   curl http://$(terraform output -raw internet_alb_dns)/
   ```
   You should see the echoserver response (e.g. request metadata).

---

## Outputs

| Output | Description |
|--------|-------------|
| `internet_alb_dns` | DNS name of the internet-facing Gateway ALB (public entry point). |
| `workload_alb_dns` | DNS name of the internal Workload ALB. |
| `workload_nlb_dns` | DNS name of the internal Workload NLB. |

---

## Customization

- **Region:** Change `region` in `main.tf` and any `aws_region` passed into the ECS module.
- **VPC CIDRs / subnets:** Edit the `terraform-aws-modules/vpc/aws` arguments in `main.tf` for `internet_vpc` and `workload_vpc`.
- **ECS:** Adjust `container_image`, `desired_count`, `cpu`, `memory` in `modules/ecs/main.tf` or via variables.
- **Transit Gateway:** Optional variables (e.g. `tgw_description`) in `modules/transit_gateway/variables.tf`.

---

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Confirm when prompted. This removes both VPCs, TGW, all load balancers, ECS cluster/service, and related networking/IAM/log resources.

---

## Summary

| Component | VPC | Purpose |
|-----------|-----|--------|
| Gateway ALB | Internet | Public entry; targets NLB ENI IPs via TGW |
| Transit Gateway | — | Connects Internet and Workload VPCs |
| Web NLB | Workload | Internal TCP 80; forwards to Web ALB |
| Web ALB | Workload | Internal HTTP 80; forwards to ECS |
| ECS Fargate | Workload | Runs echoserver on 8080 |

Together, this demonstrates a **multi-VPC, TGW-based path** from the internet to an internal ECS service, with clear separation between gateway (Internet VPC) and workload (Workload VPC) and no direct exposure of the workload VPC to the internet.
