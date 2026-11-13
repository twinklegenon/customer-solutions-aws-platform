# Customer Solutions AWS Platform

Infrastructure-as-Code for a production-ready, highly resilient AWS platform, prepared for the **Cambridge University Press & Assessment – DevOps Engineer interview task (November 2026)**.

## Scenario

A team of two DevOps engineers (one senior, one mid-level) implements DevOps practices across four shared service areas of the Customer Solutions Team:

- Customer Identity & Access Management
- Web
- CRM Applications
- Ecommerce Services

The estate has these characteristics, and the design has to respect them:

| Area | Expectation |
|---|---|
| Multi-account estate | Legacy and modern services across several AWS accounts. Ownership is split between DevOps and other teams under shared guardrails. |
| Security by design | Private by default, least-privilege IAM, centralised secrets and keys, TLS end-to-end, AWS WAF at the edge. |
| FinOps & tagging | Standard tags drive cost allocation and showback/chargeback. |
| Environments | Dev, Stage and Prod are kept consistent. |
| Operations & resilience | Actionable dashboards, metrics and alarms, plus a DR strategy for in-scope services. |

## The task

Build the system below as IaC, and present the implementation approach in a talk of **20 minutes or less**, leaving time for questions. The presentation should show how the approach and experience fit the role. After the interview, send the presentation and this repo for review.

### Target architecture

```
Route 53 -> CloudFront -+-> (static content) -> S3 static bucket
                        |
                        +-> WAF -> (dynamic requests) -> Application Load Balancer (public subnets)
                                                                |
PRIMARY REGION                                                  v
   Private subnet AZ1: ECS service / backend tasks   <--+
   Private subnet AZ2: ECS service / backend tasks   <--+--> Data layer
                                                              - Redis cache (ElastiCache)
                                                              - RDS primary  --(Multi-AZ sync)--> RDS standby
                                                                    |
                                                                    | cross-region replication
                                                                    v
DR REGION                                                    RDS read replica
```

### Key areas to address

1. **Infrastructure & Systems (AWS depth)**: VPC, subnets, ALB, ECS, RDS, ElastiCache, S3, CloudFront, Route 53.
2. **Automation & IaC / CI-CD**: the module structure below, kept in this Git repo.
3. **Security & Compliance**: IAM, secrets/KMS, TLS, WAF, private networking, guardrails.
4. **Observability**: dashboards, metrics, alarms, logging.
5. **Resilience & DR**: Multi-AZ, cross-region replica, failover and recovery targets (RTO/RPO).

## IaC abstract structure

The layout follows the structure given in the brief: a root configuration, reusable layers as modules, environment-specific resources, and an interface of variables and outputs. The directory tree below is the **planned layout**, so check the repo for what has been implemented so far.

```
.
├── modules/                  # Reusable infrastructure layers
│   ├── network/              # VPC, public/private subnets across 2 AZs, routing, NAT, endpoints
│   ├── security/             # IAM roles/policies, KMS, Secrets Manager, security groups, WAF
│   ├── compute/              # ALB, ECS cluster/services/task definitions, autoscaling
│   └── data/                 # RDS (Multi-AZ + cross-region replica), ElastiCache Redis, S3
├── environments/             # One root configuration per environment
│   ├── dev/
│   ├── stage/
│   └── prod/
│       ├── main.tf           # terraform {backend "remote"}, required_providers, provider,
│       │                     #   module calls (networking, security, compute, data),
│       │                     #   environment-specific resources
│       ├── variables.tf      # environment, region, ...
│       └── outputs.tf        # service_endpoint, ...
└── README.md
```

Each environment's root configuration has four parts:

- **Root configuration**: a `terraform` block with a remote backend and required providers, and the `provider` block.
- **Reusable layers**: `networking`, `security`, `compute` and `data` modules, sourced from `../modules/*`.
- **Environment-specific resources**: the application service resources for that environment.
- **Interfaces**: `environment` and `region` input variables, and a `service_endpoint` output.

Dev, Stage and Prod call the same modules and differ only in variable values, which keeps the environments consistent.

## Design principles

- **Consistency**: one set of modules for all environments, parameterised by `environment` and `region`.
- **Least privilege**: scoped IAM roles, private subnets for compute and data, and only the ALB exposed behind CloudFront and WAF.
- **Encryption**: KMS-encrypted data at rest, TLS in transit, secrets held in a central secrets store.
- **FinOps**: mandatory tags (for example `environment`, `service`, `owner`, `cost-center`) applied through provider default tags.
- **Resilience**: two AZs for compute, Multi-AZ RDS, and a cross-region read replica for DR.
- **Observability**: CloudWatch dashboards and alarms for the ALB, ECS, RDS and Redis, with alarms routed to notifications.
- **Safe delivery**: CI/CD runs `fmt`, `validate`, lint and security scans, then a plan on pull requests. Apply is gated per environment, with approval for Prod.

## Usage

Prerequisites: Terraform, AWS credentials for the target account, and access to the remote state backend.

```bash
cd environments/<dev|stage|prod>
terraform init
terraform plan  -var="environment=<env>" -var="region=<region>"
terraform apply -var="environment=<env>" -var="region=<region>"
```

## Deliverables

- [ ] Presentation (20 minutes or less)
- [x] Git repository (this repo)
- [ ] IaC modules and environment configurations
