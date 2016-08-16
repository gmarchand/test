SPECS_FILES = $(shell find ./src -type f -name "*.spec.js")

SHELL := /bin/bash

# Contains
GITLAB_FQDN?=      $(shell git config --get remote.origin.url | sed 's@\(.*\):\(.*\).git@\2@g')
GITLAB_REF_NAME?=  $(shell git rev-parse --abbrev-ref HEAD | tr '/' '-' )
GITLAB_REF?=       $(shell git log -1|head -n1|cut -d ' ' -f2-)
GITLAB_REF_SHORT?= $(shell echo $(GITLAB_REF) | head -c 8)

APP_VERSION=       $(GITLAB_REF_NAME)_$(GITLAB_REF_SHORT)
APP_NAME?=         mycanal-dev
APP_ENV_DEV?=      mycanal-dev
APP_ENV_PREPROD?=  mycanal-preprod
APP_ENV_PROD?=     mycanal-prod

AWS_APP_VERSION=       $(GITLAB_REF_NAME)-$(GITLAB_REF_SHORT)
AWS_BEANSTALK_REGION?= eu-west-1
AWS_BUCKET?=           gitlab-cpl-eb-deploy

TMPDIR?=/tmp

help: ## Prints help
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | awk 'BEGIN {FS = ":.*?## "}; {printf " > \033[36m%-20s\033[0m %s\n", $$1, $$2}'

package: 	## package app and make a new revision. 'GITLAB_REF_NAME' parameter is required
	@echo "zip this artifact, upload to S3 and make eb app version ${APP_VERSION}"
	mkdir -p ${TMPDIR}
	cd dist && zip -r -q -9 ${TMPDIR}/${APP_VERSION}.zip .babelrc *
	aws s3 cp ${TMPDIR}/${APP_VERSION}.zip s3://gitlab-cpl-eb-deploy/releases/${GITLAB_FQDN}/${APP_VERSION}.zip
	aws elasticbeanstalk create-application-version --region ${AWS_BEANSTALK_REGION} --application-name ${APP_NAME} --version-label "${AWS_APP_VERSION}" --source-bundle S3Bucket=${AWS_BUCKET},S3Key=releases/${GITLAB_FQDN}/${APP_VERSION}.zip


# JS test suite

test-js-cs: ## Check JS coding convention are respected
	@./node_modules/.bin/eslint ./src ./tests --cache

test-js-func: test-js-func-ie test-js-func-chrome test-js-func-firefox test-js-func-safari test-js-func-android test-js-func-iphone ## Start JS cucumber tests

test-js-func-ie: ## Start JS cucumber tests for IE
	./tests/functional/run.sh ie

test-js-func-chrome: ## Start JS cucumber tests for Chrome
	./tests/functional/run.sh chrome

test-js-func-firefox: ## Start JS cucumber tests for Firefox
	./tests/functional/run.sh firefox

test-js-func-safari: ## Start JS cucumber tests for Safari
	./tests/functional/run.sh safari

test-js-func-android: ## Start JS cucumber tests for Android
	./tests/functional/run.sh android

test-js-func-iphone: ## Start JS cucumber tests for iPhone
	./tests/functional/run.sh iphone

test-js-func-for-ci: ## Start JS cucumber tests executed in CI context
	./tests/functional/run.sh -d ie

test-js-func-local: ## Start JS cucumber tests in local
	./tests/functional/run.sh local

test-js-unit-with-coverage: ## Start JS unit tests with coverage
	@NODE_ENV=test ./node_modules/.bin/babel-node ./node_modules/.bin/isparta cover \
		--root './src' \
		--dir './coverage' \
		--include-all-sources \
		--excludes **/container/*.js \
		--excludes *.spec.js \
		./node_modules/.bin/_mocha -- $(SPECS_FILES) \
		--require ./config/spec.setup.js \
		--compilers js:babel-register \
		--recursive --full-trace

test-js-unit: ## Start JS unit tests with Mocha
	@NODE_ENV=test ./node_modules/.bin/_mocha $(SPECS_FILES) \
		--require ./config/spec.setup.js \
		--compilers js:babel-register \
		--recursive --full-trace

test-js: test-js-unit test-js-cs ## Start the complete JS tests suite

# SCSS test suite

test-scss-cs: ## Check SCSS coding convention are respected
	@scss-lint ./src

test-scss: test-scss-cs ## Start the complete SCSS tests suite

# Global test suite

test-cs: test-js-cs test-scss-cs ## Check coding convention are respected

test: test-js test-scss ## Start the complete tests suite

install: ## Install application dependencies
	@npm install

build: ## Build the application into dist/ directory
	@NODE_ENV=production ./node_modules/.bin/webpack --config ./config/webpack/webpack.config.prod.js --verbose --colors --display-error-details
	@NODE_ENV=production node ./config/deploy

dev: ## Start the development environment and watchers
	@./node_modules/.bin/concurrently --kill-others "npm run watch-client" "npm run start-dev"

run: ## Start the application
	@node index.js

clean:    # clean. 'GITLAB_REF_NAME' parameter is required
	rm -rf dist
	rm -rf ${TMPDIR}/${APP_VERSION}.zip

deploy: info ## Deploy a new revision
	@echo "update environment ${${env}} with this version ${version}"
	aws elasticbeanstalk update-environment --region ${AWS_BEANSTALK_REGION} --environment-name ${${env}} --version-label "${AWS_APP_VERSION}"

info: ## Display information about the release
	@echo GITLAB_FQDN=${GITLAB_FQDN}
	@echo GITLAB_REF_NAME=${GITLAB_REF_NAME}
	@echo GITLAB_REF=${GITLAB_REF}
	@echo GITLAB_REF_SHORT=${GITLAB_REF_SHORT}
	@echo APP_VERSION=${APP_VERSION}
	@echo APP_NAME=${APP_NAME}
	@echo APP_ENV_DEV=${APP_ENV_DEV}
	@echo APP_ENV_PROD=${APP_ENV_PROD}
	@echo AWS_APP_VERSION=${AWS_APP_VERSION}
	@echo AWS_BEANSTALK_REGION=${AWS_BEANSTALK_REGION}
	@echo AWS_BUCKET=${AWS_BUCKET}
	@echo TMPDIR=${TMPDIR}
