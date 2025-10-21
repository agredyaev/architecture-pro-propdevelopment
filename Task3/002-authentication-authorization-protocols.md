## 2. Протоколы аутентификации и авторизации

### 2.1 Аутентификация PropDevelopment → Платформа партнёра

**REQ-AUTH-001**: Использовать OAuth 2.0 Client Credentials Flow (RFC 6749)

**Обоснование**: Machine-to-machine (M2M) взаимодействие. Client Credentials - стандарт для сервисных аккаунтов без участия пользователя.

**REQ-AUTH-002**: Access Token MUST иметь срок жизни ≤ 1 час
**REQ-AUTH-003**: Smart Home Integration Service MUST обновлять токены автоматически при истечении
**REQ-AUTH-004**: Client Secret MUST храниться в KMS (HashiCorp Vault), запрещено хардкодить
**REQ-AUTH-005**: Ротация Client Secret: ежеквартально

### 2.2 Аутентификация Мобильное приложение → API Gateway → Smart Home Integration Service

**REQ-AUTH-006**: Использовать JWT (JSON Web Token, RFC 7519)

**Обоснование**: Stateless аутентификация, подпись токена гарантирует целостность, можно встроить `tenant_id` для Tenant Isolation.

**REQ-AUTH-007**: JWT MUST подписываться алгоритмом RS256 (RSA + SHA-256, асимметричное шифрование)
**REQ-AUTH-008**: JWT MUST содержать `tenant_id` для проверки Tenant Isolation
**REQ-AUTH-009**: JWT срок жизни: 15 минут (Access Token), 7 дней (Refresh Token)
**REQ-AUTH-010**: API Gateway MUST валидировать подпись JWT при каждом запросе
**REQ-AUTH-011**: API Gateway MUST проверять `exp` (expiration) и отклонять истёкшие токены

### 2.3 Авторизация (RBAC - Role-Based Access Control)

**REQ-AUTHZ-001**: Реализовать RBAC с ролями:
- **owner** (собственник): может управлять доступом только для своей квартиры
- **administrator** (администратор УК): может управлять всеми квартирами в ЖК
- **guest** (гость): read-only доступ к статусу устройств

**REQ-AUTHZ-002**: Проверка авторизации на уровне Smart Home Integration Service

**REQ-AUTHZ-003**: Матрица доступа:

| Роль | Управление доступом (добавить лицо/номер) | Открыть дверь/шлагбаум | Просмотр логов доступа | Удаление данных |
|------|-------------------------------------------|------------------------|------------------------|-----------------|
| owner | Yes (только своя квартира) | Yes (только своя квартира) | Yes (только своя квартира) | Yes (только свои данные) |
| administrator | Yes (весь ЖК) | Yes (весь ЖК) | Yes (весь ЖК) | Yes (весь ЖК) |
| guest | No | No | Yes (read-only) | No |

**Обоснование**: Принцип least privilege (минимальных привилегий). Защита от несанкционированного доступа.

### 2.4 Webhook аутентификация (от платформы партнёра → PropDevelopment)

**REQ-AUTH-012**: Если платформа партнёра отправляет Webhook (события от устройств), аутентифицировать их через HMAC-SHA256 signature

**REQ-AUTH-013**: Shared Secret для HMAC MUST храниться в KMS
**REQ-AUTH-014**: Webhook MUST содержать timestamp, API Gateway отклоняет события старше 5 минут (защита от replay attacks)