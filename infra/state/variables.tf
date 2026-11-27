variable "region" {
  type        = string
  description = "华为云区域"
  default     = "cn-north-4"
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "存储 Terraform 状态的 OBS 桶名（全局唯一）"
}
