@echo off
cd /d "%~dp0"

echo Выгрузка конфигурации из базы в src\ ...
powershell -ExecutionPolicy Bypass -File tools\deploy\Dump-1C.ps1
if errorlevel 1 (
	echo.
	echo Выгрузка не удалась, коммит не создаётся.
	pause
	exit /b 1
)

git add src
git status --short

git diff --cached --quiet
if not errorlevel 1 (
	echo.
	echo Изменений в src\ нет, коммитить нечего.
	pause
	exit /b 0
)

echo.
set /p COMMITMSG="Сообщение коммита (Enter = отмена): "
if "%COMMITMSG%"=="" (
	echo Коммит отменён.
	pause
	exit /b 0
)

git commit -m "%COMMITMSG%"
if errorlevel 1 (
	pause
	exit /b 1
)

git push
pause
