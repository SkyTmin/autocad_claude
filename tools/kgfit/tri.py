# -*- coding: utf-8 -*-
from model import area, clip_sign, piece, fix_overlap


def sgn_changes(hs):
    z = [(1 if h > 0 else (-1 if h < 0 else 0)) for h in hs]
    z = [x for x in z if x]
    if len(z) < 2:
        return 0
    return sum(1 for i in range(len(z)) if z[i] != z[(i + 1) % len(z)])


def tris(pts, diag):
    n = len(pts)
    if n < 3:
        return []
    if n == 3:
        return [pts]
    if n == 4:
        return ([[pts[0], pts[1], pts[2]], [pts[0], pts[2], pts[3]]] if diag == 13
                else [[pts[1], pts[2], pts[3]], [pts[1], pts[3], pts[0]]])
    s = 0 if diag == 13 else 1               # веер из вершины 0 или 1
    return [[pts[s], pts[(s + i) % n], pts[(s + i + 1) % n]] for i in range(1, n - 1)]


def calc_tri(pts, hs, marked, saddle_diag=None, mn=0.01):
    """saddle_diag=None — метод квадратов всегда; 13/24 — треугольники
    на квадратах, где знак меняется больше двух раз."""
    st = area(pts)
    mp = [p for p, m in zip(pts, marked) if m]
    mh = [h for h, m in zip(hs, marked) if m]
    if len(mp) < 3 or area(mp) < 1e-9:
        mp, mh = list(pts), list(hs)
    if any(h is None for h in mh):
        return None
    s0 = area(mp)
    use_tri = saddle_diag is not None and sgn_changes(mh) > 2
    if not use_tri:
        p, ph = clip_sign(mp, mh, 1);  fill, sf = piece(p, ph)
        p, ph = clip_sign(mp, mh, -1); cut, sc = piece(p, ph)
        if sf <= 0 and sc <= 0:
            sf = s0
        if abs(sf + sc - s0) > 1e-6:
            fill, sf, cut, sc = fix_overlap(fill, sf, cut, sc, s0)
    else:
        fill = sf = cut = sc = 0.0
        hmap = {(round(p[0], 4), round(p[1], 4)): h for p, h in zip(mp, mh)}
        for t in tris(mp, saddle_diag):
            th = [hmap.get((round(p[0], 4), round(p[1], 4))) for p in t]
            if any(h is None for h in th):
                continue
            p, ph = clip_sign(t, th, 1);  f, a1 = piece(p, ph)
            p, ph = clip_sign(t, th, -1); cc, a2 = piece(p, ph)
            fill += f; sf += a1; cut += cc; sc += a2
    k = st / s0 if s0 > 1e-9 else 1.0
    fill, cut = k * fill, k * cut
    if abs(cut) < mn:  cut = 0.0
    if abs(fill) < mn: fill = 0.0
    return fill - abs(cut)
