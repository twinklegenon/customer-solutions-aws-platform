# Disaster recovery

Strategy: **pilot light**. The data is copied to a second region all the time, and the services that use it are not running there. On a regional failure the replica is promoted and the compute layers are rebuilt from the same Terraform modules.

Module: `modules/dr`. It is called from the environment root and switched by `enable_dr` (off by default, on in prod).

## What runs in the DR region

| Item | Why |
|---|---|
| RDS read replica `dev-rds-dr` | Asynchronous copy of the primary, encrypted with its own key |
| KMS keys `dev-kms-rds-dr`, `dev-kms-sns-dr` | A replica must be encrypted with a key of its own region |
| VPC `dev-vpc-dr` with two private subnets and a DB subnet group | The replica needs a subnet group. No public subnets, no NAT, no VPC endpoints |
| Security group `dev-sg-rds-dr` | No rules: nothing reaches the replica until the application tier exists there |
| Alarm `dev-alarm-rds-replica-lag` and SNS topic `dev-sns-alarms-dr` | A CloudWatch alarm reads only the metrics of its own region, so the alarm lives in the DR region. The dashboard shows the lag as a widget |

Not running in the DR region: ECS, the load balancer, Redis, VPC endpoints, a Multi-AZ standby. These are the hourly costs, which is why the pilot light is cheap.

## Scope

| Service | In scope | Approach |
|---|---|---|
| RDS | Yes | Cross-region read replica, promoted on failover |
| ECS and ALB | Yes | Rebuilt from the `network`, `security` and `compute` modules in the DR region |
| Redis | Yes | A cache: not replicated, starts empty |
| S3 static files | Yes | Published again from the build. Cross-region replication is an option |
| CloudFront, WAF, Route 53 | Global | Not regional. Route 53 or the CloudFront origin is pointed at the DR load balancer |

## Targets

Targets to confirm with a drill, not measured values.

| | Target | Basis |
|---|---|---|
| RPO | Seconds to minutes | Replica lag, watched by the alarm (threshold 300 seconds) |
| RTO | Tens of minutes | Promote the replica, then rebuild the compute layers |

## Failover runbook

1. Confirm the primary region is unavailable and agree to fail over.
2. Promote the replica to a standalone database (RDS, Actions, Promote). This ends replication permanently.
3. Apply the `network`, `security`, `compute` and `edge` modules in the DR region, with the replica endpoint as the database host.
4. Make the dependencies available in the DR region: the application image (ECR replication or a push), an ACM certificate for the load balancer, and the database secret.
5. Point Route 53 or the CloudFront origin at the DR load balancer.
6. Check `/health` and a read and a write through the application.

Failback: create a new replica in the primary region from the promoted database, wait until the lag is near zero, and switch back in a quiet period.

## Known gaps

- The runbook has not been run end to end. Compute is rebuilt from the same code, so the risks are the dependencies in step 4.
- ECR cross-region replication, a replicated database secret and a DR certificate are not built.
- The replica has no Multi-AZ standby (a cost choice for the pilot light).

## Cost

The always-on parts are the replica, its storage and the small VPC. The first demo uses a single-AZ `db.t4g.micro` replica. Turn `enable_dr` on only for a demo window, then off again so `destroy-dev` removes it.

## Use it

Set `enable_dr = true` in the environment's tfvars, merge, and run `plan-dev` and `apply-dev`. The replica takes 20 to 40 minutes to create. Confirm the subscription email from the DR region once.
