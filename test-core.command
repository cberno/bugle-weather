#!/bin/bash
set -e
cd "$(dirname "$0")/BugleCore"
swift test
