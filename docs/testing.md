# Testing

What was tested on the dev stack, how, and what was observed. Region `ap-southeast-1`, dev account, domain `customersolutionslab.com`. The stack was built from the pipeline, tested while it ran, then removed with `destroy-dev`.

Screenshots of the tests (proof): [Google Drive folder](https://drive.google.com/drive/folders/1Y1Vj8GLHkrNYDZshGMrc_Up3UmkkgXME?usp=sharing).

Commands are for a shell with AWS credentials for the dev account. In PowerShell, `curl` is an alias, so use `curl.exe` or `Invoke-WebRequest ... -UseBasicParsing`.

## Network and edge

| Test | How | Result |
|---|---|---|
| Site loads over HTTPS | Open `https://app.customersolutionslab.com` | Pass. Task Manager page, footer shows the AZ, the task and the cache state |
| HTTP redirects to HTTPS | `curl.exe -I http://app.customersolutionslab.com` | Pass. `301` to HTTPS |
| TLS version | Browser certificate details | Pass. TLS 1.3, certificate from Amazon |
| Origin not reachable directly | `curl.exe -m 10 https://origin.customersolutionslab.com` | Pass. No answer (the load balancer admits only CloudFront) |
| Static bucket is private | Open the S3 object URL directly | Pass. `403` |
| Static content through CloudFront | Upload `static/hello.txt`, open `/static/hello.txt` | Pass. File returned |
| Error page | Set the ECS desired count to 0, open the site | CloudFront shows the page from S3 (`/errors/error.html`), the status stays 5xx |
| Both AZs serve traffic | Reload the page and watch the footer | Pass. It alternates between `ap-southeast-1a` and `1b` with different task IDs |
| Cache cycle | Add, list and delete a task | Pass. Footer shows `MISS`, then `HIT`. CloudFront replaces `X-Cache`, so the app sends `X-App-Cache` |

## Security (WAF)

| Test | How | Result |
|---|---|---|
| XSS in the URL | `https://app.customersolutionslab.com/?q=<script>alert(1)</script>` | Pass. `403` |
| Path traversal in the query | `.../?file=../../etc/passwd` | Pass. `403` |
| XSS in a JSON body | `POST /api/tasks` with a `<script>` title | Pass. `403` |
| SQL injection | `.../?id=1' OR '1'='1` | `403` after the SQLi rule group was added. Before it, the Common rule set did not block it |
| No false positive | Save a task whose title has an apostrophe | The task saves normally |
| WAF logs | CloudWatch Logs Insights on `aws-waf-logs-dev-cloudfront` (us-east-1): `fields @timestamp, action, terminatingRuleId \| filter action = "BLOCK" \| stats count() by terminatingRuleId` | Pass. `BLOCK` events by `aws-common`, `aws-sqli` and `aws-known-bad-inputs` (the last one from an external scanner) |

## Resilience

| Test | How | Result |
|---|---|---|
| ECS task recovery | ECS console, cluster `dev-ecs-cluster`, Tasks tab: stop one task | Pass. The site stayed up from the other AZ and ECS started a replacement |
| Multi-AZ database failover | `aws rds reboot-db-instance --db-instance-identifier dev-rds --force-failover --region ap-southeast-1` | Pass. About 29 seconds from the started to the completed event |
| Failover events | `aws rds describe-events --source-identifier dev-rds --source-type db-instance --duration 180 --region ap-southeast-1 --query 'Events[].[Date,Message]' --output text` | Events `RDS-EVENT-0013` (started) and `RDS-EVENT-0049` (completed), also by email |
| Failover proof | `EP=$(aws rds describe-db-instances --db-instance-identifier dev-rds --region ap-southeast-1 --query 'DBInstances[0].Endpoint.Address' --output text); getent hosts $EP` | The endpoint IP moves between the data subnets (`10.10.20.x` is 1a, `10.10.21.x` is 1b). The console and API AZ labels lag by several minutes |

## Observability

| Test | How | Result |
|---|---|---|
| Dashboard | Open `dev-dashboard-platform` | Pass. Every widget has data (the WAF widget needed the dimensions `WebACL` and `Rule=ALL`) |
| Alarm email | `aws cloudwatch set-alarm-state --alarm-name dev-alarm-alb-5xx --state-value ALARM --state-reason test --region ap-southeast-1` | Pass. ALARM email, then OK. The SNS subscription must be confirmed first |
| Application error | `PUT /api/tasks/abc` returns `500` | Pass. The error is in `/dev/ecs/app` and the `ErrorCount` metric rises. One failed request counts twice, because the metric filter counts matching log lines |
| App logs from private subnets | CloudWatch Logs `/dev/ecs/app` | Pass. Start-up lines, `Database schema ready`, and health check lines |

## Tags (FinOps)

| Test | How | Result |
|---|---|---|
| Workload resources | Tag Editor, or `aws resourcegroupstaggingapi get-resources --tag-filters Key=Service,Values=web --region ap-southeast-1` | Web resources (ECS, ALB, RDS, Redis, static bucket) carry `Service=web`, `Owner=web`, `CostCenter=cc-web` |
| Platform resources | Same with `Values=shared` | Network, security, edge and observability carry `Service=shared`, `Owner=devops`, `CostCenter=cc-devops-shared` |

Every resource also has `Project`, `Environment` and `ManagedBy`.

## Security configuration checks

- Encryption: RDS and Redis use their own KMS keys, the static bucket uses SSE-KMS with public access blocked. The ALB log bucket uses S3-managed keys.
- Security groups chain ALB to app to RDS and Redis, with nothing open between other tiers.
- Secrets: the database password is generated at apply time and stored in Secrets Manager. It is never in code or state.

## Pipeline

- Merge request: `validate` (fmt and validate for dev, stage and prod), Checkov (report only), and `plan-dev-mr` with the read-only role.
- `main`: `plan-dev`, then a manual `apply-dev`. Stage and prod jobs are manual and stop with a message until their role variables exist.
- `destroy-dev` is manual and removes everything in dev.
- The merge request plan failed with `403` each time a new resource type needed read access on the plan role, until the read actions were added.

## Not tested

- Stage and prod: the roots validate, but they were never applied (one account in this exercise).
- Promotion of the DR replica, and rebuilding the application in the DR region. But the dr.tfvars is ready for just in case of regional outage.
- Multi-account setup, SCPs and central keys (a design only, see `multi-account.md`).
