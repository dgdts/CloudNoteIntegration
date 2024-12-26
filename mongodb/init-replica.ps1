# 创建存储和配置
kubectl apply -f mongodb/mongodb-storage.yaml
kubectl apply -f mongodb/mongodb-configmap.yaml
kubectl apply -f mongodb/mongodb-secret.yaml

# 部署 MongoDB
kubectl apply -f mongodb/mongodb-statefulset.yaml
kubectl apply -f mongodb/mongodb-service.yaml

Write-Host "Waiting for MongoDB pods to be ready..."
# 等待所有 Pod 就绪，增加超时时间到 5 分钟
$retries = 0
$maxRetries = 30
do {
    $ready = $true
    $pods = kubectl get pods -l app=mongodb -o jsonpath='{.items[*].status.phase}'
    if ($pods -ne "Running Running Running") {
        $ready = $false
        $retries++
        Write-Host "Waiting for pods to be ready... Attempt $retries of $maxRetries"
        Start-Sleep -Seconds 10
    }
} while (-not $ready -and $retries -lt $maxRetries)

if ($retries -eq $maxRetries) {
    Write-Host "Timeout waiting for MongoDB pods to be ready"
    exit 1
}

Write-Host "All MongoDB pods are ready. Initializing replica set..."
# 等待额外 10 秒确保 MongoDB 进程完全启动
Start-Sleep -Seconds 10

# 初始化副本集
kubectl exec mongodb-0 -- mongosh --eval '
rs.initiate({
  _id: "rs0",
  members: [
    {_id: 0, host: "mongodb-0.mongodb-headless:27017"},
    {_id: 1, host: "mongodb-1.mongodb-headless:27017"},
    {_id: 2, host: "mongodb-2.mongodb-headless:27017"}
  ]
})'
