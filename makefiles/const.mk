# Setting SHELL to bash allows bash commands to be executed by recipes.
SHELL = /usr/bin/env bash -o pipefail
.SHELL_FLAGS = -ec

TIME_LONG	= `date +%Y-%m-%d' '%H:%M:%S`
TIME_SHORT	= `date +%H:%M:%S`
TIME		= $(TIME_SHORT)

BLUE         := $(shell printf "\033[34m")
YELLOW       := $(shell printf "\033[33m")
RED          := $(shell printf "\033[31m")
GREEN        := $(shell printf "\033[32m")
CNone        := $(shell printf "\033[0m")

INFO	= echo ${TIME} ${BLUE}[INFO]${CNone}
WARN	= echo ${TIME} ${YELLOW}[WARN]${CNone}
ERR		= echo ${TIME} ${RED}[FAIL]${CNone}
OK		= echo ${TIME} ${GREEN}[ OK ]${CNone}
FAIL	= (echo ${TIME} ${RED}[FAIL]${CNone} && false)


# Git Repo info
BUILD_DATE            := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

GIT_COMMIT            ?= git-$(shell git rev-parse --short HEAD)
GIT_COMMIT_LONG       ?= $(shell git rev-parse HEAD)
GIT_COMMIT_MESSAGE    := $(shell git log -1 --pretty=format:"%s" | sed 's/"/\\"/g')
GIT_REMOTE            := origin
GIT_BRANCH            := $(shell git rev-parse --symbolic-full-name --verify --quiet --abbrev-ref HEAD)
GIT_TAG               := $(shell git describe --exact-match --tags --abbrev=0  2> /dev/null || echo untagged)
GIT_TREE_STATE        := $(shell if [[ -z "`git status --porcelain`" ]]; then echo "clean" ; else echo "dirty"; fi)
RELEASE_TAG           := $(shell if [[ "$(GIT_TAG)" =~ ^v[0-9]{1,}.[0-9]{1,}[.\|-][0-9]{1,} ]]; then echo "true"; else echo "false"; fi)
GO_VERSION            := $(shell go version | awk '{print $$3}' 2>/dev/null || echo unknown)

VERSION               := latest
ifeq ($(RELEASE_TAG),true)
VERSION               := $(GIT_TAG)
endif

$(info ########## MAKE INFO ##########)
$(info ##### GIT_BRANCH: $(GIT_BRANCH) )
$(info ##### GIT_TAG: $(GIT_TAG) )
$(info ##### GIT_COMMIT_SHA: $(GIT_COMMIT) )
$(info ##### GIT_COMMIT_MSG: $(GIT_COMMIT_MESSAGE) )
$(info ##### GIT_TREE_STATE: $(GIT_TREE_STATE) )
$(info ##### IS_RELEASE_TAG: $(RELEASE_TAG) )
$(info ##### BUILD_VERSION: $(VERSION) )
$(info ##### BUILD_DATE: $(BUILD_DATE) )
$(info ##### GO_VERSION: $(GO_VERSION) )
$(info ###############################)
