# secure-terraform-pipeline

> A production-grade Terraform pipeline for AWS infrastructure with automated security scanning, policy enforcement, integration testing, drift detection, and zero static credentials.

[![CI](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/ci.yml)
[![CD](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/cd.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/cd.yml)
[![Drift Detection](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/drift-detection.yml/badge.svg)](https://github.com/shilucloud/secure-terraform-pipeline/actions/workflows/drift-detection.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Toolchain](#toolchain)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [OPA Policy Enforcement](#opa-policy-enforcement)
- [Integration Tests](#integration-tests)
- [CI/CD Workflows](#cicd-workflows)
- [Drift Detection](#drift-detection)
- [Required GitHub Secrets](#required-github-secrets)
- [Task Reference](#task-reference)

---

## Overview

This repository demonstrates a fully automated, security-hardened Terraform pipeline designed for teams that need confidence at every stage of infrastructure delivery. It combines static analysis, policy-as-code, integration testing against a local AWS emulator, and nightly drift remediation — all without a single static credential.

**Key properties:**

- **Zero static credentials** — OIDC-based authentication for all AWS interactions in CI/CD
- **Shift-left security** — Checkov and OPA policies run on every pull request before any real infrastructure is touched
- **Reproducible environments** — Nix pins every tool version; no "works on my machine" issues
- **Safe testing** — Integration tests run against LocalStack Pro, not real AWS
- **Automated drift remediation** — Nightly checks detect and optionally correct configuration drift

---

## Architecture

### Pull Request Pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Pull Request                                │
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌─────────────┐    ┌────────────┐  │
│  │  fmt  +  │    │ Checkov  │    │  Conftest   │    │ Terratest  │  │
│  │  tflint  │ →  │ Security │ →  │ OPA Policy  │ →  │    E2E     │  │
│  └──────────┘    └──────────┘    └─────────────┘    └────────────┘  │
│                          (LocalStack Pro)                            │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ merge to main
                                   ▼
```

### CD Pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│                           CD Pipeline                                │
│                                                                      │
│   OIDC Auth → terraform plan → Manual Approval → terraform apply     │
│                          (real AWS)                                  │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ every night at 2 AM
                                   ▼
```

### Drift Detection

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Drift Detection                              │
│                                                                      │
│  terraform plan --refresh-only                                       │
│       → drift found? → Open GitHub Issue                             │
│                      → Manual Approval → terraform apply             │
│       → no drift?   → Pass silently                                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Toolchain

| Tool | Purpose |
|---|---|
| **Nix** | Reproducible, pinned dev environment via `nixpkgs` commit hash |
| **LocalStack Pro** | Local AWS emulation (S3, STS) for safe integration testing |
| **Terraform** | Infrastructure as Code — provisions AWS S3 resources |
| **tflocal** | Terraform wrapper that redirects API calls to LocalStack |
| **Checkov** | Static security analysis; hard-fails on HIGH/CRITICAL findings |
| **Conftest + OPA** | Custom policy enforcement via Rego |
| **Terratest** | Go-based integration and end-to-end tests |
| **tflint** | Terraform linter |
| **actionlint** | GitHub Actions workflow linter |
| **hadolint** | Dockerfile linter |
| **Renovate** | Automated dependency update PRs |
| **act** | Run GitHub Actions workflows locally |
| **Task** | Developer task runner |

---

## Project Structure

```
secure-terraform-pipeline/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # PR validation against LocalStack
│       ├── cd.yml                  # Production deploy to real AWS
│       ├── drift-detection.yml     # Nightly drift detection + remediation
│       ├── actionlint.yml          # Lint GitHub Actions workflow files
│       ├── dockerlint.yml          # Lint Dockerfile
│       └── dependency-review.yml
│
├── infrastructure/
│   ├── envs/
│   │   ├── aws.backend             # Real AWS S3 backend config
│   │   └── localstack.backend      # LocalStack backend config
│   ├── main.tf                     # S3 bucket with versioning + encryption
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── terraform.tf
│
├── policy/
│   ├── bucketname_starting_with.rego   # Bucket must start with 'company-'
│   ├── private_bucket_only.rego        # No public ACLs allowed
│   ├── required_tags.rego              # Owner + Environment tags required
│   └── versioning_enabled.rego         # S3 versioning must be Enabled
│
├── test/
│   ├── s3_bucket_test.go           # Validates Terraform output values
│   └── e2e_test.go                 # Uploads + reads back file from S3
│
├── localstack/
│   └── localstack-compose.yml
├── objects/
│   └── s3_test_object.txt          # Test file used in E2E test
├── shell.nix                       # Context-aware Nix shell definition
├── Taskfile.yml                    # Developer task shortcuts
└── renovate.json                   # Automated dependency update config
```

---

## Getting Started

### Prerequisites

- [Nix](https://nixos.org/download)
- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev/installation/)
- A [LocalStack Pro auth token](https://app.localstack.cloud/)

### First-Time Setup

```bash
# 1. Install Nix
task download

# 2. Set required environment variables
export BUCKET_NAME="company-your-bucket-name"
export LOCALSTACK_AUTH_TOKEN="your-localstack-pro-token"

# 3. Enter Nix shell — all tools installed automatically at pinned versions
task setup
```

> **Note:** First-time setup takes 15–20 minutes while Nix downloads and builds all tools. Every subsequent run completes in under 2 minutes thanks to the Nix store cache.

### Daily Development Workflow

```bash
task localstack-up      # Start LocalStack (emulated AWS at localhost:4566)
task tflocal-init       # Initialize Terraform against LocalStack
task tflocal-apply      # Deploy to LocalStack
task scan               # Run Checkov + Conftest security checks
task test               # Run all Terratest integration tests
task localstack-down    # Tear down LocalStack
```

### Run Individual Tests

```bash
task test-s3    # S3 bucket output validation only
task test-e2e   # End-to-end file upload + read-back only
```

### Simulate the Full CI Pipeline Locally

```bash
# Copy and populate the example secrets file
cp .secrets.env.example .secrets.env

# Run the full CI pipeline locally via act
task act-terraform
```

---

## OPA Policy Enforcement

Four Rego policies are evaluated against the Terraform plan JSON on every pull request. All four must pass before a PR can be merged.

| Policy File | Rule |
|---|---|
| `bucketname_starting_with.rego` | Bucket name must begin with `company-` |
| `private_bucket_only.rego` | Public-read ACLs are not permitted |
| `required_tags.rego` | `Owner` and `Environment` tags required on all resources |
| `versioning_enabled.rego` | S3 versioning must be set to `Enabled` |

---

## Integration Tests

Two Terratest suites live in `test/`:

**`s3_bucket_test.go`** — Deploys to LocalStack and asserts that all three Terraform outputs (`bucket_id`, `bucket_arn`, `bucket_domain_name`) are present and correctly formatted.

**`e2e_test.go`** — Deploys to LocalStack, uploads a real file to the provisioned bucket, reads it back, verifies the content matches, empties all object versions, then destroys the infrastructure. No real AWS resources or costs involved.

---

## CI/CD Workflows

### CI (`ci.yml`)

Triggers on pull requests to `main` when `infrastructure/`, `policy/`, or `test/` files change.

```
Restore Nix cache
  → terraform fmt + tflint
  → tflocal init + plan → tfplan.json
  → Checkov (hard-fail on HIGH/CRITICAL)
  → Conftest OPA policy checks
  → Terratest suite (30-minute timeout)
  → Post PR summary comment with artifact links
```

Runs entirely against LocalStack Pro — no real AWS access, no cost.

### CD (`cd.yml`)

Triggers on push to `main` when `infrastructure/` files change.

```
OIDC authentication (no static credentials)
  → terraform init (real AWS backend)
  → terraform plan → upload plan artifact
  → Manual approval gate
  → terraform apply
```

---

## Drift Detection

The `drift-detection.yml` workflow runs nightly at 2 AM.

```
terraform plan --refresh-only -detailed-exitcode
  → Drift detected  → Open GitHub Issue + mark workflow red
                    → Trigger auto-remediation job
                    → Full terraform plan → Manual approval
                    → terraform apply
                    → Auto-close the drift issue
  → No drift        → Pass silently
```

---

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `TF_VAR_BUCKET_NAME` | Target S3 bucket name |
| `TF_VAR_AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `TF_VAR_ENABLE_VERSIONING` | `true` or `false` |
| `TF_VAR_ENV` | Environment name (e.g. `prod`) |
| `TF_VAR_TAGS` | Additional resource tags as JSON |
| `AWS_ROLE_ARN_S3_ACCESS` | IAM role ARN for CD and drift remediation |
| `AWS_ROLE_ARN_FULL_ACCESS` | IAM role ARN for drift detection |
| `LOCALSTACK_AUTH_TOKEN` | LocalStack Pro authentication token |
| `PAT_TOKEN` | GitHub Personal Access Token for manual approval gates |

---

## Task Reference

```bash
# Environment
task download            # Install Nix
task setup               # Update backend configs and enter Nix shell

# LocalStack
task localstack-up       # Start LocalStack Pro
task localstack-down     # Stop LocalStack

# Terraform (LocalStack)
task tflocal-init        # terraform init → LocalStack
task tflocal-plan        # terraform plan → LocalStack
task tflocal-apply       # terraform apply → LocalStack
task tflocal-destroy     # terraform destroy → LocalStack

# Security Scanning
task checkov             # Run Checkov static analysis
task conftest            # Run Conftest OPA policy checks
task scan                # Run Checkov + Conftest together

# Testing
task test                # Run all Terratest tests
task test-s3             # Run S3 bucket validation test only
task test-e2e            # Run end-to-end test only

# Local CI Simulation (via act)
task act-show            # List all available workflows
task act-terraform       # Run full CI pipeline locally
task act-lint            # Run actionlint workflow locally
task act-dockerlint      # Run Dockerfile lint locally

# Composite Workflows
task dev-local           # Setup → LocalStack → init (ready to develop)
task all-local           # Full pipeline: setup → deploy → scan → test
task ci-local            # Simulate complete CI via act
```

---

## Related

- 📝 **Blog post:** [Building a Secure, Testable, and Reproducible Terraform Pipeline](https://medium.com/aws-in-plain-english/building-a-secure-testable-and-reproducible-terraform-pipeline-with-terratest-localstack-661356d0cd59)
- 📦 **LocalStack Pro:** [localstack.cloud](https://localstack.cloud)
- 🔍 **Checkov:** [checkov.io](https://www.checkov.io)
- 📜 **OPA / Conftest:** [conftest.dev](https://www.conftest.dev)
- 🧪 **Terratest:** [terratest.gruntwork.io](https://terratest.gruntwork.io)

---

## License

This project is licensed under the [MIT License](LICENSE).