# Observability

Module: `modules/observability`, plus log settings in the compute, data and edge modules. Everything is Terraform, and everything is removed by `destroy-dev`.

## What is covered

| Layer | Metrics and dashboard | Alarms | Logs |
|---|---|---|---|
| Edge (CloudFront, WAF) | Requests, 5xx rate, allowed and blocked requests | none (view only) | WAF log group `aws-waf-logs-dev-cloudfront` (us-east-1) |
| Load balancer | Requests, 5xx, healthy and unhealthy targets, response time | 4 | Access logs in S3 `dev-s3-alb-logs-<account>` |
| ECS | CPU, memory | 2 | `/dev/ecs/app` |
| RDS | CPU, connections, free storage | 3, plus failover events | `/aws/rds/instance/dev-rds/postgresql` |
| Redis | Engine CPU, memory | 2 | none |
| Network | none | none | `/dev/vpc/flow-logs` |
| Application | Error line count | 1 | `/dev/ecs/app` |

## Notifications

All alarms and RDS failover events publish to one SNS topic, `dev-sns-alarms`, encrypted with the customer-managed key `dev-kms-sns`. The email address comes from the CI/CD variable `TF_VAR_alarm_email` and is never stored in the repo. The subscription must be confirmed once after the first apply.

## Alarms

Alarm names are `dev-alarm-<service>-<what>`. Each evaluates 5-minute periods and triggers after 2 in a row. Thresholds are module variables.

| Alarm | Fires when |
|---|---|
| `alb-5xx` | More than 5 target 5xx responses |
| `alb-unhealthy-hosts` | At least 1 failing target |
| `alb-healthy-hosts-low` | Fewer than 2 healthy targets (one per zone) |
| `alb-response-time` | Average over 1 second |
| `ecs-cpu`, `ecs-memory` | Over 80% |
| `rds-cpu` | Over 80% |
| `rds-free-storage` | Under 5 GiB |
| `rds-connections` | Over 80 |
| `redis-cpu`, `redis-memory` | Over 80% |
| `app-errors` | More than 5 log lines containing ERROR, Error or error (metric filter on `/dev/ecs/app`) |

An RDS event subscription also sends **failover** and **failure** events to the same topic.

## Dashboard

`dev-dashboard-platform` is one dashboard with a widget per layer: ALB, targets, ECS, RDS, storage, Redis, CloudFront, WAF and application errors.

## Naming in CloudWatch

- Log groups: `/<env>/<service>/<name>`, so `/dev/` lists our own logs together. Two names are fixed by AWS: WAF (`aws-waf-logs-` prefix) and RDS (`/aws/rds/instance/...`).
- Alarms: filter by `dev-alarm-` and then by service.

## Logs: retention and encryption

| Log | Where | Retention | Encryption at rest |
|---|---|---|---|
| Application (ECS) | CloudWatch `/dev/ecs/app` | 30 days | CloudWatch Logs default (AWS-managed key) |
| RDS PostgreSQL | CloudWatch `/aws/rds/instance/dev-rds/postgresql` | 30 days | CloudWatch Logs default |
| WAF | CloudWatch `aws-waf-logs-dev-cloudfront` (us-east-1) | 30 days | CloudWatch Logs default |
| VPC flow logs | CloudWatch `/dev/vpc/flow-logs` | 30 days | CloudWatch Logs default |
| ALB access logs | S3 `dev-s3-alb-logs-<account>` | 30 days (lifecycle rule) | S3 default (SSE-S3) |

All logs are encrypted at rest by default. The log groups do not use a customer-managed KMS key yet (next steps). Retention comes from the `log_retention_days` variable of each module (`flow_log_retention_days` for the flow logs). Nothing logs CloudFront access, S3 access or Redis, and there is no CloudTrail trail in this account.

## Design choices

- **Customer-managed key for the topic.** CloudWatch alarms cannot publish to a topic that uses the AWS-managed SNS key, so the module uses its own key with a policy for CloudWatch and RDS events.
- **Alarms stay in each environment account.** A problem in prod pages the prod team even if a central account is down.
- **Healthy-target count instead of running-task count.** The running-task metric needs Container Insights, which costs extra.
- **Log retention is 30 days** (a variable). The ALB log bucket expires objects after the same period.
- **Destroyable in dev.** The log groups are created by Terraform, and the ALB log bucket uses the same `force_destroy` switch as the other buckets.

## How to verify

1. Confirm the SNS subscription email.
2. Open the dashboard `dev-dashboard-platform` and check that each widget has data.
3. Force an alarm: `aws cloudwatch set-alarm-state --alarm-name dev-alarm-alb-5xx --state-value ALARM --state-reason test`. An email arrives.
4. Reboot the database with failover. Failover events arrive by email, and the dashboard shows the connection drop.
5. Send a blocked request (for example a `<script>` URL). It appears in the WAF log group.

## Not included (next steps)

- Filtering logs by level or action (for example blocked WAF requests only) to cut volume and cost.
- Container Insights, anomaly detection, X-Ray tracing.
- A central dashboard over dev, stage and prod using CloudWatch cross-account observability: stage and prod share their metrics and logs with a monitoring account, and alarms stay local.
- Log retention of one year for audit logs, and customer-managed KMS keys for the log groups (they use the default encryption today). The ALB log bucket uses S3-managed encryption, because the load balancer cannot write access logs to a KMS-encrypted bucket.
