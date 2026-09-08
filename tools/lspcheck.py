# -*- coding: utf-8 -*-
"""Статическая проверка AutoLISP-файлов проекта.

ЗАЧЕМ. В этом окружении AutoCAD нет, и единственный способ поймать ошибку
до прогона у Шамиля - проверить то, что проверяется без запуска. Каждая
проверка здесь появилась после настоящей поломки, см. docs/pitfalls.md.

Запуск:
    python3 tools/lspcheck.py src/lisp/commands/*.lsp

Что проверяется:
  * баланс скобок с УЧЁТОМ экранирования внутри строк;
  * настоящий перевод строки внутри строкового литерала - признак
    потерянного экранирования в скрипте правки (\\n стал переносом);
  * вызовы gc-* без определения, в том числе в кавычках;
  * кодировка CP1251 целиком (ADR-0004).
"""
import re
import sys


def scan_parens(d):
    """Скобки и переносы внутри строк. Возвращает (глубина, список ошибок).

    ЭКРАНИРОВАНИЕ РАЗБИРАЕТСЯ ЧЕСТНО. Прежняя редакция смотрела на
    предыдущий символ и на литерале "\\"" считала кавычки неверно: файл
    объявлялся сломанным, хотя был цел. Контролёр, который врёт, хуже
    отсутствующего - по нему принимают решения (docs/pitfalls.md -> П72).
    """
    depth = 0
    instr = incom = esc = False
    line = 1
    bad = []
    for ch in d:
        if ch == '\n':
            line += 1
            incom = False
            if instr:
                bad.append(('перенос строки внутри литерала', line - 1))
                instr = esc = False
            continue
        if incom:
            continue
        if instr:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                instr = False
            continue
        if ch == ';':
            incom = True
        elif ch == '"':
            instr, esc = True, False
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth < 0:
                bad.append(('лишняя закрывающая скобка', line))
                depth = 0
    return depth, bad


NAME = r'[a-zA-Zа-яА-Я0-9:_*<>?\-]+'


def scan(path):
    raw = open(path, 'rb').read()
    try:
        d = raw.decode('cp1251')
    except UnicodeDecodeError as e:
        print('%s\n  [!!] файл не читается как CP1251: %s' % (path, e))
        return False

    depth, bad = scan_parens(d)

    defined = set(re.findall(r'\(defun\s+(' + NAME + ')', d))
    called = set(re.findall(r'\((gc-' + NAME + ')', d))
    quoted = set(re.findall(r"'(gc-" + NAME + ")", d))
    miss = sorted(c for c in (called | quoted) if c not in defined)

    try:
        d.encode('cp1251')
        enc = 'ok'
    except UnicodeEncodeError as e:
        enc = 'НЕ КОДИРУЕТСЯ: %s' % e

    ok = (depth == 0) and not bad and not miss and enc == 'ok'
    print('%s\n  скобки: %d | ошибки: %s\n  не определены: %s\n  CP1251: %s'
          % (path, depth, bad or 'нет', miss or 'нет', enc))
    return ok


if __name__ == '__main__':
    files = sys.argv[1:]
    if not files:
        print(__doc__)
        sys.exit(2)
    sys.exit(0 if all([scan(f) for f in files]) else 1)
