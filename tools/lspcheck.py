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
VAR = r'[a-zA-Zа-яА-Я][a-zA-Zа-яА-Я0-9-]*'


def scan_locals(d):
    """Переменные, не объявленные после слэша в (defun ... ( / ...)).

    ЗАЧЕМ. В AutoLISP переменная цикла foreach и любая setq БЕЗ объявления
    остаётся глобальной после выхода из функции. Пока имена не пересекаются,
    это незаметно; как только две функции возьмут одно короткое имя (c, p, k)
    и одна вызовет другую - вложенный вызов затрёт значение внешнего, и
    сломается тот, кто ничего не менял (docs/pitfalls.md -> П70).
    """
    out = []
    for m in re.finditer(r'\(defun (' + NAME + r') \(([^)]*)\)', d):
        name = m.group(1)
        loc = set(a for a in m.group(2).replace('/', ' ').split())
        start = m.end()
        nxt = d.find('\n(defun ', start)
        body = d[start: nxt if nxt > 0 else len(d)]
        used = set(re.findall(r'\(foreach (' + VAR + ')', body))
        used |= set(re.findall(r'\(setq (' + VAR + ')', body))
        miss = sorted(v for v in used - loc if not v.startswith('*'))
        if miss:
            out.append((name, miss))
    return out



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

    leaks = scan_locals(d)

    # Утечки в глобальные НЕ роняют проверку: их 44 в kg.lsp на момент
    # заведения, и чинить их надо отдельным разбором, а не вперемешку
    # с расчётной правкой (status/ISSUES.md -> #008). Но молчать о них
    # нельзя - иначе число будет только расти.
    ok = (depth == 0) and not bad and not miss and enc == 'ok'
    print('%s\n  скобки: %d | ошибки: %s\n  не определены: %s\n  CP1251: %s\n'
          '  утекают в глобальные: %d функций%s'
          % (path, depth, bad or 'нет', miss or 'нет', enc, len(leaks),
             '' if not leaks else
             '\n    ' + '\n    '.join('%-26s %s' % (n, ' '.join(v))
                                       for n, v in leaks[:6])
             + ('\n    ...' if len(leaks) > 6 else '')))
    return ok


if __name__ == '__main__':
    files = sys.argv[1:]
    if not files:
        print(__doc__)
        sys.exit(2)
    sys.exit(0 if all([scan(f) for f in files]) else 1)
