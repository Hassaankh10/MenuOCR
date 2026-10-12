#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/checks
swiftc Sources/MenuOCR/Feedback.swift Checks/Feedback/main.swift -o .build/checks/feedback
.build/checks/feedback "$PWD/.build/checks/confirmation-preview.png" "$PWD/Assets/AppIcon.icns"
