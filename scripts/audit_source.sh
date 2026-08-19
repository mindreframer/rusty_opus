#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if git grep -nIE '(/Users/[^ ]+|/home/[^ ]+|\.\./rusty_opus|\.\./opus)' -- . \
  ':(exclude)@meta/**' ':(exclude)AGENTS.md' ':(exclude)scripts/audit_source.sh' \
  ':(exclude)bin/qa_check.sh' ':(exclude)*.md'; then
  echo "machine-specific or sibling path found" >&2
  exit 1
fi

if git grep -nIE '(std::process::(exit|abort|Command)|libc::(fork|daemon|_exit)|Command::new)' \
  -- 'native/rusty_opus_native/**'; then
  echo "forbidden process-control use in embedded native source" >&2
  exit 1
fi

if git grep -nIE '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16})' -- . \
  ':(exclude)scripts/audit_source.sh'; then
  echo "possible committed credential" >&2
  exit 1
fi

[ -f docs/provenance.md ]
grep -q '0.1.29' docs/provenance.md
grep -q 'BSD-3-Clause' docs/provenance.md

echo "source audit passed"
