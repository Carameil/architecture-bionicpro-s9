# BionicPRO Makefile
# Автоматизация развертывания и управления проектом

.PHONY: help build up down restart logs clean setup init check test

# Цвета для вывода
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# По умолчанию показываем помощь
help:
	@echo "$(GREEN)BionicPRO - Команды для управления проектом$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 Быстрый старт:$(NC)"
	@echo "  make init         - ⭐ ПОЛНАЯ автоматическая установка (рекомендуется)"
	@echo "  make start        - Альтернатива для init"
	@echo ""
	@echo "$(YELLOW)Основные команды:$(NC)"
	@echo "  make build        - Собрать все Docker образы"
	@echo "  make up           - Запустить все сервисы"
	@echo "  make down         - Остановить все сервисы"
	@echo "  make restart      - Перезапустить все сервисы"
	@echo "  make logs         - Показать логи всех сервисов"
	@echo "  make clean        - Очистить данные и остановить сервисы"
	@echo ""
	@echo "$(YELLOW)Настройка и проверка:$(NC)"
	@echo "  make setup        - Установка без автоинициализации"
	@echo "  make check        - Проверить доступность сервисов"
	@echo "  make test         - Запустить тесты"
	@echo "  make check-ldap   - Проверить LDAP пользователей"
	@echo "  make check-auth   - Проверить аутентификацию"
	@echo ""
	@echo "$(YELLOW)Логи отдельных сервисов:$(NC)"
	@echo "  make logs-keycloak    - Логи Keycloak"
	@echo "  make logs-auth        - Логи bionicpro-auth"
	@echo "  make logs-frontend    - Логи frontend"
	@echo "  make logs-ldap        - Логи OpenLDAP"
	@echo ""
	@echo "$(YELLOW)Переинициализация:$(NC)"
	@echo "  make sync-ldap        - Синхронизировать LDAP пользователей с Keycloak"
	@echo "  make reinit-ldap      - Перезагрузить данные LDAP"
	@echo "  make reinit-keycloak  - Перепроверить Keycloak"
	@echo "  make reinit-all       - Полная переинициализация"

# Сборка всех образов
build:
	@echo "$(GREEN)Сборка Docker образов...$(NC)"
	docker-compose build

# Запуск всех сервисов (без инициализации)
up:
	@echo "$(GREEN)Запуск сервисов...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Сервисы запущены!$(NC)"

# Полная автоматическая инициализация (рекомендуется)
init: build
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)  BionicPRO - Полная инициализация$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	docker-compose up -d
	@echo "$(YELLOW)Запуск скрипта автоматической инициализации...$(NC)"
	@bash scripts/init-all.sh
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✅ Система полностью готова к работе!$(NC)"
	@echo "$(GREEN)========================================$(NC)"

# Альтернативное название для init
start: init

# Остановка всех сервисов
down:
	@echo "$(YELLOW)Остановка сервисов...$(NC)"
	docker-compose down

# Перезапуск сервисов
restart: down up

# Показать логи всех сервисов
logs:
	docker-compose logs -f

# Логи отдельных сервисов
logs-keycloak:
	docker-compose logs -f keycloak

logs-auth:
	docker-compose logs -f bionicpro-auth

logs-frontend:
	docker-compose logs -f frontend

logs-ldap:
	docker-compose logs -f openldap

# Очистка данных
clean:
	@echo "$(RED)Остановка сервисов и удаление данных...$(NC)"
	docker-compose down -v
	rm -rf postgres-keycloak-data ldap-data ldap-config
	@echo "$(GREEN)Очистка завершена!$(NC)"

# Полная установка и настройка
setup: build up
	@echo "$(GREEN)Настройка Keycloak...$(NC)"
	@if [ -x ./keycloak/setup-keycloak.sh ]; then \
		./keycloak/setup-keycloak.sh; \
	else \
		echo "$(YELLOW)Скрипт настройки Keycloak не найден или не исполняемый$(NC)"; \
	fi
	@echo "$(GREEN)Установка завершена!$(NC)"
	@echo ""
	@echo "$(YELLOW)Доступные сервисы:$(NC)"
	@echo "  Frontend:        http://localhost:3000"
	@echo "  Keycloak:        http://localhost:8080"
	@echo "  BionicPRO Auth:  http://localhost:8000"
	@echo "  phpLDAPadmin:    http://localhost:6443"

# Проверка доступности сервисов
check:
	@echo "$(YELLOW)Проверка доступности сервисов...$(NC)"
	@echo -n "Keycloak:        "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "BionicPRO Auth:  "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Frontend:        "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "LDAP:            "
	@docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "dc=example,dc=com" -H ldap://localhost > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"

# Проверка LDAP пользователей
check-ldap:
	@echo "$(YELLOW)LDAP пользователи:$(NC)"
	@docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "ou=People,dc=example,dc=com" -H ldap://localhost uid | grep "uid:" || echo "$(RED)Пользователи не найдены$(NC)"
	@echo ""
	@echo "$(YELLOW)LDAP группы:$(NC)"
	@docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "ou=Groups,dc=example,dc=com" -H ldap://localhost cn | grep "cn:" || echo "$(RED)Группы не найдены$(NC)"

# Проверка аутентификации
check-auth:
	@echo "$(YELLOW)Проверка API аутентификации:$(NC)"
	@echo -n "Health endpoint: "
	@curl -s http://localhost:8000/health | jq -r '.status' | grep -q "healthy" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Ошибка$(NC)"
	@echo -n "Auth check:      "
	@curl -s http://localhost:8000/api/auth/check | jq -r '.authenticated' | grep -q "false" && echo "$(GREEN)✓ OK (не аутентифицирован)$(NC)" || echo "$(RED)✗ Ошибка$(NC)"

# Запуск тестов
test: check
	@echo "$(YELLOW)Запуск тестов PKCE...$(NC)"
	@echo "Откройте браузер и перейдите на http://localhost:3000"
	@echo "Проверьте DevTools Network на наличие code_challenge параметра"

# Мониторинг активных сессий
monitor:
	@echo "$(YELLOW)Активные сессии:$(NC)"
	@curl -s http://localhost:8000/api/sessions/active | jq '.'

# Быстрый перезапуск отдельных сервисов
restart-auth:
	docker-compose restart bionicpro-auth

restart-frontend:
	docker-compose restart frontend

restart-keycloak:
	docker-compose restart keycloak

# Подключение к контейнерам
shell-auth:
	docker exec -it bionicpro-auth /bin/bash

shell-keycloak:
	docker exec -it bionicpro_keycloak_1 /bin/bash

shell-ldap:
	docker exec -it bionicpro-ldap /bin/bash

# Переинициализация компонентов
reinit-ldap:
	@echo "$(YELLOW)Переинициализация LDAP...$(NC)"
	@bash scripts/init-ldap.sh

reinit-keycloak:
	@echo "$(YELLOW)Переинициализация Keycloak...$(NC)"
	@bash scripts/init-keycloak.sh

reinit-all:
	@echo "$(YELLOW)Переинициализация всех компонентов...$(NC)"
	@bash scripts/init-all.sh

# Синхронизация LDAP пользователей с Keycloak
sync-ldap:
	@echo "$(YELLOW)Синхронизация LDAP пользователей...$(NC)"
	@chmod +x scripts/sync-ldap-users.sh
	@bash scripts/sync-ldap-users.sh
