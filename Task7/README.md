# Задание 7. Подтверждение политик безопасности контейнеров

Решение включает два уровня контроля:
- namespace `audit-zone` с профилем PodSecurity `restricted`;
- набор ограничений OPA Gatekeeper, запрещающих `privileged`, `hostPath`, запуск от root и требующих `readOnlyRootFilesystem: true`.

Для проверки используются примеры небезопасных и исправленных Pod-манифестов, а также скрипты, запускаемые через `Makefile`.

## Структура

```
Task7/
├── 01-create-namespace.yaml        # PodSecurity Admission (restricted)
├── audit-policy.yaml               # Политика аудита kube-apiserver
├── gatekeeper/
│   ├── constraint-templates/       # Rego-шаблоны ограничений
│   │   ├── hostpath.yaml
│   │   ├── privileged.yaml
│   │   ├── readonlyrootfs.yaml
│   │   └── runasnonroot.yaml
│   └── constraints/                # Применение правил к нужным namespace
│       ├── hostpath.yaml
│       ├── privileged.yaml
│       ├── readonlyrootfs.yaml
│       └── runasnonroot.yaml
├── insecure-manifests/             # Примеры нарушений (privileged, hostPath, UID 0)
├── secure-manifests/               # Исправленные Pod'ы
├── verify/
│   ├── verify-admission.sh         # E2E проверка отклонения/допуска pod'ов
│   └── validate-security.sh        # Аудит запущенных pod'ов
└── Makefile                        # Основные команды для проверки
```

## Предварительные требования
- Kubernetes 1.23+ с включённым PodSecurity Admission.
- Установлен `kubectl` (контекст указывает на нужный кластер).
- Установлен OPA Gatekeeper (`kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml`).
- Для запуска скриптов требуется `jq`.

## Основной рабочий процесс

| Команда | Назначение |
| --- | --- |
| `make setup` | Создать namespace `audit-zone` и применить политики Gatekeeper. |
| `make verify-admission` | Проверить, что небезопасные Pod'ы отклоняются, а безопасные проходят. |
| `make validate-security` | Проанализировать все Pod'ы в `audit-zone` на соблюдение требований. |
| `make apply-secure` | Развернуть безопасные примеры Pod'ов. |
| `make status` | Показывает состояние namespace и Pod'ов. |
| `make clean` | Удаляет примеры Pod'ов и namespace `audit-zone`. |

Команды можно комбинировать, например:

```bash
make setup
make verify-admission    # Совмещённая проверка admission-контроля
make validate-security   # Дополнительный аудит состояния кластера
make clean               # Очистка после проверки
```

Ожидаемые результаты:
- `verify-admission` сообщает об отклонении всех манифестов из `insecure-manifests/` и успешном применении файлов из `secure-manifests/`.
- `validate-security` не находит нарушений после развёртывания безопасных Pod'ов.

## Политика аудита

Файл `audit-policy.yaml` фиксирует все операции, связанные с PodSecurity и Gatekeeper. Для включения аудита скопируйте файл на master-ноду и добавьте в манифест `kube-apiserver` параметры:

```yaml
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

После перезапуска API-сервера убедитесь, что лог `/var/log/kubernetes/audit.log` генерируется.
