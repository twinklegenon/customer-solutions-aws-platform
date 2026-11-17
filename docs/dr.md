# Disaster recovery

Strategy: **pilot light**. The data is copied to a second region all the time, and the services that use it are not running there. On a regional failure the replica is promoted and the compute layers are rebuilt from the same Terraform modules.

Module: `modules/dr`. It is called from the environment root and switched by `enable_dr` (off by default, on in prod).

## Why pilot light

Two layers of protection, because the failures are different:

| Failure | How often | Protection | Cost |
|---|---|---|---|
| Instance or Availability Zone | The common case | Multi-AZ: RDS standby, ECS tasks in two zones behind the load balancer | Already in the design |
| Whole region | Rare, but severe | Cross-region replica, rest rebuilt on demand (pilot light) | Replica and a small network only |

- **Zone failures are more common than region failures.** Uptime Institute, Public Cloud Costs Versus Resiliency: "Failures in zones are more common than in regions." Multi-AZ therefore covers the likely failure, and the DR region is for the unlikely one.
- **Multi-AZ already removes most downtime.** Uptime Institute (April 2025): an application across zones has on average 19 minutes less downtime than a single-zone one, and 36 minutes less across regions. The extra step to multi-region buys comparatively little, which does not justify a running second copy.
- **AWS names the strategies by the definition of disaster.** For the loss of one data center in a well-architected, highly available workload, backup and restore may be enough. If a disaster means a whole region, AWS says to consider pilot light, warm standby or multi-site. The brief draws a live replica in the DR region, so it treats a regional loss as in scope.
- **Pilot light is the lowest-cost live option.** AWS: the data stores are always on, the application servers are "switched off", and the approach "minimizes the ongoing cost of disaster recovery". Warm standby adds a running, scaled-down application tier, and multi-site active/active is the most complex and costly.
- **Recovery time fits.** AWS: promoting an RDS read replica "takes a few minutes", and failover is often started manually, because automatic failover on a false alarm loses availability and data.
- **No outage count is used.** Nobody can predict which zone or region will fail (Uptime Institute, April 2025), and published counts of regional outages differ by source. The choice rests on the cost of protection against the rare case, not on a count.

Sources:

- [AWS, Disaster Recovery of Workloads on AWS: disaster recovery options in the cloud](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html)
- [Uptime Institute, Outage data shows cloud apps must be designed for failure (April 2025)](https://journal.uptimeinstitute.com/outage-data-shows-cloud-apps-must-be-designed-for-failure/)
- [Uptime Institute, Public Cloud Costs Versus Resiliency: Stateless Applications](https://uptimeinstitute.com/resources/research-and-reports/public-cloud-costs-versus-resiliency-stateless-applications)

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

## Testing

The replica is checked while it runs, and the promotion is a separate, optional drill because it cannot be undone.

| Check | How | Expected |
|---|---|---|
| Replica replicates | `aws rds describe-db-instances --db-instance-identifier dev-rds-dr --region ap-southeast-2` | `available`, source is the primary, encrypted, not public |
| Replica lag | `ReplicaLag` metric in the DR region, or the dashboard widget | Seconds, well under the 300 second threshold |
| Writes keep replicating | Write to the primary and check the status and lag again | Status stays `available`, lag returns to near zero |
| Lag alarm | `aws cloudwatch set-alarm-state --alarm-name dev-alarm-rds-replica-lag --state-value ALARM --state-reason test --region ap-southeast-2` | Email from the DR topic, then back to OK |
| Replica is private | The security group has no inbound rules | Nothing can reach it |

Promotion drill, optional and last:

- Promoting ends replication for good, so run it only as the final step before the environment is destroyed, or skip it.
- A regional outage cannot be switched on, so it is simulated: declare the outage, stop the application in the primary region, then recover using only the DR region.
- Record the time from the promote command until the database is `available` with no replica source. That is the recovery time of the data tier.
- Not covered by the drill: rebuilding the application tier in the DR region, so the compute recovery time stays a target.

The Multi-AZ failover inside the primary region was tested separately (about 29 seconds).

## Known gaps

- **Found on the first apply, now fixed in code:** RDS does not allow a read replica of a PostgreSQL instance whose master password is managed by RDS. The `data` module now uses a write-only password: an ephemeral random value given to the database and to a Secrets Manager secret, so it never reaches the state, and the tasks read that secret. The trade-off is that RDS no longer rotates the password automatically; rotation is a Secrets Manager rotation function, added later. Not yet applied: the replica is verified at the next apply with `enable_dr = true`.
- The runbook has not been run end to end, and the promotion has not been drilled. Compute is rebuilt from the same code, so the risks are the dependencies in step 4.
- ECR cross-region replication, a replicated database secret and a DR certificate are not built.
- The replica has no Multi-AZ standby (a cost choice for the pilot light).

## Cost

The always-on parts are the replica, its storage and the small VPC. The first demo uses a single-AZ `db.t4g.micro` replica. Turn `enable_dr` on only for a demo window, then off again so `destroy-dev` removes it.

## Use it

Prerequisite: the primary database uses the unmanaged write-only password (done in the `data` module).

Set `enable_dr = true` in the environment's tfvars, merge, and run `plan-dev` and `apply-dev`. The replica takes 20 to 40 minutes to create. Confirm the subscription email from the DR region once.
