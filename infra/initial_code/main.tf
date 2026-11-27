# ============================================================================
# 整改前基础网络：VPC + 4 子网
# ============================================================================
# 此代码故意缺少安全加固措施（无 Flow Logs、无 KMS 加密、子网映射公网 IP），
# 供 Checkov 安全扫描发现安全问题，随后用 updated_code/ 中的加固版本替换。
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

  # 状态存储到 OBS 桶
  backend "s3" {
    endpoint = "https://obs.cn-north-4.myhuaweicloud.com"
    bucket   = "your-tfstate-bucket-name"
    key      = "initial_code/terraform.tfstate"
    region   = "cn-north-4"
  }
}

provider "huaweicloud" {
  region = var.region
}

# VPC
resource "huaweicloud_vpc" "vpc" {
  name = "myvpc"
  cidr = "10.0.0.0/16"
}

# 公网子网 1
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
