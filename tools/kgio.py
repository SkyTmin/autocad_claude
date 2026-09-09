# -*- coding: utf-8 -*-
"""Чтение и запись файлов проекта в CP1251 — безопасно.

ЗАЧЕМ. Файлы кода в CP1251 без BOM (ADR-0004). Наивная запись

    open(path, 'wb').write(text.encode('cp1251'))

обнуляет файл, если в тексте есть символ, которого в CP1251 нет: open
обрезает файл ПЕРВЫМ, encode падает ВТОРЫМ, и на диске остаётся ноль
байт. Так было потеряно четыре файла — 2026-08-24 (sv.lsp, иероглиф),
2026-09-03 и 2026-09-04 (kg.lsp, типографский минус U+2212),
2026-09-09 (kg.lsp, греческая θ). См. docs/pitfalls.md → П10.

Правило «сначала encode, потом open» записывалось трижды и трижды
не срабатывало: скрипты правки пишутся заново каждый раз, и строка
записи набирается руками. Поэтому она вынесена сюда — руками этот шаг
больше не набирается.

Использование в скрипте правки:

    import sys; sys.path.insert(0, 'tools')
    from kgio import read_lsp, write_lsp, replace_once

    d = read_lsp('src/lisp/commands/kg.lsp')
    d = replace_once(d, 'старое', 'новое')
    write_lsp('src/lisp/commands/kg.lsp', d)
"""
import sys

ENC = 'cp1251'


def unencodable(text, enc=ENC):
    """Символы, которых нет в кодировке. Спрашиваем у САМОЙ кодировки.

    Список «плохих символов» из головы уже подводил: в него попали
    длинное тире, ёлочки и многоточие, которые в CP1251 ЕСТЬ, и
    санитайзер молча испортил 87 тире по всему файлу (П10).
    """
    bad = []
    for ch in sorted(set(text)):
        try:
            ch.encode(enc)
        except UnicodeEncodeError:
            bad.append(ch)
    return bad


def read_lsp(path, enc=ENC):
    return open(path, 'rb').read().decode(enc)


def write_lsp(path, text, enc=ENC):
    """Записать. Кодирует ДО открытия файла — иначе потеря при сбое."""
    bad = unencodable(text, enc)
    if bad:
        where = []
        for ch in bad:
            i = text.find(ch)
            line = text.count('\n', 0, i) + 1
            where.append('%r (U+%04X) строка %d' % (ch, ord(ch), line))
        raise ValueError(
            'в тексте символы, которых нет в %s — файл НЕ тронут:\n  %s'
            % (enc, '\n  '.join(where)))
    blob = text.encode(enc)          # сначала проверили
    open(path, 'wb').write(blob)     # потом открыли
    return len(blob)


def replace_once(text, old, new, count=1):
    """Замена с проверкой числа вхождений.

    Молчаливая замена «ноль раз» — это правка, которой не было, а её
    считают сделанной. Молчаливая замена «два раза» — правка не в том
    месте. И то, и другое ловится только счётом.
    """
    n = text.count(old)
    if n != count:
        raise ValueError('вхождений %d, ожидалось %d:\n%s' % (n, count, old[:300]))
    return text.replace(old, new)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        t = read_lsp(p)
        bad = unencodable(t)
        print('%s: %d символов, вне CP1251: %s'
              % (p, len(t), bad if bad else 'нет'))
