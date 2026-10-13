#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/checks
swiftc ${SWIFT_CHECK_FLAGS:-} Sources/MenuOCR/OCR.swift Checks/main.swift -o .build/checks/check
.build/checks/check
