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

## Architecture

```
Route 53 -> CloudFront (WAF) -+-> /static/*, /errors/*  -> S3 static bucket (private, Origin Access Control)
                              |
                              +-> everything else -> Application Load Balancer (public subnets, HTTPS only)
                                                            |
PRIMARY REGION (ap-southeast-1)                             | HTTPS to the container (port 8443)
   Private app subnet AZ1: ECS Fargate tasks   <------------+
   Private app subnet AZ2: ECS Fargate tasks   <------------+--> Private data subnets
                                                                 - Redis (ElastiCache, TLS)
                                                                 - RDS PostgreSQL primary --(Multi-AZ sync)--> standby
                                                                       |
                                                                       | cross-region replication (pilot light)
                                                                       v
DR REGION (ap-southeast-2)                                       RDS read replica
```

The application is a separate repository (`sample-app`). Its pipeline pushes a versioned image to ECR and uploads the static files to S3. This repo only runs the image it is told to run (`app_image_tag`).

## Repository layout

```
.
├── modules/                    Reusable infrastructure layers
│   ├── network/                VPC, three subnet tiers in 2 AZs, endpoints, flow logs
│   ├── security/               KMS keys, security groups, IAM roles
│   ├── data/                   RDS (Multi-AZ), Redis, DB secret, S3 buckets
│   ├── compute/                ALB, ECS cluster, service, task definition
│   ├── dns/                    Hosted zone lookup, ACM certificates
│   ├── edge/                   WAF, CloudFront, Route 53 records
│   ├── observability/          Dashboard, alarms, SNS topic
│   └── dr/                     DR region network, key and RDS read replica
├── environments/               One root configuration per environment
│   ├── dev/                    Deployed and tested
│   ├── stage/                  Same modules, sample values
│   └── prod/                   Same modules, sample values
├── docs/                       Short design notes (see below)
├── .gitlab-ci.yml              Pipeline
└── README.md
```

Each environment root has the files below, and each starts with the banner of the section it belongs to (Root Configuration, Reusable Infrastructure Layers, Environment-Specific Resources, Interfaces):

| File | Content |
|---|---|
| `versions.tf`, `backend.tf`, `providers.tf` | Root configuration: Terraform and provider versions, S3 backend, providers |
| `main.tf` | The `networking`, `security`, `compute` and `data` module calls, plus the environment-specific resources (edge, DNS, observability, DR) |
| `variables.tf`, `outputs.tf` | Interfaces |
| `locals.tf` | Tags |
| `<env>.tfvars` | Values for the environment |

Dev, Stage and Prod call the same modules and differ only in values, which keeps the environments consistent.

## Design notes

| Document | Topic |
|---|---|
| [docs/security.md](docs/security.md) | Keys, TLS end to end, WAF, secrets |
| [docs/observability.md](docs/observability.md) | Dashboard, alarms, logs, notifications |
| [docs/dr.md](docs/dr.md) | Pilot light strategy, RTO/RPO, failover steps, known gaps |
| [docs/tagging.md](docs/tagging.md) | Tag model for cost allocation |
| [docs/multi-account.md](docs/multi-account.md) | Account per environment, guardrails, central keys and secrets (design only) |
| [docs/build-order.md](docs/build-order.md) | The order the layers were built and verified |

## Design principles

- **Consistency**: one set of modules for all environments, parameterised by values.
- **Least privilege**: scoped IAM roles, private subnets for compute and data, and only the ALB exposed behind CloudFront and WAF.
- **Encryption**: customer-managed KMS keys per service, TLS in transit all the way to the container.
- **Secrets**: the database password is generated at apply time, never stored in code or state, and kept in Secrets Manager. The pipeline uses short-lived OIDC credentials, with no stored AWS keys.
- **FinOps**: standard tags (`Project`, `Environment`, `Service`, `Owner`, `CostCenter`, `ManagedBy`) applied through provider default tags, with a platform set and a workload set.
- **Resilience**: two AZs for compute, Multi-AZ RDS, and a cross-region read replica (pilot light) for DR.
- **Observability**: a dashboard and 12 alarms to one encrypted SNS topic, plus WAF, load balancer, RDS and application logs.
- **Safe delivery**: GitLab CI/CD runs `fmt`, `validate` and Checkov, plans on merge requests, and applies from `main` only. Stage and prod jobs are manual and use their own roles.

## Usage

Prerequisites: Terraform `~> 1.15.0`, AWS credentials for the target account, access to the S3 state backend, and the pieces Terraform does not create: the ECR repository (with an image pushed) and a Route 53 hosted zone for the domain.

```bash
cd environments/<dev|stage|prod>
terraform init
terraform plan  -var-file=<env>.tfvars
terraform apply -var-file=<env>.tfvars
```

The `*.tfvars` files are git-ignored. The pipeline passes the same values as CI/CD variables, and `alarm_email` comes from `TF_VAR_alarm_email`.

Settings to know about:

- `enable_dr`: creates the DR region resources and the read replica. Off outside demo windows because the replica costs money.
- `app_image_tag`: the image version to run. Raise it to release, set it back to roll back.
- Dev only: `db_skip_final_snapshot`, `db_deletion_protection`, `s3_force_destroy`, `alb_deletion_protection` and `secret_recovery_window_days` allow a quick destroy. Stage and prod keep the safe values.

## Pipeline

Stages: `validate`, `plan-dev`, `apply-dev`, `plan-stage`, `apply-stage`, `plan-prod`, `apply-prod`, `destroy`.

- Merge requests: `validate`, Checkov (report only) and a plan with a read-only role.
- `main`: plan, then a manual apply for dev. Stage and prod plan and apply are manual and fail with a clear message until their own role variable is set.
- `destroy-dev` is manual and exists for demo windows.
- Rollback: infrastructure by Git tag, application by `app_image_tag`.

## Deliverables

- [ ] Presentation (20 minutes or less)
- [x] Git repository (this repo)
- [x] IaC modules and environment configurations
