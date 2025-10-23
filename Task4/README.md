# Task 4: Kubernetes RBAC

Организация ролевой модели доступа к Kubernetes с учётом доменной структуры компании.

## Структура репозитория

```
Task4/
├── manifests/
│   ├── 10-namespaces-and-users.yaml   # Namespaces + service accounts
│   ├── 20-clusterroles.yaml           # Общие ClusterRole для всех доменов
│   └── 30-bindings.yaml               # ClusterRoleBinding/RoleBinding
├── scripts/
│   └── verify-rbac.sh                 # Проверка основных прав через kubectl auth can-i
├── Makefile                           # Автоматизация (validate/apply/delete/test)
├── rbac-roles-table.md                # Таблица ролей и полномочий
└── README.md                          # Этот файл
```

## Быстрый старт

```bash
make help           # Список целей
KUBECONFIG=$HOME/.kube/config make validate
KUBECONFIG=$HOME/.kube/config make apply
KUBECONFIG=$HOME/.kube/config make test-all
KUBECONFIG=$HOME/.kube/config make delete
```

## Роли и группы

| Роль             | Тип         | Назначение                                |
|------------------|-------------|--------------------------------------------|
| `cluster-admin`  | ClusterRole | Полный контроль (используется встроенная роль) |
| `cluster-viewer` | ClusterRole | Read-only без доступа к secrets            |
| `namespace-admin`| ClusterRole | Полный доступ в namespace домена (DevOps)  |
| `developer`      | ClusterRole | Read + exec. Отладка без секретов          |
| `sre-operator`   | ClusterRole | Read + restart. Без удаления сервисов      |

Подробности и мэппинг на группы пользователей - в `rbac-roles-table.md`.

## Основные цели Makefile

- `validate` - dry-run для всех YAML в каталоге `manifests/`
- `apply` - применяет манифесты в порядке: namespaces → clusterroles → bindings
- `delete`/`reset` - удаление ресурсов (reset дополнительно очищает тестовые объекты)
- `status` - быстрый обзор namespaces, service accounts и ролей
- `test-*` - ручные проверки прав для каждой роли
- `verify` - запуск скрипта `scripts/verify-rbac.sh` с набором канонических проверок

## Скрипт верификации

`scripts/verify-rbac.sh` выполняет ключевые `kubectl auth can-i` проверки:
- разработчик не видит secrets и не выходит за границы namespace
- devops не может деплоить в чужой namespace
- viewer не может удалять или читать secrets
- SRE может патчить deployment в своём домене

## Порядок применения

1. `make validate`
2. `make apply`
3. `make test-all` или `make verify`
4. `make delete` (по завершении проверки)

Все команды предполагают корректно настроенный `kubectl`/`KUBECONFIG`.
