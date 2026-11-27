# ============================================================================
# Terraform 状态后端：OBS 桶
# ============================================================================
# 华为云 Terraform 使用 OBS 作为 state backend，OBS 原生支持状态锁定，
# 无需额外创建锁表。
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

# OBS 桶用于存储 Terraform 状态文件
resource "huaweicloud_obs_bucket" "terraform_state" {
  bucket        = var.terraform_state_bucket_name
  acl           = "private"
  force_destroy = false
  versioning    = true

  encryption    = true
  sse_algorithm = "AES256"

  tags = {
    purpose = "terraform-state"
  }
}

output "terraform_state_bucket" {
  description = "存储 Terraform 状态的 OBS 桶名"
  value       = huaweicloud_obs_bucket.terraform_state.bucket
}
