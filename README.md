# 🔐 secure-terraform-pipeline

> A production-grade, secure, testable, and reproducible Terraform pipeline for AWS infrastructure — with automated security scanning, policy enforcement, integration testing, drift detection, and zero static credentials.

[![CI](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/ci.yml)
[![CD](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/cd.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/cd.yml)
[![Drift Detection](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/drift-detection.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/drift-detection.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 Blog Post

Full writeup: [Building a Secure, Testable, and Reproducible Terraform Pipeline](https://medium.com/@shilucloud)

---

## 🏗 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Pull Request                             │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌────────────┐  │
│  │  fmt +   │  │ Checkov  │  │  Conftest   │  │ Terratest  │  │
│  │  tflint  │→ │ Security │→ │ OPA Policy  │→ │    E2E     │  │
│  └──────────┘  └──────────┘  └─────────────┘  └────────────┘  │
│                       (LocalStack Pro)                          │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ merge to main
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CD Pipeline                                │
│                                                                 │
│   OIDC Auth → terraform plan → Manual Approval → terraform apply│
│                     (real AWS)                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  │ every night 2 AM
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Drift Detection                               │
│                                                                 │
│  terraform plan --refresh-only → drift found? → GitHub Issue   │
│                                             → Manual Approval  │
│                                             → terraform apply  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠 Toolchain

| Tool | Purpose |
|---|---|
| [Nix](https://nixos.org) | Reproducible, context-aware dev environment — pinned nixpkgs commit |
| [LocalStack Pro](https://localstack.cloud) | Emulates AWS S3 + STS locally for safe testing |
| [Terraform](https://terraform.io) | Infrastructure as Code — provisions AWS S3 bucket |
| [tflocal](https://github.com/localstack/terraform-local) | Terraform wrapper that redirects API calls to LocalStack |
| [Checkov](https://checkov.io) | Static security analysis — hard-fails on HIGH/CRITICAL |
| [Conftest + OPA](https://conftest.dev) | Custom policy enforcement via Rego |
| [Terratest](https://terratest.gruntwork.io) | Go-based integration tests with real file I/O |
| [tflint](https://github.com/terraform-linters/tflint) | Terraform linter |
| [actionlint](https://github.com/rhysd/actionlint) | GitHub Actions workflow linter |
| [hadolint](https://github.com/hadolint/hadolint) | Dockerfile linter |
| [Renovate](https://docs.renovatebot.com) | Automated dependency updates |
| [act](https://github.com/nektos/act) | Run GitHub Actions workflows locally |
| [Task](https://taskfile.dev) | Developer task runner |

---

## 📁 Project Structure

```
secure-terraform-pipeline/
├── .github/
│   └── workflows/
│       ├── ci.yml               # PR validation against LocalStack
│       ├── cd.yml               # Production deploy to AWS
│       ├── drift-detection.yml  # Nightly drift detection + remediation
│       ├── actionlint.yml       # Lint workflow YAML files
│       ├── dockerlint.yml       # Lint Dockerfile
│       └── dependency-review.yml
├── infrastructure/
│   ├── envs/
│   │   ├── aws.backend          # Real AWS S3 backend config
│   │   └── localstack.backend   # LocalStack backend config
│   ├── main.tf                  # S3 bucket + versioning + encryption
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── terraform.tf
├── policy/
│   ├── bucketname_starting_with.rego  # Bucket must start with 'company-'
│   ├── private_bucket_only.rego       # No public ACLs allowed
│   ├── required_tags.rego             # Owner + Environment tags required
│   └── versioning_enabled.rego        # Versioning must be enabled
├── test/
│   ├── s3_bucket_test.go        # Validates Terraform outputs
│   └── e2e_test.go              # Uploads + reads back file from S3
├── localstack/
│   └── localstack-compose.yml
├── objects/
│   └── s3_test_object.txt       # Test file used in E2E test
├── shell.nix                    # Context-aware Nix shell
├── Taskfile.yml                 # Developer task shortcuts
└── renovate.json                # Automated dependency updates config
```

---

## 🚀 Local Development

### Prerequisites

- [Nix](https://nixos.org/download) 
- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev/installation/)
- LocalStack Pro auth token ([get one here](https://localstack.cloud))

### First Time Setup

```bash
# 1. Install Nix
task download

# 2. Set required environment variables
export BUCKET_NAME="company-your-bucket-name"
export LOCALSTACK_AUTH_TOKEN="your-localstack-pro-token"

# 3. Enter Nix shell — all tools installed automatically at pinned versions
task setup
```

> ⏱ First-time setup takes 15-20 minutes as Nix downloads and builds all tools. Every subsequent run is under 2 minutes thanks to the Nix store cache.

### Daily Development Workflow

```bash
task localstack-up     # start LocalStack (fake AWS at localhost:4566)
task tflocal-init      # init Terraform against LocalStack
task tflocal-apply     # deploy to LocalStack
task scan              # run Checkov + Conftest security checks
task test              # run all Terratest integration tests
task localstack-down   # clean up
```

### Run Individual Tests

```bash
task test-s3    # S3 bucket output validation test only
task test-e2e   # E2E file upload + read-back test only
```

### Simulate the Full CI Pipeline Locally

```bash
# Create .secrets.env with your secrets first
cp .secrets.env.example .secrets.env

# Run the full CI pipeline locally using act
task act-terraform
```

---

## 🔒 OPA Policies

Four custom Rego policies run against the Terraform plan JSON on every PR:

| Policy | Rule |
|---|---|
| `bucketname_starting_with.rego` | Bucket name must start with `company-` |
| `private_bucket_only.rego` | No `public-read` ACLs allowed |
| `required_tags.rego` | `Owner` and `Environment` tags required on all resources |
| `versioning_enabled.rego` | S3 versioning must be `Enabled` |

---

## 🧪 Tests

Two Terratest files in `test/`:

**`s3_bucket_test.go`** — deploys to LocalStack and validates all three Terraform outputs (`bucket_id`, `bucket_arn`, `bucket_domain_name`) are present and correctly formatted.

**`e2e_test.go`** — deploys to LocalStack, uploads a real file to the bucket, reads it back, verifies content, empties all object versions, then destroys infrastructure.

---

## ⚙️ GitHub Actions Workflows

### CI (`ci.yml`)
Triggers on PRs to `main` when `infrastructure/`, `policy/`, or `test/` changes.

```
Setup Nix (CI toolset) → Cache restore
→ terraform fmt + tflint
→ tflocal init + plan → tfplan.json
→ Checkov (hard-fail on HIGH/CRITICAL)
→ Conftest OPA policies
→ Terratest (30 min timeout)
→ PR summary comment with artifact links
```

Runs entirely against **LocalStack Pro** — no real AWS, no cost.

### CD (`cd.yml`)
Triggers on push to `main` when `infrastructure/` changes.

```
OIDC Auth (no static credentials)
→ terraform init (real AWS backend)
→ terraform plan → upload artifact
→ Manual approval gate
→ terraform apply
```

### Drift Detection (`drift-detection.yml`)
Runs nightly at 2 AM.

```
terraform plan --refresh-only -detailed-exitcode
→ drift found? → GitHub issue opened + workflow fails red
→ auto_remediation triggers
→ full terraform plan → Manual approval
→ terraform apply (recreates deleted/modified resources)
→ drift issue auto-closed
```

---

## 🔑 Required GitHub Secrets

| Secret | Description |
|---|---|
| `TF_VAR_BUCKET_NAME` | S3 bucket name |
| `TF_VAR_AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `TF_VAR_ENABLE_VERSIONING` | `true` or `false` |
| `TF_VAR_ENV` | Environment name (e.g. `prod`) |
| `TF_VAR_TAGS` | Additional tags as JSON |
| `AWS_ROLE_ARN_S3_ACCESS` | IAM role ARN for CD and drift remediation |
| `AWS_ROLE_ARN_FULL_ACCESS` | IAM role ARN for drift detection |
| `LOCALSTACK_AUTH_TOKEN` | LocalStack Pro auth token |
| `PAT_TOKEN` | GitHub Personal Access Token for manual approval gates |

---

## 📋 All Available Tasks

```bash
task download          # Install Nix
task setup             # Update backend configs + enter Nix shell
task localstack-up     # Start LocalStack Pro
task localstack-down   # Stop LocalStack
task tflocal-init      # Terraform init → LocalStack
task tflocal-plan      # Terraform plan → LocalStack
task tflocal-apply     # Terraform apply → LocalStack
task tflocal-destroy   # Terraform destroy → LocalStack
task checkov           # Run Checkov security scan
task conftest          # Run Conftest OPA policies
task scan              # Run Checkov + Conftest together
task test              # Run all Terratest tests
task test-s3           # Run S3 bucket test only
task test-e2e          # Run E2E test only
task act-show          # List all available workflows
task act-terraform     # Run full CI pipeline locally
task act-lint          # Run actionlint workflow locally
task act-dockerlint    # Run Dockerfile lint locally
task dev-local         # Setup → LocalStack → init (ready to develop)
task all-local         # Full pipeline: setup → deploy → scan → test
task ci-local          # Simulate CI via act
```

---

## 📄 License

MIT — see [LICENSE](LICENSE)
