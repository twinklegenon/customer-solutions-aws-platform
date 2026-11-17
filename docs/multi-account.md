# Multi-account setup

The brief describes a multi-account estate, with ownership split between DevOps and other teams under shared guardrails. It does not say how the accounts are divided. This design assumes **one AWS account per environment** (dev, stage, prod), deployed from the **same repository** and promoted through the pipeline, inside an AWS Organization with guardrails.

## Status

| Part | State |
|---|---|
| Dev | Built and run end to end through the pipeline |
| Stage and prod | Root files and sample tfvars exist and validate. Not applied: this exercise has one account |
| Pipeline | Dev jobs only. The stage and prod jobs below are a design, not wired |
| Organization, guardrails (SCPs), central keys and secrets | **Design only**, described below. Nothing is built |

## The account comes from the credentials, not the code

The AWS account is decided by the role the pipeline job assumes. `providers.tf` holds only the region and the tags, and that is correct.

| | Dev | Stage | Prod |
|---|---|---|---|
| AWS account | Dev account | Stage account | Prod account |
| Folder | `environments/dev` | `environments/stage` | `environments/prod` |
| Values | `dev.tfvars` | `stage.tfvars` | `prod.tfvars` |
| State key | `.../dev/terraform.tfstate` | `.../stage/terraform.tfstate` | `.../prod/terraform.tfstate` |
| OIDC role | `gitlab-terraform-dev` | `gitlab-terraform-stage` | `gitlab-terraform-prod` |

The three folders have the same files and call the same modules. Only the values, the state and the assumed role differ. The tfvars hold no secrets and are committed. The alarm email comes from the CI/CD variable `TF_VAR_alarm_email`.

## One-time setup for each new account (in AWS)

1. Create the OIDC identity provider for `https://gitlab.com` with audience `https://gitlab.com`. It is per account, because IAM is per account.
2. Create the role `gitlab-terraform-<env>`, trusted from the project's `main` branch only, like the dev role.
3. Give it the permissions for that account's services, and create a read-only plan role like dev has.
4. Create the state bucket. The simplest is one bucket per account, with its name in that environment's `backend.tf`. The sample roots currently point at the dev account's bucket with a separate key per environment.
5. Create the prerequisites that Terraform does not manage: the ECR repository, and a Route 53 hosted zone for the environment's domain.

## GitLab setup

- **Role variables scoped by environment.** `AWS_ROLE_ARN` and the plan role ARN exist once per environment, each holding that account's ARN. A job declared with `environment: stage` gets the stage value, so one job template serves all three.
- **Approval for prod.** Make prod a protected environment with required approvers, which gives the manual gate. The available controls depend on the GitLab plan. Without them, use a manual job on the protected `main` branch.
- **Values.** The tfvars are in the repository, so the pipeline reads them directly. Anything secret stays in CI/CD variables.

## How promotion runs (same commit)

```
merge request  ->  validate, checkov, plan-dev-mr
merge to main
  ->  plan-dev    ->  apply-dev                        (dev account)
  ->  plan-stage  ->  [approve]  ->  apply-stage       (stage account)
  ->  plan-prod   ->  [approve, protected environment] ->  apply-prod   (prod account)
```

- The same commit and the same modules go through every stage. Only the tfvars and the assumed role change. This is what "consistent environments" means.
- Each environment has its own `resource_group`, so applies do not overlap.
- Each plan is saved and applied exactly as planned, as in dev today.
- A failed stage stops the chain, so prod never receives an unverified commit.

## Target organization (design)

```
Management account            Organizations, billing. No workloads.
|
+-- Security OU
|     Log archive account     Organization trail and logs, write-once
|     Security tooling        Delegated admin for threat detection, security findings, config checks
|
+-- Shared services OU
|     Shared services         Central keys and shared secrets, shared tooling
|
+-- Workloads OU
      +-- Non-prod OU         dev account, stage account
      +-- Prod OU             prod account (and optionally a prod DR account)
```

- An account is the isolation boundary: by default nothing is allowed between accounts, and sharing has to be allowed explicitly ([AWS: organizing your environment](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)).
- The management account holds no workloads, because SCPs do not apply to it.
- Prod DR can stay in the prod account (as built in `modules/dr`) or move to its own account. AWS recommends a different account per Region for pilot light, for the highest isolation ([AWS: disaster recovery options](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html)).
- People sign in through a central identity service (IAM Identity Center) and roles, not IAM users. The pipeline uses the OIDC roles above. No long-lived access keys.

## Guardrails: service control policies (design)

What an SCP is, from the AWS documentation ([AWS: SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)):

- An SCP grants no permissions. It sets the **maximum** permissions of users and roles in member accounts, including the root user.
- It does not apply to the management account or to service-linked roles.
- Roles still need their own IAM policies. The effective permission is the overlap of the SCP and the IAM policy.
- AWS recommends not attaching an SCP to the organization root without testing. Move accounts into a test OU one at a time first, and do not remove the default `FullAWSAccess` policy unless it is replaced.

Guardrails I would attach, by level:

| Guardrail | Attached to | Why |
|---|---|---|
| Deny actions outside the approved Regions (ap-southeast-1, ap-southeast-2, and us-east-1 for CloudFront and WAF certificates), with global services exempt | Workloads OU | Keeps data and cost inside the planned footprint |
| Deny leaving the organization, and deny turning off the organization trail, threat detection or config checks | Root, except the management account | Protects the audit trail |
| Deny creating IAM users and access keys | Workloads OU | Forces roles and the OIDC pipeline roles, no static keys |
| Deny removing S3 Block Public Access at account level | Workloads OU | Private by default |
| Deny scheduling deletion or disabling of KMS keys, except for a security role | **Prod OU and stage account**, not dev | Protects the data keys. Dev is excluded because `destroy-dev` schedules key deletion on purpose |
| Tag policy for `Service`, `Owner`, `CostCenter`, `Environment`, `Project` | Root | The allowed keys and values that `docs/tagging.md` defines |

The pipeline roles must stay inside what the SCPs allow, so each guardrail is tested on one account in a test OU before it is attached widely.

## Central keys and secrets (design)

The brief asks for centralised secrets and keys. The design separates **central control** from **central storage**:

| Question | Design |
|---|---|
| Where do workload keys live? | In the workload's own account, one customer-managed key per service, as built today (`rds`, `redis`, `s3`, `secrets`, `sns`). Data stays encrypted by a key in its own isolation boundary, so one compromised account does not expose another |
| Who controls them centrally? | Key policies allow the account and one `security-admin` role. The SCP above blocks deletion for everyone else. IAM Access Analyzer reports any cross-account access |
| Where do workload secrets live? | In the workload account. The database password is created and rotated by RDS in the account that owns the database, never in code or state |
| What is stored centrally? | The shared services account holds only what several accounts need: shared secrets (for example third-party credentials) and the keys that encrypt them |
| How does another account read a central secret? | Three things together, from the AWS documentation ([AWS: cross-account secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html)): a resource policy on the secret, an identity policy on the reading role, and a key policy that lets that role decrypt |
| Which key encrypts a shared secret? | A customer-managed key. AWS states that the default `aws/secretsmanager` key cannot be used for cross-account access |
| Regions | A replica Region needs its own key, as `modules/dr` creates, or a multi-Region key |
| How is it deployed? | With Terraform, from a separate shared-services stack with its own state and role. Workload stacks only reference the keys and secrets by ARN |

## Rollout order (design)

1. Management account: enable Organizations with all features, and the organization trail. No workloads.
2. Create the OUs and the accounts: Security (log archive, security tooling), Shared services, Non-prod (dev, stage) and Prod. A landing zone service can do this, or Terraform.
3. Delegate the security services to the security tooling account.
4. Set up central sign-in for people.
5. Attach the SCPs one at a time to a test OU, then to the Workloads OU and the Prod OU. Attach the tag policy and activate the cost allocation tags from the management account.
6. Bootstrap each account: OIDC provider, pipeline roles, state bucket (one stack, run once per account).
7. Build the shared services stack: the shared keys and secrets.
8. Wire the stage and prod jobs, with the approval gate.

## Limits

- Only dev has been deployed. Stage and prod follow the same pattern but were not run, because there is one account in this exercise.
- The organization, the SCPs, the shared services account and the central secrets are a design. None of it exists, and no SCP has been tested.
- Disaster recovery for prod is in `docs/dr.md`: the DR replica is on in prod and off in stage.
- Drafting the stage and prod pipeline jobs is the next step. `.gitlab-ci.yml` has dev jobs only and has not been changed.
