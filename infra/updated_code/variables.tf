variable "region" {
  type        = string
  description = "华为云区域"
  default     = "cn-north-4"
}

# -------------------KMS 密钥变量-------------------
variable "kms_key_alias" {
  type        = string
  description = "KMS 密钥别名"
  default     = "vpc-flow-logs-key-v2"
}

# -------------------LTS 日志变量-------------------
variable "log_group_name" {
  type        = string
  description = "VPC Flow Logs 的 LTS 日志组名称"
  default     = "vpc-flow-logs-group"
}

variable "retention_in_days" {
  type        = number
  description = "VPC Flow Logs 日志保留天数"
  default     = 7
}
