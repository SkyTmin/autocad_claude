@echo off
setlocal enabledelayedexpansion
rem Кодировка консоли. Без этого русский текст - и наш, и сообщения
rem компилятора - выводится кашей: файл в одной кодировке, консоль
rem в другой. Переключаем явно, а сам файл храним в CP1251.
chcp 1251 >nul
title Сборка GcSurface.dll

echo.
echo ==================================================
echo   Сборка GcSurface.dll для Civil 3D
echo ==================================================
echo.
echo Visual Studio и SDK от Autodesk НЕ нужны.
echo Компилятор входит в состав Windows, библиотеки
echo берутся из папки установленного Civil 3D.
echo.

rem ---------------------------------------------------------------
rem 1. Компилятор C#. Входит в .NET Framework 4, который есть
rem    в любой Windows начиная с 8-й. Ставить ничего не надо.
rem ---------------------------------------------------------------
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo [ОШИБКА] Не найден компилятор C#:
  echo          %CSC%
  echo.
  echo Значит в системе нет .NET Framework 4.
  goto :fail
)
echo [ok] компилятор найден

rem ---------------------------------------------------------------
rem 2. Папка Civil 3D. Берём ту, где есть И библиотеки AutoCAD,
rem    И подпапка C3D: только такая установка нам подходит.
rem    Если версий несколько, возьмётся последняя по алфавиту,
rem    и она будет напечатана - чтобы это не осталось незамеченным.
rem ---------------------------------------------------------------
set "ACAD="
for /d %%d in ("%ProgramFiles%\Autodesk\AutoCAD *") do (
  if exist "%%~fd\AcDbMgd.dll" if exist "%%~fd\C3D\AeccDbMgd.dll" set "ACAD=%%~fd"
)
if not defined ACAD (
  echo [ОШИБКА] Не нашёл установленный Civil 3D.
  echo.
  echo Искал папку вида:
  echo   %ProgramFiles%\Autodesk\AutoCAD 20XX
  echo в которой есть AcDbMgd.dll и подпапка C3D с AeccDbMgd.dll
  echo.
  echo Если Civil 3D стоит в другом месте - откройте этот файл
  echo блокнотом и впишите путь в строку ниже:
  echo   set "ACAD=D:\ваш\путь\AutoCAD 2021"
  goto :fail
)
echo [ok] Civil 3D: %ACAD%

rem ---------------------------------------------------------------
rem 3. Ссылки на библиотеки.
rem
rem    Aec*Mgd.dll подключаем ВСЕ, какие найдём, а не выбранные по именам:
rem    от версии к версии классы переезжают между сборками, и угадывание,
rem    в какой лежит нужный, - гарантия поломки на чужой машине.
rem
rem    Искать надо В ДВУХ МЕСТАХ. AeccDbMgd.dll лежит в подпапке C3D,
rem    а AecBaseMgd.dll - в КОРНЕ папки AutoCAD. Без второго компилятор
rem    не видит родства типов и сыплет ошибками, которые выглядят как
rem    "нет такого метода", хотя метод есть.
rem
rem    Одну и ту же сборку нельзя подключать дважды. AecBaseMgd.dll лежит
rem    и в корне, и в подпапке ACA - это один и тот же файл в двух местах,
rem    и компилятор на такое ругается. Поэтому ведём список уже взятых
rem    ИМЁН и второй раз то же имя не добавляем: побеждает тот, кто
rem    встретился раньше, а порядок задан от корня к подпапкам.
rem
rem    Список пишем в файл ответов: ссылок под тридцать штук, и командная
rem    строка упёрлась бы в свой предел длины.
rem ---------------------------------------------------------------
set "RSP=%~dp0refs.rsp"
> "%RSP%" echo /nologo
>>"%RSP%" echo /target:library
>>"%RSP%" echo /platform:x64
>>"%RSP%" echo /optimize+
>>"%RSP%" echo /out:"%~dp0GcSurface.dll"
>>"%RSP%" echo /r:"%ACAD%\AcDbMgd.dll"
>>"%RSP%" echo /r:"%ACAD%\AcMgd.dll"
if exist "%ACAD%\AcCoreMgd.dll" >>"%RSP%" echo /r:"%ACAD%\AcCoreMgd.dll"
set REFN=0
for %%f in ("%ACAD%\Aec*Mgd.dll")      do call :addref "%%~ff"
for %%f in ("%ACAD%\C3D\Aec*Mgd.dll") do call :addref "%%~ff"
if exist "%ACAD%\ACA" for %%f in ("%ACAD%\ACA\Aec*Mgd.dll") do call :addref "%%~ff"
>>"%RSP%" echo "%~dp0GcSurface.cs"

echo Подключено библиотек Aec*: !REFN!
echo.
echo Собираю...
echo.
"%CSC%" @"%RSP%"

if errorlevel 1 goto :fail
if not exist "%~dp0GcSurface.dll" goto :fail
del /q "%RSP%" 2>nul
goto :built

rem ---------------------------------------------------------------
rem Добавить ссылку, если сборка с таким именем ещё не бралась.
rem ---------------------------------------------------------------
:addref
if defined SEEN_%~n1 exit /b 0
set "SEEN_%~n1=1"
>>"%RSP%" echo /r:"%~f1"
set /a REFN=!REFN!+1
exit /b 0

:built

echo.
echo ==================================================
echo   ГОТОВО: GcSurface.dll
echo ==================================================
echo.
echo Что дальше, в Civil 3D:
echo.
echo   1. Команда NETLOAD
echo   2. Выбрать файл:
echo      %~dp0GcSurface.dll
echo   3. Запустить KG - в отчёте появится строка
echo      "граница: точная, из поверхности"
echo.
echo Если NETLOAD ругается на безопасность: правой кнопкой
echo по GcSurface.dll - Свойства - галка "Разблокировать".
echo.
goto :end

:fail
echo.
echo ==================================================
echo   НЕ СОБРАЛОСЬ
echo ==================================================
echo.
echo Пришлите весь текст выше - по нему видно, где встало.
echo.

:end
rem Пауза нужна при ручном запуске, чтобы окно не закрылось и было
rem видно сообщения. Установщик вызывает этот файл сам и вывод уводит
rem в лог - там пауза означала бы намертво замерший экран без единой
rem строки объяснения. Поэтому он выставляет GC_NOPAUSE.
if not defined GC_NOPAUSE pause
