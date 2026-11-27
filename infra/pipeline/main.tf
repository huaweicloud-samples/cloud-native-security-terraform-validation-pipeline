# ============================================================================
# CI/CD 流水线基础设施：CodeArts + OBS + SMN + FunctionGraph + CES + IAM
# ============================================================================
# 流水线四阶段：Source → Validate(Checkov) → Approval → Deploy
#
# Source:      CodeArts Repo（代码仓库）
# Validate:    CodeArts Build（terraform plan + checkov 安全扫描）
# Approval:    SMN 邮件通知 + 人工审批
# Deploy:      CodeArts Build（terraform apply）
#
# 辅助能力：
# - OBS 桶存储验证结果（plan_output.json + checkov_output.txt）
# - OBS 桶存储流水线构件
# - FunctionGraph 函数：构建失败时发送邮件通知
# - CES 告警规则：监听构建失败事件并触发通知函数
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

#   backend "s3" {
#     endpoint = "https://obs.cn-north-4.myhuaweicloud.com"
#     bucket   = "your-tfstate-bucket-name"
#     key      = "pipeline/terraform.tfstate"
#     region   = "cn-north-4"
#   }
}

# provider "huaweicloud" {
#   region = var.region
# }

# ============================================================================
# 1. CodeArts 项目 + 代码仓库
# ============================================================================

resource "huaweicloud_codearts_project" "main" {
  name        = var.codearts_project_name
  description = "Terraform IaC 安全验证流水线项目"
  type        = "scrum"
}

resource "huaweicloud_codearts_repository" "main" {
  project_id  = huaweicloud_codearts_project.main.id
  name        = var.codearts_repository_name
  description = "存储 Terraform IaC 脚本的代码仓库"
}

# ============================================================================
# 2. OBS 桶：验证结果存储 + 流水线构件存储
# ============================================================================

resource "huaweicloud_obs_bucket" "validation_result" {
  bucket        = var.validation_result_bucket_name
  acl           = "private"
  force_destroy = true

  encryption    = true
  sse_algorithm = "AES256"

  tags = {
    purpose = "terraform-validation-result"
  }
}

resource "huaweicloud_obs_bucket" "pipeline_artifact" {
  bucket        = var.pipeline_artifact_bucket_name
  acl           = "private"
  force_destroy = true

  encryption    = true
  sse_algorithm = "AES256"

  tags = {
    purpose = "pipeline-artifact"
  }
}

# ============================================================================
# 3. SMN 主题：审批通知 + 验证失败通知
# ============================================================================

resource "huaweicloud_smn_topic" "approval_request" {
  name         = var.smn_topic_name
  display_name = "Terraform validation approval notification"
}

resource "huaweicloud_smn_subscription" "approval_email" {
  topic_urn = huaweicloud_smn_topic.approval_request.id
  protocol  = "email"
  endpoint  = var.email_notification_endpoint
  remark    = "Approval request notification"
}

# ============================================================================
# 4. IAM 委托：让 FunctionGraph 可访问 OBS + SMN
# ============================================================================

resource "huaweicloud_identity_agency" "functiongraph" {
  name                  = var.functiongraph_agency_name
  description           = "Agency for FunctionGraph to access OBS and SMN"
  duration              = "FOREVER"
  delegated_domain_name = var.domain_name

  project_role {
    project = var.region
    roles = [
      "OBS OperateAccess",
      "SMN FullAccess",
    ]
  }
}

# ============================================================================
# 5. FunctionGraph 函数：构建失败邮件通知
# ============================================================================

resource "huaweicloud_fgs_function" "send_notification" {
  name        = "terraform-validation-failure-notification"
# agency removed - FGS needs service agency
  handler     = "index.handler"
  memory_size = 256
  timeout     = 60
  runtime     = "Python3.9"
  package     = "default"

  code_type = "obs"
  code_url  = "https://${var.validation_result_bucket_name}.obs.${var.region}.myhuaweicloud.com/function-code/send_notification.zip"

  user_data = jsonencode({
    SMN_TOPIC_URN = huaweicloud_smn_topic.approval_request.id
    OBS_BUCKET    = huaweicloud_obs_bucket.validation_result.bucket
    REGION        = var.region
  })
}

# ============================================================================
# 6. CES 告警规则：监听 CodeArts Build 失败事件
# ============================================================================
#
# CodeArts 构建失败事件通过 CES 事件告警捕获，触发 FunctionGraph 通知函数。
# 注：CES 事件类告警的精确配置可能需要通过控制台完成，
#     此处提供基础告警规则框架。

# resource "huaweicloud_ces_alarmrule" "build_failed" {
#   alarm_name        = "terraform-validation-failed"
#   alarm_description = "Triggered when Terraform validation build fails"
#   alarm_enabled     = true
# 
#   alarm_actions {
#     type              = "functiongraph"
#     notification_list = [huaweicloud_fgs_function.send_notification.urn]
#   }

#   metric {
#     metric_name = "build_status"
#     namespace   = "SYS.CODEARTS"
#   }

#   condition {
#     count               = 1
#     period              = 300
#     filter              = "average"
#     comparison_operator = ">="
#     value               = 1
#     unit                = "count"
#   }
# }

# ============================================================================
# 7. CodeArts 流水线（通过 YAML 定义，部署时导入）
# ============================================================================
#
# CodeArts Pipeline 的四阶段定义在 pipeline.yaml 文件中，
# 部署时通过 CodeArts 控制台或 CLI 导入。
# Terraform provider 对 CodeArts Pipeline 的支持有限，
# 建议通过 CodeArts 控制台配置流水线阶段。

# ============================================================================
# 输出
# ============================================================================

output "codearts_project_id" {
  description = "CodeArts 项目 ID"
  value       = huaweicloud_codearts_project.main.id
}

output "codearts_repository_name" {
  description = "CodeArts 仓库名"
  value       = huaweicloud_codearts_repository.main.name
}

output "validation_result_bucket" {
  description = "验证结果 OBS 桶名"
  value       = huaweicloud_obs_bucket.validation_result.bucket
}

output "pipeline_artifact_bucket" {
  description = "流水线构件 OBS 桶名"
  value       = huaweicloud_obs_bucket.pipeline_artifact.bucket
}

output "smn_topic_urn" {
  description = "SMN 主题 URN"
  value       = huaweicloud_smn_topic.approval_request.id
}

output "notification_function_name" {
  description = "通知函数名"
  value       = huaweicloud_fgs_function.send_notification.name
}
