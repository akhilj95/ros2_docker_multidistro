# ==============================================================================
# Generic multi-distro ROS 2 workspace — common operations.
#
#   make init                    # generate .env from your host user (run once)
#   make shell DISTRO=humble     # build if needed, start, drop into a terminal
#   make jazzy                   # shortcut for: make shell DISTRO=jazzy
#   make build DISTRO=jazzy      # (re)build the image
#   make shell DISTRO=humble GPU=1   # with NVIDIA GPU passthrough
#
# DISTRO defaults to whatever ROS_DISTRO is in .env (falls back to 'humble').
# Run `make help` for the full list.
# ==============================================================================
SHELL := /bin/bash
COMPOSE := docker compose

# Default distro comes from .env if present, else humble.
DISTRO ?= $(shell [ -f .env ] && grep -E '^ROS_DISTRO=' .env | cut -d= -f2 || echo humble)
GPU ?= 0

ifeq ($(GPU),1)
  COMPOSE_FILES := -f compose.yml -f compose.gpu.yml
else
  COMPOSE_FILES := -f compose.yml
endif

# Exported so `docker compose` interpolates ${ROS_DISTRO} in image/container/volume names.
export ROS_DISTRO := $(DISTRO)
# Each distro gets its OWN compose project, so `up`/`down` on one never touches
# another (they'd otherwise share the single 'ros2' service and get reconciled).
export COMPOSE_PROJECT_NAME := ros2_$(DISTRO)

WS := ws/$(DISTRO)

.DEFAULT_GOAL := help
.PHONY: help init build up down shell import rebuild clean status prune humble jazzy kilted rolling

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "  DISTRO=$(DISTRO) (override with DISTRO=<name>)   GPU=$(GPU) (set GPU=1 for NVIDIA)"

init: ## Generate .env from your host user (UID/GID matching). Run once.
	@./scripts/init.sh $(DISTRO)

build: ## Build the image for DISTRO
	@mkdir -p $(WS)/src $(WS)/build $(WS)/install $(WS)/log
	@$(COMPOSE) $(COMPOSE_FILES) build

up: ## Start the DISTRO container in the background
	@mkdir -p $(WS)/src $(WS)/build $(WS)/install $(WS)/log
	@$(COMPOSE) $(COMPOSE_FILES) up -d

shell: ## Open a terminal in the DISTRO container (builds/starts it if needed)
	@./scripts/shell.sh "$(DISTRO)" "$(GPU)"

import: ## vcs import ws/DISTRO/project.repos into the workspace (host or container)
	@./scripts/import.sh "$(DISTRO)"

down: ## Stop and remove the DISTRO container
	@$(COMPOSE) $(COMPOSE_FILES) down

rebuild: ## Re-run colcon build inside the DISTRO container
	@$(COMPOSE) $(COMPOSE_FILES) exec ros2 bash -lc 'source /etc/ros2_shell_setup.sh && cb'

clean: ## Remove colcon build/install/log for DISTRO (keeps src)
	@rm -rf $(WS)/build $(WS)/install $(WS)/log
	@echo "Cleaned $(WS). Run 'make rebuild DISTRO=$(DISTRO)'."

status: ## Show running containers
	@docker ps --filter "name=ros2_" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

# ---- Convenience shortcuts (copy a line to add a distro) --------------------
humble:  ## Shell into Humble
	@$(MAKE) --no-print-directory shell DISTRO=humble  GPU=$(GPU)
jazzy:   ## Shell into Jazzy
	@$(MAKE) --no-print-directory shell DISTRO=jazzy   GPU=$(GPU)
kilted:  ## Shell into Kilted
	@$(MAKE) --no-print-directory shell DISTRO=kilted  GPU=$(GPU)
rolling: ## Shell into Rolling
	@$(MAKE) --no-print-directory shell DISTRO=rolling GPU=$(GPU)