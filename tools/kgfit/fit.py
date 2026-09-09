# -*- coding: utf-8 -*-
"""Подбор правила отбора расчётных узлов по данным четырёх чертежей."""
import json, sys, math
sys.path.insert(0, '.')
from model import cell_total, features, DUP

import os
_HERE = os.path.dirname(os.path.abspath(__file__))
C = json.load(open(os.path.join(_HERE, 'cells.json'), encoding='utf-8'))
DW = ['d1', 'd2', 'd3', 'd4']


def key(p):
    return (round(p[0] / DUP), round(p[1] / DUP))


def build(dwg):
    """Глобальный список точек чертежа: (grid, max dev, bend при max dev)."""
    g = {}
    for c in C:
        if c['dwg'] != dwg:
            continue
        pts = [(v['x'], v['y']) for v in c['verts']]
        for v, (d, b) in zip(c['verts'], features(pts)):
            for kk in (key((v['x'] + dx, v['y'] + dy))
                       for dx in (-DUP/2, 0, DUP/2) for dy in (-DUP/2, 0, DUP/2)):
                if kk in g:
                    break
            else:
                kk = key((v['x'], v['y']))
            e = g.get(kk)
            if e is None or d > e[1]:
                g[kk] = (v['grid'] or (e[0] if e else False), d, b)
            elif v['grid']:
                g[kk] = (True, e[1], e[2])
    return g


GLOB = {d: build(d) for d in DW}


def lookup(dwg, p):
    g = GLOB[dwg]
    kk = key(p)
    if kk in g:
        return g[kk]
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            e = g.get((kk[0] + dx, kk[1] + dy))
            if e:
                return e
    return (False, 0.0, 0.0)


def run(rule, dwgs=DW):
    """rule(grid, dev, bend) -> bool. Возвращает (сумма |модель-его|, по чертежам)."""
    tot = 0.0; per = {d: 0.0 for d in dwgs}; n = 0
    for c in C:
        if c['dwg'] not in dwgs:
            continue
        pts = [(v['x'], v['y']) for v in c['verts']]
        hs = [v['h'] for v in c['verts']]
        mk = []
        for v in c['verts']:
            gr, dv, bn = lookup(c['dwg'], (v['x'], v['y']))
            mk.append(bool(rule(gr, dv, bn)))
        r = cell_total(pts, hs, mk)
        if r is None:
            continue
        d = abs(r[0] - c['his']); tot += d; per[c['dwg']] += d; n += 1
    return tot, per, n


def check_reproduces():
    """Совпадает ли модель с НАШИМ столбцом при нынешнем правиле."""
    bad = 0; mx = 0.0
    for c in C:
        pts = [(v['x'], v['y']) for v in c['verts']]
        hs = [v['h'] for v in c['verts']]
        mk = []
        for v in c['verts']:
            gr, dv, bn = lookup(c['dwg'], (v['x'], v['y']))
            mk.append(gr or dv >= 0.22)
        r = cell_total(pts, hs, mk)
        if r is None:
            continue
        d = abs(r[0] - c['our'])
        mx = max(mx, d)
        if d > 0.006:
            bad += 1
    return bad, mx
