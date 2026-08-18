;;; sv.lsp -- obrabotka svay (SPEC-001 / SPEC-002 / SPEC-003 / SPEC-004 v21)
;;; Komandy:
;;;   SV  -- rezhimy 1/2 i novyy rezhim 3.
;;;   SVP -- sechenie svai na zadannoy otmetke + proektnoe otklonenie.
;;;
;;; v21: vysota teksta stala VEDUSHCHIM razmerom, kak v ol.lsp: dlina strelki
;;;      = 2 x vysota, nakonechnik = 0.4 x vysota, smeshchenie cifry = 1 x
;;;      vysota. Ranshe dlina strelki byla zafiksirovana 0.400 pri tekste
;;;      0.100 -- sootnoshenie 1:4, i cifra vyglyadela melkoy ryadom so
;;;      strelkoy. Teper 1:2, kak u OL. Umolchanie teksta 0.100 -> 0.200,
;;;      dlina strelki pri etom ostalas 0.400.
;;;      Dobavlena knopka [Tekst] v zapros rezhima: menyaet vysotu i tem samym
;;;      masshtabiruet vsyu grafiku. Znachenie obshchee dlya SV i SVP.
;;;
;;; v20: raspolozhenie cifr privedeno k ol.lsp. Ranshe storona podpisi
;;;      schitalas ot znakov otkloneniya i zavisela ot kvadranta -- cifra
;;;      prygala to nad strelkoy, to pod ney. Teper smeshchenie beretsya ot
;;;      NORMALIZOVANNOGO napravleniya strelki, i storona postoyannaya:
;;;      u gorizontalnoy strelki cifra vsegda sverhu, u vertikalnoy -- sleva.
;;;      Konstanty *gc-pile-text-along* / *gc-pile-text-lateral* udaleny:
;;;      smeshchenie vyvoditsya iz dliny strelki i vysoty teksta.
;;;
;;; v19: stil teksta privedyon k ol.lsp -- v cepochku podbora dobavlen "MGS"
;;;      pervym. Imenno etot stil stoit v chertezhah Shamilya, a SV bez nego
;;;      padal na GOSTB/Standard -- otsyuda drugoy shrift u cifr.
;;;
;;; v18: strelki pererisovany v stile ol.lsp -- LWPOLYLINE iz 3 vershin
;;;      s plavno suzhayushchimsya nakonechnikom vmesto LINE + treugolnik
;;;      SOLID. Proporcii iz obrazca menuGEO: shirina nakonechnika 0.2 ot
;;;      dliny strelki (0.080 pri 0.400), nakonechnik vo vtoroy polovine.
;;;
;;; v17: zashchita ot otsutstviya Visual LISP COM. U Kosti vyletala oshibka
;;;      "no function definition: VLAX-ENAME->VLA-OBJECT" -- (vl-load-com)
;;;      v shapke fayla ne otrabotal. Teper koordinaty obychnoy tochki
;;;      berutsya iz DXF-gruppy 10 BEZ COM, a COM trogaetsya tolko dlya
;;;      COGO Point Civil 3D, prichem s proverkoy i vnyatnym soobshcheniem.
;;;
;;; v16: ubrano verhnee ogranichenie dZ mezhdu nizhnim i verhnim secheniem.
;;;      Svai s bolshim raznosom po vysote, naprimer Z 1.000 -> 12.000,
;;;      obrabatyvayutsya vo vseh avtomaticheskih rezhimah.
;;; v15: ispravlen perenos grafiki SV 3: "vverh" = po osi +Y, ne po Z.
;;;      SV-otkloneniya v mode 3 risuyutsya sinim so sdvigom +Y 1.700 m.
;;;      SVP-proektnye otkloneniya v mode 3 risuyutsya belym so sdvigom +Y 2.600 m.
;;; v14: SV mode 3 = SV mode 1 + SVP za odin zapusk.
;;; v13: SVP schitaet otklonenie ot proektnogo centra k novomu secheniyu.
;;; v12: dobavlena komanda SVP (SPEC-003).
;;; v11: gc-pile-strip-hm udalyaet paru otmetchikov vysoty tolko esli ona
;;;      yavno izolirovana nad secheniem.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/sv.lsp").
;;; Zavisimosti: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ
;;; ====================================================================

(setq *gc-pile-r-norm*             0.710) ; норма радиуса сваи, м
(setq *gc-pile-r-warn*             0.050)
;; ВЫСОТА ТЕКСТА ЗАДАЁТ ВСЮ ГРАФИКУ — как в ol.lsp. Длина стрелки и ширина
;; наконечника считаются от неё, поэтому цифра и стрелка всегда в одной
;; пропорции. Меняется кнопкой [Текст] в запросе режима.
(setq *gc-pile-arrow-k*            2.0)   ; длина стрелки = 2.0 x высота текста
;; Ширина наконечника = доля от длины стрелки. 0.2 x 0.400 = 0.080 —
;; ровно как в образце menuGEO, тот же вид, что у стрелок ol.lsp.
(setq *gc-pile-arrow-head-k*       0.2)
(setq *gc-pile-tol-mm-per-m*      20.0)
(setq *gc-pile-text-h*             0.200) ; высота текста, м — ведущий размер
;; *gc-pile-text-along* и *gc-pile-text-lateral* удалены в v20: смещение
;; подписи теперь выводится из геометрии, как в ol.lsp — вдоль стрелки это
;; ровно её середина, поперёк — высота текста. Отдельные константы только
;; расходились бы с реальным размером стрелки.
(setq *gc-pile-z-cluster*          0.050)
(setq *gc-pile-xy-cluster*         1.800)
(setq *gc-pile-pair-dz-min*        0.300)
(setq *gc-pile-hm-pair-dz-max*     0.002)
(setq *gc-pile-hm-gap-min*         0.010)
(setq *gc-pile-project-match-max*  2.000)
(setq *gc-pile-sv3-sv-dev-dy*      1.700)
(setq *gc-pile-sv3-prj-dev-dy*     2.600)

(setq *gc-pile-ssget-filter*
      '((0 . "POINT,AECC*POINT,AEC*POINT")))

(setq *gc-pile-project-ssget-filter*
      '((0 . "CIRCLE,POINT,AECC*POINT,AEC*POINT")))

(setq *gc-l-low*                "GC-Сваи-Низ")
(setq *gc-l-high*               "GC-Сваи-Верх")
(setq *gc-l-arrows*             "GC-Сваи-Отклонения")
(setq *gc-l-text*               "GC-Сваи-Текст")
(setq *gc-l-cut*                "GC-Сваи-Срез")
(setq *gc-l-project-arrows*     "GC-Сваи-Проект-Отклонения")
(setq *gc-l-project-text*       "GC-Сваи-Проект-Текст")
(setq *gc-l-sv3-arrows*         "GC-Сваи-SV3-Синие-Отклонения")
(setq *gc-l-sv3-text*           "GC-Сваи-SV3-Синий-Текст")
(setq *gc-l-sv3-project-arrows* "GC-Сваи-SV3-Проект-Отклонения")
(setq *gc-l-sv3-project-text*   "GC-Сваи-SV3-Проект-Текст")

;;; ====================================================================
;;; ИЗВЛЕЧЕНИЕ КООРДИНАТ
;;; ====================================================================

;; Проверяет, доступен ли Visual LISP COM, и при необходимости догружает его.
;; ПОЧЕМУ нужно: у Кости вылетала ошибка
;;   "no function definition: VLAX-ENAME->VLA-OBJECT"
;; то есть (vl-load-com) в шапке файла не отработал. Ссылка на несвязанный
;; символ в AutoLISP возвращает nil и не падает, поэтому наличие функции
;; можно проверить прямо так.
(defun gc-pile-com-ok ( / )
  (if (null vlax-ename->vla-object) (vl-load-com))
  (if vlax-ename->vla-object T nil))

;; Координаты объекта: (x y z).
;; ПОРЯДОК ВАЖЕН. Сначала пробуем DXF-группу 10 — она есть у обычной точки
;; и не требует Visual LISP COM вообще. COM трогаем только для COGO Point
;; Civil 3D, где координаты доступны лишь через Easting/Northing.
;; Так команда продолжает работать даже там, где COM недоступен.
(defun gc-pile-get-coords (ent / ed typ p10 obj)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed))
        p10 (cdr (assoc 10 ed)))
  (cond
    ;; COGO Point — только через COM.
    ((wcmatch typ "AECC*POINT,AEC*POINT")
     (if (gc-pile-com-ok)
       (progn
         (setq obj (vlax-ename->vla-object ent))
         (cond
           ((vlax-property-available-p obj 'Easting)
            (list (vla-get-Easting obj)
                  (vla-get-Northing obj)
                  (vla-get-Elevation obj)))
           ((vlax-property-available-p obj 'Coordinates)
            (vlax-safearray->list
              (vlax-variant-value (vla-get-Coordinates obj))))
           ((vlax-property-available-p obj 'InsertionPoint)
            (vlax-safearray->list
              (vlax-variant-value (vla-get-InsertionPoint obj))))
           (T nil)))
       nil))
    ;; Обычная точка и всё, у чего есть группа 10 — без COM.
    ((and p10 (caddr p10)) p10)
    ;; Остальное — пробуем COM, если он есть.
    ((gc-pile-com-ok)
     (setq obj (vlax-ename->vla-object ent))
     (cond
       ((vlax-property-available-p obj 'Coordinates)
        (vlax-safearray->list
          (vlax-variant-value (vla-get-Coordinates obj))))
       ((vlax-property-available-p obj 'InsertionPoint)
        (vlax-safearray->list
          (vlax-variant-value (vla-get-InsertionPoint obj))))
       (T nil)))
    (T nil)))

(defun gc-pile-get-project-center (ent / ed typ c)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed)))
  (cond
    ((= typ "CIRCLE")
     (setq c (cdr (assoc 10 ed)))
     (if c (list (car c) (cadr c) (if (caddr c) (caddr c) 0.0)) nil))
    ((wcmatch typ "POINT,AECC*POINT,AEC*POINT")
     (setq c (gc-pile-get-coords ent))
     (if c (list (car c) (cadr c) (if (caddr c) (caddr c) 0.0)) nil))
    (T nil)))

(defun gc-pile-ss-to-points (ss / i n pts ent c skipped)
  (setq pts '() skipped 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c (gc-pile-get-coords ent))
    (if c
      (setq pts (cons c pts))
      (setq skipped (1+ skipped)))
    (setq i (1+ i)))
  (if (> skipped 0)
    (progn
      (princ (strcat "\n[!] Пропущено объектов без координат: " (itoa skipped)))
      (if (null (gc-pile-com-ok))
        (princ (strcat "\n[!] Visual LISP COM недоступен в этой версии CAD."
                       "\n    COGO Point Civil 3D без него прочитать нельзя."
                       "\n    Обычные точки (POINT) читаются и без него.")))))
  (reverse pts))

(defun gc-pile-ss-to-project-centers (ss / i n centers ent c skipped)
  (setq centers '() skipped 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c (gc-pile-get-project-center ent))
    (if c
      (setq centers (cons c centers))
      (setq skipped (1+ skipped)))
    (setq i (1+ i)))
  (if (> skipped 0)
    (princ (strcat "\n[!] SVP: пропущено проектных объектов без координат: "
                   (itoa skipped))))
  (reverse centers))

(defun gc-pile-read-project-centers ( / ss centers)
  (princ "\nВыделите проектные круги или проектные точки (Enter — без проектных отклонений): ")
  (setq ss (ssget *gc-pile-project-ssget-filter*))
  (if ss
    (progn
      (setq centers (gc-pile-ss-to-project-centers ss))
      (princ (strcat "\n[i] Проектных центров выбрано: " (itoa (length centers))))
      centers)
    (progn
      (princ "\n[!] Проектные объекты не выбраны: проектные отклонения не строятся.")
      nil)))

;;; ====================================================================
;;; ГЕОМЕТРИЯ
;;; ====================================================================

(defun gc-pile-circle-3 (p1 p2 p3 / ax ay bx by d ux uy)
  (setq ax (- (car p2)  (car p1))
        ay (- (cadr p2) (cadr p1))
        bx (- (car p3)  (car p1))
        by (- (cadr p3) (cadr p1)))
  (setq d (* 2.0 (- (* ax by) (* ay bx))))
  (if (< (abs d) 1.0e-9)
    nil
    (progn
      (setq ux (/ (- (* by (+ (* ax ax) (* ay ay)))
                     (* ay (+ (* bx bx) (* by by))))
                  d)
            uy (/ (- (* ax (+ (* bx bx) (* by by)))
                     (* bx (+ (* ax ax) (* ay ay))))
                  d))
      (list (+ (car p1)  ux)
            (+ (cadr p1) uy)
            (sqrt (+ (* ux ux) (* uy uy)))))))

(defun gc-pile-avg (lst / sum)
  (setq sum 0.0)
  (foreach v lst (setq sum (+ sum v)))
  (/ sum (float (length lst))))

(defun gc-pile-strip-hm (zg / sorted top1 top2 top3 rest)
  (if (< (length zg) 5)
    zg
    (progn
      (setq sorted (vl-sort zg '(lambda (a b) (> (caddr a) (caddr b)))))
      (setq top1 (car sorted)
            top2 (cadr sorted)
            top3 (caddr sorted)
            rest (cddr sorted))
      (if (and (< (abs (- (caddr top1) (caddr top2))) *gc-pile-hm-pair-dz-max*)
               (>= (- (caddr top2) (caddr top3)) *gc-pile-hm-gap-min*))
        (progn
          (princ (strcat "\n[i] Удалена пара отметчиков высоты"
                         " (Z~" (rtos (caddr top1) 2 3)
                         " м, зазор до сечения "
                         (rtos (* 1000 (- (caddr top2) (caddr top3))) 2 1)
                         " мм)"))
          rest)
        zg))))

(defun gc-pile-combos3 (lst / n i j k res)
  (setq res '() n (length lst) i 0)
  (while (< i (- n 2))
    (setq j (1+ i))
    (while (< j (- n 1))
      (setq k (1+ j))
      (while (< k n)
        (setq res (cons (list (nth i lst) (nth j lst) (nth k lst)) res))
        (setq k (1+ k)))
      (setq j (1+ j)))
    (setq i (1+ i)))
  res)

(defun gc-pile-best-circle (points / triples best best-err circ err)
  (if (< (length points) 3)
    nil
    (progn
      (setq triples (gc-pile-combos3 points))
      (setq best nil best-err 1.0e99)
      (foreach tr triples
        (setq circ (gc-pile-circle-3 (car tr) (cadr tr) (caddr tr)))
        (if circ
          (progn
            (setq err (abs (- (caddr circ) *gc-pile-r-norm*)))
            (if (< err best-err)
              (setq best-err err best circ)))))
      best)))

(defun gc-pile-dist-xy (p1 p2 / dx dy)
  (setq dx (- (car p1) (car p2))
        dy (- (cadr p1) (cadr p2)))
  (sqrt (+ (* dx dx) (* dy dy))))

(defun gc-pile-take-nearest-project (target projects limit / best best-dist rest p d)
  (if (null projects)
    (list nil projects nil)
    (progn
      (setq best nil best-dist 1.0e99 rest '())
      (foreach p projects
        (setq d (gc-pile-dist-xy target p))
        (if (< d best-dist)
          (progn
            (if best (setq rest (cons best rest)))
            (setq best p best-dist d))
          (setq rest (cons p rest))))
      (if (and best (<= best-dist limit))
        (list best (reverse rest) best-dist)
        (list nil projects best-dist)))))

(defun gc-pile-cluster-by-xy (pts / clusters remaining cur grow keep)
  (setq remaining pts clusters '())
  (while remaining
    (setq cur (list (car remaining))
          remaining (cdr remaining))
    (setq grow T)
    (while grow
      (setq grow nil keep '())
      (foreach p remaining
        (if (vl-some
              '(lambda (m) (<= (gc-pile-dist-xy p m) *gc-pile-xy-cluster*))
              cur)
          (progn (setq cur (cons p cur) grow T))
          (setq keep (cons p keep))))
      (setq remaining (reverse keep)))
    (setq clusters (cons cur clusters)))
  (reverse clusters))

(defun gc-pile-cluster-by-z (pts / sorted groups cur-group cur-z pt)
  (setq sorted (vl-sort pts '(lambda (a b) (< (caddr a) (caddr b)))))
  (setq groups '() cur-group '() cur-z nil)
  (foreach pt sorted
    (cond
      ((null cur-z)
       (setq cur-z (caddr pt) cur-group (list pt)))
      ((<= (- (caddr pt) cur-z) *gc-pile-z-cluster*)
       (setq cur-group (cons pt cur-group)))
      (T
       (setq groups (cons (reverse cur-group) groups))
       (setq cur-z (caddr pt) cur-group (list pt)))))
  (if cur-group
    (setq groups (cons (reverse cur-group) groups)))
  (reverse groups))

;;; ====================================================================
;;; СЛОИ И ОТРИСОВКА
;;; ====================================================================

(defun gc-pile-ensure-layer (name color)
  (if (null (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name)
                   '(70 . 0)
                   (cons 62 color)
                   '(6 . "Continuous")))))

(defun gc-pile-text-style ( / )
  (cond
    ((tblsearch "STYLE" "МГС")      "МГС")
    ((tblsearch "STYLE" "GOSTB")    "GOSTB")
    ((tblsearch "STYLE" "ISOCPEUR") "ISOCPEUR")
    (T                              "Standard")))

(defun gc-pile-draw-circle (cx cy z r layer)
  (entmake (list '(0 . "CIRCLE")
                 (cons 8 layer)
                 (cons 10 (list cx cy z))
                 (cons 40 r))))

;; Стрелка = LWPOLYLINE из 3 вершин: тонкий хвост, затем плавно сужающийся
;; наконечник во второй половине. Раньше здесь была LINE плюс треугольник
;; SOLID — выглядело грубее. Теперь тот же вид, что в ol.lsp, а пропорции
;; взяты из образца menuGEO: наконечник шириной 0.2 от длины стрелки
;; (0.080 при длине 0.400) и занимает вторую половину.
;;
;; Ширина задаётся ПОСЕГМЕНТНО: группа 40 — начальная ширина сегмента,
;; начинающегося в этой вершине, группа 41 — конечная. Поэтому наконечник
;; описывается на средней вершине.
;;
;; LWPOLYLINE плоская, высота хранится в группе 38 — берём Z начала, чтобы
;; стрелка легла на ту же отметку, что и раньше LINE.
(defun gc-pile-draw-arrow (start end layer / dx dy len ux uy mid head z)
  (setq dx  (- (car  end) (car  start))
        dy  (- (cadr end) (cadr start))
        len (sqrt (+ (* dx dx) (* dy dy))))
  (if (> len 1.0e-9)
    (progn
      (setq ux (/ dx len)
            uy (/ dy len))
      (setq mid (list (+ (car  start) (* ux (/ len 2.0)))
                      (+ (cadr start) (* uy (/ len 2.0)))))
      (setq head (* *gc-pile-arrow-head-k* len))
      (setq z (if (caddr start) (caddr start) 0.0))
      (entmake
        (list '(0 . "LWPOLYLINE")
              '(100 . "AcDbEntity")
              (cons 8 layer)
              '(100 . "AcDbPolyline")
              '(90 . 3)
              '(70 . 0)
              (cons 38 z)
              (cons 10 (list (car start) (cadr start))) (cons 40 0.0)  (cons 41 0.0)
              (cons 10 (list (car mid)   (cadr mid)))   (cons 40 head) (cons 41 0.0)
              (cons 10 (list (car end)   (cadr end)))   (cons 40 0.0)  (cons 41 0.0))))))

(defun gc-pile-draw-text-rot (pt text style layer rotation)
  (entmake (list '(0 . "TEXT")
                 (cons 8 layer)
                 (cons 7 style)
                 (cons 10 pt)
                 (cons 40 *gc-pile-text-h*)
                 (cons 1 text)
                 (cons 50 rotation)
                 (cons 72 1)
                 (cons 11 pt)
                 (cons 73 2))))

(defun gc-pile-mm-rounded (mm)
  (rtos (abs mm) 2 0))

(defun gc-pile-mm-signed (mm)
  (strcat (if (>= mm 0) "+" "")
          (rtos mm 2 0) " мм"))

;; Точка вставки и поворот подписи у стрелки — правило из ol.lsp:
;; середина стрелки плюс смещение на высоту текста по перпендикуляру,
;; поворот вдоль стрелки с нормализацией, чтобы цифра не встала вверх ногами.
;;
;; ПОЧЕМУ это лучше прежнего: раньше сторона подписи считалась от знаков
;; отклонения (sx, sy) и потому зависела от квадранта — цифра прыгала то над
;; стрелкой, то под ней. Теперь смещение берётся от НОРМАЛИЗОВАННОГО
;; направления, и сторона получается постоянной: у горизонтальной стрелки
;; цифра всегда сверху, у вертикальной — всегда слева, куда бы стрелка
;; ни смотрела. Ровно как в OL.
;;
;; Возвращает (точка угол) либо nil, если стрелка нулевой длины.
;; Длина стрелки выводится из высоты текста — те же пропорции, что в ol.lsp.
(defun gc-pile-arrow-len ( / )
  (* *gc-pile-arrow-k* *gc-pile-text-h*))

(defun gc-pile-text-at-arrow (start end / dx dy len ux uy mid ang td nx ny)
  (setq dx  (- (car  end) (car  start))
        dy  (- (cadr end) (cadr start))
        len (sqrt (+ (* dx dx) (* dy dy))))
  (if (< len 1.0e-9)
    nil
    (progn
      (setq ux (/ dx len)
            uy (/ dy len))
      (setq mid (list (+ (car  start) (* ux (/ len 2.0)))
                      (+ (cadr start) (* uy (/ len 2.0)))))
      (setq ang (atan uy ux))
      (if (or (> ang (/ pi 2.0)) (<= ang (- (/ pi 2.0))))
        (setq ang (+ ang pi)))
      (setq td (list (cos ang) (sin ang)))
      (setq nx (- (cadr td))
            ny (car  td))
      (list (list (+ (car  mid) (* nx *gc-pile-text-h*))
                  (+ (cadr mid) (* ny *gc-pile-text-h*))
                  (caddr start))
            ang))))

(defun gc-pile-draw-xy-deviation (base-pt dir-dx-mm dir-dy-mm label-x-mm label-y-mm
                                  arrow-layer text-layer color /
                                  tstyle sx sy p-end-x p-end-y tx ty)
  (gc-pile-ensure-layer arrow-layer color)
  (gc-pile-ensure-layer text-layer color)
  (setq tstyle (gc-pile-text-style))
  (setq sx (if (>= dir-dx-mm 0) 1.0 -1.0))
  (setq sy (if (>= dir-dy-mm 0) 1.0 -1.0))
  (setq p-end-x (list (+ (car base-pt) (* (gc-pile-arrow-len) sx))
                      (cadr base-pt)
                      (caddr base-pt)))
  (setq p-end-y (list (car base-pt)
                      (+ (cadr base-pt) (* (gc-pile-arrow-len) sy))
                      (caddr base-pt)))
  (gc-pile-draw-arrow base-pt p-end-x arrow-layer)
  (gc-pile-draw-arrow base-pt p-end-y arrow-layer)
  ;; Подписи размещаются по правилу ol.lsp (см. gc-pile-text-at-arrow).
  (setq tx (gc-pile-text-at-arrow base-pt p-end-x))
  (setq ty (gc-pile-text-at-arrow base-pt p-end-y))
  (if tx (gc-pile-draw-text-rot (car tx) (gc-pile-mm-rounded label-x-mm)
                                tstyle text-layer (cadr tx)))
  (if ty (gc-pile-draw-text-rot (car ty) (gc-pile-mm-rounded label-y-mm)
                                tstyle text-layer (cadr ty)))
  T)

(defun gc-pile-draw-project-deviation (project-pt target-pt / dx-mm dy-mm p-base)
  (setq p-base (list (car project-pt) (cadr project-pt) (caddr target-pt)))
  (setq dx-mm (* 1000.0 (- (car target-pt)  (car project-pt)))
        dy-mm (* 1000.0 (- (cadr target-pt) (cadr project-pt))))
  (gc-pile-draw-xy-deviation p-base dx-mm dy-mm dx-mm dy-mm
                             *gc-l-project-arrows* *gc-l-project-text* 2)
  (princ (strcat "\nПроектное отклонение: dX = " (gc-pile-mm-signed dx-mm)
                 "   dY = " (gc-pile-mm-signed dy-mm)))
  T)

(defun gc-pile-draw-project-deviation-sv3 (project-pt target-pt / dx-mm dy-mm p-base)
  (setq p-base (list (car project-pt)
                     (+ (cadr project-pt) *gc-pile-sv3-prj-dev-dy*)
                     (caddr target-pt)))
  (setq dx-mm (* 1000.0 (- (car target-pt)  (car project-pt)))
        dy-mm (* 1000.0 (- (cadr target-pt) (cadr project-pt))))
  (gc-pile-draw-xy-deviation p-base dx-mm dy-mm dx-mm dy-mm
                             *gc-l-sv3-project-arrows*
                             *gc-l-sv3-project-text*
                             7)
  (princ (strcat "\nSV 3: проектное отклонение со сдвигом +Y 2600 мм: dX = "
                 (gc-pile-mm-signed dx-mm)
                 "   dY = " (gc-pile-mm-signed dy-mm)))
  T)

;;; ====================================================================
;;; ОБРАБОТКА СЕЧЕНИЙ
;;; ====================================================================

(defun gc-pile-section-data (low-pts high-pts tag / c-low c-high z-low z-high)
  (setq c-low  (gc-pile-best-circle low-pts))
  (setq c-high (gc-pile-best-circle high-pts))
  (cond
    ((null c-low)
     (princ (strcat "\n[ОШИБКА] " tag ": не удалось построить круг по нижним точкам."))
     nil)
    ((null c-high)
     (princ (strcat "\n[ОШИБКА] " tag ": не удалось построить круг по верхним точкам."))
     nil)
    (T
     (setq z-low  (gc-pile-avg (mapcar 'caddr low-pts))
           z-high (gc-pile-avg (mapcar 'caddr high-pts)))
     (list c-low c-high z-low z-high))))

(defun gc-pile-draw-sv-graphics (data arrow-layer text-layer color y-offset label /
                                  c-low c-high z-low z-high dx-mm dy-mm dz dx-pm dy-pm
                                  base-pt dev-low dev-high)
  (setq c-low  (nth 0 data)
        c-high (nth 1 data)
        z-low  (nth 2 data)
        z-high (nth 3 data))
  (gc-pile-ensure-layer *gc-l-low* 1)
  (gc-pile-ensure-layer *gc-l-high* 3)
  (gc-pile-draw-circle (car c-low)  (cadr c-low)  z-low  (caddr c-low)  *gc-l-low*)
  (gc-pile-draw-circle (car c-high) (cadr c-high) z-high (caddr c-high) *gc-l-high*)
  (setq dx-mm (* 1000.0 (- (car c-high)  (car c-low)))
        dy-mm (* 1000.0 (- (cadr c-high) (cadr c-low)))
        dz    (- z-high z-low))
  (if (> (abs dz) 1.0e-6)
    (setq dx-pm (/ dx-mm dz)
          dy-pm (/ dy-mm dz))
    (setq dx-pm dx-mm
          dy-pm dy-mm))
  (setq base-pt (list (car c-low) (+ (cadr c-low) y-offset) z-low))
  (gc-pile-draw-xy-deviation base-pt dx-mm dy-mm dx-pm dy-pm
                             arrow-layer text-layer color)
  (setq dev-low  (* 1000.0 (- (caddr c-low)  *gc-pile-r-norm*)))
  (setq dev-high (* 1000.0 (- (caddr c-high) *gc-pile-r-norm*)))
  (princ (strcat "\n--- " label ": свая обработана ---"))
  (princ (strcat "\nНиз:  ("
                 (rtos (car c-low) 2 3) ", "
                 (rtos (cadr c-low) 2 3) ", "
                 (rtos z-low 2 3) ")  R = "
                 (rtos (caddr c-low) 2 3)
                 " м (отклонение от нормы "
                 (gc-pile-mm-signed dev-low) ")"))
  (princ (strcat "\nВерх: ("
                 (rtos (car c-high) 2 3) ", "
                 (rtos (cadr c-high) 2 3) ", "
                 (rtos z-high 2 3) ")  R = "
                 (rtos (caddr c-high) 2 3)
                 " м (отклонение от нормы "
                 (gc-pile-mm-signed dev-high) ")"))
  (princ (strcat "\ndX = " (gc-pile-mm-signed dx-mm)
                 " (" (rtos (abs dx-pm) 2 0) " мм/1м)"
                 "   dY = " (gc-pile-mm-signed dy-mm)
                 " (" (rtos (abs dy-pm) 2 0) " мм/1м)"))
  (princ (strcat "\ndZ между сечениями = " (rtos dz 2 3) " м"))
  (if (> (abs y-offset) 1.0e-9)
    (princ (strcat "\n[i] Графика отклонений смещена по +Y на "
                   (rtos (* y-offset 1000.0) 2 0) " мм.")))
  (if (or (> (caddr c-low)  (+ *gc-pile-r-norm* *gc-pile-r-warn*))
          (< (caddr c-low)  (- *gc-pile-r-norm* *gc-pile-r-warn*))
          (> (caddr c-high) (+ *gc-pile-r-norm* *gc-pile-r-warn*))
          (< (caddr c-high) (- *gc-pile-r-norm* *gc-pile-r-warn*)))
    (princ "\n[!] Радиус сильно отличается от нормы — проверьте съёмку."))
  (if (or (> (abs dx-pm) *gc-pile-tol-mm-per-m*)
          (> (abs dy-pm) *gc-pile-tol-mm-per-m*))
    (princ (strcat "\n[!] Превышен допуск "
                   (rtos *gc-pile-tol-mm-per-m* 2 0) " мм/1м!")))
  (princ "\n----------------------")
  T)

(defun gc-pile-draw-target-cut (data target-z / c-low c-high z-low z-high dz k target-x target-y target-pt)
  (setq c-low  (nth 0 data)
        c-high (nth 1 data)
        z-low  (nth 2 data)
        z-high (nth 3 data)
        dz     (- z-high z-low))
  (if (<= (abs dz) 1.0e-6)
    (progn
      (princ "\n[ОШИБКА] SVP: dZ между сечениями слишком мал для расчета.")
      nil)
    (progn
      (setq k (/ (- target-z z-low) dz))
      (setq target-x (+ (car c-low) (* k (- (car c-high) (car c-low)))))
      (setq target-y (+ (cadr c-low) (* k (- (cadr c-high) (cadr c-low)))))
      (setq target-pt (list target-x target-y target-z))
      (gc-pile-ensure-layer *gc-l-cut* 4)
      (gc-pile-draw-circle target-x target-y target-z *gc-pile-r-norm* *gc-l-cut*)
      (princ "\n--- SVP: сечение построено ---")
      (princ (strcat "\nZ среза: " (rtos target-z 2 3) " м"
                     "  |  Центр: ("
                     (rtos target-x 2 3) ", "
                     (rtos target-y 2 3) ", "
                     (rtos target-z 2 3) ")"
                     "  |  R = " (rtos *gc-pile-r-norm* 2 3) " м"))
      (princ (strcat "\nОпорные Z: низ=" (rtos z-low 2 3)
                     " м, верх=" (rtos z-high 2 3)
                     " м, k=" (rtos k 2 3)))
      target-pt)))

(defun gc-pile-process (low-pts high-pts / data)
  (setq data (gc-pile-section-data low-pts high-pts "SV"))
  (if data
    (gc-pile-draw-sv-graphics data *gc-l-arrows* *gc-l-text* 7 0.0 "SV")
    nil))

(defun gc-pile-process-extension (low-pts high-pts target-z / data)
  (setq data (gc-pile-section-data low-pts high-pts "SVP"))
  (if data
    (gc-pile-draw-target-cut data target-z)
    nil))

(defun gc-pile-process-sv3 (low-pts high-pts target-z / data target-pt)
  (setq data (gc-pile-section-data low-pts high-pts "SV 3"))
  (if data
    (progn
      (gc-pile-draw-sv-graphics data
                                *gc-l-sv3-arrows*
                                *gc-l-sv3-text*
                                5
                                *gc-pile-sv3-sv-dev-dy*
                                "SV 3 / SV")
      (setq target-pt (gc-pile-draw-target-cut data target-z))
      target-pt)
    nil))

;;; ====================================================================
;;; ПОДГОТОВКА ПАР СЕЧЕНИЙ
;;; ====================================================================

(defun gc-pile-pair-from-cluster (pile-pts / z-groups valid-secs zg clean-zg
                                   circ z-mean sorted-secs lo hi dz z-list)
  (cond
    ((< (length pile-pts) 6) nil)
    (T
     (setq z-groups (gc-pile-cluster-by-z pile-pts))
     (setq valid-secs '())
     (foreach zg z-groups
       (setq clean-zg (gc-pile-strip-hm zg))
       (if (>= (length clean-zg) 3)
         (progn
           (setq circ (gc-pile-best-circle clean-zg))
           (if circ
             (progn
               (setq z-mean (gc-pile-avg (mapcar 'caddr clean-zg)))
               (setq valid-secs (cons (cons z-mean clean-zg) valid-secs)))))))
     (cond
       ((< (length valid-secs) 2)
        (setq z-list (apply 'strcat
                       (mapcar '(lambda (p) (strcat (rtos (caddr p) 2 3) " "))
                               pile-pts)))
        (princ (strcat "\n[!] Свая X~" (rtos (caar pile-pts) 2 1)
                       " Y~" (rtos (cadar pile-pts) 2 1)
                       ": сечений найдено " (itoa (length valid-secs))
                       " (нужно >=2) — пропуск."
                       "\n    Z всех точек: " z-list))
        nil)
       (T
        (setq sorted-secs
              (vl-sort valid-secs '(lambda (a b) (< (car a) (car b)))))
        (setq lo (car sorted-secs)
              hi (last sorted-secs))
        (setq dz (- (car hi) (car lo)))
        (cond
          ((< dz *gc-pile-pair-dz-min*)
           (princ (strcat "\n[!] Свая X~" (rtos (caar pile-pts) 2 1)
                          ": dZ=" (rtos dz 2 3) " м < "
                          (rtos *gc-pile-pair-dz-min* 2 2) " м — пропуск."))
           nil)
          (T (cons (cdr lo) (cdr hi)))))))))

(defun gc-pile-mode1 ( / ss pts n xy-clusters pairs pile-pts pair)
  (princ "\nВыделите точки свай (рамкой). Не-точки игнорируются: ")
  (setq ss (ssget *gc-pile-ssget-filter*))
  (cond
    ((null ss)
     (princ "\n[ОШИБКА] Точки не выбраны.")
     nil)
    (T
     (setq pts (gc-pile-ss-to-points ss))
     (setq n (length pts))
     (cond
       ((< n 6)
        (princ (strcat "\n[ОШИБКА] Нужно минимум 6 точек (2 сечения x 3). Найдено: "
                       (itoa n)))
        nil)
       (T
        (princ (strcat "\n[i] Точек выбрано: " (itoa n)
                       "  |  Диаметр сваи: "
                       (rtos (* 2.0 *gc-pile-r-norm* 1000.0) 2 0) " мм"
                       "  |  Z: "
                       (rtos (apply 'min (mapcar 'caddr pts)) 2 3)
                       " — "
                       (rtos (apply 'max (mapcar 'caddr pts)) 2 3) " м"))
        (setq xy-clusters (gc-pile-cluster-by-xy pts))
        (princ (strcat "\n[i] Выявлено XY-кластеров (свай): "
                       (itoa (length xy-clusters))))
        (setq pairs '())
        (foreach pile-pts xy-clusters
          (setq pair (gc-pile-pair-from-cluster pile-pts))
          (if pair (setq pairs (cons pair pairs))))
        (cond
          ((null pairs)
           (princ "\n[ОШИБКА] Ни одной сваи не удалось сформировать.")
           nil)
          (T
           (princ (strcat "\n[i] Свай для обработки: " (itoa (length pairs))))
           (reverse pairs))))))))

(defun gc-pile-mode2 ( / ss-low ss-high low-pts high-pts)
  (princ "\nВыделите точки нижнего сечения: ")
  (setq ss-low (ssget *gc-pile-ssget-filter*))
  (cond
    ((null ss-low)
     (princ "\n[ОШИБКА] Нижнее сечение не выбрано.")
     nil)
    (T
     (princ "\nВыделите точки верхнего сечения: ")
     (setq ss-high (ssget *gc-pile-ssget-filter*))
     (cond
       ((null ss-high)
        (princ "\n[ОШИБКА] Верхнее сечение не выбрано.")
        nil)
       (T
        (setq low-pts  (gc-pile-ss-to-points ss-low))
        (setq high-pts (gc-pile-ss-to-points ss-high))
        (cond
          ((< (length low-pts) 3)
           (princ "\n[ОШИБКА] В нижнем сечении меньше 3 валидных точек.")
           nil)
          ((< (length high-pts) 3)
           (princ "\n[ОШИБКА] В верхнем сечении меньше 3 валидных точек.")
           nil)
          (T (list low-pts high-pts))))))))

;;; ====================================================================
;;; ОБЩИЙ РАННЕР SVP / SV 3
;;; ====================================================================

(defun gc-pile-run-project-match (target-pt project-centers draw-mode /
                                  match project-pt match-dist)
  (setq match (gc-pile-take-nearest-project
                target-pt
                project-centers
                *gc-pile-project-match-max*))
  (setq project-pt (car match)
        project-centers (cadr match)
        match-dist (caddr match))
  (if project-pt
    (progn
      (princ (strcat "\n[i] Проектный центр: расстояние до среза "
                     (rtos match-dist 2 3) " м"))
      (if (= draw-mode "SV3")
        (gc-pile-draw-project-deviation-sv3 project-pt target-pt)
        (gc-pile-draw-project-deviation project-pt target-pt))
      (list project-centers 1 0))
    (progn
      (if match-dist
        (princ (strcat "\n[!] SVP: ближайший проектный центр дальше "
                       (rtos *gc-pile-project-match-max* 2 3)
                       " м (расстояние " (rtos match-dist 2 3)
                       " м) — проектное отклонение пропущено."))
        (princ "\n[!] SVP: проектный центр не найден — проектное отклонение пропущено."))
      (list project-centers 0 1))))

(defun gc-pile-run-svp-core (pairs target-z project-centers draw-mode / project-mode
                             total idx ok skipped dev-ok dev-skipped p target-pt res)
  (setq project-mode (not (null project-centers)))
  (setq total (length pairs) idx 1 ok 0 skipped 0 dev-ok 0 dev-skipped 0)
  (foreach p pairs
    (princ (strcat "\n=== " draw-mode ": Свая " (itoa idx) " / " (itoa total) " ==="))
    (setq target-pt
      (if (= draw-mode "SV3")
        (gc-pile-process-sv3 (car p) (cdr p) target-z)
        (gc-pile-process-extension (car p) (cdr p) target-z)))
    (if target-pt
      (progn
        (setq ok (1+ ok))
        (if project-mode
          (cond
            ((null project-centers)
             (setq dev-skipped (1+ dev-skipped))
             (princ "\n[!] Нет свободного проектного центра — проектное отклонение пропущено."))
            (T
             (setq res (gc-pile-run-project-match target-pt project-centers draw-mode))
             (setq project-centers (car res))
             (setq dev-ok (+ dev-ok (cadr res)))
             (setq dev-skipped (+ dev-skipped (caddr res)))))))
      (setq skipped (1+ skipped)))
    (setq idx (1+ idx)))
  (princ (strcat "\n[Итог " draw-mode "] построено сечений: " (itoa ok)
                 "  пропущено сечений: " (itoa skipped)
                 "  всего свай: " (itoa total)))
  (if project-mode
    (princ (strcat "\n[Итог " draw-mode "] проектных отклонений: " (itoa dev-ok)
                   "  пропущено отклонений: " (itoa dev-skipped)))
    (princ (strcat "\n[Итог " draw-mode "] проектные отклонения не строились: проектные объекты не выбраны.")))
  T)

(defun gc-pile-run-sv3 ( / pairs target-z project-centers)
  (princ "\nSV 3: SV 1 + SVP за один запуск.")
  (setq pairs (gc-pile-mode1))
  (cond
    ((null pairs)
     (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z для среза, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq project-centers (gc-pile-read-project-centers))
        (gc-pile-run-svp-core pairs target-z project-centers "SV3"))))))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

;;; ====================================================================
;;; ВЫСОТА ТЕКСТА — кнопка [Текст]
;;; ====================================================================

;; Обрезка пробелов по краям без vl-string-trim — чтобы не зависеть от того,
;; как конкретная сборка обрабатывает не-ASCII.
(defun gc-pile-trim (s / )
  (while (and (> (strlen s) 0) (= (substr s 1 1) " "))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) " "))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; Запятая и точка равнозначны, пробелы игнорируются.
;; ПОЧЕМУ свой парсер, а не getreal: getreal не принимает запятую, а Шамиль
;; вводит размеры именно через запятую.
(defun gc-pile-parse-size (s / n i ch bad seps digits norm val)
  (setq n (strlen s) i 1 bad nil seps 0 digits 0 norm "")
  (while (<= i n)
    (setq ch (substr s i 1))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
       (setq digits (1+ digits) norm (strcat norm ch)))
      ((or (= ch ",") (= ch "."))
       (setq seps (1+ seps) norm (strcat norm ".")))
      ((or (= ch " ") (= ch "\t")) nil)
      (T (setq bad T)))
    (setq i (1+ i)))
  (cond
    (bad          nil)
    ((= digits 0) nil)
    ((> seps 1)   nil)
    (T
     (setq val (atof norm))
     (if (> val 1.0e-9) val nil))))

(defun gc-pile-fmt (m)
  (vl-string-subst "," "." (rtos m 2 3)))

(defun gc-pile-set-text-h ( / res s val)
  (princ "\n\n--- ВЫСОТА ТЕКСТА ---")
  (princ "\nВысота цифры в метрах чертежа. От неё считается вся графика:")
  (princ "\n  длина стрелки = 2 x высота, наконечник = 0.4 x высота,")
  (princ "\n  смещение цифры от стрелки = 1 x высота.")
  (princ "\nЗначение общее для SV и SVP.")
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "0, 200"
    ;; молча превратилось бы в "0," = 0 м.
    (setq s (gc-pile-trim
              (getstring T (strcat "\nВысота текста, м <"
                                   (gc-pile-fmt *gc-pile-text-h*) ">: "))))
    (cond
      ((= s "") (setq res *gc-pile-text-h*))
      (T
       (setq val (gc-pile-parse-size s))
       (if val
         (setq res val)
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 0,200"))))))
  (setq *gc-pile-text-h* res)
  (princ (strcat "\n[i] Высота текста " (gc-pile-fmt *gc-pile-text-h*)
                 " м, длина стрелки " (gc-pile-fmt (gc-pile-arrow-len)) " м"))
  *gc-pile-text-h*)

(defun c:sv ( / mode-str pairs g idx total ok skipped p)
  (princ "\n  1 = все точки сразу (автоопределение свай)")
  (princ "\n  2 = по группам вручную (нижнее/верхнее сечение)")
  (princ "\n  3 = все сразу: SV 1 + SVP")
  ;; Ключевое слово продублировано одной буквой: для кириллицы AutoCAD
  ;; не распознаёт заглавную букву как сокращение и требует слово целиком.
  ;; Цикл — чтобы после смены высоты снова спросить режим.
  (setq mode-str nil)
  (while (null mode-str)
    (princ (strcat "\n  Высота текста: " (gc-pile-fmt *gc-pile-text-h*)
                   " м  |  длина стрелки: " (gc-pile-fmt (gc-pile-arrow-len)) " м"))
    (initget "1 2 3 Текст Т")
    (setq mode-str (getkword "\nРежим [1/2/3/Текст] <1>: "))
    (if (null mode-str) (setq mode-str "1"))
    (if (member mode-str '("Текст" "Т"))
      (progn (gc-pile-set-text-h) (setq mode-str nil))))
  (princ (strcat "\nРежим: " mode-str))
  (cond
    ((= mode-str "3")
     (gc-pile-run-sv3))
    (T
     (cond
       ((= mode-str "1")
        (setq pairs (gc-pile-mode1)))
       (T
        (setq g (gc-pile-mode2))
        (if g
          (setq pairs (list (cons (car g) (cadr g))))
          (setq pairs nil))))
     (cond
       ((null pairs)
        (princ "\nКоманда отменена."))
       (T
        (setq total (length pairs) idx 1 ok 0 skipped 0)
        (foreach p pairs
          (princ (strcat "\n=== Свая " (itoa idx) " / " (itoa total) " ==="))
          (if (gc-pile-process (car p) (cdr p))
            (setq ok (1+ ok))
            (setq skipped (1+ skipped)))
          (setq idx (1+ idx)))
        (princ (strcat "\n[Итог] обработано: " (itoa ok)
                       "  пропущено: " (itoa skipped)
                       "  всего: " (itoa total)))))))
  (princ))

(defun c:svp ( / pairs target-z project-centers)
  (princ "\nSVP: сечение сваи на заданной отметке + проектное отклонение.")
  (setq pairs (gc-pile-mode1))
  (cond
    ((null pairs)
     (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq project-centers (gc-pile-read-project-centers))
        (gc-pile-run-svp-core pairs target-z project-centers "SVP")))))
  (princ))

(princ "\n[gc] sv.lsp v21 загружен. Команды: SV, SVP")
(princ)
