# Security layer

Module: `modules/security`. It creates the encryption keys, the security groups that chain the tiers together, and the IAM roles for ECS. Everything is private by default: with no rule, nothing is allowed.

## Traffic flow

```
Internet -> CloudFront (WAF) -> ALB -> App (ECS) -> Database (RDS)
                                              \-> Cache (Redis)
```

Each hop accepts traffic only from the one before it.

## Encryption keys (KMS)

One key per service, so each can be granted access separately. Rotation is on.

| Key | Alias | Will encrypt |
|---|---|---|
| `dev-kms-rds` | `alias/dev-kms-rds` | RDS storage and snapshots |
| `dev-kms-redis` | `alias/dev-kms-redis` | Redis at rest |
| `dev-kms-s3` | `alias/dev-kms-s3` | S3 static bucket |
| `dev-kms-secrets` | `alias/dev-kms-secrets` | Secrets Manager secrets |

## Security groups

| Group | Purpose |
|---|---|
| `dev-sg-alb` | Application load balancer |
| `dev-sg-app` | ECS application tasks |
| `dev-sg-rds` | Database |
| `dev-sg-redis` | Redis cache |

## Rules

Rules reference other security groups, not IP addresses.

| Rule | Direction | Allows | Purpose |
|---|---|---|---|
| ALB from CloudFront | In to `alb` | `alb_port` from the CloudFront prefix list (443 with a certificate, 80 without) | Only CloudFront can reach the load balancer |
| ALB to app | Out of `alb` | 8080 to `app` | The ALB forwards only to the application |
| App from ALB | In to `app` | 8080 from `alb` | The app accepts traffic only from the load balancer |
| App to database | Out of `app` | 5432 to `rds` | Application reaches the database |
| App to Redis | Out of `app` | 6379 to `redis` | Application reaches the cache |
| App to VPC endpoints | Out of `app` | 443 to the VPC CIDR | ECR, CloudWatch Logs and Secrets Manager |
| App to S3 | Out of `app` | 443 to the S3 prefix list | Image layers through the S3 gateway endpoint |
| Database from app | In to `rds` | 5432 from `app` | Only the application reaches the database |
| Cache from app | In to `redis` | 6379 from `app` | Only the application reaches the cache |

The database and cache groups have no outbound rules.

## IAM roles

| Role | Used by | Permissions |
|---|---|---|
| `dev-ecs-task-execution-role` | ECS, to start the task | AWS-managed `AmazonECSTaskExecutionRolePolicy`: pull images from ECR, write logs |
| `dev-ecs-task-role` | The application at runtime | None yet. Added only as the application needs them (least privilege) |

Both roles can be assumed only by `ecs-tasks.amazonaws.com`.

## Assumptions

| Item | Value | Where to change |
|---|---|---|
| Database engine | PostgreSQL | `db_port` (5432) |
| Application port | 8080 | `app_port` |
| Redis port | 6379 | Rule definitions in the module |

## Not included yet

| Item | Why | When |
|---|---|---|
| Secrets read access for the execution role | No secret exists yet | `data` module, when RDS creates its managed secret |
| KMS key for CloudWatch Logs | Needs a key policy, and no log group is encrypted yet | When log groups are encrypted |
| WAF and TLS certificates | Attach to CloudFront and the ALB | Edge layer |
