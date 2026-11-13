#!/bin/sh

# Lints every YAML file in the repository against its declared schema.
# The linter version is pinned so results do not change between runs;
# raise it deliberately.
npx --yes yaml-schema-lint@2.1.0 --no-schema-store "**/*.yaml"
