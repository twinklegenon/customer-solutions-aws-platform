# Tagging

Tags drive cost allocation and show-back/charge-back, so resources are billed to the appropriate teams (interview brief, FinOps & tagging).

## Two layers

| Layer | Owner | `Service` | `Owner` | `CostCenter` | Resources |
|---|---|---|---|---|---|
| Platform | DevOps | `shared` | `devops` | `cc-devops-shared` | Network, security (KMS, security groups, IAM roles), edge (CloudFront, WAF, Route 53, certificates), observability |
| Workload | The service area | `web` | `web` | `cc-web` | Compute (ECS, load balancer, log bucket), data (RDS, Redis, static bucket), the DR replica and its alarm |

The tags come only from provider `default_tags`. The environment root has two sets of tags (`common_tags` for the platform, `workload_tags` for the workload) and passes the workload provider to the `compute`, `data` and `dr` modules. No module sets a tag other than `Name`.

## Tags

| Tag | Value | Source |
|---|---|---|
| `Project` | `customer-solutions-platform` | `project` variable |
| `Environment` | `dev`, `stage`, `prod` | `environment` variable |
| `Service` | `shared`, or the service area of the workload | Fixed for the platform, `service` variable for the workload |
| `Owner` | `devops`, or the owning team | `owner` and `workload_owner` variables |
| `CostCenter` | `cc-devops-shared`, or the team's code (placeholders until finance provides the real codes) | `cost_center` and `workload_cost_center` variables |
| `ManagedBy` | `terraform` | Fixed |
| `Name` | Per resource, from the naming guide | Set in the module |

## Example: the same resource type in each layer

| Tag | Platform resource, VPC `dev-vpc` | Workload resource, DR VPC `dev-vpc-dr` |
|---|---|---|
| `Project` | `customer-solutions-platform` | `customer-solutions-platform` |
| `Environment` | `dev` | `dev` |
| `Service` | `shared` | `web` |
| `Owner` | `devops` | `web` |
| `CostCenter` | `cc-devops-shared` | `cc-web` |
| `ManagedBy` | `terraform` | `terraform` |
| `Name` | `dev-vpc` | `dev-vpc-dr` |

Only `Service`, `Owner` and `CostCenter` differ between the layers. `Name` is set by the module, and many resources take their name from a `name` argument instead, so they show no separate `Name` tag.

`Service` is `shared` for the platform and not `devops`: DevOps is the owner (the `Owner` tag), while `Service` says which service area the cost is charged to, and `shared` marks a cost that is divided across the teams.

The ECR repository is created by hand, outside Terraform. Tag it in the console with the workload values (`Service=web`, `Owner=web`, `CostCenter=cc-web`) and the global tags.

## Service areas (from the brief)

The brief names four shared service areas in the Customer Solutions Team: Customer Identity & Access Management (CIAM), Web, CRM Applications and Ecommerce Services. It does not define their scope, so the table below is an assumed split of the architecture diagram.

| Service area | Footprint in the diagram | Status |
|---|---|---|
| Web | Static content in S3, CloudFront, Route 53. In this stack: the Task Manager workload | **Onboarded**, tagged `Service=web` |
| Ecommerce Services | Backend ECS services, Multi-AZ RDS: transactions, highest resilience | Example, not onboarded |
| Customer Identity & Access Management | Session cache in Redis, authentication services, login protection | Example, not onboarded |
| CRM Applications | Internal ECS services in private subnets, an analytics read replica in the primary region | Example, not onboarded |
| Shared platform | VPC and networking, load balancer, security baseline, observability | In the platform layer, `Service=shared` |

Tags for Identity, CRM and Ecommerce will be implemented once those workloads exist. Nothing is created for them now.

## Onboarding a team

1. Create a stack for the team from the same modules (its own state key and tfvars).
2. Set `service`, `workload_owner` and `workload_cost_center` for that team.
3. The platform stays unchanged and keeps `Service=shared`.

The DR replica protects the primary database in another region. It is not an analytics replica: CRM reporting would use a separate replica in the primary region.

## Billing steps

1. Activate the cost allocation tags in Billing: `Service`, `CostCenter`, `Environment`, `Project`, `Owner`. A tag must already be on a resource, and it takes up to 24 hours to become active. It applies to costs from then on.
2. Report in Cost Explorer grouped by `Service`.
3. Shared costs (VPC endpoints, WAF, CloudFront, load balancer, observability) are divided across the teams by a rule agreed with finance, using an AWS Cost Category split-charge rule. Request share can be calculated from the load balancer access logs (collected in S3) and applied as fixed percentages.
4. Later: AWS Organizations tag policies to require the keys and allowed values, and budgets per `Service`.

## Parked

- Tags and cost centers for Identity, CRM and Ecommerce, until those workloads exist.
- Real cost center codes.
- Tagging each diagram component with its own team (needs the `data`, `compute` and `edge` modules split).
- Tag enforcement with tag policies.
