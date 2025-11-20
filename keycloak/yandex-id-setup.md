# Настройка Яндекс ID в Keycloak

## ℹ️ Статус конфигурации

✅ **Конфигурация Яндекс ID уже включена в realm `reports-realm`** и импортируется автоматически при запуске системы через `make init`.

Этот документ описывает, как **добавить реальные Client ID и Client Secret** от Яндекса для активации интеграции.

---

## 📋 Шаг 1: Регистрация приложения в Яндекс OAuth

1. **Перейдите на портал Яндекс OAuth**: https://oauth.yandex.ru/
2. **Создайте новое приложение** (нажмите "Зарегистрировать новое приложение")
3. **Заполните форму**:
   - Название: `BionicPRO Reports`
   - Платформа: `Веб-сервисы`
4. **Укажите Redirect URI**:
   ```
   http://localhost:8080/realms/reports-realm/broker/yandex/endpoint
   ```

5. **Выберите права доступа** (scopes):
   - ✅ `login:email` - доступ к email адресу
   - ✅ `login:info` - доступ к имени и фамилии

6. **Сохраните и получите**:
   - **Client ID** (идентификатор приложения)
   - **Client Secret** (пароль приложения)

---

## 🔧 Шаг 2: Добавление Client ID и Secret в Keycloak

### Вариант A: Через UI (рекомендуется)

1. **Откройте Keycloak Admin Console**: http://localhost:8080
   - Логин: `admin`
   - Пароль: `admin`

2. **Выберите realm**: `reports-realm` (в выпадающем списке сверху слева)

3. **Перейдите**: Identity Providers → **yandex** (уже настроен!)

4. **Обновите учетные данные**:
   - **Client ID**: вставьте ваш Client ID из Яндекса
   - **Client Secret**: вставьте ваш Client Secret из Яндекса

5. **Нажмите "Save"**

### Вариант B: Через переменные окружения

Обновите `docker-compose.yaml` (секция `keycloak`):

```yaml
environment:
  YANDEX_CLIENT_ID: "ваш_client_id"
  YANDEX_CLIENT_SECRET: "ваш_client_secret"
```

---

## ✅ Шаг 3: Проверка конфигурации

### Текущая конфигурация (уже настроено):

- ✅ **Alias**: `yandex`
- ✅ **Display Name**: `Яндекс ID`
- ✅ **Provider Type**: OpenID Connect (OIDC)
- ✅ **PKCE**: Включен (S256)
- ✅ **Authorization URL**: `https://oauth.yandex.ru/authorize`
- ✅ **Token URL**: `https://oauth.yandex.ru/token`
- ✅ **User Info URL**: `https://login.yandex.ru/info`
- ✅ **Default Scopes**: `login:email login:info`
- ✅ **Sync Mode**: `IMPORT`
- ✅ **Trust Email**: `true`
- ✅ **First Broker Login Flow**: `first broker login`

### Attribute Mappers (уже настроены):

| Mapper | Claim (Яндекс) | User Attribute (Keycloak) |
|--------|----------------|---------------------------|
| ✅ yandex-email-mapper | `default_email` | `email` |
| ✅ yandex-firstname-mapper | `first_name` | `firstName` |
| ✅ yandex-lastname-mapper | `last_name` | `lastName` |
| ✅ yandex-username-mapper | `login` | `username` |

---

## 🧪 Шаг 4: Тестирование интеграции

1. **Откройте frontend**: http://localhost:3000

2. **Нажмите "Sign in with Keycloak"**

3. **На странице логина Keycloak** вы должны увидеть кнопку **"Яндекс ID"**

4. **Нажмите на "Яндекс ID"** → вас перенаправит на Яндекс

5. **Войдите через Яндекс** → при первом входе Яндекс запросит разрешение на доступ к данным

6. **Подтвердите доступ** → вас вернет в приложение

7. **Проверьте в Keycloak Admin Console**:
   - Users → найдите пользователя, созданного из Яндекса
   - Проверьте атрибуты (email, firstName, lastName)

---

## 🔒 Безопасность

### Что уже реализовано:

- ✅ **PKCE (S256)**: Защита от перехвата authorization code
- ✅ **State parameter**: Защита от CSRF атак
- ✅ **HTTP-only cookies**: Токены не доступны из JavaScript
- ✅ **Token не сохраняются**: `storeToken: false` (токены Яндекса не хранятся в Keycloak)
- ✅ **Consent screen**: При первом входе запрос разрешения от пользователя (на стороне Яндекса)

---

## 📊 First Broker Login Flow

При первом входе через Яндекс ID происходит:

1. **Review Profile** (`on`): Пользователь может просмотреть данные профиля
2. **Create User If Unique**: Создание нового пользователя, если email уникален
3. **Link Existing Account**: Если пользователь с таким email существует, возможность связать аккаунты

---

## 🐛 Troubleshooting

### Проблема: Кнопка "Яндекс ID" не отображается

**Решение**:
```bash
# Проверьте, что realm импортирован
make check

# Проверьте логи Keycloak
make logs-keycloak | grep -i yandex
```

### Проблема: Ошибка "Invalid redirect_uri"

**Решение**: Проверьте, что в Яндекс OAuth указан правильный Redirect URI:
```
http://localhost:8080/realms/reports-realm/broker/yandex/endpoint
```

### Проблема: "Client authentication failed"

**Решение**: Проверьте Client ID и Client Secret в Keycloak (Identity Providers → yandex)

---

## 📚 Дополнительные ресурсы

- [Yandex OAuth Documentation](https://yandex.ru/dev/id/doc/ru/)
- [Keycloak Identity Brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)

