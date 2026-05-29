SHELL := /bin/bash
DIV   := ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: setup up down migrate capture token logs reset

## One-time setup: generate secrets and install capture deps
setup:
	@echo ""
	@echo "$(DIV)"
	@echo "  verifierform-stake-env — Setup"
	@echo "$(DIV)"
	@echo ""
	@if [ ! -f ".env" ]; then \
		cp .env.example .env; \
		echo "  → .env created from .env.example"; \
	fi
	@APP_KEY_VAL=$$(grep "^APP_KEY=" .env | cut -d'=' -f2-); \
	if [ -z "$$APP_KEY_VAL" ]; then \
		KEY="base64:$$(openssl rand -base64 32)"; \
		sed -i.bak "s|^APP_KEY=.*|APP_KEY=$$KEY|" .env && rm .env.bak; \
		echo "  ✓ APP_KEY generated"; \
	else \
		echo "  ✓ APP_KEY already set"; \
	fi
	@ADMIN_VAL=$$(grep "^STAKE_ADMIN_TOKEN=" .env | cut -d'=' -f2-); \
	if [ -z "$$ADMIN_VAL" ]; then \
		RAW=$$(openssl rand -hex 32); \
		HASH=$$(printf '%s' "$$RAW" | openssl dgst -sha256 | awk '{print $$NF}'); \
		sed -i.bak "s|^STAKE_ADMIN_TOKEN=.*|STAKE_ADMIN_TOKEN=$$HASH|" .env && rm .env.bak; \
		sed -i.bak "s|^STAKE_ADMIN_RAW_TOKEN=.*|STAKE_ADMIN_RAW_TOKEN=$$RAW|" .env && rm .env.bak; \
		echo "  ✓ Admin token pair generated (hash → container, raw → local only)"; \
	else \
		echo "  ✓ Admin token already set"; \
	fi
	@if [ ! -d "../stake-bet-lookup/scripts/node_modules" ]; then \
		(cd ../stake-bet-lookup/scripts && npm install --silent); \
		echo "  ✓ Capture script deps installed"; \
	fi
	@echo ""
	@echo "$(DIV)"
	@echo "  Setup complete!"
	@echo ""
	@echo "  Next:"
	@echo "    make up       — pull images and start all services"
	@echo "    make migrate  — run database migrations (first time)"
	@echo "    make capture  — capture Cloudflare clearance (required for real lookups)"
	@echo "$(DIV)"
	@echo ""

## Pull latest images and start all services
up:
	docker compose pull
	docker compose up -d
	@echo ""
	@echo "  App:  http://localhost:$${PORT:-3000}"
	@echo ""
	@echo "  First time? Run:  make migrate"
	@echo "  Real lookups?     make capture"
	@echo ""

## Stop all services
down:
	docker compose down --remove-orphans

## Run database migrations (required after first 'make up')
migrate:
	docker compose exec lookup-app php artisan migrate --force

## Capture Cloudflare clearance credentials (required for live Stake lookups)
##
## Reads STAKE_ADMIN_RAW_TOKEN from .env and writes scripts/sync-config.json
## pointing at this environment's endpoint before delegating to stake-bet-lookup.
capture:
	@if [ ! -f ".env" ]; then echo "  ✗ Run make setup first"; exit 1; fi
	@RAW=$$(grep "^STAKE_ADMIN_RAW_TOKEN=" .env | cut -d'=' -f2-); \
	if [ -z "$$RAW" ]; then \
		echo "  ✗ STAKE_ADMIN_RAW_TOKEN not set — run make setup"; \
		exit 1; \
	fi
	@printf '{\n  "method": "api",\n  "api": {\n    "endpoint": "http://localhost:%s/api/admin/update-clearance",\n    "token": "%s"\n  }\n}\n' \
		"$${PORT:-3000}" "$$RAW" \
		> ../stake-bet-lookup/scripts/sync-config.json
	$(MAKE) -C ../stake-bet-lookup capture

## Rotate the admin token
token:
	@if [ ! -f ".env" ]; then echo "  ✗ Run make setup first"; exit 1; fi
	@RAW=$$(openssl rand -hex 32); \
	HASH=$$(printf '%s' "$$RAW" | openssl dgst -sha256 | awk '{print $$NF}'); \
	sed -i.bak "s|^STAKE_ADMIN_TOKEN=.*|STAKE_ADMIN_TOKEN=$$HASH|" .env && rm .env.bak; \
	sed -i.bak "s|^STAKE_ADMIN_RAW_TOKEN=.*|STAKE_ADMIN_RAW_TOKEN=$$RAW|" .env && rm .env.bak; \
	echo "  ✓ Token rotated — hash and raw written to .env"; \
	echo "  Run 'make up' to apply."

## Tail logs from all services
logs:
	docker compose logs -f

## Wipe all Docker volumes (fresh database)
reset:
	docker compose down -v --remove-orphans
	@echo "Volumes cleared. Run 'make up && make migrate' to restart."
