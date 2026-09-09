# -*- coding: utf-8 -*-
"""Модель расчёта kg.lsp на Python — чтобы подбирать правила численно,
не тратя прогоны в Civil 3D."""

def area(pts):
    s = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) * 0.5


def clip_sign(pts, hs, sgn):
    out, outh, any_ = [], [], False
    n = len(pts)
    for i in range(n):
        a, h0 = pts[i], hs[i]
        b, h1 = pts[(i + 1) % n], hs[(i + 1) % n]
        keep = (h0 >= 0.0) if sgn > 0 else (h0 < 0.0)
        if keep:
            any_ = True; out.append(a); outh.append(h0)
        if (h0 >= 0.0 and h1 < 0.0) or (h0 < 0.0 and h1 >= 0.0):
            t = h0 / (h0 - h1)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
            outh.append(0.0)
    return (out, outh) if any_ else ([], [])


def piece(pts, hs):
    if len(pts) < 3:
        return 0.0, 0.0
    a = area(pts)
    return a * (sum(hs) / len(hs)), a


def split2(pts, hs):
    p, ph = clip_sign(pts, hs, 1);  fill, sf = piece(p, ph)
    p, ph = clip_sign(pts, hs, -1); cut, sc = piece(p, ph)
    if sf <= 0.0 and sc <= 0.0:
        sf = area(pts)
    return fill, sf, cut, sc


def fix_overlap(fill, sf, cut, sc, s0, deg=0):
    hf = fill / sf if sf > 1e-12 else 0.0
    hc = cut / sc if sc > 1e-12 else 0.0
    ov = sf + sc - s0
    if deg == 0:
        if sf >= sc: sc = s0 - sf
        else:        sf = s0 - sc
    elif deg == 1:
        if sf >= sc: sf = s0 - sc
        else:        sc = s0 - sf
    elif deg == 2:
        sf -= 0.5 * ov; sc -= 0.5 * ov
    else:
        if sf + sc > 1e-12:
            r = s0 / (sf + sc); sf *= r; sc *= r
    sf = max(sf, 0.0); sc = max(sc, 0.0)
    return hf * sf, sf, hc * sc, sc


def vol_marked(pts, hs, marked):
    """pts/hs — полный контур; marked — булев список «расчётный узел»."""
    st = area(pts)
    mp = [p for p, m in zip(pts, marked) if m]
    mh = [h for h, m in zip(hs, marked) if m]
    if len(mp) < 3 or area(mp) < 1e-9:
        mp, mh = list(pts), list(hs)          # откат на весь контур
    if any(h is None for h in mh):
        return None
    s0 = area(mp)
    fill, sf, cut, sc = split2(mp, mh)
    if abs(sf + sc - s0) > 1e-6:
        fill, sf, cut, sc = fix_overlap(fill, sf, cut, sc, s0)
    k = st / s0 if s0 > 1e-9 else 1.0
    return k * fill, k * sf, k * cut, k * sc


def cell_total(pts, hs, marked, mn=0.01):
    r = vol_marked(pts, hs, marked)
    if r is None:
        return None
    fill, sf, cut, sc = r
    if abs(cut) < mn:  cut, sc = 0.0, 0.0
    if abs(fill) < mn: fill, sf = 0.0, 0.0
    return fill - abs(cut), abs(cut), fill, sc, sf


import math

DUP = 0.05          # допуск «та же точка», м (*gc-kg-dup-tol*)


def nb_of(pts, k, d):
    """Ближайший НЕсовпадающий сосед вершины k. d=+1 вперёд, -1 назад."""
    n = len(pts); b = pts[k]
    for i in range(1, n):
        m = pts[(k + d * i) % n]
        if math.hypot(m[0] - b[0], m[1] - b[1]) > DUP:
            return m
    return b


def dev_of(a, b, c):
    """Отклонение b от прямой через a и c, м."""
    l = math.hypot(c[0] - a[0], c[1] - a[1])
    if l < 1e-12:
        return math.hypot(b[0] - a[0], b[1] - a[1])
    return abs((c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])) / l


def bend_of(a, b, c):
    """Излом контура в b, град: 0 — прямая, 180 — разворот назад."""
    v1 = (b[0] - a[0], b[1] - a[1])
    v2 = (c[0] - b[0], c[1] - b[1])
    l1 = math.hypot(*v1); l2 = math.hypot(*v2)
    if l1 < 1e-12 or l2 < 1e-12:
        return 0.0
    cs = max(-1.0, min(1.0, (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2)))
    return math.degrees(math.acos(cs))


def features(pts):
    """Для каждой вершины: (отклонение, излом) по НЕсовпадающим соседям."""
    out = []
    for k in range(len(pts)):
        a = nb_of(pts, k, -1); c = nb_of(pts, k, 1)
        out.append((dev_of(a, pts[k], c), bend_of(a, pts[k], c)))
    return out
