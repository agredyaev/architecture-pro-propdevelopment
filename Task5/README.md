# Task 5: Kubernetes Network Policies

Изоляция сетевого трафика между сервисами в кластере Kubernetes с использованием Network Policies (L3/L4).

## Структура

```
Task5/
├── manifests/
│   ├── 10-namespace-and-services.yaml  # Namespace, pods, services
│   ├── 20-default-deny.yaml            # Default deny (ingress + DNS egress)
│   ├── 30-client-api-policy.yaml       # front-end ↔ back-end-api
│   └── 40-admin-api-policy.yaml        # admin-front-end ↔ admin-back-end-api
├── scripts/
│   └── test-network-policies.sh        # Проверка соединений
├── Makefile                      # Автоматизация команд
└── README.md                     # Данный файл
```

## Требования

- Kubernetes кластер с CNI плагином, поддерживающим Network Policies (Calico, Cilium, Weave Net)
- kubectl настроен и подключен к кластеру

**Для Minikube:**
```bash
minikube start --cni=calico
```

## Быстрый старт

### Просмотр доступных команд
```bash
make help
```

### Валидация манифестов
```bash
make validate
```

### Применение Network Policies
```bash
make apply
```

Команда выполняет:
1. Создание namespace `demo-network-policies`
2. Развертывание 4 подов (front-end, back-end-api, admin-front-end, admin-back-end-api)
3. Применение default-deny политик
4. Применение allow политик для разрешённых соединений

### Проверка состояния
```bash
make status
```

### Тестирование политик
```bash
make test
```

Скрипт проверяет:
- [ALLOW] front-end → back-end-api
- [ALLOW] admin-front-end → admin-back-end-api
- [DENY] front-end → admin-back-end-api
- [DENY] admin-front-end → back-end-api
- [DENY] back-end-api → admin-back-end-api

### Удаление ресурсов
```bash
make delete
```

## Матрица доступа

| Source → Target      | front-end | back-end-api | admin-front-end | admin-back-end-api |
|---------------------|-----------|--------------|-----------------|-------------------|
| front-end           | -         | ALLOW        | DENY            | DENY              |
| back-end-api        | ALLOW     | -            | DENY            | DENY              |
| admin-front-end     | DENY      | DENY         | -               | ALLOW             |
| admin-back-end-api  | DENY      | DENY         | ALLOW           | -                 |

## Архитектура

**Default Deny + Explicit Allow:**
1. `20-default-deny.yaml`: блокирует весь трафик (кроме DNS)
2. `30-client-api-policy.yaml`: разрешает front-end ↔ back-end-api
3. `40-admin-api-policy.yaml`: разрешает admin-front-end ↔ admin-back-end-api

**Изоляция:**
- Клиентские сервисы изолированы от административных
- DNS разрешен глобально (egress к kube-system на порт 53)
- Все остальные соединения блокируются
