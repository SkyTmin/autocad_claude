# -*- coding: utf-8 -*-
"""Варианты того, КАК считается краевой квадрат."""
from model import area, fix_overlap


def clip2(pts, hs, cnt, sgn):
    """Как clip_sign, но каждая вершина несёт флаг cnt — идёт ли она в среднее.
    Точки пересечения идут всегда."""
    out, outh, any_ = [], [], False
    n = len(pts)
    for i in range(n):
        a, h0, c0 = pts[i], hs[i], cnt[i]
        b, h1 = pts[(i + 1) % n], hs[(i + 1) % n]
        keep = (h0 >= 0.0) if sgn > 0 else (h0 < 0.0)
        if keep:
            any_ = True; out.append(a); outh.append(h0 if c0 else None)
        if (h0 >= 0.0 and h1 < 0.0) or (h0 < 0.0 and h1 >= 0.0):
            t = h0 / (h0 - h1)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
            outh.append(0.0)
    return (out, outh) if any_ else ([], [])


def piece2(pts, hs):
    if len(pts) < 3:
        return 0.0, 0.0
    a = area(pts)
    vals = [h for h in hs if h is not None]
    if not vals:
        return 0.0, a
    return a * (sum(vals) / len(vals)), a


def calc(pts, hs, marked, geom='marked', scale=True, mn=0.01):
    """geom='marked' — режем контур ПО ПОДПИСАННЫМ узлам (как сейчас);
       geom='full'   — режем ПОЛНЫЙ контур, в среднее берём только подписанные."""
    st = area(pts)
    if geom == 'marked':
        gp = [p for p, m in zip(pts, marked) if m]
        gh = [h for h, m in zip(hs, marked) if m]
        gc = [True] * len(gp)
        if len(gp) < 3 or area(gp) < 1e-9:
            gp, gh, gc = list(pts), list(hs), [True] * len(pts)
    else:
        gp, gh, gc = list(pts), list(hs), list(marked)
        if sum(gc) < 1:
            gc = [True] * len(pts)
    if any(h is None for h, c in zip(gh, gc) if c):
        return None
    gh = [0.0 if h is None else h for h in gh]
    s0 = area(gp)
    p, ph = clip2(gp, gh, gc, 1);  fill, sf = piece2(p, ph)
    p, ph = clip2(gp, gh, gc, -1); cut, sc = piece2(p, ph)
    if sf <= 0.0 and sc <= 0.0:
        sf = s0
    if abs(sf + sc - s0) > 1e-6:
        fill, sf, cut, sc = fix_overlap(fill, sf, cut, sc, s0)
    k = (st / s0) if (scale and s0 > 1e-9) else 1.0
    fill, sf, cut, sc = k * fill, k * sf, k * cut, k * sc
    if abs(cut) < mn:  cut = 0.0
    if abs(fill) < mn: fill = 0.0
    return fill - abs(cut)
