.PHONY: up down logs test build

up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f

test:
	cd app && ./gradlew test

build:
	cd app && ./gradlew build
