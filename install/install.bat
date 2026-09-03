@echo off
setlocal enabledelayedexpansion
title Установка GeoClaude

set "REPO=SkyTmin/autocad_claude"
set "BRANCH=claude/project-status-check-h0n2w"
set "RAW=https://raw.githubusercontent.com/%REPO%/%BRANCH%"
set "HOME_DIR=%APPDATA%\Autodesk\ApplicationPlugins\GeoClaude.bundle"

echo.
echo ==================================================
echo   GeoClaude - установка
echo ==================================================
echo.
echo Ставлю сюда:
echo   %HOME_DIR%
echo.
echo После этого команды будут грузиться при запуске
echo Civil 3D сами. APPLOAD и NETLOAD руками больше
echo не нужны, а обновление - команда GCU внутри CAD.
echo.

rem ---------------------------------------------------------------
rem Папки
rem ---------------------------------------------------------------
if not exist "%HOME_DIR%\Contents\lisp" mkdir "%HOME_DIR%\Contents\lisp"
if not exist "%HOME_DIR%\Contents\net"  mkdir "%HOME_DIR%\Contents\net"

rem ---------------------------------------------------------------
rem Качаем. PowerShell есть в любой Windows, ставить ничего не надо.
rem TLS 1.2 включаем явно: без него GitHub рвёт соединение
rem на Windows 7 и 8, а сообщение при этом невнятное.
rem ---------------------------------------------------------------
set FAIL=0

call :get "install/PackageContents.xml"          "%HOME_DIR%\PackageContents.xml"
call :get "src/lisp/commands/gc-update.lsp"      "%HOME_DIR%\Contents\lisp\gc-update.lsp"
call :get "src/lisp/commands/kg.lsp"             "%HOME_DIR%\Contents\lisp\kg.lsp"
call :get "src/lisp/commands/ol.lsp"             "%HOME_DIR%\Contents\lisp\ol.lsp"
call :get "src/lisp/commands/vo.lsp"             "%HOME_DIR%\Contents\lisp\vo.lsp"
call :get "src/lisp/commands/sv.lsp"             "%HOME_DIR%\Contents\lisp\sv.lsp"
call :get "src/lisp/commands/vid.lsp"            "%HOME_DIR%\Contents\lisp\vid.lsp"
call :get "src/lisp/commands/rs.lsp"             "%HOME_DIR%\Contents\lisp\rs.lsp"
call :get "src/dotnet/GcSurface/GcSurface.cs"    "%HOME_DIR%\Contents\net\GcSurface.cs"
call :get "src/dotnet/GcSurface/build.bat"       "%HOME_DIR%\Contents\net\build.bat"

if %FAIL% GTR 0 (
  echo.
  echo [ОШИБКА] Не скачалось файлов: %FAIL%
  echo Проверьте интернет и повторите.
  goto :end
)

rem ---------------------------------------------------------------
rem Модуль .NET. Он НЕОБЯЗАТЕЛЕН: не собрался - команды работают,
rem только край области считается приближённо. Поэтому неудача
rem сборки не считается неудачей установки.
rem ---------------------------------------------------------------
echo.
echo --------------------------------------------------
echo   Собираю модуль .NET (необязательный)
echo --------------------------------------------------
pushd "%HOME_DIR%\Contents\net"
call build.bat >build.log 2>&1
popd

if exist "%HOME_DIR%\Contents\net\GcSurface.dll" (
  echo [ok] GcSurface.dll собран
) else (
  echo [i]  GcSurface.dll не собрался - это не страшно.
  echo      Команды будут работать без него, край области
  echo      посчитается приближённо.
  echo      Подробности: %HOME_DIR%\Contents\net\build.log
)

echo.
echo ==================================================
echo   ГОТОВО
echo ==================================================
echo.
echo Дальше:
echo   1. Запустите Civil 3D (если он открыт - перезапустите).
echo   2. Команды загрузятся сами.
echo   3. Проверить: наберите GCV - покажет, что лежит на диске.
echo.
echo Обновлять команды: GCU прямо в командной строке CAD.
echo Перезапуск CAD при этом не нужен.
echo.
goto :end

rem ---------------------------------------------------------------
:get
echo   качаю %~1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -UseBasicParsing -Uri '%RAW%/%~1' -OutFile '%~2' } catch { exit 1 }"
if errorlevel 1 (
  echo        [!!] не скачалось
  set /a FAIL=!FAIL!+1
)
exit /b 0

:end
pause
