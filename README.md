# BionicPRO - Повышение безопасности системы

## 📋 Обзор решения

Реализовано комплексное решение для устранения уязвимостей системы BionicPRO:

1. **PKCE (Proof Key for Code Exchange)** - защита от перехвата authorization code
2. **Backend for Frontend (BFF)** - токены изолированы от фронтенда
3. **LDAP Federation** - поддержка пользователей из разных стран
4. **MFA через OTP** - обязательная двухфакторная аутентификация
5. **Яндекс ID** - интеграция внешнего IdP

## 🚀 Быстрый старт

### Запуск одной командой (рекомендуется)

```bash
git clone https://github.com/Yandex-Practicum/architecture-bionicpro.git
cd architecture-bionicpro-s9
make init
```

## 📚 Команды Makefile

### Основные команды

```bash
make help         # Показать все доступные команды
make init         # ⭐ Полная автоматическая установка (РЕКОМЕНДУЕТСЯ)
make start        # Альтернатива для init
```

### Управление сервисами

```bash
make build        # Собрать Docker образы
make up           # Запустить сервисы
make down         # Остановить сервисы
make restart      # Перезапустить сервисы
make clean        # Очистить данные и volumes
```

### Проверка и мониторинг

```bash
make check        # Проверить доступность всех сервисов
make check-ldap   # Проверить LDAP пользователей и группы
make check-auth   # Проверить API аутентификации
make logs         # Просмотр логов всех сервисов
make monitor      # Мониторинг активных сессий
```

### Логи отдельных сервисов

```bash
make logs-keycloak    # Логи Keycloak
make logs-auth        # Логи bionicpro-auth
make logs-frontend    # Логи frontend
make logs-ldap        # Логи OpenLDAP
```

### Переинициализация

```bash
make sync-ldap        # Синхронизировать LDAP пользователей с Keycloak
make reinit-ldap      # Перезагрузить данные LDAP
make reinit-keycloak  # Перепроверить Keycloak
make reinit-all       # Полная переинициализация
```

### Быстрый перезапуск отдельных сервисов

```bash
make restart-auth       # Перезапустить bionicpro-auth
make restart-frontend   # Перезапустить frontend
make restart-keycloak   # Перезапустить Keycloak
```

## 🔗 URL сервисов

После запуска `make init` доступны:

- **Frontend**: http://localhost:3000
- **Keycloak**: http://localhost:8080 (admin / admin)
- **BionicPRO Auth API**: http://localhost:8000
- **phpLDAPadmin**: http://localhost:6443

## 👤 Тестовые пользователи LDAP

- **john.doe** / password (роль: prothetic_user)
- **jane.smith** / password (роль: user)
- **alex.johnson** / password (роль: prothetic_user)

> **Примечание**: При первом входе потребуется настроить OTP (двухфакторную аутентификацию). Отсканируйте QR-код в приложении Google Authenticator или FreeOTP.

## 🏗️ Технологический стек

- **Frontend**: React + TypeScript
- **Backend**: Python (FastAPI)
- **IAM**: Keycloak
- **LDAP**: OpenLDAP
- **Infrastructure**: Docker Compose

## 📁 Структура проекта

```
bionicpro-s9/
├── bionicpro-auth/     # BFF сервис (Python/FastAPI)
├── frontend/           # React приложение с PKCE
├── keycloak/           # Конфигурация Keycloak
├── ldap/               # LDAP данные (config.ldif)
├── scripts/            # Скрипты автоматической инициализации
├── Makefile            # Команды управления
└── docker-compose.yaml # Оркестрация сервисов
```

## 🔐 Компоненты безопасности

### 1. PKCE Flow
- Frontend генерирует `code_verifier` и `code_challenge`
- Защита от перехвата authorization code

### 2. BFF (Backend for Frontend)
- Токены хранятся только на бэкенде
- Frontend получает HTTP-only Secure cookie
- Автоматическое обновление токенов
- Ротация сессий

### 3. LDAP Federation
- Интеграция с OpenLDAP
- Маппинг ролей между представительствами

### 4. MFA
- OTP через Google Authenticator / FreeOTP
- Настраивается в Keycloak Admin Console

### 5. Яндекс ID (не работает, т.к. Яндекс не поддерживает работу с oidc)
- Identity Brokering через OpenID Connect
- См. `keycloak/yandex-id-setup.md`

## 📦 Результаты Assignment 1

### Выполненные задачи

✅ **Задача 1.1**: Архитектурное решение
- Диаграмма C4 в [BionicPro_auth_C4.drawio.xml](diagrams/BionicPro_auth_C4.drawio.xml)
- Унификация доступа через внешние IdP
- Локальное хранение персональных данных
- Безопасная работа с токенами

✅ **Задача 1.2**: PKCE реализация
- Frontend генерирует `code_verifier` и `code_challenge`
- Keycloak настроен на PKCE
- Защита от перехвата authorization code

✅ **Задача 1.3**: Backend for Frontend (BFF)
- Новый сервис `bionicpro-auth` (Python/FastAPI)
- Токены хранятся только на бэкенде
- HTTP-only Secure cookies для сессий
- Автоматическое обновление access token
- Ротация сессий для защиты от session fixation

✅ **Задача 1.4**: LDAP Federation
- OpenLDAP развернут с тестовыми пользователями
- Keycloak интегрирован с LDAP
- User Attribute Mappers настроены
- Маппинг групп и ролей работает

✅ **Задача 1.5**: Multi-Factor Authentication (MFA)
- OTP обязателен для всех пользователей
- Поддержка Google Authenticator и FreeOTP
- Настройка при первом входе

✅ **Задача 1.6**: Яндекс ID Integration
- Identity Brokering через OpenID Connect
- Конфигурация в [yandex-id-setup.md](keycloak/yandex-id-setup.md)
- Запрос согласия на использование данных

### Артефакты

- **Код PKCE**: `frontend/src/utils/pkce.ts`
- **BFF сервис**: `bionicpro-auth/`
- **Frontend изменения**: `frontend/src/`
- **LDAP конфигурация**: `ldap/config.ldif`
- **Keycloak realm**: `keycloak/realm-export.json`
- **Финальная конфигурация**: `keycloak/keycloak-results-export.json` (создать через `make export-realm`)

## 🐛 Решение проблем

### Ошибки при сборке

```bash
# Если возникли ошибки TypeScript
make clean
make build

# Полная пересборка
docker-compose build --no-cache
```

### LDAP не запускается

```bash
# Пересоздать LDAP с данными
make down
sudo rm -rf ldap-data ldap-config
make init
```

### Сервисы не отвечают

```bash
# Проверить логи
make logs

# Проверить статус контейнеров
docker-compose ps

# Перезапустить всё
make restart
```

## ✅ Достигнутые улучшения безопасности

- ✅ Токены недоступны для JavaScript (защита от XSS)
- ✅ PKCE защищает от MITM атак
- ✅ Сессии привязаны к IP и User-Agent
- ✅ Ротация сессий (защита от session fixation)
- ✅ MFA обязательна
- ✅ Федерация через LDAP