# 検証手順

ECS Fargate 上の FireLens (Fluent Bit) サイドカーのログバッファ挙動を実際に再現・観測するための手順書。  
[プロジェクト README](../README.md) を参照して `terraform apply` でリソースを作成してから実施する。

## 前提条件

- `terraform apply` 完了済み
- aws-vault インストール済み・プロファイル `<profile>` 設定(置換)済み
- AWS CLI インストール済み

> 以降のコマンドはすべて以下の形式で記述する。
> `aws-vault exec <profile> -- aws`
> `aws-vault exec <profile> -- terraform`

---

## 共通変数

プロジェクトルートで以下を実行する。`REGION` のみ手動設定し、残りは `terraform output` から取得する。

```bash
# terraform.tfvars の aws_region と合わせて設定
REGION=ap-northeast-1

# 以下は terraform output から取得
CLUSTER=$(aws-vault exec <profile> -- terraform output -raw ecs_cluster_name)
TASKDEF=$(aws-vault exec <profile> -- terraform output -raw task_definition_arn)
SG=$(aws-vault exec <profile> -- terraform output -raw task_security_group_id)
APP_LOG=$(aws-vault exec <profile> -- terraform output -raw app_log_group_name)
ROUTER_LOG=$(aws-vault exec <profile> -- terraform output -raw log_router_log_group_name)
S3_BUCKET=$(aws-vault exec <profile> -- terraform output -raw s3_bucket_name)
TASK_ROLE=$(aws-vault exec <profile> -- terraform output -raw task_role_arn | awk -F'/' '{print $NF}')
VPC=$(aws-vault exec <profile> -- terraform output -raw vpc_id)

# サブネット確認 — Public=True のサブネット ID を SUBNET に設定する
aws-vault exec <profile> -- aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC" \
  --query "Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}" \
  --output table --region "$REGION"

SUBNET=subnet-XXXX   # ↑ の出力から設定
```

---

## 検証1｜ecs_* メタデータ付与 / Fargate で ec2_instance_id なし

**仮説**: FireLens は既定で各レコードに `ecs_cluster` / `ecs_task_arn` / `ecs_task_definition` を付与する。Fargate では `ec2_instance_id` は付かない。

### 手順（検証1）

```bash
# タスク起動（stdout に 1 行出して 30 秒待つ）
aws-vault exec <profile> -- aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASKDEF" \
  --launch-type FARGATE \
  --region "$REGION" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"app","command":["sh","-c","echo hello-firelens-verify && sleep 30"]}]}'

# ログ確認（起動から 30〜60 秒後）
aws-vault exec <profile> -- aws logs tail "$APP_LOG" --follow --region "$REGION"
```

### 確認ポイント（検証1）

届いたログイベントの JSON に以下が含まれること:

| フィールド | 期待値 |
| --- | --- |
| `ecs_cluster` | クラスター名 |
| `ecs_task_arn` | タスク ARN |
| `ecs_task_definition` | タスク定義ファミリー:リビジョン |
| `ec2_instance_id` | **含まれない**（Fargate のため） |

#### 結果（検証1）

![検証結果1](../docs/images/verify-1.png)

---

## 検証2｜mem buf overlimit でログ欠落

**仮説**: 既定（memory バッファ、`Mem_Buf_Limit 50MB`）で大量ログを短時間に流すと input が pause され、ログが欠落する。

### 手順（検証2）

```bash
export MSYS_NO_PATHCONV=1       # Windows Git Bashの場合のみ必要
export MSYS2_ARG_CONV_EXCL="*"  # Windows Git Bashの場合のみ必要

# 連番 100,000 行を高速出力してバッファを溢れさせる
aws-vault exec <profile> -- aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASKDEF" \
  --launch-type FARGATE \
  --region "$REGION" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"app","command":["sh","-c","P=$(printf %10000s | tr \" \" X); while true; do echo \"$P\"; done"]}]}' \
  --query "tasks[0].taskArn" --output text

# log_router のログで paused を観察（タスク実行中）
aws-vault exec <profile> -- aws logs tail "$ROUTER_LOG" --follow --region "$REGION" | grep -i "paused\|overlimit"

# タスク完了後、CloudWatch に到達した行数を数える
STREAM=$(aws-vault exec <profile> -- aws logs describe-log-streams \
  --log-group-name "$APP_LOG" \
  --order-by LastEventTime --descending \
  --query "logStreams[0].logStreamName" --output text --region "$REGION")

aws-vault exec <profile> -- aws logs get-log-events \
  --log-group-name "$APP_LOG" \
  --log-stream-name "$STREAM" \
  --query "length(events)" --output text --region "$REGION"
```

### 確認ポイント（検証2）

> **背景**:  
> AWS FireLens のデフォルト設定には `forward` プラグインに `Mem_Buf_Limit 50MB` が注入されている。  
> バッファが 50 MB を超えると入力が pause（バックプレッシャー）され、50 MB 未満に下がると resume される。  
> そのため OOMKill は発生せず、ログのドロップが起きる。

- `ROUTER_LOG` に `[input] tcp.1 paused (mem buf overlimit)` が出る
- 到達行数 < 100,000（欠落あり）
- OOMKill は発生しない

#### 結果（検証2）

**実測結果（2026-06-17）**:

| 確認項目 | 期待 | 実測 |
| --- | --- | --- |
| `ROUTER_LOG` の出力 | pause/resume の繰り返し | `mem buf overlimit` → pause/resume サイクルが確認された |
| OOMKill | 発生しない | **発生しない** |

**結論**: AWS FireLens デフォルトの `Mem_Buf_Limit 50MB` によりバックプレッシャーが機能し、OOMKill は抑制される。ただしバッファが詰まっている間は新規ログがドロップされる点に注意。

![検証結果2-1](../docs/images/verify-2-1.png)
![検証結果2-2](../docs/images/verify-2-2.png)

---

## 検証3｜FireLens 標準 CloudWatch メトリクスは存在しない

**仮説**: FireLens / Fluent Bit 専用の CloudWatch メトリクスは AWS 標準では提供されない。観測はログルーター自身のログと宛先側メトリクスに依存する。

> **背景**:  
> ここで「メトリクスが存在しない」とは、Fluent Bit の**内部動作に関するメトリクス**が CloudWatch の専用ネームスペースとして公開されていないことを指す。  
> 具体的には以下のようなメトリクスが**存在しない**:
>
> | 存在しないメトリクス例 | 意味 |
> | --- | --- |
> | バッファ使用率 | 現在バッファが何 MB 使われているか |
> | ドロップレコード数 | バックプレッシャーで捨てられたログ行数 |
> | リトライ回数 | 宛先への再送試行数 |
>
> **Container Insights との違い**:  
> Container Insights はコンテナの CPU・メモリ・ネットワークといった**インフラ層のメトリクス**を収集するが、FireLens が「ログを正常に転送できているか」（バッファが詰まっているか、ドロップが発生しているか）は観測できない。

### 手順（検証3）

```bash
# FireLens 専用ネームスペースを検索（存在しないことを確認）
aws-vault exec <profile> -- aws cloudwatch list-metrics --namespace "FireLens" --region "$REGION"
aws-vault exec <profile> -- aws cloudwatch list-metrics --namespace "ECS/FireLens" --region "$REGION"

# 代替観測: CloudWatch Logs 宛先側メトリクス
aws-vault exec <profile> -- aws cloudwatch list-metrics \
  --namespace "AWS/Logs" \
  --metric-name "IncomingLogEvents" \
  --dimensions "Name=LogGroupName,Value=$APP_LOG" \
  --region "$REGION"
```

### 確認ポイント（検証3）

- `FireLens` / `ECS/FireLens` ネームスペースが空（メトリクスなし）
- 観測手段が `ROUTER_LOG` のログ＋宛先側メトリクス（`AWS/Logs` `IncomingLogEvents` 等）のみであることを確認

**FireLens の健全性を間接的に把握するための代替手段**:

| 観測手段 | 何がわかるか | 限界 |
| --- | --- | --- |
| `ROUTER_LOG` のログ | `mem buf overlimit` / `paused` などの警告でバッファ詰まりを検知 | ログ量が多いと警告が埋もれる |
| `AWS/Logs` `IncomingLogEvents` | CloudWatch への到達ログ数が急減したら転送停止を推測できる | 減少の原因が FireLens か宛先かの切り分けが必要 |

#### 結果（検証3）

![検証結果3-1](../docs/images/verify-3-1.png)
![検証結果3-2](../docs/images/verify-3-2.png)
![検証結果3-3](../docs/images/verify-3-3.png)

---

## 検証後の Teardown

```bash
# 1. タスクロールの権限が元に戻っていることを確認
aws-vault exec <profile> -- aws iam list-attached-role-policies --role-name "$TASK_ROLE"

# 2. 実行中タスクがないことを確認
aws-vault exec <profile> -- aws ecs list-tasks --cluster "$CLUSTER" --region "$REGION"

# 3. Terraform で全リソース破棄
aws-vault exec <profile> -- terraform destroy
```
