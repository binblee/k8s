# Prometheus deployment

此文档介绍如何部署开源 prometheus 到 EKS 集群中，并配置数据持久化和高可用。

  

开源 prometheus 基于以下 GitHUB 仓库：

https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md

  

Prometheus 数据持久化需要使用EBS存储卷，所以在安装 prometheus 之前，需要安装 AWS EBS CIS Driver。

```Bash
# 若您尚未给集群开启OIDC provider，请执行以下命令开启
eksctl utils associate-iam-oidc-provider --region=<Your Region> --cluster=<Your Cluster Name> --approve

# 为 aws-ebs-csi-driver 创建 iamserviceaccount，授予其调用AWS EBS卷的权限
eksctl create iamserviceaccount \
--name ebs-csi-controller-sa \
--namespace kube-system \
--cluster <Your Cluster Name> \
--region=<Your Region> \
--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
--approve \
--role-only

# 获取 roleARN
roleARN=`eksctl get iamserviceaccount --name ebs-csi-controller-sa --cluster <Your Cluster Name> --region=<Your Region> --output json | jq -r '.[0].status.roleARN'`
echo $roleARN

# 安装aws-ebs-csi-driver插件
aws eks create-addon --cluster-name <Your Cluster Name> --region=<Your Region> --addon-name aws-ebs-csi-driver --service-account-role-arn ${roleARN}

# 检查插件是否已安装成功
aws eks describe-addon --cluster-name <Your Cluster Name> --region=<Your Region> --addon-name aws-ebs-csi-driver

# 创建 EBS storage class
cat > ebs-sc.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
allowVolumeExpansion: true
metadata:
  name: ebs-sc
parameters:
  type: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f ebs-sc.yaml
```

  

因为prometheus官方的镜像是从quay.io拉取，国内拉可能比较慢或拉不到，建议把镜像推到ECR，避免后续Pod重启镜像拉取失败。

```Bash
# 为prometheus镜像创建ECR repository
aws ecr create-repository \
  --repository-name prometheus/k8s-sidecar \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name prometheus/grafana \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name kube-state-metrics/kube-state-metrics \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>

aws ecr create-repository \
  --repository-name prometheus-operator/prometheus-operator \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name prometheus/alertmanager \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>

aws ecr create-repository \
  --repository-name prometheus-operator/prometheus-config-reloader \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name prometheus/prometheus \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name prometheus/node-exporter \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
aws ecr create-repository \
  --repository-name ingress-nginx/kube-webhook-certgen \
  --image-scanning-configuration scanOnPush=true \
  --region <REGION>
  
# 获取ECR repository地址
export BASE_REPO=`aws ecr describe-repositories \
  --repository-names prometheus/prometheus \
  --region <REGION> \
  --query "repositories[0].repositoryUri" \
  --output text | cut -d / -f1`

echo $BASE_REPO

docker pull quay.io/kiwigrid/k8s-sidecar:1.22.0
docker pull docker.io/grafana/grafana:9.5.2
docker pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.8.2
docker pull quay.io/prometheus-operator/prometheus-operator:v0.65.1                                                                                                                                     
docker pull quay.io/prometheus/alertmanager:v0.25.0
docker pull quay.io/prometheus-operator/prometheus-config-reloader:v0.65.1
docker pull quay.io/prometheus/prometheus:v2.42.0
docker pull quay.io/prometheus/node-exporter:v1.5.0
docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6

docker tag quay.io/kiwigrid/k8s-sidecar:1.22.0 $BASE_REPO/prometheus/k8s-sidecar:1.22.0 
docker tag docker.io/grafana/grafana:9.5.2 $BASE_REPO/prometheus/grafana:9.5.2
docker tag registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.8.2 $BASE_REPO/kube-state-metrics/kube-state-metrics:v2.8.2
docker tag quay.io/prometheus-operator/prometheus-operator:v0.65.1 $BASE_REPO/prometheus-operator/prometheus-operator:v0.65.1                                                                                       
docker tag quay.io/prometheus/alertmanager:v0.25.0 $BASE_REPO/prometheus/alertmanager:v0.25.0
docker tag quay.io/prometheus-operator/prometheus-config-reloader:v0.65.1 $BASE_REPO/prometheus-operator/prometheus-config-reloader:v0.65.1
docker tag quay.io/prometheus/prometheus:v2.42.0 $BASE_REPO/prometheus/prometheus:v2.42.0
docker tag quay.io/prometheus/node-exporter:v1.5.0 $BASE_REPO/prometheus/node-exporter:v1.5.0
docker tag registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6 $BASE_REPO/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6

# 登录ECR仓库
aws ecr get-login-password --region <Your Region> | docker login --username AWS --password-stdin 625011733915.dkr.ecr.<Your Region>.amazonaws.com

# 推送镜像到ECR仓库
docker push $BASE_REPO/prometheus/k8s-sidecar:1.22.0 
docker push $BASE_REPO/prometheus/grafana:9.5.2
docker push $BASE_REPO/kube-state-metrics/kube-state-metrics:v2.8.2
docker push $BASE_REPO/prometheus-operator/prometheus-operator:v0.65.1                                                                                       
docker push $BASE_REPO/prometheus/alertmanager:v0.25.0
docker push $BASE_REPO/prometheus-operator/prometheus-config-reloader:v0.65.1
docker push $BASE_REPO/prometheus/prometheus:v2.42.0
docker push $BASE_REPO/prometheus/node-exporter:v1.5.0
docker push $BASE_REPO/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6

```

安装 Prometheus

```Bash
# 建议把prometheus套件部署到单独节点组，避免影响生产应用
# 例如使用monitoring节点组来部署prometheus
# 您需要根据prometheus实际使用的资源选择合适的节点类型
# 建议您选择多AZ提高高可用
eksctl create nodegroup \
  --cluster <Your Cluster Name> \
  --name monitoring \
  --node-type c6i.large \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --region <Your Region> \
  --subnet-ids subnet-068c41b2b15cd3dd4,subnet-0e3fbb88bc117ef90 \
  --node-private-networking

aws eks update-nodegroup-config \
  --cluster-name \
  --nodegroup-name \
  --region <YOUR Region> \
  --labels addOrUpdateLabels={app=monitoring} \
  --taints "addOrUpdateTaints=[{key="app",value="monitoring",effect="NO_SCHEDULE"}]"

# 安装 prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat > prometheus_values.yaml <<EOF
## Provide a name to substitute for the full names of resources
##
fullnameOverride: "kube-prometheus-stack"

global:
  # 镜像仓库地址，如果使用原仓库地址，可以注释这一行
  imageRegistry: "$BASE_REPO"

alertmanager:
  podDisruptionBudget:
    enabled: true
  
  # Alertmanager UI
  #service:
    #type: LoadBalancer
    #port: 80
    #annotations: 
      #service.beta.kubernetes.io/aws-load-balancer-type: nlb
      #service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      # 若只需要内网访问，可以把下一行的注释删除
      #service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    
  # Alertmanager statefulset 定义
  alertmanagerSpec:
    # 实例数   
    replicas: 2
    # 数据保留时间
    retention: 120h
    
    # 持久化存储卷，后续可以通过调整pvc卷大小动态扩容
    storage:
     volumeClaimTemplate:
       spec:
         storageClassName: ebs-sc
         accessModes: ["ReadWriteOnce"]
         resources:
           requests:
             storage: 30Gi
    
    # 部署到指定节点，如果没有专用节点组，可以注释这部分
    nodeSelector:
      app: monitoring
    tolerations:
    - key: "app"
      operator: "Equal"
      value: "monitoring"
      effect: "NoSchedule"
    
    # 资源配置，您需要根据实际资源使用量进行调整
    resources:
      limits:
        cpu: 200m
        memory: 50Mi
      requests:
        cpu: 200m
        memory: 50Mi
    # 反亲和
    podAntiAffinity: "soft"
    # 实例分散到不同AZ
    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: alertmanager

grafana:
  # 登录grafana页面的admin帐号密码，您需要修改为自己的密码
  adminPassword: DDJn7~MY
  # 镜像仓库地址，如果使用原仓库地址，可以注释下面两行
  image:
    repository: $BASE_REPO/prometheus/grafana
  
  persistence:
    type: pvc
    enabled: true
    storageClassName: ebs-sc
    accessModes:
      - ReadWriteOnce
    size: 10Gi
  
  service:
    type: LoadBalancer
    annotations: 
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      # 若只需要内网访问，可以把下一行的注释删除
      #service.beta.kubernetes.io/aws-load-balancer-scheme: internal
      
  # 镜像仓库地址，如果使用原仓库地址，可以注释下面三行
  sidecar:
    image:
      repository: $BASE_REPO/prometheus/k8s-sidecar
      
  # 部署到指定节点，如果没有专用节点组，可以注释这部分
  nodeSelector:
    app: monitoring
  tolerations:
  - key: "app"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"
  
  # Grafana 多实例部署
  replicas: 2
  headlessService: true
  
  # 反亲和
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - grafana
          topologyKey: kubernetes.io/hostname
        weight: 100
  
  grafana.ini:
    # Grafana 多实例统一告警
    unified_alerting:
      enabled: true
      ha_peers: kube-prometheus-stack-grafana-headless:9094
      ha_listen_address: \${POD_IP}:9094
      ha_advertise_address: \${POD_IP}:9094
    # SMTP 配置
    smtp:
      enabled: true
      host: "smtp.office365.com:587"

  # 需提前创建 secret
  # kubectl create secret generic smtp-secret --from-literal=user="Mailid" --from-literal=password="password" -n monitoring
  smtp:
    existingSecret: "smtp-secret"

prometheusOperator:
  # 部署到指定节点，如果没有专用节点组，可以注释这部分
  nodeSelector:
    app: monitoring
  tolerations:
  - key: "app"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"
  
prometheus:
  ## Configuration for Prometheus service
  ##
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      # 若只需要内网访问，可以把下一行的注释删除
      #service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    port: 80
    
  podDisruptionBudget:
    enabled: true
    
  prometheusSpec:
    # 部署到指定节点，如果没有专用节点组，可以注释这部分
    nodeSelector:
      app: monitoring
    tolerations:
    - key: "app"
      operator: "Equal"
      value: "monitoring"
      effect: "NoSchedule"
    
    # 数据保留时间
    retention: 10d
    
    # 实例数
    replicas: 2
    
    # 反亲和
    podAntiAffinity: "soft"
    # 实例分散到不同AZ
    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: prometheus

    # 资源配置，您需要根据实际资源使用量进行调整
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 1000m
        memory: 1Gi
    
    # 持久化存储，后续可以通过调整pvc卷大小动态扩容
    storageSpec:
      volumeClaimTemplate:
       spec:
         storageClassName: ebs-sc
         accessModes: ["ReadWriteOnce"]
         resources:
           requests:
             storage: 50Gi
             
kube-state-metrics:
  # 部署到指定节点，如果没有专用节点组，可以注释这部分
  nodeSelector:
    app: monitoring
  tolerations:
  - key: "app"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"
EOF

kubectl create namespace monitoring
# 创建SMTP secret
kubectl create secret generic smtp-secret --from-literal=user="Mailid" --from-literal=password="password" -n monitoring

helm upgrade -i -n monitoring kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 45.31.0 -f prometheus_values.yaml
```

  

卸载prometheus

```Bash
helm uninstall -n monitoring kube-prometheus-stack
```