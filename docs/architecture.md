# 架构说明

## 概述

本实践演示如何在构建 Terraform IaC 安全验证流水线，使用 Checkov 对 Terraform plan 进行安全扫描，在部署前拦截不合规的基础设施变更。

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    CodeArts Pipeline                         │
│                                                              │
│  ┌──────────┐    ┌──────────────┐    ┌─────────┐    ┌──────┐│
│  │  Source  │───▶│   Validate   │───▶│ Approve │───▶│Deploy││
│  │          │    │              │    │         │    │      ││
│  │ CodeArts │    │ terraform   │    │ Manual  │    │terra-││
│  │ Repo     │    │ plan +      │    │ Approval│    │form  ││
│  │          │    │ checkov     │    │ + SMN   │    │apply ││
│  └──────────┘    └──────┬───────┘    └─────────┘    └──────┘│
│                         │                                    │
│                         ▼                                    │
│              ┌──────────────────┐                            │
│              │  OBS (验证结果)   │                            │
│              │  plan_output.json │                            │
│              │  checkov_output   │                            │
│              └──────────────────┘                            │
└─────────────────────────────────────────────────────────────┘

         ┌──────────────────────────┐
         │    CES 告警规则           │
         │  (构建失败事件监听)        │
         └────────────┬─────────────┘
                      │
                      ▼
         ┌──────────────────────────┐
         │  FunctionGraph 函数       │
         │  (读取 OBS 结果 +         │
         │   SMN 发送邮件通知)       │
         └──────────────────────────┘
```

## 流水线阶段

### 1. Source（源代码）
- **CodeArts Repo**：存储 Terraform IaC 脚本的代码仓库
- 流水线从 main 分支拉取最新代码

### 2. Validate（验证）
- **CodeArts Build**：执行 Terraform 验证构建
- 构建步骤：
  1. 安装 Terraform CLI 和 Checkov
  2. `terraform init` — 初始化后端和 provider
  3. `terraform plan -out plan_output.plan` — 生成执行计划
  4. `terraform show -json plan_output.plan > plan_output.json` — 导出 JSON 格式计划
  5. `checkov -f plan_output.json` — 对计划文件执行安全扫描
  6. 上传 `plan_output.json` 和 `checkov_output.txt` 到 OBS 桶

### 3. Approve-Reject（人工审批）
- 审批者收到 SMN 邮件通知后，查看 OBS 中的验证结果
- 根据 Checkov 扫描结果决定是否批准部署

### 4. Deploy（部署）
- **CodeArts Build**：执行 Terraform 部署构建
- 构建步骤：
  1. 安装 Terraform CLI
  2. `terraform init` — 初始化
  3. `terraform apply --auto-approve` — 应用变更

## 辅助能力

### 验证失败通知
- **CES 告警规则**：监听 CodeArts Build 构建失败事件
- **FunctionGraph 函数**：被 CES 触发后，从 OBS 读取 Checkov 扫描结果，通过 SMN 发送邮件通知

## 整改演示

本实践包含两组 IaC 代码，演示 Checkov 安全扫描的整改流程：

### initial_code（整改前）
- 基础 VPC + 4 子网
- 缺少安全加固：无 Flow Logs、无 KMS 加密、子网映射公网 IP

### updated_code（整改后）
- VPC + 4 子网 + 安全加固
- KMS 密钥加密 VPC Flow Logs
- LTS 日志组存储 VPC Flow Logs
- 显式安全组定义（不依赖默认安全组）
- 移除子网公网 IP 映射

## 涉及云服务

| 服务 | 用途 |
|---|---|
| CodeArts（Repo/Build/Pipeline） | 代码仓库 + 构建执行 + 流水线编排 |
| OBS | 验证结果存储 + 流水线构件存储 + Terraform 状态后端 |
| SMN | 审批通知 + 验证失败通知 |
| FunctionGraph | 验证失败邮件通知函数 |
| CES | 构建失败事件告警 |
| IAM | 服务委托与权限管理 |
| KMS | VPC Flow Logs 加密密钥 |
| LTS | VPC Flow Logs 日志存储 |
| VPC | 基础网络（整改演示载体） |
