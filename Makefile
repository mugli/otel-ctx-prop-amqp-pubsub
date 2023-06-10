.PHONY: all
all: help

build: ## Build docker-compose
	docker-compose build

run: ## Run docker-compose
	docker-compose up --force-recreate --attach ruby_emit_logs --attach ruby_receive_logs --attach http_logger

clean: ## Remove all service containers, orphans and one off containers.
	docker-compose down -v --remove-orphans
	docker-compose rm -v


## help: Show help and exit.
help: ## Show this help message
	@echo "# Makefile Help #"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
