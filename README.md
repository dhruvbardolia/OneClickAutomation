# OneClickAutomation

End-to-end automation stack that provisions short-lived demo environments on AWS with a single Jenkins pipeline. The repo couples Jenkins pipelines, Packer image builds, and Terraform modules so backend, database, and frontend infrastructure can be created (and later destroyed) in minutes.

## Highlights
- **One-click environments** – Jenkins parameters (`NAME`, `RDS_ENDPOINT`, `BE_BRANCH_NAME`, `FE_BRANCH_NAME`) control everything from the database snapshot to the frontend branch.
- **Immutable backend** – Packer builds a Laravel-ready AMI that bakes secrets into `rc.local`, ensuring every EC2 instance launches with the right code branch.
- **Full AWS footprint** – Terraform modules manage RDS snapshots, EC2 spot capacity behind an Auto Scaling Group, Route53 DNS, a per-environment Elastic IP, and an S3 website for the SPA frontend.
- **Lifecycle aware** – A companion Jenkins pipeline tears down EC2, S3, RDS, AMIs, snapshots, and DynamoDB entries when the environment is no longer needed.

## Repository Layout

```
.
├── jenkins/
│   ├── dev-deployment/Jenkinsfile   # Creates RDS (optional), builds AMI, deploys backend + frontend, stores metadata
│   └── dev-deletion/Jenkinsfile     # Deregisters AMIs, destroys Terraform stacks, cleans DynamoDB
├── packer/
│   └── build.pkr.hcl               # Amazon EBS builder + rc.local bootstrapper for the Laravel backend
└── terraform/
    ├── EC2-S3/                     # EC2 launch template, ASG, EIP, Route53, and S3 static hosting
    └── RDS/                        # Clones production snapshot into a sandbox RDS instance
```

## Workflow Overview
1. **Database (optional)** – If `RDS_ENDPOINT=Production`, Terraform clones a production snapshot into a staging RDS instance and seeds user data. Otherwise, the pipeline reuses the shared dev database.
2. **Backend AMI** – Packer builds an image using the branch supplied via `BE_BRANCH_NAME`, writing environment variables and deployment commands to `/etc/rc.local`.
3. **Infrastructure deploy** – Terraform (`terraform/EC2-S3`) allocates an Elastic IP, Route53 record, launch template, Auto Scaling Group, and a timestamped S3 bucket/website for the frontend.
4. **Frontend build** – A Dockerized Node toolchain clones the frontend repo (`FE_BRANCH_NAME`), injects outputs from Terraform, builds, and uploads the SPA to the S3 bucket.
5. **Bookkeeping** – The environment name is stored in DynamoDB for quick lookup, and Jenkins logs include EIP, API URL, and frontend distribution URL.
6. **Deletion** – The `dev-deletion` pipeline reverses the process: destroys RDS (if created), deregisters the AMI, deletes snapshots, tears down Terraform resources, and removes the DynamoDB entry.

## Deployment Flow

```
┌────────────────────┐
│ Jenkins (dev-deploy│
│ ment pipeline)     │
└────────┬───────────┘
         │ parameters drive NAME / branches / RDS mode
         ▼
┌──────────────────────────────┐
│ Stage: Database Creation     │──► optional Terraform in terraform/RDS clones snapshot
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Stage: Backend Deployment    │
│  • Packer builds AMI         │
│  • Terraform EC2-S3 module   │──► Launch template + ASG + Elastic IP + Route53
│  • EC2 instances (backend)   │      → Backend reachable at `${NAME}-api.<root_domain>`
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Stage: Frontend Deployment   │
│  • Dockerized Node build     │
│  • Upload static files to S3 │──► `s3://${NAME}-timestamp-${suffix}` served via S3 website endpoint
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Stage: DynamoDB Registration │──► stores `${NAME}` for environment tracking
└──────────────────────────────┘
```

Backend workloads run on spot-backed EC2 instances in an Auto Scaling Group behind a dedicated Elastic IP/DNS record. Frontend assets are hosted from the timestamped S3 bucket (static website hosting), so new deployments receive a unique URL while sharing the same backend API.

## Jenkins Pipelines

### Parameters
| Name | Type | Description |
| --- | --- | --- |
| `NAME` | String | Unique environment label used across Terraform, Packer, S3, and DynamoDB. |
| `RDS_ENDPOINT` | Choice (`Production`/`Development`) | Whether to clone a production snapshot or reuse the shared dev DB. |
| `BE_BRANCH_NAME` | String | Backend Git branch baked into the AMI. |
| `FE_BRANCH_NAME` | String | Frontend Git branch built for the S3 site. |

### Credentials used in Jenkins

| ID | Type | Purpose |
| --- | --- | --- |
| `github-credentials` | Username/Password (or PAT) | Clone infrastructure + backend/frontend repositories. |
| `rds-credentials` | Username/Password | MySQL connectivity for seeding users/passwords. |
| `USER_PASSWORD` | Secret text | Password injected into staging users. |
| `APP_KEY`, `DB_HOST`, `SPARKPOST_SECRET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUGSNAG_API_KEY`, `FCM_SERVER_KEY`, `STRIPE_KEY`, `STRIPE_SECRET` | Secret text | Laravel `.env` material passed to Packer. |

⚠️ **Tip:** Store environment-specific secrets in Jenkins credentials; the repository never hardcodes them. For local runs, use `terraform.tfvars` / `packer auto.var` files that remain untracked.

## Terraform Modules

### `terraform/EC2-S3`
- **Launch template & ASG** – Spot instances launched from the Packer AMI, with user data rendered from `user_data.tpl` to attach an Elastic IP and update Route53 records automatically.
- **Networking** – Elastic IP `aws_eip.dev` is allocated per environment and used in both DNS and pipeline outputs.
- **S3 static hosting** – Buckets are timestamped (`<name>-<timestamp>-<suffix>`) with versioning enabled and a website configuration tailored for SPA routing.
- **Outputs** – Exposes `public_ip`, `s3_url`, and `s3_name` so Jenkins can announce the deployed endpoints.

Required variables (see `variables.tf`):
- `route53_zone_id`, `root_domain`, `frontend_bucket_suffix`, `iam_profile`, `image_id`, `instance_type`, `key_name`, `vpc_security_group_ids`, `subnets`, `aws_region`.

Example plan:

```bash
cd terraform/EC2-S3
terraform init -backend-config=backend.conf
terraform plan -var-file=staging.tfvars
```

### `terraform/RDS`
- Creates an on-demand snapshot of the production instance (`trainingamigo-prod`) and launches a sandbox RDS instance from it.
- Security groups and subnet groups are parameterized via `staging.tfvars` so the cloned DB lives inside private subnets.

```bash
cd terraform/RDS
terraform init -backend-config=backend.conf
terraform apply -var-file=staging.tfvars -var="name=demo"
```

## Packer Image (`packer/build.pkr.hcl`)
- Uses the `amazon-ebs` builder to create a Laravel-ready AMI based on Ubuntu.
- Writes all application configuration into `/etc/rc.local` via a heredoc (no more fragile `echo` chains).
- Accepts secrets (DB creds, Stripe, SparkPost, etc.) as variables—supply them with `-var` or `auto.pkrvars.hcl` files.

Validation/build example:

```bash
cd packer
packer init .
packer validate -var "AMI_NAME=demo-ami" build.pkr.hcl
packer build \
  -var "AMI_NAME=demo-ami" \
  -var "BE_BRANCH_NAME=main" \
  -var "APP_KEY=..." \
  build.pkr.hcl
```

## Making It Public
- **Secrets** – All sensitive values now flow through Jenkins credentials, `staging.tfvars`, or runtime vars. Avoid committing real IDs by keeping tfvars files generic (as in the repo) and storing live values in your CI/CD secrets manager.
- **Docs** – This README plus inline code comments explain the moving parts; add architecture diagrams or screenshots of the Jenkins pipeline before publishing.
- **License** – Choose a license (MIT/Apache-2.0/etc.) and commit a `LICENSE` file so others know how they can use the project.

## Getting Started Locally
1. Install **Terraform ≥ 1.5**, **Packer ≥ 1.9**, **AWS CLI v2**, and **Node 18+** (for frontend builds).
2. Configure AWS credentials with permissions for EC2, RDS, Route53, DynamoDB, and S3.
3. Update `terraform/**/backend.conf` with your remote state bucket/key, or remove the backend if you prefer local state.
4. Create sanitized `staging.tfvars` / `auto.pkrvars.hcl` files mirroring production inputs.
5. Run the Terraform modules, build the AMI with Packer, then point Jenkins (or `terraform apply`) at the outputs to spin up an environment.

## Validation Checklist
- `packer fmt -check` and `packer validate` succeed.
- `terraform fmt` + `terraform validate` + `terraform plan` succeed in both modules.
- Jenkins pipelines run end-to-end, producing the expected Route53 record, backend IP, and S3 URL in their logs.
- `dev-deletion` pipeline returns the AWS account to a clean state (no orphaned EIPs, AMIs, snapshots, or DynamoDB items).

## Contributing
1. Fork the repo and create a feature branch.
2. Keep Terraform, Packer, and Jenkins changes isolated with clear commits.
3. Run `terraform fmt`, `packer fmt`, and any relevant tests before opening a PR.
4. Document new parameters or credentials in this README.

## License
No license file is included yet. Pick an open-source license before making the repository public so others understand how they can consume and contribute to OneClickAutomation.
