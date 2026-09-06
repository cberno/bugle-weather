#!/bin/bash
set -e
cd "$(dirname "$0")/BugleCore"
swift run bugle-backtest --lat 38.96 --lon -77.08 --start 2024-01-01 --end 2025-12-31
