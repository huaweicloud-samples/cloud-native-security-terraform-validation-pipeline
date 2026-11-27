variable "region" {
  type        = string
  description = "华为云区域"
  default     = "cn-north-4"
}

variable "domain_name" {
  type        = string
  description = "华为云账号域名（IAM 委托归属域）"
}

# -------------------CodeArts 变量-------------------
variable "codearts_project_name" {
  type        = string
  description = "CodeArts 项目名称"
}

variable "codearts_repository_name" {
  type        = string
  description = "CodeArts 代码仓库名称"
}

# -------------------OBS 变量-------------------
variable "validation_result_bucket_name" {
  type        = string
  description = "存储 Checkov 验证结果的 OBS 桶名"
}

variable "pipeline_artifact_bucket_name" {
  type        = string
  description = "存储流水线构件的 OBS 桶名"
}

# -------------------SMN 变量-------------------
variable "smn_topic_name" {
  type        = string
  description = "SMN 主题名称"
}

variable "email_notification_endpoint" {
  type        = string
  description = "接收通知的邮箱地址"
}

# -------------------IAM 变量-------------------
variable "functiongraph_agency_name" {
  type        = string
  description = "FunctionGraph 委托名称"
}
