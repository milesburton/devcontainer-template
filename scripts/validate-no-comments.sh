#!/usr/bin/env bash
set -euo pipefail

fail=0

check_file() {
  file="$1"
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    case "$file" in
      *.ps1)
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" == *"<#"* ]] || [[ "$line" == *"#>"* ]]; then
          if [[ "$line" =~ ^\#\! ]]; then
            continue
          fi
          echo "$file:$lineno"
          fail=1
        fi
        ;;
      *.sh|*/Dockerfile)
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
          if [[ "$line" =~ ^\#\! ]]; then
            continue
          fi
          echo "$file:$lineno"
          fail=1
        fi
        ;;
      *)
        :
        ;;
    esac
  done < "$file"
}

check_file ".devcontainer/Dockerfile"
check_file "scripts/publish-devcontainer.sh"
check_file "scripts/publish-devcontainer.ps1"

if [ "$fail" -ne 0 ]; then
  echo "comment lines found"
  exit 1
fi
