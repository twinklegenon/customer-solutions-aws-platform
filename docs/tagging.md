# Tagging

Tags drive cost allocation and showback/chargeback, so resources are billed to the appropriate teams (interview brief, FinOps & tagging).

## Global tags

Applied to every resource through provider `default_tags`.

| Tag | Value | Source |
|---|---|---|
| `Project` | `customer-solutions-platform` | `project` variable |
| `Environment` | `dev`, `stage`, `prod` | `environment` variable |
| `Owner` | `devops` | `owner` variable |
| `CostCenter` | `cc-devops-shared` (placeholder until finance provides the real code) | `cost_center` variable |
| `ManagedBy` | `terraform` | Fixed |

There is no global `Service` tag: the network and other shared layers are not owned by one service area.

## Teams (from the brief)

- DevOps: two engineers implementing DevOps practices across the shared services.
- Four shared service areas in the Customer Solutions Team: Customer Identity & Access Management, Web, CRM Applications, Ecommerce Services.

## Parked

- Per-team and per-resource-set tags: how Web, CIAM, CRM and Ecommerce resources carry their own `Service`, `Owner` and `CostCenter`, overriding the global values.
- Real cost center codes.
- Billing steps: activate cost allocation tags, report by tag, allocate shared cost, budgets, tag enforcement.
