@echo off
:: Navigate to the project directory
cd /d "%USERPROFILE%\Desktop\Application\Back-end"

:: Start the FastAPI server in a NEW window
:: The 'cmd /k' switch keeps the new window open even if the command finishes or fails
start "FastAPI Backend Server" cmd /k "python -m venv .venv && .venv\Scripts\activate && pip install -r requirements.txt && uvicorn main:app --reload"

echo Backend startup initiated in a new window.
pause
