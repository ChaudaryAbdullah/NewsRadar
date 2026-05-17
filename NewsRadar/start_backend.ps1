# NewsRadar — Quick Start Scripts
# Run these from the d:\google_hackathon\NewsRadar directory

# ─── Step 1: Start the Backend ────────────────────────────────────────────────
# Open a new terminal and run:
#   cd d:\google_hackathon\NewsRadar\backend
#   python main.py

# ─── Step 2: Start the Flutter App ───────────────────────────────────────────
# Open another terminal and run:
#   cd d:\google_hackathon\NewsRadar\frontend
#   flutter pub get
#   flutter run

# ─── Backend start script ─────────────────────────────────────────────────────
Write-Host "Starting NewsRadar Backend..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot\backend"
python main.py
