# menuGEO — Справочник инструментария

> Извлечено из `menu_GEO_0_15.cuix` (v0.15). 456 команд.
> Файл: `.cuix` = ZIP с `MenuGroup.cui` (XML) + PNG-иконки.

---

## Команды, критичные для проекта свай

| Название | Команда AutoCAD | Файл / Сборка |
|---|---|---|
| **Отклонения по сваям в плане и по высоте** | `svai` | `svai.lsp` |
| **Аппроксимация точек окружностью** | `_CAP2` | `CircleApproximation.dll` |
| **Гео отклонения** | `geo_otkl` | `Geo_Otkl_09_10.vlx` |
| **Планово-высотные отклонения** | `_XYZDifferences` | `XYZDifferences.dll` |
| **Стрелки отклонения** (стены) | `_iCmd_DrawWallValueArrows` | `IgorKL.ACAD3.Customization.dll` |
| **Верх/Низ** (стены) | `_iCmd_DrawWallArrows` | `IgorKL.ACAD3.Customization.dll` |
| **Анкера** | `_iCmd_DrawArrows` | `IgorKL.ACAD3.Customization.dll` |
| **Отрисовка векторов откл. верх/низ** | `otklvectorvn` | `otklvectorvn.lsp` |
| **Отклонение точки от линии** | `geo_isp` | `geo_isp.lsp` |
| **Отрисовка векторов и значений откл.** | (VBA) | `AxeAndPointZ.dvb` |

> `svai.lsp` — оригинальный скрипт Шамиля, который наш `sv.lsp` заменяет.
> `CircleApproximation._CAP2` — аналог нашего `gc-pile-best-circle` (мы реализовали сами).

---

## Команды геодезические (общие)

| Название | Команда | Файл |
|---|---|---|
| Импорт точек | `Geo_Import` | `Geo_Import_v2_10.vlx` |
| Экспорт точек | `geo_export` | `Geo_Export_v2_11.vlx` |
| Выноска | (VBA) | `Vinoska_v2.dvb` |
| Профиль сети | `pro` | `profil.lsp` |
| Быстрый профиль | `QPRF` | `QuickProfile.vlx` |
| Откос | `Geo_Otkos` | `Geo_Otkos.vlx` |
| Пикетаж | `DRPK` | `DR-PK-ROAD_2_1.vlx` |
| Подписи крестов | — | `XY.fas` |
| Проставить отметку точки | `pl` | `pl.lsp` |
| Интерполяция по линии | `Find_Z_OnLine` | `Find_Z_OnLine.lsp` |
| Интерполяция по 3D граням | `g` | `g.lsp` |
| Триангуляция точек | `triangulate` | `triangulate.lsp` |
| Уклон по точкам в профиль | `uklon` | `uklon.lsp` |
| Бергштрихи по горизонталям | `Bergbar` | `Bergbar.fas` |
| Обратная геодезическая задача | (exe) | `ogz.exe` |
| Перевод координат | (exe) | `XYH2NXYH.exe` |
| Реверс координат | `revkoor` | `RVK.vlx` |
| Нумерация с префиксом/суффиксом | `NumInc` | `NumIncV3-1.lsp` |
| Таблица геоданных | `geo_table` | `geo_table.lsp` |
| Таблица XYZ полилинии | `3CORD` | `3CORD.lsp` |
| Найти точки ниже/выше поверхности | `onsurf` | `onsurf.lsp` |
| Найти min/max отметки | `Geo_Find_min_max` | `Geo_Find_min_max.lsp` |

---

## Инструменты полилиний (pltools)

`PL-VFI`, `PL-VxAdd`, `PL-VxDel`, `PL-VxMove`, `PL-Vx1`, `PL-VxRdc`,
`PL-DIV`, `PL-DIVALL`, `PL-NoArc`, `PL-L2A`, `PL-A2L`, `PL-CLONE`,
`PL-SGWIDTH`, `PL-CW`, `PL-CCW` — все из `pltools.lsp`.

---

## Инструменты Civil 3D / SDR (тахеометр)

| Название | Команда |
|---|---|
| Импорт с тахеометра | `_SDRIMPORT` / `_SDRIMPORTCOM` |
| Экспорт в тахеометр | `_SDREXPORT` / `_SDREXPORTCOM` |

Сборка: `SDR33C3D.dll`

---

## IgorKL.ACAD3.Customization — команды

Все команды через `_netload;IgorKL.ACAD3.Customization;_iCmd_...`:

| Команда | Назначение |
|---|---|
| `_iCmd_DrawSlopeLines` | Линии откоса |
| `_iCmd_DrawArrows` | Анкера |
| `_iCmd_DrawWallArrows` | Стрелки Верх/Низ (стены) |
| `_iCmd_DrawWallValueArrows` | Стрелки отклонения со значениями (стены) |
| `_iCmd_EditDimensionValueRandom` | Размеры (случайные значения) |

> Исходники закрыты (скомпилированная .NET сборка).

---

## Структура .cuix файла

```
menu_GEO_0_15.cuix  ←  ZIP-архив
├── MenuGroup.cui       ← XML: все команды, меню, тулбары
├── *.png / *.bmp       ← иконки (URL-encoded имена на русском)
└── _rels/              ← служебные связи
```

Распаковка: `unzip menu_GEO_0_15.cuix -d /tmp/menu_geo/`

---

## Иконки, связанные со сваями

| Файл | Команда |
|---|---|
| `отклонения по сваям.png` | svai |
| `стрелки отклонений.png` | `_iCmd_DrawWallValueArrows` |
| `отрисовка векторов и значений отклонений.png` | `AxeAndPointZ` |
| `отрисовка векторов отклонений верх-низ.png` | `otklvectorvn` |
| `планово-высотные отклонения.png` | `_XYZDifferences` |
| `гео отклонения.png` | `geo_otkl` |
