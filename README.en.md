# cloud-native-security-terraform-validation-pipeline · Cloud-Native Security Terraform Validation Pipeline

![License: MIT-0](https://img.shields.io/badge/License-MIT--0-blue.svg)
![Huawei Cloud](https://img.shields.io/badge/Cloud-HuaweiCloud-red.svg)

## 1. Overview

### Overview

This practice demonstrates how to build a Terraform IaC security validation pipeline using [Checkov](https://github.com/bridgecrewio/checkov) to scan Terraform plans for security issues before infrastructure changes are deployed. Designed for DevOps teams that need an IaC security compliance gate in their CI/CD pipeline.

---

## 2. Table of Contents

- [1. Overview](#1-overview)
- [2. Table of Contents](#2-table-of-contents)
- [3. Architecture Diagram](#3-architecture-diagram)
- [4. Highlights](#4-highlights)
- [5. Cloud Services Used](#5-cloud-services-used)
- [6. Prerequisites](#6-prerequisites)
- [7. Quick Start](#7-quick-start)
- [8. Step-by-Step Deployment](#8-step-by-step-deployment)
- [9. Usage / Verification](#9-usage--verification)
- [10. Cleanup](#10-cleanup)
- [11. Detailed Explanation](#11-detailed-explanation)
- [12. Dependencies](#12-dependencies)
- [13. FAQ / Troubleshooting](#13-faq--troubleshooting)
- [14. Contributing](#14-contributing)
- [15. License](#15-license)
- [16. Contact / Maintainers](#16-contact--maintainers)

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- `infra/state/` — Terraform state backend (OBS bucket)
- `infra/pipeline/` — CI/CD pipeline infrastructure
- `infra/initial_code/` — Pre-remediation baseline network code
- `infra/updated_code/` — Post-remediation hardened network code
- `src/functions/` — FunctionGraph notification function

---

## 3. Architecture Diagram

```
Source(CodeArts Repo) → Validate(terraform plan + checkov) → Approve(SMN) → Deploy(terraform apply)
```

On validation failure, a CES alarm triggers a FunctionGraph function that reads scan results from OBS and sends an email notification via SMN.

See [Architecture](docs/architecture.md) for details.

---

## 4. Highlights

- **Shift-left security**: Security scanning at the plan stage (before deployment), not post-deployment audit
- **Automated gate**: Checkov scan results serve as a pipeline gate — non-compliant changes cannot pass
- **Remediation demo**: Pre/post-remediation IaC code pairs demonstrate the full security hardening workflow
- **Event-driven notification**: Build failures automatically trigger email notifications, no manual polling required

---

## 5. Cloud Services Used

| Service | Purpose |
|---|---|
| CodeArts | Code repository + build execution + pipeline orchestration |
| OBS | Validation result storage + Terraform state backend |
| SMN | Approval notification + validation failure notification |
| FunctionGraph | Validation failure email notification function |
| CES | Build failure event alarm |
| IAM | Service agency and permission management |
| KMS | VPC Flow Logs encryption |
| LTS | VPC Flow Logs log storage |
| VPC | Base network (remediation demo carrier) |

Resource cleanup: `terraform destroy` (see the deployment guide)

---

## 6. Prerequisites

1. Huawei Cloud account with CodeArts, OBS, SMN, FunctionGraph, CES, KMS, LTS enabled
2. Terraform >= 1.5 installed
3. Huawei Cloud CLI or obsutil installed with AK/SK configured
4. Default region cn-north-4, adjustable as needed

---

## 7. Quick Start

```bash
# 1. Create state backend
cd infra/state
terraform init && terraform apply

# 2. Deploy pipeline infrastructure
cd ../pipeline
terraform init && terraform apply

# 3. Push IaC code to CodeArts repo, pipeline triggers automatically
```

See the [Deployment Guide](docs/deployment-guide.md) for details.

---

## 8. Step-by-Step Deployment

Detailed steps are in the [Deployment Guide](docs/deployment-guide.md); the core flow is:

1. Create the Terraform state backend: `cd infra/state`, edit `terraform.tfvars` with the OBS bucket name, then run `terraform init && terraform apply`.
2. Deploy the CI/CD pipeline infrastructure: `cd infra/pipeline`, configure `terraform.tfvars` parameters (domain_name, codearts_project_name, codearts_repository_name, validation_result_bucket_name, pipeline_artifact_bucket_name, smn_topic_name, email_notification_endpoint, functiongraph_agency_name), then run init, plan, and apply.
3. Upload the FunctionGraph function code: `cd src/functions`, package `send_notification.py` and upload it to the validation-result OBS bucket.
4. In the CodeArts console, create a pipeline, import `infra/pipeline/pipeline.yaml`, configure the `VALIDATION_RESULT_BUCKET` and `SMN_TOPIC_NAME` environment variables and build scripts.
5. Push `infra/initial_code/` or `infra/updated_code/` to the CodeArts repository; the pipeline triggers automatically.

---

## 9. Usage / Verification

### Usage

This practice triggers the pipeline by pushing IaC code to the CodeArts repository (Source → Validate(Checkov) → Approve → Deploy); see the remediation demo and verification steps below.

### Remediation Demo

1. Push `infra/initial_code/` to the CodeArts repository
2. The pipeline Validate stage runs Checkov and detects security issues (no Flow Logs, no KMS encryption, etc.)
3. Apply Checkov recommendations to produce the hardened version in `infra/updated_code/`
4. Push again — Checkov scan passes, pipeline proceeds to approval → deploy

### Verification

```bash
# List validation results in OBS
obsutil ls obs://your-validation-result-bucket/
# View Checkov scan results
obsutil cp obs://your-validation-result-bucket/checkov_output.txt ./
cat checkov_output.txt
```

After deployment, follow these steps to verify that the business functionality works before considering the delivery complete.

---

## 10. Cleanup

```bash
cd infra/pipeline && terraform destroy
cd infra/state && terraform destroy
```

---

## 11. Detailed Explanation

See [Architecture](docs/architecture.md) and the [Deployment Guide](docs/deployment-guide.md).

---

## 12. Dependencies

| Dependency | Version |
|---|---|
| Terraform | >= 1.5 |
| huaweicloud Provider | ~> 1.70 |
| Checkov | latest |

---

## 13. FAQ / Troubleshooting

- **Checkov scan fails**: check `checkov_output.txt` in the validation-result OBS bucket, remediate the IaC code per the recommendations, then push again.
- **Pipeline does not trigger**: check the CodeArts repository and pipeline source configuration; confirm the correct repository is linked.
- **Email notification not received**: check the SMN topic's email subscription and the FunctionGraph function logs.

---

## 14. Contributing

Issues and pull requests are welcome to help improve this practice.

---

## 15. License

This practice is licensed under the MIT No Attribution license.

---

## 16. Contact / Maintainers
| Item | Content |
|---|---|
| **Creator** | [dgc-git](https://github.com/dgc-git) |
| **Maintainer** | [dgc-git](https://github.com/dgc-git) |
| **Contact** | GitHub Issues / PR (see [Section 14](#14-contributing)) |
