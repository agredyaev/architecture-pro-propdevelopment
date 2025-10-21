# Таблица ролей Kubernetes RBAC

## Описание ролей и полномочий

| Роль | Scope | Полномочия | Группа пользователей | Обоснование |
|------|-------|------------|----------------------|-------------|
| `cluster-admin` | ClusterRole | Полный доступ ко всем ресурсам кластера (`*/*`) | `security-admins` (специалист по ИБ) | Требуется для аудита безопасности, управления RBAC, доступа к секретам всех namespace |
| `cluster-viewer` | ClusterRole | Read-only доступ к неконфиденциальным ресурсам кластера (`get`, `list`, `watch` на pods, services, deployments, configmaps). Запрещён доступ к secrets | `business-viewers` (менеджеры, владельцы продуктов, бизнес-аналитики) | Мониторинг состояния приложений без риска утечки credentials |
| `namespace-admin` | ClusterRole (namespaced binding) | Полный доступ к namespaced ресурсам (`*/*`), включая secrets, configmaps, deployments, services, pods, ingress. Нет прав на кластерные объекты RBAC/Quotas | `devops-engineers` (DevOps-инженеры доменной команды) | Развёртывание и настройка приложений в рамках домена без доступа к кластерным ресурсам |
| `developer` | ClusterRole (namespaced binding) | `get`, `list`, `watch` на pods, services, deployments, configmaps. `create`, `delete` на pods (для отладки). `exec`, `logs`, `port-forward` на pods. Запрещён доступ к secrets | `developers` (разработчики доменной команды) | Отладка приложений без риска изменения production-конфигурации или доступа к credentials |
| `sre-operator` | ClusterRole (namespaced binding) | `get`, `list`, `watch` на все namespaced ресурсы (включая secrets). `patch`, `update` на deployments/pods для рестарта. Запрещено `create`, `delete` на deployments/services | `sre-engineers` (инженеры по эксплуатации) | Мониторинг и восстановление работоспособности без риска изменения архитектуры |

## Namespaces по доменной структуре

| Namespace | Домен | Приложения |
|-----------|-------|------------|
| `sales` | Продажи | client-tour-app, client-mart-app, client-crm-app, client-mart-estate-app |
| `tenant-services` | ЖКУ | tenant-core-app, tenant-crm-app |
| `finance` | Финансы | accountant-service-1 |
| `data` | Дата | data-warehouse, bi-service, reporting-service |

## Группы пользователей

| Группа | Роли в организации | Количество | RBAC роли |
|--------|-------------------|------------|-----------|
| `security-admins` | Специалист по ИБ | 1 | `cluster-admin` (ClusterRole) |
| `business-viewers` | Менеджеры, владельцы продуктов, бизнес-аналитики | ~20 (4 домена × 5 человек) | `cluster-viewer` (ClusterRole) |
| `devops-engineers` | DevOps-инженеры | ~4 (1 на домен) | `namespace-admin` (Role в назначенном namespace) |
| `developers` | Разработчики | ~40 (4 домена × 10 человек) | `developer` (Role в назначенном namespace) |
| `sre-engineers` | Инженеры по эксплуатации | ~4 (1 на домен) | `sre-operator` (Role в назначенном namespace) |

## Детализация полномочий по ресурсам

### cluster-admin (специалист по ИБ)
- **Resources**: `*` (все ресурсы)
- **Verbs**: `*` (все операции)
- **apiGroups**: `*` (все API группы)
- **Примечание**: используется встроенная ClusterRole `cluster-admin` из Kubernetes

### cluster-viewer (read-only на уровне кластера)
- **Resources**: pods, services, deployments, replicasets, statefulsets, daemonsets, configmaps, endpoints, events, namespaces, nodes, persistentvolumes, persistentvolumeclaims, ingresses
- **Verbs**: `get`, `list`, `watch`
- **apiGroups**: `""`, `apps`, `networking.k8s.io`, `batch`
- **Запрещено**: secrets, rolebindings, clusterrolebindings, roles, clusterroles

### namespace-admin (DevOps в рамках namespace)
- **Resources**: `*` (все namespaced ресурсы)
- **Verbs**: `*` (все операции)
- **apiGroups**: `""`, `apps`, `batch`, `networking.k8s.io`, `autoscaling`
- **Запрещено**: изменение RBAC (roles, rolebindings), ResourceQuotas, LimitRanges

### developer (разработчики)
- **Resources (read)**: pods, services, deployments, configmaps, endpoints, events, replicasets
- **Verbs (read)**: `get`, `list`, `watch`
- **Resources (exec)**: pods, pods/log, pods/portforward, pods/exec
- **Verbs (exec)**: `get`, `create`
- **Resources (debug pods)**: pods
- **Verbs (debug)**: `create`, `delete` (только для pods с label `debug=true`)
- **Запрещено**: secrets, deployments (create/update/delete), services (create/update/delete)

### sre-operator (SRE-инженеры)
- **Resources (read)**: pods, services, deployments, configmaps, secrets, endpoints, events, replicasets, statefulsets, ingresses
- **Verbs (read)**: `get`, `list`, `watch`
- **Resources (restart)**: pods, deployments
- **Verbs (restart)**: `patch`, `update`
- **Resources (logs)**: pods/log, pods/status, events
- **Verbs (logs)**: `get`, `list`
- **Запрещено**: `create`, `delete` на deployments, services, configmaps, secrets

## Принципы разграничения доступа

1. **Least Privilege**: каждая роль имеет минимальный набор полномочий для выполнения задач
2. **Separation of Duties**: разработчики не могут изменять production-конфигурацию, SRE не могут удалять сервисы
3. **Domain Isolation**: доступ ограничен namespace домена, нет cross-domain доступа
4. **Secret Protection**: доступ к secrets только для namespace-admin и sre-operator (для диагностики), запрещён для developers и viewers
5. **Audit Trail**: все действия логируются Kubernetes Audit Log для анализа (Task 6)

## Верификация

### Критерии успеха
- [ ] Специалист по ИБ может управлять всем кластером
- [ ] Менеджеры видят статус всех приложений, но не могут изменять ресурсы
- [ ] DevOps может деплоить в свой namespace, но не в чужие
- [ ] Разработчики могут отлаживать pods, но не могут читать secrets
- [ ] SRE могут перезапускать pods и читать logs, но не могут удалять deployments
