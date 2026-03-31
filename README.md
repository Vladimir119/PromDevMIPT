# Домашнее задание 1: Распределённая система логирования и хранения

В этом репозитории подготовлено собственное веб-приложение и все Kubernetes-манифесты для развёртывания:

- `app/` — веб-приложение на Flask
- `k8s/` — Kubernetes YAML-манифесты
- `deploy.sh` — скрипт автоматического развёртывания

## Запуск

1. Собрать Docker-образ:

```bash
./deploy.sh
```

2. Проверить работу:

```bash
kubectl port-forward svc/app-service 5000:5000
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/status
curl -X POST http://127.0.0.1:5000/log -H "Content-Type: application/json" -d '{"message":"test log"}'
curl http://127.0.0.1:5000/logs
```

## Содержимое

- `k8s/app-configmap.yaml` — ConfigMap с настройками
- `k8s/app-pod.yaml` — тестовый Pod с `emptyDir` и монтированным ConfigMap
- `k8s/app-deployment.yaml` — Deployment с 3 репликами и `emptyDir`
- `k8s/app-service.yaml` — ClusterIP Service для балансировки
- `k8s/log-agent-daemonset.yaml` — DaemonSet для сбора логов с узлов
- `k8s/app-cronjob.yaml` — CronJob для архивирования логов каждые 10 минут
- `k8s/app-statefulset.yaml` — StatefulSet с PVC для персистентного хранения
