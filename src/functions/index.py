"""
FunctionGraph 函数：Terraform 验证失败通知
============================================================================
当 CodeArts Build 验证阶段失败时，此函数被 CES 告警规则触发。
函数从 OBS 读取 Checkov 扫描结果，通过 SMN 发送邮件通知。

环境变量（通过 user_data 注入）：
  SMN_TOPIC_URN: SMN 主题 URN
  OBS_BUCKET:    存储验证结果的 OBS 桶名
  REGION:        华为云区域
"""

import json
import os
import logging

from obs import ObsClient
from huaweicloudsdkcore.auth.credentials import BasicCredentials
from huaweicloudsdksmn.v1.region.smn_region import SmnRegion
from huaweicloudsdksmn.v1 import SmnClient
from huaweicloudsdksmn.v1.model import PublishMessageRequest, PublishMessageRequestBody

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# 从环境变量获取配置
SMN_TOPIC_URN = os.environ.get("SMN_TOPIC_URN", "")
OBS_BUCKET = os.environ.get("OBS_BUCKET", "")
REGION = os.environ.get("REGION", "cn-north-4")


def get_obs_client():
    """创建 OBS 客户端"""
    ak = os.environ.get("HW_ACCESS_KEY", "")
    sk = os.environ.get("HW_SECRET_KEY", "")
    endpoint = f"https://obs.{REGION}.myhuaweicloud.com"
    return ObsClient(access_key_id=ak, secret_access_key=sk, server=endpoint)


def get_smn_client():
    """创建 SMN 客户端"""
    ak = os.environ.get("HW_ACCESS_KEY", "")
    sk = os.environ.get("HW_SECRET_KEY", "")
    credentials = BasicCredentials(ak, sk)
    return SmnClient.new_builder() \
        .with_credentials(credentials) \
        .with_region(SmnRegion.value_of(REGION)) \
        .build()


def read_checkov_result(obs_client):
    """从 OBS 读取 Checkov 扫描结果"""
    try:
        resp = obs_client.getObject(OBS_BUCKET, "checkov_output.txt")
        if resp.status < 300:
            return resp.body.response.read().decode("utf-8")
    except Exception as e:
        logger.error(f"读取 OBS 失败: {e}")
    return "无法读取 Checkov 扫描结果"


def send_notification(smn_client, checkov_result):
    """通过 SMN 发送邮件通知"""
    subject = "Terraform 验证失败通知"
    message = f"""
Terraform 安全验证流水线构建失败。

Checkov 扫描结果：
{checkov_result}

请检查验证结果并修复安全问题后重新提交。
"""
    try:
        request = PublishMessageRequest(
            topic_urn=SMN_TOPIC_URN,
            body=PublishMessageRequestBody(
                subject=subject,
                message=message
            )
        )
        response = smn_client.publish_message(request)
        logger.info(f"SMN 通知发送成功: {response}")
    except Exception as e:
        logger.error(f"SMN 通知发送失败: {e}")


def handler(event, context):
    """
    FunctionGraph 入口函数

    参数:
        event: CES 告警事件，包含构建状态信息
        context: FunctionGraph 运行时上下文
    """
    logger.info(f"收到事件: {json.dumps(event, ensure_ascii=False)}")

    # 检查是否为构建失败事件
    alarm_state = event.get("alarm_state", "")
    if alarm_state and alarm_state != "alarm":
        logger.info("非告警状态，跳过通知")
        return

    # 读取 Checkov 结果
    obs_client = get_obs_client()
    checkov_result = read_checkov_result(obs_client)

    # 发送通知
    smn_client = get_smn_client()
    send_notification(smn_client, checkov_result)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "通知已发送"})
    }
