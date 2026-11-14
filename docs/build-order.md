# Build order

The platform is built bottom-up, in dependency order. Each layer is validated in dev (`fmt`, `validate`, `plan`, then apply) before the next layer is added. Dev is proven first; stage and prod reuse the same modules with different values.

## Order

| # | Layer | Contents | Depends on |
|---|---|---|---|
| 1 | Network (`modules/network`) | VPC, public / private app / private data subnets per AZ, internet gateway, route tables, S3 gateway endpoint, interface endpoints (ECR, Logs, Secrets Manager), flow logs | Backend and credentials |
| 2 | Security (`modules/security`) | KMS keys, security groups (ALB, app, data), IAM roles (ECS task and execution) | Network |
| 3 | Data (`modules/data`) | RDS Multi-AZ, ElastiCache Redis, S3 static bucket | Network, security |
| 4 | Compute (`modules/compute`) | ALB, ECS cluster, service, task definition | Network, security, data |
| 5 | Edge | ACM certificates, WAF, CloudFront (ALB and S3 origins), Route 53 | Compute, data (S3) |
| 6 | Observability | CloudWatch dashboards and alarms for ALB, ECS, RDS, Redis | Resources from steps 3 to 5 |
| 7 | DR | Second-region provider, DR VPC, cross-region RDS read replica, KMS key in the DR region | Primary RDS (step 3) |
| 8 | Stage and prod | Copy dev, change values | Dev proven |
| 9 | CI/CD (`.gitlab-ci.yml`) | validate, plan, apply; manual approval for prod | Stable code |

## Why this order

- Everything lives inside the network, so it comes first.
- Security groups, KMS and IAM roles are referenced by data and compute, so they come before them.
- Data is stateful and hard to change later, so it is settled before compute.
- Edge services sit in front of compute and are built last among the resources.
- Observability needs real resources to watch.
- DR depends on the primary database being correct.
- The pipeline comes last, once the code is stable, but the layout is pipeline-friendly from the start.

## Rules for each step

1. Build the smallest working slice, then widen.
2. Run `terraform fmt -recursive`, `terraform validate` and `terraform plan` after every change.
3. Apply to dev and verify before starting the next layer.
4. Build security in from the start: private subnets, encryption, least-privilege roles.
5. Values go in `*.tfvars`, never hardcoded in resources.

## Environments

- Dev, stage and prod each assume their own AWS account and VPC.
- Same modules everywhere; only the values differ.
- Promotion is done by the pipeline on the same commit: dev, stage, then prod after manual approval.
