PACKER ?= packer
PACKER_LOG ?= 1


.PHONY: clean-lxd
clean-lxd:
	./../scripts/clean_lxd.sh democluster

.PHONY: clean
clean:
	sudo rm -rf output-*
	rm -f *.fd
	rm -f seeds-cloudimg.iso
	rm -f *.img

.PHONY: check-deps
check-deps: ## Check deps needed to build the image
	dpkg -s qemu-system wget libnbd-bin nbdkit fuse2fs cloud-image-utils wget > /dev/null

.PHONY: init
init: ## Run packer init .
	@if [ ! -z "$JG_VERSION" ]; then\
		sed -i 's/jobbergate-agent==[0-9]\+\.[0-9]\+\.[0-9]\+/jobbergate-agent==$(JG_VERSION)/' user-data;\
    fi
	${PACKER} init .

.PHONY: stage0
stage0: check-deps init ## Build democluster stage 0
	PACKER_LOG=${PACKER_LOG} ${PACKER} build -only=stage0.* .

.PHONY: final
final: check-deps init ## Build democluster img file for use with multipass
	PACKER_LOG=${PACKER_LOG} ${PACKER} build -only=final.* .

.PHONY: all
all: check-deps clean init stage0 final ## Build all democluster from the ground up

.PHONY: delete-democluster-local
delete-democluster-local: ## Delete the local democluster.
	multipass delete democluster
	multipass purge

.PHONY: deploy-democluster-local 
deploy-democluster-local: delete-democluster-local ## Deploy democluster from locally built image.
	./helpers/deploy_local_democluster.sh $(CLIENT_ID) $(CLIENT_SECRET)

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


# SETTINGS
# Use one shell for all commands in a target recipe
.ONESHELL:
# Set default goal
.DEFAULT_GOAL := help
# Use bash shell in Make instead of sh
SHELL := /bin/bash
