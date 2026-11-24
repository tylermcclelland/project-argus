#!/bin/bash
# Show live alerts as they happen. Press Ctrl+C to stop.
# Usage: ./alerts.sh
cd "$(dirname "$0")"
echo "Showing live alerts from logs/live/fast.log (Ctrl+C to stop)..."
tail -n 20 -F logs/live/fast.log
