TUNING_WORKSHOP_ID ?= 3360453136
STEAMDECK ?= deck@steamdeck
DESKTOP ?= pete@fitzgerald-1

DEPLOY := ./scripts/deploy_mod.sh

.PHONY: deploy-tuning deploy-tuning-steamdeck deploy-tuning-desktop

deploy-tuning: deploy-tuning-steamdeck deploy-tuning-desktop

deploy-tuning-steamdeck:
	$(DEPLOY) tuning $(TUNING_WORKSHOP_ID) $(STEAMDECK)

deploy-tuning-desktop:
	$(DEPLOY) tuning $(TUNING_WORKSHOP_ID) $(DESKTOP)
