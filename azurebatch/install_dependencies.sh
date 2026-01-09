#!/bin/bash
# Azure Batch Node Startup Script
# This script installs Python dependencies on the compute node

set -e

echo "Starting dependency installation..."
echo "Python version: $(python3 --version)"

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found, using python3 -m pip instead"
    PIP_CMD="python3 -m pip"
    
    # Bootstrap pip if not available
    if ! python3 -m pip --version &> /dev/null; then
        echo "Installing pip..."
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3 - --user
        export PATH="$HOME/.local/bin:$PATH"
        PIP_CMD="python3 -m pip"
    fi
else
    echo "Pip version: $(pip3 --version)"
    PIP_CMD="pip3"
fi

# Install required packages from requirements.txt
if [ -f "requirements.txt" ]; then
    echo "Installing dependencies from requirements.txt..."
    $PIP_CMD install --user -r requirements.txt
else
    echo "Warning: requirements.txt not found!"
    exit 1
fi

echo "Dependencies installed successfully!"
echo "Installed packages:"
python3 -m pip list | grep -E "(azure|Pillow)"
