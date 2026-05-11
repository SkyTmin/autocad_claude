;;; sv.lsp -- obrabotka svay (SPEC-001 / SPEC-002 / SPEC-003 v12)
;;; Komandy:
;;;   SV  -- dva secheniya svai i otkloneniya mezhdu centrami.
;;;   SVP -- sechenie svai na zadannoy vysotnoy otmetke.
;;;
;;; v12: dobavlena komanda SVP (SPEC-003): prodlenie/interpolyaciya svai
;;;      po dvum naydennym secheniyam. SV v11 ostavlen kak stabilnaya baza.
;;; v11: gc-pile-strip-hm udalyaet paru otmetchikov vysoty tolko esli ona
;;;      yavno izolirovana nad secheniem.
;;;
;;; Specifikacii: specs/001-pile-deviation.md,
;;;               specs/002-pile-multi-batch.md,
;;;               specs/003-pile-extension.md
;;; Zagruzka: APPLOAD ili (load "put/k/sv.lsp").
;;; Zavisimosti: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ
;;; ====================================================================

(setq *gc-pile-r-norm*           0.710) ; норма радиуса сваи, м (D1420мм / 2)
(setq *gc-pile-r-warn*           0.050) ; превышение |R-norm| -> предупреждение
(setq *gc-pile-arrow-len*        0.400) ; длина Leader, м
(setq *gc-pile-tol-mm-per-m*    20.0)   ; норматив 20 мм/1м
(setq *gc-pile-text-h*           0.100) ; высота текста, м
(setq *gc-pile-text-along*       0.200) ; смещение текста вдоль стрелки, м
(setq *gc-pile-text-lateral*     0.100) ; смещение текста поперек стрелки, м
(setq *gc-pile-z-cluster*        0.050) ; порог одной высоты по Z, м
(setq *gc-pile-xy-cluster*       1.800) ; порог XY-кластеризации свай, м
(setq *gc-pile-pair-dz-min*      0.300) ; минимальный dZ между сечениями, м
(setq *gc-pile-pair-dz-max*      5.000) ; максимальный dZ между сечениями, м
(setq *gc-pile-hm-pair-dz-max*   0.002) ; макс ΔZ внутри пары отметчиков, м
(setq *gc-pile-hm-gap-min*       0.010) ; мин зазор от отметчиков до сечения, м

(setq *gc-pile-ssget-filter*
      '((0 . "POINT,AECC*POINT,AEC*POINT")))

(setq *gc-l-low*    "GC-Сваи-Низ")
(setq *gc-l-high*   "GC-Сваи-Верх")
(setq *gc-l-arrows* "GC-Сваи-Отклонения")
(setq *gc-l-text*   "GC-Сваи-Текст")
(setq *gc-l-cut*    "GC-Сваи-Срез")

;;; ====================================================================
;;; ИЗВЛЕЧЕНИЕ КООРДИНАТ ИЗ ОБЪЕКТА
;;; ====================================================================

(defun gc-pile-get-coords (ent / obj)
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
    (princ (strcat "\n[!] Пропущено объектов неподдерживаемого типа: "
                   (itoa skipped))))
  (reverse pts))

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
      (setq top1 (car   sorted)
            top2 (cadr  sorted)
            top3 (caddr sorted)
            rest (cddr  sorted))
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
    ((tblsearch "STYLE" "GOSTB")    "GOSTB")
    ((tblsearch "STYLE" "ISOCPEUR") "ISOCPEUR")
    (T                              "Standard")))

(defun gc-pile-draw-circle (cx cy z r layer)
  (entmake (list '(0 . "CIRCLE")
                 (cons 8 layer)
                 (cons 10 (list cx cy z))
                 (cons 40 r))))

(defun gc-pile-draw-arrow (start end layer)
  (entmake (list '(0 . "LINE")
                 (cons 8 layer)
                 (cons 10 start)
                 (cons 11 end)))
  (gc-pile-draw-arrow-head start end layer))

(defun gc-pile-draw-arrow-head (start end layer / dx dy len ux uy nx ny size t1 t2)
  (setq dx (- (car  end) (car  start))
        dy (- (cadr end) (cadr start)))
  (setq len (sqrt (+ (* dx dx) (* dy dy))))
  (if (> len 1.0e-9)
    (progn
      (setq ux (/ dx len) uy (/ dy len))
      (setq nx (- uy) ny ux)
      (setq size (* 0.30 len))
      (setq t1 (list (- (car  end) (* size ux) (* (/ size 3.0) nx))
                     (- (cadr end) (* size uy) (* (/ size 3.0) ny))
                     (caddr end)))
      (setq t2 (list (+ (- (car  end) (* size ux)) (* (/ size 3.0) nx))
                     (+ (- (cadr end) (* size uy)) (* (/ size 3.0) ny))
                     (caddr end)))
      (entmake (list '(0 . "SOLID")
                     (cons 8 layer)
                     (cons 10 t1)
                     (cons 11 t2)
                     (cons 12 end)
                     (cons 13 end))))))

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

(defun gc-pile-mm-rounded (per-m-mm)
  (rtos (abs per-m-mm) 2 0))

(defun gc-pile-mm-signed (mm)
  (strcat (if (>= mm 0) "+" "")
          (rtos mm 2 0) " мм"))

;;; ====================================================================
;;; ОБРАБОТКА SV
;;; ====================================================================

(defun gc-pile-process (low-pts high-pts /
                         c-low c-high z-low z-high
                         dx-mm dy-mm dz dx-pm dy-pm
                         tstyle p-low p-end-x p-end-y
                         pt-text-x pt-text-y sx sy
                         dev-low dev-high)
  (setq c-low  (gc-pile-best-circle low-pts))
  (setq c-high (gc-pile-best-circle high-pts))
  (cond
    ((null c-low)
     (princ "\n[ОШИБКА] Не удалось построить круг по нижним точкам.")
     nil)
    ((null c-high)
     (princ "\n[ОШИБКА] Не удалось построить круг по верхним точкам.")
     nil)
    (T
     (setq z-low  (gc-pile-avg (mapcar 'caddr low-pts))
           z-high (gc-pile-avg (mapcar 'caddr high-pts)))
     (gc-pile-ensure-layer *gc-l-low*    1)
     (gc-pile-ensure-layer *gc-l-high*   3)
     (gc-pile-ensure-layer *gc-l-arrows* 7)
     (gc-pile-ensure-layer *gc-l-text*   7)
     (setq tstyle (gc-pile-text-style))
     (gc-pile-draw-circle (car c-low)  (cadr c-low)  z-low  (caddr c-low)  *gc-l-low*)
     (gc-pile-draw-circle (car c-high) (cadr c-high) z-high (caddr c-high) *gc-l-high*)
     (setq dx-mm (* 1000.0 (- (car  c-high) (car  c-low)))
           dy-mm (* 1000.0 (- (cadr c-high) (cadr c-low)))
           dz    (- z-high z-low))
     (if (> (abs dz) 1.0e-6)
       (setq dx-pm (/ dx-mm dz)
             dy-pm (/ dy-mm dz))
       (setq dx-pm dx-mm dy-pm dy-mm))
     (setq p-low (list (car c-low) (cadr c-low) z-low))
     (setq p-end-x (list (+ (car  p-low)
                            (* *gc-pile-arrow-len*
                               (if (>= dx-mm 0) 1.0 -1.0)))
                         (cadr p-low)
                         z-low))
     (setq p-end-y (list (car p-low)
                         (+ (cadr p-low)
                            (* *gc-pile-arrow-len*
                               (if (>= dy-mm 0) 1.0 -1.0)))
                         z-low))
     (gc-pile-draw-arrow p-low p-end-x *gc-l-arrows*)
     (gc-pile-draw-arrow p-low p-end-y *gc-l-arrows*)
     (setq sx (if (>= dx-mm 0) 1.0 -1.0))
     (setq sy (if (>= dy-mm 0) 1.0 -1.0))
     (setq pt-text-y
       (list (+ (car  p-low) (* (- sx) *gc-pile-text-lateral*))
             (+ (cadr p-low) (* sy     *gc-pile-text-along*))
             z-low))
     (setq pt-text-x
       (list (+ (car  p-low) (* sx *gc-pile-text-along*))
             (- (cadr p-low) (* sy *gc-pile-text-lateral*))
             z-low))
     (gc-pile-draw-text-rot pt-text-x (gc-pile-mm-rounded dx-pm)
                            tstyle *gc-l-text* 0.0)
     (gc-pile-draw-text-rot pt-text-y (gc-pile-mm-rounded dy-pm)
                            tstyle *gc-l-text* (/ pi 2.0))
     (setq dev-low  (* 1000.0 (- (caddr c-low)  *gc-pile-r-norm*)))
     (setq dev-high (* 1000.0 (- (caddr c-high) *gc-pile-r-norm*)))
     (princ "\n--- Свая обработана ---")
     (princ (strcat "\nНиз:  ("
                    (rtos (car  c-low)  2 3) ", "
                    (rtos (cadr c-low)  2 3) ", "
                    (rtos z-low         2 3) ")  R = "
                    (rtos (caddr c-low) 2 3) " м (отклонение от нормы "
                    (gc-pile-mm-signed dev-low) ")"))
     (princ (strcat "\nВерх: ("
                    (rtos (car  c-high)  2 3) ", "
                    (rtos (cadr c-high)  2 3) ", "
                    (rtos z-high         2 3) ")  R = "
                    (rtos (caddr c-high) 2 3) " м (отклонение от нормы "
                    (gc-pile-mm-signed dev-high) ")"))
     (princ (strcat "\ndX = " (gc-pile-mm-signed dx-mm)
                    " (" (rtos (abs dx-pm) 2 0) " мм/1м)"
                    "   dY = " (gc-pile-mm-signed dy-mm)
                    " (" (rtos (abs dy-pm) 2 0) " мм/1м)"))
     (princ (strcat "\ndZ между сечениями = " (rtos dz 2 3) " м"))
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
     T)))

;;; ====================================================================
;;; ОБРАБОТКА SVP
;;; ====================================================================

(defun gc-pile-process-extension (low-pts high-pts target-z /
                                   c-low c-high z-low z-high dz k
                                   target-x target-y)
  (setq c-low  (gc-pile-best-circle low-pts))
  (setq c-high (gc-pile-best-circle high-pts))
  (cond
    ((null c-low)
     (princ "\n[ОШИБКА] SVP: не удалось построить круг по нижним точкам.")
     nil)
    ((null c-high)
     (princ "\n[ОШИБКА] SVP: не удалось построить круг по верхним точкам.")
     nil)
    (T
     (setq z-low  (gc-pile-avg (mapcar 'caddr low-pts))
           z-high (gc-pile-avg (mapcar 'caddr high-pts))
           dz     (- z-high z-low))
     (if (<= (abs dz) 1.0e-6)
       (progn
         (princ "\n[ОШИБКА] SVP: dZ между сечениями слишком мал для расчета.")
         nil)
       (progn
         (setq k (/ (- target-z z-low) dz))
         (setq target-x (+ (car c-low) (* k (- (car c-high) (car c-low)))))
         (setq target-y (+ (cadr c-low) (* k (- (cadr c-high) (cadr c-low)))))
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
         T)))))

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
                       " (нужно ≥2) — пропуск."
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
          ((> dz *gc-pile-pair-dz-max*)
           (princ (strcat "\n[!] Свая X~" (rtos (caar pile-pts) 2 1)
                          ": dZ=" (rtos dz 2 3) " м > "
                          (rtos *gc-pile-pair-dz-max* 2 2) " м — пропуск."))
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
        (princ (strcat "\n[ОШИБКА] Нужно минимум 6 точек (2 сечения × 3). Найдено: "
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
    ((null ss-low) (princ "\n[ОШИБКА] Нижнее сечение не выбрано.") nil)
    (T
     (princ "\nВыделите точки верхнего сечения: ")
     (setq ss-high (ssget *gc-pile-ssget-filter*))
     (cond
       ((null ss-high) (princ "\n[ОШИБКА] Верхнее сечение не выбрано.") nil)
       (T
        (setq low-pts  (gc-pile-ss-to-points ss-low))
        (setq high-pts (gc-pile-ss-to-points ss-high))
        (cond
          ((< (length low-pts) 3)
           (princ "\n[ОШИБКА] В нижнем сечении меньше 3 валидных точек.") nil)
          ((< (length high-pts) 3)
           (princ "\n[ОШИБКА] В верхнем сечении меньше 3 валидных точек.") nil)
          (T (list low-pts high-pts))))))))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

(defun c:sv ( / mode-str pairs g idx total ok skipped p)
  (princ "\n  1 = все точки сразу (автоопределение свай)")
  (princ "\n  2 = по группам вручную (нижнее/верхнее сечение)")
  (initget "1 2")
  (setq mode-str (getkword "\nРежим [1/2] <1>: "))
  (if (null mode-str) (setq mode-str "1"))
  (princ (strcat "\nРежим: " mode-str))
  (cond
    ((= mode-str "1")
     (setq pairs (gc-pile-mode1)))
    (T
     (setq g (gc-pile-mode2))
     (if g (setq pairs (list (cons (car g) (cadr g)))) (setq pairs nil))))
  (cond
    ((null pairs) (princ "\nКоманда отменена."))
    (T
     (setq total (length pairs) idx 1 ok 0 skipped 0)
     (foreach p pairs
       (princ (strcat "\n=== Свая " (itoa idx) " / " (itoa total) " ==="))
       (if (gc-pile-process (car p) (cdr p))
         (setq ok (1+ ok))
         (setq skipped (1+ skipped)))
       (setq idx (1+ idx)))
     (princ (strcat "\n[Итог] обработано: " (itoa ok)
                    "  пропущено: "          (itoa skipped)
                    "  всего: "              (itoa total)))))
  (princ))

(defun c:svp ( / pairs target-z idx total ok skipped p)
  (princ "\nSVP: сечение сваи на заданной высотной отметке.")
  (setq pairs (gc-pile-mode1))
  (cond
    ((null pairs) (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq total (length pairs) idx 1 ok 0 skipped 0)
        (foreach p pairs
          (princ (strcat "\n=== SVP: Свая " (itoa idx) " / " (itoa total) " ==="))
          (if (gc-pile-process-extension (car p) (cdr p) target-z)
            (setq ok (1+ ok))
            (setq skipped (1+ skipped)))
          (setq idx (1+ idx)))
        (princ (strcat "\n[Итог SVP] построено: " (itoa ok)
                       "  пропущено: "        (itoa skipped)
                       "  всего: "            (itoa total)))))))
  (princ))

(princ "\n[gc] sv.lsp v12 загружен. Команды: SV, SVP")
(princ)
