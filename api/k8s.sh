kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

kubectl apply -f k8s/deployment.yaml

kubectl apply -f k8s/account-service.yaml
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/gateway-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/product-service.yaml

kubectl apply -f k8s/service.yaml