export PATH := "node_modules/.bin:" + env_var('PATH')

build:
    spago build

build-strict:
    spago build --json-errors | node scripts/filter-warnings.js


mk-single-pkg:
    node scripts/mk-single-pkg.js

install-git-hooks:
    rm -rf .git/hooks
    ln -s ../git-hooks .git/hooks

lint:
    node scripts/lint.js

install:
    npm ci

# Dist

clean-dist:
    rm -rf dist

dist: clean-dist dist-examples dist-mdbook

dist-examples:
    #!/usr/bin/env bash
    set -euxo pipefail
    rm -f output/package.json
    rm -rf .parcel-cache
    main_dir="purescript-interactive-data"; \
    export VERSION=$(git rev-parse HEAD); \
    for dir in demo/src/Demo/Samples/*/; do \
        name=$(basename $dir); \
        echo Building $name $VERSION; \
        export PREFIX="/$main_dir/$name"; \
        parcel build --dist-dir dist/$main_dir/$name --public-url /$main_dir/$name/ $dir/index.html ; \
    done

dist-mdbook:
    mdbook build mdbook --dest-dir ../dist/purescript-interactive-data/manual

serve-dist:
    http-server dist

# Fix

format:
    purs-tidy format-in-place "packages/*/src/**/*.purs"
    purs-tidy format-in-place "packages/*/test/**/*.purs"
    purs-tidy format-in-place "demo/src/**/*.purs"
    purs-tidy format-in-place "demo/test/**/*.purs"

# Dev

dev: clean-parcel
    #!/bin/bash
    export SAMPLE=HalogenFullscreen
    parcel demo/src/Demo/Samples/$SAMPLE/index.html

run-example: build clean-parcel
    #!/bin/bash
    FILE=`mktemp`
    node scripts/run-example.js $FILE
    export SAMPLE=`cat $FILE`
    echo "Starting $SAMPLE"
    parcel demo/src/Demo/Samples/$SAMPLE/index.html

run-dist:
    http-server dist

# Clean

clean: clean-parcel clean-purs

clean-purs:
    rm -rf .spago output

clean-parcel:
    rm -rf .parcel-cache

# Generate

gen: gen-graph gen-readme gen-assets gen-mdbook

gen-graph:
    dot -Tsvg assets/local-packages-graph.dot -o assets/local-packages-graph.svg

gen-readme:
    node scripts/gen-readme.js
    doctoc README.md

gen-mdbook:
    #!/bin/bash
    node scripts/gen-mdbook.js

gen-assets:
    purs-virtual-dom-assets \
      --srcPath packages/interactive-data-app/assets \
      --dstPath packages/interactive-data-app/src/InteractiveData/App/UI/Assets \
      --baseModule 'InteractiveData.App.UI.Assets'

purs-docs:
    #!/bin/bash
    shopt -s globstar;
    purs docs $(spago sources)

# Fix

suggest-list:
    spago build --json-errors | node scripts/filter-warnings.js | ps-suggest --list

suggest-apply:
    spago build --json-errors | node scripts/filter-warnings.js | ps-suggest --apply

# CI

ci_: install spell format gen build build-strict dist check-git-clean

ci: clean
    just ci_

ci-tmp:
    HERE=$(pwd); \
    DIR=$(mktemp -d); \
    echo $DIR; \
    cd $DIR; \
    git clone $HERE .; \
    nix develop --command just ci
    
check-git-clean:
    [ "" = "$(git status --porcelain)" ]

# IDE

build-ide:
    spago build --json-errors | node scripts/filter-warnings.js

open-all-files:
    code $(node scripts/modules.js)

# Spelling

spell:
    cspell lint --config cspell.config.yaml

# Dev

dev-manual:
    #!/bin/bash
    set -euxo pipefail

    trap "echo cleanup...; pkill -P "$$"; exit" SIGINT SIGTERM EXIT

    chokidar "demo/src/Manual/**/*.purs" -c "node scripts/gen-mdbook.js --file {path}" &

    mdbook serve mdbook &

    read -rp "Press Enter to cancel..."