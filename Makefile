SO:=$(shell uname -s | awk '{print tolower($$0)}')
AZK_VERSION:=$(shell cat package.json | grep -e "version" | cut -d' ' -f4 | sed -n 's/\"//p' | sed -n 's/\"//p' | sed -n 's/,//p')

AZK_ROOT_PATH:=$(shell pwd)
AZK_LIB_PATH:=${AZK_ROOT_PATH}/lib
AZK_NPM_PATH:=${AZK_ROOT_PATH}/node_modules
NVM_BIN_PATH:=${AZK_LIB_PATH}/nvm.sh

AZK_BIN:=${AZK_ROOT_PATH}/bin/azk

# Load dependencies versions
include .dependencies

# default target
all: bootstrap

# BOOTSTRAP
NVM_DIR := ${AZK_LIB_PATH}/nvm
NODE = ${NVM_DIR}/${NVM_NODE_VERSION}/bin/node
VM_DISKS_DIR := ${AZK_LIB_PATH}/vm/${AZK_ISO_VERSION}

SRC_JS = $(shell cd ${AZK_ROOT_PATH} && find ./src -name '*.*' -print 2>/dev/null)

teste_envs:
	@echo ${LIBNSS_RESOLVER_VERSION}
	@echo ${AZK_ISO_VERSION}

${AZK_LIB_PATH}/azk: $(SRC_JS) ${AZK_NPM_PATH}/.install
	@echo "task: $@"
	@export AZK_LIB_PATH=${AZK_LIB_PATH} && \
		export AZK_NPM_PATH=${AZK_NPM_PATH} && \
		${AZK_BIN} nvm gulp babel && touch ${AZK_LIB_PATH}/azk

${AZK_NPM_PATH}/.install: npm-shrinkwrap.json package.json ${NODE}
	@echo "task: $@"
	@mkdir -p ${AZK_NPM_PATH}
	@export AZK_LIB_PATH=${AZK_LIB_PATH} && \
		${AZK_BIN} nvm npm install && \
		touch ${AZK_NPM_PATH}/.install

${NODE}:
	@echo "install node ${NVM_NODE_VERSION} in $@"
	@set +x && export NVM_DIR=${NVM_DIR} && \
		mkdir -p ${NVM_DIR} && \
		. ${NVM_BIN_PATH} && \
		nvm install $(NVM_NODE_VERSION) && \
		${AZK_BIN} nvm npm install npm -g

clean:
	@echo "task: $@"
	@find ${AZK_LIB_PATH} -maxdepth 1 -not -name "lib" | egrep -v '\/vm$$' | xargs rm -Rf
	@rm -Rf ${AZK_NPM_PATH}/..?* ${AZK_NPM_PATH}/.[!.]* ${AZK_NPM_PATH}/*
	@rm -Rf ${NVM_DIR}/..?* ${NVM_DIR}/.[!.]* ${NVM_DIR}/*

bootstrap: dependencies ${AZK_LIB_PATH}/azk

dependencies: ${AZK_LIB_PATH}/nvm.sh ${AZK_LIB_PATH}/bats ${VM_DISKS_DIR}/azk.iso ${VM_DISKS_DIR}/azk-agent.vmdk.gz

S3_URL=https://s3-sa-east-1.amazonaws.com/repo.azukiapp.com/vm_disks/${AZK_ISO_VERSION}
${VM_DISKS_DIR}/azk.iso:
	@echo Downloading: ${S3_URL}/azk.iso ...
	@mkdir -p ${VM_DISKS_DIR}
	@curl ${S3_URL}/azk.iso -o ${@}

${VM_DISKS_DIR}/azk-agent.vmdk.gz:
	@echo Downloading: ${S3_URL}/azk-agent.vmdk.gz ...
	@curl ${S3_URL}/azk-agent.vmdk.gz -o ${@}

NVM_URL=https://raw.githubusercontent.com/creationix/nvm/v${NVM_VERSION}/nvm.sh
${AZK_LIB_PATH}/nvm.sh:
	@echo "$@"
	@echo Downloading: ${NVM_URL} ...
	@curl ${NVM_URL} -o ${@}
	@chmod +x ${@}

${AZK_LIB_PATH}/bats:
	@git clone -b ${BATS_VERSION} https://github.com/sstephenson/bats ${AZK_LIB_PATH}/bats

slow_test: TEST_SLOW="--slow"
slow_test: test
	@echo "task: $@"

test: bootstrap
	@echo "task: $@"
	${AZK_BIN} nvm gulp test ${TEST_SLOW} $(if $(filter undefined,$(origin TEST_GREP)),"",--grep "${TEST_GREP}")

# PACKAGE
AZK_PACKAGE_PATH:=${AZK_ROOT_PATH}/package
AZK_PACKAGE_PREFIX:=${AZK_PACKAGE_PATH}/v${AZK_VERSION}
PATH_USR_LIB_AZK:=${AZK_PACKAGE_PREFIX}/usr/lib/azk
PATH_USR_BIN:=${AZK_PACKAGE_PREFIX}/usr/bin
PATH_NODE_MODULES:=${PATH_USR_LIB_AZK}/node_modules
PATH_AZK_LIB:=${PATH_USR_LIB_AZK}/lib
PATH_AZK_NVM:=${PATH_AZK_LIB}/nvm
NODE_PACKAGE = ${PATH_AZK_NVM}/${NVM_NODE_VERSION}/bin/node
PATH_MAC_PACKAGE:=${AZK_PACKAGE_PATH}/azk_${AZK_VERSION}.tar.gz

# Build package folders tree
package_brew: package_build fix_permissions check_version ${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION} ${PATH_MAC_PACKAGE}
package_mac:
	@export AZK_PACKAGE_PATH=${AZK_PACKAGE_PATH}/brew && \
		mkdir -p $$AZK_PACKAGE_PATH && \
		make -e package_brew

# Alias to create a distro package
LINUX_CLEAN:="--clean"
package_linux: package_build creating_symbolic_links fix_permissions check_version
package_deb:
	@mkdir -p package
	@./src/libexec/package.sh deb ${LINUX_CLEAN}
package_rpm:
	@mkdir -p package
	@./src/libexec/package.sh rpm ${LINUX_CLEAN}

package_clean:
	@echo "task: $@"
	@rm -Rf ${AZK_PACKAGE_PREFIX}/..?* ${AZK_PACKAGE_PREFIX}/.[!.]* ${AZK_PACKAGE_PREFIX}/*

check_version: NEW_AZK_VERSION=$(shell ${PATH_USR_LIB_AZK}/bin/azk version)
check_version:
	@echo "task: $@"
	@if [ ! "azk ${AZK_VERSION}" = "${NEW_AZK_VERSION}" ] ; then \
		echo 'Error to run: ${PATH_USR_LIB_AZK}/bin/azk version'; \
		echo 'Expect: azk ${AZK_VERSION}'; \
		echo 'Output: ${NEW_AZK_VERSION}'; \
		exit 1; \
	fi

${PATH_NODE_MODULES}: ${PATH_USR_LIB_AZK}/npm-shrinkwrap.json ${NODE_PACKAGE}
	@echo "task: $@"
	@cd ${PATH_USR_LIB_AZK} && ${AZK_BIN} nvm npm install --production

${PATH_USR_LIB_AZK}/npm-shrinkwrap.json: ${PATH_USR_LIB_AZK}/package.json
	@echo "task: $@"
	@test -e ${PATH_NODE_MODULES} && rm -rf ${PATH_NODE_MODULES} || true
	@ln -s ${AZK_NPM_PATH} ${PATH_NODE_MODULES}
	@cd ${PATH_USR_LIB_AZK} && ${AZK_BIN} nvm npm shrinkwrap
	@rm ${PATH_NODE_MODULES}

${NODE_PACKAGE}:
	@echo "task: $@"
	@export NVM_DIR=${PATH_AZK_NVM} && \
		mkdir -p ${PATH_AZK_NVM} && \
		. ${NVM_BIN_PATH} && \
		nvm install $(NVM_NODE_VERSION) && \
		azk nvm npm install npm -g

define COPY_FILES
$(abspath $(2)/$(3)): $(abspath $(1)/$(3))
	@echo "task: copy from $$< to $$@"
	@mkdir -p $$(dir $$@)
	@if [ -d "$$<" ]; then \
		if [ -d "$$@" ]; then \
			touch $$@; \
		else \
			mkdir -p $$@; \
		fi \
	fi
	@[ -d $$< ] || cp -f $$< $$@
endef

# copy regular files
FILES_FILTER  = package.json bin shared CHANGELOG.md LICENSE README.md .dependencies
FILES_ALL     = $(shell cd ${AZK_ROOT_PATH} && find $(FILES_FILTER) -print 2>/dev/null)
FILES_TARGETS = $(foreach file,$(addprefix $(PATH_USR_LIB_AZK)/, $(FILES_ALL)),$(abspath $(file)))
$(foreach file,$(FILES_ALL),$(eval $(call COPY_FILES,$(AZK_ROOT_PATH),$(PATH_USR_LIB_AZK),$(file))))

# Copy transpiled files
copy_transpiled_files:
	@echo "task: $@"
	@mkdir -p ${PATH_AZK_LIB}/azk
	@cp -R $(AZK_LIB_PATH)/azk ${PATH_AZK_LIB}

fix_permissions:
	@chmod 755 ${PATH_USR_LIB_AZK}/bin/*

creating_symbolic_links:
	@echo "task: $@"
	@mkdir -p ${PATH_USR_BIN}
	@ln -sf ../lib/azk/bin/azk ${PATH_USR_BIN}/azk
	@ln -sf ../lib/azk/bin/adocker ${PATH_USR_BIN}/adocker

${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION}: ${AZK_LIB_PATH}/vm
	@mkdir -p ${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION}
	@cp -r ${VM_DISKS_DIR} ${PATH_AZK_LIB}/vm

${PATH_MAC_PACKAGE}: ${AZK_PACKAGE_PREFIX}
	@cd ${PATH_USR_LIB_AZK}/.. && tar -czf ${PATH_MAC_PACKAGE} ./

package_build: bootstrap $(FILES_TARGETS) copy_transpiled_files ${PATH_NODE_MODULES}

.PHONY: bootstrap clean package_brew package_mac package_deb package_rpm package_build package_clean copy_transpiled_files fix_permissions creating_symbolic_links dependencies check_version slow_test test
