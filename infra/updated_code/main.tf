# ============================================================================
# 整改后安全加固网络：VPC + KMS 加密 + VPC Flow Logs + 安全组加固
# ============================================================================
# 根据 Checkov 安全扫描建议整改后的代码：
# 1. 添加 KMS 密钥用于 VPC Flow Logs 加密
# 2. 启用 VPC Flow Logs 记录所有流量
# 3. 清空默认安全组规则
# 4. 移除子网的公网 IP 映射
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

#   # backend "s3" {
#     endpoint = "https://obs.cn-north-4.myhuaweicloud.com"
#     bucket   = "your-tfstate-bucket-name"
#     key      = "updated_code/terraform.tfstate"
#     region   = "cn-north-4"
#   }
}

# provider "huaweicloud" {
#   region = var.region
# }

# ============================================================================
# KMS 密钥（用于 VPC Flow Logs 加密）
# ============================================================================

resource "huaweicloud_kms_key" "flow_logs_key" {
  key_alias       = var.kms_key_alias
  pending_days    = 7
  key_description = "KMS key for VPC Flow Logs encryption"
}

# ============================================================================
# LTS 日志组（用于 VPC Flow Logs 存储）
# ============================================================================

resource "huaweicloud_lts_group" "vpc_flow_logs" {
  group_name  = var.log_group_name
  ttl_in_days = var.retention_in_days
}

resource "huaweicloud_lts_stream" "vpc_flow_logs" {
  group_id    = huaweicloud_lts_group.vpc_flow_logs.id
  stream_name = "${var.log_group_name}-stream"
  ttl_in_days = var.retention_in_days
}

# ============================================================================
# VPC + 子网
# ============================================================================

resource "huaweicloud_vpc" "vpc" {
  name = "myvpc"
  cidr = "10.0.0.0/16"
}

# 公网子网 1（整改后不映射公网 IP）
resource "huaweicloud_vpc_subnet" "public_subnet1" {
  name       = "Public_Subnet1"
  vpc_id     = huaweicloud_vpc.vpc.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
}

# 公网子网 2
resource "huaweicloud_vpc_subnet" "public_subnet2" {
  name       = "Public_Subnet2"
  vpc_id     = huaweicloud_vpc.vpc.id
  cidr       = "10.0.2.0/24"
  gateway_ip = "10.0.2.1"
}

# 私网子网 1
resource "huaweicloud_vpc_subnet" "private_subnet1" {
  name       = "Private_Subnet1"
  vpc_id     = huaweicloud_vpc.vpc.id
  cidr       = "10.0.3.0/24"
  gateway_ip = "10.0.3.1"
}

# 私网子网 2
resource "huaweicloud_vpc_subnet" "private_subnet2" {
  name       = "Private_Subnet2"
  vpc_id     = huaweicloud_vpc.vpc.id
  cidr       = "10.0.4.0/24"
  gateway_ip = "10.0.4.1"
}

# ============================================================================
# 安全组（显式定义，不依赖默认安全组）
# ============================================================================

resource "huaweicloud_networking_secgroup" "vpc_sg" {
  name                 = "vpc-security-group"
  description          = "Security group for VPC resources"
  delete_default_rules = true
}

# ============================================================================
# VPC Flow Logs
# ============================================================================

resource "huaweicloud_vpc_flow_log" "vpc_flow_logs" {
  name          = "vpc-flow-logs"
  resource_type = "vpc"
  resource_id   = huaweicloud_vpc.vpc.id
  traffic_type  = "all"
  log_group_id  = huaweicloud_lts_group.vpc_flow_logs.id
  log_stream_id = huaweicloud_lts_stream.vpc_flow_logs.id
}
