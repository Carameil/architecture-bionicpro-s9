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
	@echo "  make logs-reports     - Логи bionicpro-reports"
	@echo "  make logs-frontend    - Логи frontend"
	@echo "  make logs-ldap        - Логи OpenLDAP"
	@echo "  make logs-clickhouse  - Логи ClickHouse"
	@echo "  make logs-airflow     - Логи Airflow"
	@echo ""
	@echo "$(YELLOW)Assignment 2 - Reports Service:$(NC)"
	@echo "  make check-clickhouse - Проверить ClickHouse"
	@echo "  make check-airflow    - Проверить Airflow"
	@echo "  make trigger-etl      - Запустить ETL вручную"
	@echo ""
	@echo "$(YELLOW)Assignment 3 - S3 & CDN Caching:$(NC)"
	@echo "  make check-s3         - Проверить MinIO (S3)"
	@echo "  make check-cdn        - Проверить Nginx CDN"
	@echo ""
	@echo "$(YELLOW)Assignment 4 - CDC with Debezium:$(NC)"
	@echo "  make check-kafka      - Проверить Kafka"
	@echo "  make check-kafka-connect - Проверить Kafka Connect"
	@echo "  make check-postgres-crm - Проверить PostgreSQL CRM"
	@echo "  make register-debezium - Зарегистрировать Debezium connector"
	@echo "  make check-debezium   - Проверить статус Debezium connector"
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
	@echo "  Reports API:     http://localhost:8002"
	@echo "  ClickHouse:      http://localhost:8123"
	@echo "  Airflow UI:      http://localhost:8081 (admin/admin)"
	@echo "  phpLDAPadmin:    http://localhost:6443"

# Проверка доступности сервисов
check:
	@echo "$(YELLOW)=== Assignment 1: Auth Services ===$(NC)"
	@echo -n "Keycloak:        "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "BionicPRO Auth:  "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Frontend:        "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "LDAP:            "
	@docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "dc=example,dc=com" -H ldap://localhost > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Assignment 2: Reports & ETL ===$(NC)"
	@echo -n "Reports API:     "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/health | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "ClickHouse:      "
	@curl -s http://localhost:8123/ping > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Airflow Web:     "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health | grep -q "200" && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Assignment 3: S3 & CDN ===$(NC)"
	@echo -n "MinIO (S3):      "
	@curl -s http://localhost:9002/minio/health/live > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Nginx CDN:       "
	@curl -s http://localhost:8090/health > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Assignment 4: CDC with Debezium ===$(NC)"
	@echo -n "PostgreSQL CRM:  "
	@docker exec bionicpro-postgres-crm pg_isready -U crmuser -d crmdb > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Kafka:           "
	@docker exec bionicpro-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"
	@echo -n "Kafka Connect:   "
	@curl -s http://localhost:8083/ > /dev/null 2>&1 && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Недоступен$(NC)"

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

# Assignment 2: Reports Service Commands

check-clickhouse:
	@echo "$(YELLOW)Проверка ClickHouse...$(NC)"
	@curl -sf http://localhost:8123/ping > /dev/null && \
		echo "$(GREEN)ClickHouse: ✓ OK$(NC)" || \
		echo "$(RED)ClickHouse: ✗ Недоступен$(NC)"
	@docker exec bionicpro-clickhouse clickhouse-client --query "SELECT count() as reports FROM bionicpro.user_reports" 2>/dev/null && \
		echo "$(GREEN)  Reports data loaded$(NC)" || true

check-airflow:
	@echo "$(YELLOW)Проверка Airflow...$(NC)"
	@curl -sf http://localhost:8081/health > /dev/null && \
		echo "$(GREEN)Airflow Web: ✓ OK$(NC)" || \
		echo "$(RED)Airflow Web: ✗ Недоступен$(NC)"
	@docker ps | grep airflow-scheduler > /dev/null && \
		echo "$(GREEN)Airflow Scheduler: ✓ Запущен$(NC)" || \
		echo "$(RED)Airflow Scheduler: ✗ Остановлен$(NC)"

check-reports:
	@echo "$(YELLOW)Проверка Reports API...$(NC)"
	@curl -sf http://localhost:8002/health > /dev/null && \
		echo "$(GREEN)Reports API: ✓ OK$(NC)" || \
		echo "$(RED)Reports API: ✗ Недоступен$(NC)"

trigger-etl:
	@echo "$(YELLOW)Запуск ETL вручную...$(NC)"
	@echo "Открывается Airflow UI: http://localhost:8081"
	@echo "Логин: admin / admin"
	@echo "Найдите DAG 'bionicpro_reports_etl' и нажмите 'Trigger DAG'"

logs-reports:
	@echo "$(YELLOW)Логи bionicpro-reports:$(NC)"
	docker-compose logs -f bionicpro-reports

logs-clickhouse:
	@echo "$(YELLOW)Логи ClickHouse:$(NC)"
	docker-compose logs -f clickhouse

logs-airflow:
	@echo "$(YELLOW)Логи Airflow (webserver + scheduler):$(NC)"
	docker-compose logs -f airflow-webserver airflow-scheduler

# Assignment 3: S3 & CDN Commands

check-s3:
	@echo "$(YELLOW)Проверка MinIO (S3)...$(NC)"
	@curl -sf http://localhost:9002/minio/health/live > /dev/null && \
		echo "$(GREEN)MinIO: ✓ OK$(NC)" || \
		echo "$(RED)MinIO: ✗ Недоступен$(NC)"

check-cdn:
	@echo "$(YELLOW)Проверка Nginx CDN...$(NC)"
	@curl -sf http://localhost:8090/health > /dev/null && \
		echo "$(GREEN)Nginx CDN: ✓ OK$(NC)" || \
		echo "$(RED)Nginx CDN: ✗ Недоступен$(NC)"

logs-minio:
	@echo "$(YELLOW)Логи MinIO:$(NC)"
	docker-compose logs -f minio

logs-nginx:
	@echo "$(YELLOW)Логи Nginx CDN:$(NC)"
	docker-compose logs -f nginx-cdn

# Assignment 4: CDC with Debezium Commands

check-kafka:
	@echo "$(YELLOW)Проверка Kafka...$(NC)"
	@docker exec bionicpro-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && \
		echo "$(GREEN)Kafka: ✓ OK$(NC)" || \
		echo "$(RED)Kafka: ✗ Недоступен$(NC)"

check-kafka-connect:
	@echo "$(YELLOW)Проверка Kafka Connect...$(NC)"
	@curl -sf http://localhost:8083/ > /dev/null && \
		echo "$(GREEN)Kafka Connect: ✓ OK$(NC)" || \
		echo "$(RED)Kafka Connect: ✗ Недоступен$(NC)"

check-postgres-crm:
	@echo "$(YELLOW)Проверка PostgreSQL CRM...$(NC)"
	@docker exec bionicpro-postgres-crm pg_isready -U crmuser -d crmdb > /dev/null 2>&1 && \
		echo "$(GREEN)PostgreSQL CRM: ✓ OK$(NC)" || \
		echo "$(RED)PostgreSQL CRM: ✗ Недоступен$(NC)"
	@docker exec bionicpro-postgres-crm psql -U crmuser -d crmdb -c "SELECT COUNT(*) FROM customers" 2>/dev/null && \
		echo "$(GREEN)  CRM data loaded$(NC)" || true

register-debezium:
	@echo "$(YELLOW)Регистрация Debezium connector...$(NC)"
	@chmod +x debezium/register-connector.sh
	@bash debezium/register-connector.sh

check-debezium:
	@echo "$(YELLOW)Проверка Debezium connector...$(NC)"
	@curl -sf http://localhost:8083/connectors/bionicpro-crm-connector/status > /dev/null && \
		echo "$(GREEN)Debezium Connector: ✓ Зарегистрирован$(NC)" || \
		echo "$(RED)Debezium Connector: ✗ Не найден$(NC)"
	@curl -s http://localhost:8083/connectors/bionicpro-crm-connector/status 2>/dev/null | python3 -m json.tool || true

logs-kafka:
	@echo "$(YELLOW)Логи Kafka:$(NC)"
	docker-compose logs -f kafka

logs-kafka-connect:
	@echo "$(YELLOW)Логи Kafka Connect:$(NC)"
	docker-compose logs -f kafka-connect

logs-postgres-crm:
	@echo "$(YELLOW)Логи PostgreSQL CRM:$(NC)"
	docker-compose logs -f postgres-crm
