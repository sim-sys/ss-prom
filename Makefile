node := node
eslint := tools/node_modules/.bin/eslint
flow := tools/node_modules/.bin/flow
babel := tools/node_modules/.bin/babel
babel-node := tools/node_modules/.bin/babel-node
mocha := tools/node_modules/.bin/mocha
_mocha := tools/node_modules/.bin/_mocha
babel-external-helpers := tools/node_modules/.bin/babel-external-helpers
istanbul := tools/node_modules/.bin/istanbul

MOCHA_OPTS := --ui=`pwd`/tools/mocha-interface.js

SCRIPT_FILES = $(wildcard scripts/*.js)
SCRIPTS = $(patsubst scripts/%.js,%,$(SCRIPT_FILES))

define SCRIPT

run.$(1):
	@echo
	@echo "Running \033[0;32mscripts/$(1).js\033[0m"
	@echo
	@$(babel-node) ./scripts/$(1).js

endef

all: clean flow lint test check-coverage compile

$(foreach i,$(SCRIPTS), $(eval $(call SCRIPT,$(i))))


lint:
	$(eslint) src

flow:
	$(flow) check --no-flowlib

compile:
	@rm -rf src-compiled
	$(babel) src --ignore __tests__ --out-dir src-compiled --copy-files

compile-test:
	@rm -rf src-compiled-test
	$(babel) src --out-dir src-compiled-test --copy-files

compile-cover:
	@rm -rf src-compiled-cover
	$(babel) src --out-dir src-compiled-cover --copy-files --plugins=`pwd`/tools/node_modules/babel-plugin-external-helpers-2

cover: compile-cover
	@rm -rf cover
	$(babel-external-helpers) > ./babel-helpers.js
	$(istanbul) cover $(_mocha) -- --require ./babel-helpers.js src-compiled-cover/**/__tests__/**/*.js $(MOCHA_OPTS)
	@rm babel-helpers.js

check-coverage: cover
	$(istanbul) check-coverage

test: compile-test
	$(mocha) src-compiled-test/**/__tests__/**/*.js $(MOCHA_OPTS)

clean:
	@rm -rf src-compiled
	@rm -rf src-compiled-test
	@rm -rf src-compiled-cover
	@rm -rf cover

# lib only

define PKG
var pkg = require('./package.json');
delete pkg.devDependencies;
delete pkg.scripts;
delete pkg.private; // private is used to prevent from publishing source
delete pkg.allowPublish;
console.log(JSON.stringify(pkg));
endef

export PKG

define CHECK
var pkg = require('./package.json');
if (!pkg.allowPublish) {
  throw new Error('publishing is not allowed');
}
endef

export CHECK

dist: compile
	@$(node) -e "$$CHECK"
	@rm -rf dist
	@mkdir -p dist
	@cp -r src/ dist
	@find dist/ -name '__tests__' | xargs rm -r
	@find dist/ -name '*.js' | xargs -I {} mv {} {}.flow
	@cp -r src-compiled/ dist
	@$(node) -e "$$PKG" > dist/package.json

publish:
	cd dist && npm publish

deps:
	npm install
	cd tools && npm install

ci: flow lint test check-coverage compile

.PHONY: clean test lint flow compile compile-test compile-cover all cover run.% check-coverage dist publish deps ci
