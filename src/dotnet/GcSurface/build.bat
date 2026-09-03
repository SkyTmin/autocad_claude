@echo off
setlocal enabledelayedexpansion
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
rem    Aec*Mgd.dll подключаем ВСЕ, какие есть, а не выбранные
rem    по именам: от версии к версии классы переезжают между
rem    сборками, и угадывать, в какой лежит нужный, - гарантия
rem    поломки на чужой машине. Лишние ссылки компилятору не мешают.
rem ---------------------------------------------------------------
set "REFS=/r:"%ACAD%\AcDbMgd.dll" /r:"%ACAD%\AcMgd.dll""
if exist "%ACAD%\AcCoreMgd.dll" set "REFS=!REFS! /r:"%ACAD%\AcCoreMgd.dll""
for %%f in ("%ACAD%\C3D\Aec*Mgd.dll") do set "REFS=!REFS! /r:"%%~ff""

echo.
echo Собираю...
echo.
"%CSC%" /nologo /target:library /platform:x64 /optimize+ ^
        /out:"%~dp0GcSurface.dll" !REFS! "%~dp0GcSurface.cs"

if errorlevel 1 goto :fail
if not exist "%~dp0GcSurface.dll" goto :fail

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
