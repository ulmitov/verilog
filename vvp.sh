#!/usr/bin/env bash
export UVM_HOME="~/dev/sda6/UVM/1800.2-2020/src"
if [[ -z "$VIRTUAL_ENV_PROMPT" ]]; then source ~/dev/sda6/oss-cad-suite/environment; fi
shift # Remove '-c' passed by Make
eval "$@"
