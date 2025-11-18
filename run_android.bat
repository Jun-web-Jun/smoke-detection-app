@echo off
echo ================================
echo   Android 에뮬레이터로 앱 실행
echo ================================
echo.
echo Android 에뮬레이터를 실행합니다...
echo 에뮬레이터 부팅 중... (30초 소요)
echo.

cd /d "%~dp0"

REM Android 에뮬레이터 실행
start "" flutter emulators --launch Jun

REM 에뮬레이터 부팅 대기 (30초)
timeout /t 30 /nobreak

echo.
echo 앱을 빌드하고 설치합니다...
echo.

REM 앱 실행
flutter run

pause
