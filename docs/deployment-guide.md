# 部署指导书

## 前置条件

1. **华为云账号**：已开通 CodeArts、OBS、SMN、FunctionGraph、CES、KMS、LTS 服务
2. **Terraform**：已安装 Terraform >= 1.5
3. **华为云 CLI 或 obsutil**：已安装并配置 AK/SK
4. **区域**：默认使用 cn-north-4（北京四），可按需修改
5. **AK/SK**：从运行环境读取，不写入配置文件
   ```bash
   export HW_ACCESS_KEY="your-access-key"
   export HW_SECRET_KEY="your-secret-key"
   ```

## 部署步骤

### 步骤 1：创建 Terraform 状态后端

```bash
cd infra/state
# 编辑 terraform.tfvars，填入 OBS 桶名
terraform init
terraform plan
terraform apply
```

此步骤创建一个 OBS 桶用于存储所有 Terraform 配置的状态文件。

### 步骤 2：部署 CI/CD 流水线基础设施

```bash
cd infra/pipeline
# 编辑 terraform.tfvars，填入以下参数：
# - domain_name: 华为云账号域名
# - codearts_project_name: CodeArts 项目名
# - codearts_repository_name: 代码仓库名
# - validation_result_bucket_name: 验证结果 OBS 桶名
# - pipeline_artifact_bucket_name: 流水线构件 OBS 桶名
# - smn_topic_name: SMN 主题名
# - email_notification_endpoint: 通知邮箱
# - functiongraph_agency_name: FunctionGraph 委托名

terraform init -backend-config="endpoint=https://obs.cn-north-4.myhuaweicloud.com" \
  -backend-config="bucket=your-tfstate-bucket-name" \
  -backend-config="key=pipeline/terraform.tfstate" \
  -backend-config="region=cn-north-4"

terraform plan
terraform apply
```

此步骤创建：
- CodeArts 项目和代码仓库
- OBS 桶（验证结果 + 流水线构件）
- SMN 主题和邮件订阅
- FunctionGraph 通知函数
- CES 告警规则
- IAM 委托

### 步骤 3：上传 FunctionGraph 函数代码

```bash
# 打包函数代码
cd src/functions
zip -r send_notification.zip send_notification.py

# 上传到 OBS
obsutil cp send_notification.zip obs://your-validation-result-bucket/function-code/
```

### 步骤 4：配置 CodeArts 流水线

在 CodeArts 控制台中：
1. 进入项目 → 流水线 → 新建流水线
2. 导入 `infra/pipeline/pipeline.yaml` 文件
3. 配置环境变量：
   - `VALIDATION_RESULT_BUCKET`：验证结果 OBS 桶名
   - `SMN_TOPIC_NAME`：SMN 主题名
4. 将 `buildspec_terraform_validation.yml` 和 `buildspec_deploy.yml` 配置为构建脚本

### 步骤 5：推送 IaC 代码到 CodeArts 仓库

```bash
# 将 initial_code 或 updated_code 的 Terraform 配置推送到 CodeArts 仓库
git remote add codearts https://codehub.cn-north-4.myhuaweicloud.com/your-project/your-repo.git
git push codearts main
```

推送后流水线将自动触发：Source → Validate(Checkov) → Approve → Deploy

## 验证

### 验证流水线运行

1. 在 CodeArts 控制台查看流水线运行状态
2. Validate 阶段完成后，检查 OBS 桶中的验证结果：
   ```bash
   obsutil ls obs://your-validation-result-bucket/
   ```
3. 查看 Checkov 扫描结果：
   ```bash
   obsutil cp obs://your-validation-result-bucket/checkov_output.txt ./
   cat checkov_output.txt
   ```

### 验证整改效果

1. 先推送 `infra/initial_code/` 到仓库，观察 Checkov 扫描发现的安全问题
2. 再推送 `infra/updated_code/` 到仓库，观察安全问题已被修复

## 清理资源

```bash
# 销毁流水线基础设施
cd infra/pipeline
terraform destroy

# 销毁状态后端
cd infra/state
terraform destroy
```
