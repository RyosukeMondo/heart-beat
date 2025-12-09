#!/bin/bash
set -e

echo "Running pre-commit verifications..."

# Run metrics verification
echo "Checking metrics (LOC, Complexity)..."
python3 scripts/verify_metrics.py
if [ $? -ne 0 ]; then
    echo "Metrics verification failed!"
    exit 1
fi

echo "Metrics verification passed."
exit 0
