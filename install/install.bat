@echo off
setlocal enabledelayedexpansion
rem Кодировка консоли. Без этого русский текст - и наш, и сообщения
rem компилятора - выводится кашей: файл в одной кодировке, консоль
rem в другой. Переключаем явно, а сам файл храним в CP1251.
chcp 1251 >nul
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
  echo ==================================================
  echo   НЕ СКАЧАЛОСЬ ФАЙЛОВ: %FAIL%
  echo ==================================================
  echo.
  echo Смотрите код HTTP в строках выше:
  echo.
  echo   404 - репозиторий закрыт, либо ветка или файл
  echo         переименованы. Из закрытого репозитория
  echo         анонимно не скачать ничем.
  echo   403 - доступ запрещён сетью или прокси.
  echo   текст ошибки вместо кода - сеть, DNS, VPN.
  echo.
  echo Ветка, из которой качаю:
  echo   %BRANCH%
  echo.
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
echo Это занимает несколько секунд. Ход сборки ниже.
echo.

rem GC_NOPAUSE: сборщик не должен ждать нажатия клавиши. Его вывод
rem уходит в лог, и пауза выглядела бы как намертво замерший экран.
set GC_NOPAUSE=1
pushd "%HOME_DIR%\Contents\net"
call build.bat >build.log 2>&1
popd
set GC_NOPAUSE=

rem Лог показываем на экран целиком: молчащая установка - это ровно то,
rem из-за чего в прошлый раз было непонятно, работает она или встала.
type "%HOME_DIR%\Contents\net\build.log"
echo.

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
echo   2. Команды загрузятся сами - NETLOAD и APPLOAD не нужны.
echo   3. Проверить: наберите GCV - покажет, что лежит на диске
echo      и загрузился ли модуль .NET.
echo.
echo Обновлять команды: GCU прямо в командной строке CAD.
echo Перезапуск CAD при этом не нужен.
echo.
goto :end

rem ---------------------------------------------------------------
rem Закачка одного файла.
rem
rem WebClient, а не Invoke-WebRequest: он сам ходит через системный
rem прокси, а это как раз случай VPN и рабочих сетей.
rem
rem Сообщения от PowerShell печатаем латиницей: bat идёт в CP866,
rem PowerShell отвечает в другой кодировке, и русский текст между ними
rem превращается в кашу. Код ответа важнее красоты.
rem
rem Восклицательные знаки в echo внутри этого блока не используем:
rem при включённом отложенном раскрытии они съедаются, и сообщение
rem выходит пустым - на этом уже обожглись.
rem ---------------------------------------------------------------
:get
echo   качаю %~1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $u='%RAW%/%~1'; $wc=New-Object Net.WebClient; try { $wc.Proxy=[Net.WebRequest]::GetSystemWebProxy(); $wc.Proxy.Credentials=[Net.CredentialCache]::DefaultCredentials } catch {}; $wc.Headers.Add('User-Agent','GeoClaude'); try { $wc.DownloadFile($u,'%~2') } catch { $c=0; if ($_.Exception.Response) { $c=[int]$_.Exception.Response.StatusCode }; if ($c -gt 0) { Write-Host ('        HTTP ' + $c) } else { Write-Host ('        ' + $_.Exception.Message) }; exit 1 } }"
if errorlevel 1 (
  echo         НЕ СКАЧАЛОСЬ
  set /a FAIL=!FAIL!+1
)
exit /b 0

:end
pause
