#!/bin/sh

# Prints one random (version 4) UUID in lowercase. Plain `uuidgen` is used
# because the -r flag is not available on macOS.
uuidgen | tr "A-Z" "a-z"
