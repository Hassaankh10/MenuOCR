#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/checks/startup
sed '/^@main$/d' Sources/MenuOCR/App.swift > .build/checks/startup/App.swift
swiftc .build/checks/startup/App.swift Sources/MenuOCR/OCR.swift Sources/MenuOCR/Feedback.swift Sources/MenuOCR/Onboarding.swift Sources/MenuOCR/PermissionSetup.swift Checks/Startup/main.swift -o .build/checks/startup/check
.build/checks/startup/check
