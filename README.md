# cloud-native-security-terraform-validation-pipeline · Cloud-Native Security Terraform Validation Pipeline

![License: MIT-0](https://img.shields.io/badge/License-MIT--0-blue.svg)
![Huawei Cloud](https://img.shields.io/badge/Cloud-HuaweiCloud-red.svg)

## 1. 简介 / Overview

### 简介


本实践演示如何构建 Terraform IaC 安全验证流水线，使用 [Checkov](https://github.com/bridgecrewio/checkov) 对 Terraform plan 进行安全扫描，在基础设施变更部署前拦截不合规配置。适用于需要在 CI/CD 中引入 IaC 安全合规门禁的 DevOps 团队。

---

## 2. 目录

- [1. 简介 / Overview](#1-简介--overview)
- [2. 目录](#2-目录)
- [3. 架构图](#3-架构图)
- [4. 方案亮点](#4-方案亮点)
- [5. 涉及云服务](#5-涉及云服务)
- [6. 前置条件](#6-前置条件)
- [7. 快速开始](#7-快速开始)
- [8. 分步部署](#8-分步部署)
- [9. 使用方法 / 验证](#9-使用方法--验证)
- [10. 清理资源](#10-清理资源)
- [11. 详细说明](#11-详细说明)
- [12. 依赖](#12-依赖)
- [13. FAQ / 故障排除](#13-faq--故障排除)
- [14. 贡献指南](#14-贡献指南)
- [15. 许可证](#15-许可证)
- [16. 联系方式 / 维护者](#16-联系方式--维护者)


- [架构说明](docs/architecture.md)
- [部署指导书](docs/deployment-guide.md)
- `infra/state/` — Terraform 状态后端（OBS 桶）
- `infra/pipeline/` — CI/CD 流水线基础设施
- `infra/initial_code/` — 整改前基础网络代码
- `infra/updated_code/` — 整改后安全加固网络代码
- `src/functions/` — FunctionGraph 通知函数

---

## 3. 架构图

```
Source(CodeArts Repo) → Validate(terraform plan + checkov) → Approve(SMN) → Deploy(terraform apply)
```

验证失败时，CES 告警触发 FunctionGraph 函数，从 OBS 读取扫描结果并通过 SMN 发送邮件通知。

详见 [架构说明](docs/architecture.md)。

---

## 4. 方案亮点

- **安全左移**：在部署前（plan 阶段）即执行安全扫描，而非部署后审计
- **自动化门禁**：Checkov 扫描结果作为流水线门禁，不合规变更无法通过
- **整改演示**：提供整改前/后两组 IaC 代码，完整展示安全加固流程
- **事件驱动通知**：构建失败自动触发邮件通知，无需人工轮询

---

## 5. 涉及云服务

| 服务 | 用途 |
|---|---|
| CodeArts | 代码仓库 + 构建执行 + 流水线编排 |
| OBS | 验证结果存储 + Terraform 状态后端 |
| SMN | 审批通知 + 验证失败通知 |
| FunctionGraph | 验证失败邮件通知函数 |
| CES | 构建失败事件告警 |
| IAM | 服务委托与权限管理 |
| KMS | VPC Flow Logs 加密 |
| LTS | VPC Flow Logs 日志存储 |
| VPC | 基础网络（整改演示载体） |

清理资源：`terraform destroy`（详见部署指导书）

---

## 6. 前置条件

1. 华为云账号已开通 CodeArts、OBS、SMN、FunctionGraph、CES、KMS、LTS 服务
2. 已安装 Terraform >= 1.5
3. 已安装华为云 CLI 或 obsutil 并配置 AK/SK
4. 默认区域 cn-north-4，可按需修改

---

## 7. 快速开始

```bash
# 1. 创建状态后端
cd infra/state
terraform init && terraform apply

# 2. 部署流水线基础设施
cd ../pipeline
terraform init && terraform apply

# 3. 推送 IaC 代码到 CodeArts 仓库，流水线自动触发
```

详见 [部署指导书](docs/deployment-guide.md)。

---

## 8. 分步部署

详细步骤请参考 [部署指导书](docs/deployment-guide.md)，核心流程如下：

1. 创建 Terraform 状态后端：`cd infra/state`，编辑 `terraform.tfvars` 填入 OBS 桶名，执行 `terraform init && terraform apply`。
2. 部署 CI/CD 流水线基础设施：`cd infra/pipeline`，配置 `terraform.tfvars` 参数（domain_name、codearts_project_name、codearts_repository_name、validation_result_bucket_name、pipeline_artifact_bucket_name、smn_topic_name、email_notification_endpoint、functiongraph_agency_name），执行初始化、plan 与 apply。
3. 上传 FunctionGraph 函数代码：`cd src/functions`，打包 `send_notification.py` 并上传至验证结果 OBS 桶。
4. 在 CodeArts 控制台新建流水线，导入 `infra/pipeline/pipeline.yaml`，配置 `VALIDATION_RESULT_BUCKET`、`SMN_TOPIC_NAME` 环境变量及构建脚本。
5. 将 `infra/initial_code/` 或 `infra/updated_code/` 推送到 CodeArts 仓库，流水线自动触发。

---

## 9. 使用方法 / 验证

### 使用方法

本实践通过向 CodeArts 仓库推送 IaC 代码触发流水线（Source → Validate(Checkov) → Approve → Deploy），详见下方整改演示与验证步骤。

### 整改演示

1. 将 `infra/initial_code/` 推送到 CodeArts 仓库
2. 流水线 Validate 阶段运行 Checkov，发现安全问题（无 Flow Logs、无 KMS 加密等）
3. 根据 Checkov 建议修改为 `infra/updated_code/` 中的加固版本
4. 再次推送，Checkov 扫描通过，流水线进入审批 → 部署阶段

### 验证

```bash
# 查看 OBS 中的验证结果
obsutil ls obs://your-validation-result-bucket/
# 查看 Checkov 扫描结果
obsutil cp obs://your-validation-result-bucket/checkov_output.txt ./
cat checkov_output.txt
```

部署完成后请按本节步骤自行验证，确认业务功能可用，方可视为交付完成。

---

## 10. 清理资源

```bash
cd infra/pipeline && terraform destroy
cd infra/state && terraform destroy
```

---

## 11. 详细说明

详见 [架构说明](docs/architecture.md) 和 [部署指导书](docs/deployment-guide.md)。

---

## 12. 依赖

| 依赖 | 版本 |
|---|---|
| Terraform | >= 1.5 |
| huaweicloud Provider | ~> 1.70 |
| Checkov | latest |

---

## 13. FAQ / 故障排除

- **Checkov 扫描失败**：查看 OBS 验证结果桶中的 `checkov_output.txt`，按建议整改 IaC 代码后重新推送。
- **流水线未触发**：检查 CodeArts 仓库与流水线的源配置，确认已关联正确仓库。
- **邮件通知未收到**：检查 SMN 主题的邮件订阅与 FunctionGraph 函数日志。

---

## 14. 贡献指南

欢迎提交 Issue 和 Pull Request，共同完善本实践。

---

## 15. 许可证

本实践采用 MIT No Attribution 许可证。

---

## 16. 联系方式 / 维护者
| 项 | 内容 |
|---|---|
| **创建者** | [dgc-git](https://github.com/dgc-git) |
| **维护者** | [dgc-git](https://github.com/dgc-git) |
| **联系方式** | GitHub Issues / PR（见[第 14 节](#14-贡献指南)） |
