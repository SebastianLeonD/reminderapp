#!/bin/bash
# Run the reminder API server
# Usage: ./run.sh
cd "$(dirname "$0")"
pip3 install -r requirements.txt -q
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
