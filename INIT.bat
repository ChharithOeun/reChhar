@echo off
setlocal
REM reChhar — one-click git init + first commit + push to github.com/ChharithOeun/reChhar
cd /d "%~dp0"

if exist ".git" (
    echo Git repo already initialized here.
    git status
    git log --oneline -5
    goto end
)

echo Initializing git repo for reChhar...
git init
git branch -M main

echo Staging all files...
git add .

echo Creating initial commit...
git commit -m "Initial commit: reChhar v0.1.0 scaffold — Ashita port of React (auto-face-away during gaze attacks). Addon skeleton, gaze database, settings loader, command handler wired. Packet parsing + facing control pending base React source review."

echo Adding GitHub remote...
git remote add origin https://github.com/ChharithOeun/reChhar.git

echo Pushing to main...
git push -u origin main

:end
echo.
pause
