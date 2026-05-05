;;; sv.lsp — обработка свай (SPEC-001)
;;; Команда SV: по 7-13 точкам тахеометра — два круга (низ/верх сечения)
;;; и стрелки отклонений между центрами с целочисленными подписями (мм/1м).
;;;
;;; Спецификация: specs/001-pile-deviation.md
;;; Загрузка: APPLOAD или (load "путь/к/sv.lsp").
;;; Зависимости: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ — Шамиль может править эти значения вручную в начале файла
;;; ====================================================================

(setq *gc-pile-r-norm*           0.710) ; норма радиуса сваи, м (Ø1420мм / 2)
(setq *gc-pile-r-warn*           0.050) ; превышение |R−norm| → предупреждение
(setq *gc-pile-arrow-len*        0.400) ; длина Leader, м
(setq *gc-pile-tol-mm-per-m*    20.0)   ; норматив 20 мм/1м
(setq *gc-pile-text-h*           0.100) ; высота текста, м
(setq *gc-pile-text-margin*      0.050) ; отступ текста от стрелки, м (legacy)
(setq *gc-pile-text-offset*      0.400) ; SPEC-002 v2: смещение текста в квадрант, м
(setq *gc-pile-z-cluster*        0.050) ; порог "одной высоты" по Z, м
(setq *gc-pile-fit-tol*          0.050) ; SPEC-002 v2: допуск |R-norm| при поиске свай, м
(setq *gc-pile-fit-radius-eps*   0.050) ; SPEC-002 v2: запас сверх R при сборе точек сваи, м
(setq *gc-pile-pair-tolerance*   0.500) ; допуск сопоставления низ↔верх (XY), м

;; Фильтр для ssget: только точки и COGO Points. Wildcards разрешены.
;; Если в выборку попадут другие объекты — они игнорируются на уровне ssget.
(setq *gc-pile-ssget-filter*
      '((0 . "POINT,AECC*POINT,AEC*POINT")))

(setq *gc-l-low*    "GC-Сваи-Низ")
(setq *gc-l-high*   "GC-Сваи-Верх")
(setq *gc-l-arrows* "GC-Сваи-Отклонения")
(setq *gc-l-text*   "GC-Сваи-Текст")

;;; ====================================================================
;;; ИЗВЛЕЧЕНИЕ КООРДИНАТ ИЗ ОБЪЕКТА
;;; ====================================================================

;; ПОЧЕМУ через VL-свойства, а не DXF: COGO Point Civil 3D имеет
;; нестандартный DXF-тип, но через ActiveX доступен Easting/Northing/Elevation
;; единообразно. Fallback на Coordinates/InsertionPoint покрывает Point/Insert.
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

;; Окружность по 3 точкам в плане XY. Возвращает (cx cy r) или nil
;; при коллинеарности. Z игнорируется (плановое положение).
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

;;; ====================================================================
;;; ВЫБОР ЛУЧШЕЙ ОКРУЖНОСТИ — min |R - norm| по тройкам C(N,3)
;;; ====================================================================

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

;;; ====================================================================
;;; КЛАСТЕРИЗАЦИЯ ПО Z — ПЛОТНЫЕ ГРУППЫ + ОТБОР 2 САМЫХ БОЛЬШИХ
;;; ====================================================================

;; ПОЧЕМУ так: алгоритм должен быть устойчив к "лишним" точкам
;; (посторонним маркерам, точкам соседних свай, единичным выбросам).
;; Шамиль явно сформулировал: «минимум 3 точки одной высоты».
;;
;; Алгоритм:
;;   1. Кластеризуем по фиксированному порогу 50 мм между соседями по Z
;;      («одна высота» = разброс ≤ 50 мм, как при реальной съёмке).
;;   2. Отфильтровываем группы с числом точек < 3 (не сечение).
;;   3. Берём 2 самые многочисленные.
;;   4. Из них: меньший средний Z = нижнее сечение, больший = верхнее.
(defun gc-pile-cluster-z (points / sorted groups two)
  (setq sorted (vl-sort points '(lambda (a b) (< (caddr a) (caddr b)))))
  (cond
    ((< (length sorted) 6) nil)
    (T
     (setq groups (gc-pile-cluster-by-gap sorted *gc-pile-z-cluster*))
     (setq groups (vl-remove-if '(lambda (g) (< (length g) 3)) groups))
     (setq groups (vl-sort groups '(lambda (a b) (> (length a) (length b)))))
     (cond
       ((< (length groups) 2)
        (princ "\n[ОШИБКА] Не найдено двух групп ≥3 точек на одной высоте.")
        (princ "\n        Проверь: выделены ли реально точки, разнесены ли")
        (princ "\n        нижнее и верхнее сечения по Z более чем на 50 мм.")
        nil)
       (T
        (setq two (list (car groups) (cadr groups)))
        ;; Сортировка по среднему Z: нижнее, потом верхнее
        (vl-sort two
                 '(lambda (a b)
                    (< (gc-pile-avg (mapcar 'caddr a))
                       (gc-pile-avg (mapcar 'caddr b))))))))))

;; Простая кластеризация: соседние точки по Z в одну группу,
;; разрыв > gap → новая группа. sorted уже отсортирован по Z по возрастанию.
(defun gc-pile-cluster-by-gap (sorted gap / groups current prev)
  (setq groups '() current '() prev nil)
  (foreach pt sorted
    (cond
      ((null prev)
       (setq current (list pt) prev pt))
      ((> (- (caddr pt) (caddr prev)) gap)
       (setq groups (cons (reverse current) groups))
       (setq current (list pt))
       (setq prev pt))
      (T
       (setq current (cons pt current))
       (setq prev pt))))
  (if current (setq groups (cons (reverse current) groups)))
  (reverse groups))

;;; ====================================================================
;;; SPEC-002 v2: ПОИСК СВАЙ ЧЕРЕЗ ОКРУЖНОСТЬ (вместо XY-кластеризации)
;;; ====================================================================

;; ПОЧЕМУ так: при расстоянии между сваями 1.5–2.5 м точки разных свай в плане
;; могут быть ближе (~0.1–0.5 м) друг к другу, чем точки одной сваи на крайних
;; концах дуги (до 1.4 м). Поэтому single-linkage кластеризация СКЛЕИВАЕТ
;; соседние сваи. v2 решает это иначе: жадно ищем тройки, дающие окружность с
;; R≈710 мм, и забираем из массива все точки в радиусе R+ε от её центра.
;; Это привязка к КОНКРЕТНОМУ центру каждой сваи, не к расстояниям между точками.

;; Расстояние между точками в плане (XY).
(defun gc-pile-dist-xy (p1 p2 / dx dy)
  (setq dx (- (car p1) (car p2))
        dy (- (cadr p1) (cadr p2)))
  (sqrt (+ (* dx dx) (* dy dy))))

;; Среднее XY-центроида списка точек: возвращает (cx cy).
(defun gc-pile-centroid-xy (pts)
  (list (gc-pile-avg (mapcar 'car  pts))
        (gc-pile-avg (mapcar 'cadr pts))))

;; Поиск ОДНОЙ сваи в массиве точек: перебор C(N,3) троек, выбор окружности
;; с минимальным |R - 710| при условии что отклонение ≤ *gc-pile-fit-tol*.
;; После находки — собирает ВСЕ точки в радиусе R+ε от центра как точки
;; этой сваи. Возвращает (list circle pile-points) или nil.
(defun gc-pile-find-one-pile (pts / triples best best-err circ err
                                      cx cy r pile-pts limit)
  (cond
    ((< (length pts) 3) nil)
    (T
     (setq triples (gc-pile-combos3 pts))
     (setq best nil best-err 1.0e99)
     (foreach tr triples
       (setq circ (gc-pile-circle-3 (car tr) (cadr tr) (caddr tr)))
       (if circ
         (progn
           (setq err (abs (- (caddr circ) *gc-pile-r-norm*)))
           (if (and (<= err *gc-pile-fit-tol*) (< err best-err))
             (setq best-err err best circ)))))
     (cond
       ((null best) nil)
       (T
        (setq cx (car best) cy (cadr best) r (caddr best))
        (setq limit (+ r *gc-pile-fit-radius-eps*))
        ;; Все точки в радиусе r+ε от центра найденной окружности — её точки
        (setq pile-pts (vl-remove-if-not
                         '(lambda (p) (<= (gc-pile-dist-xy p (list cx cy)) limit))
                         pts))
        (cond
          ((< (length pile-pts) 3) nil)
          (T (list best pile-pts))))))))

;; Жадно ищет ВСЕ сваи в массиве точек одной Z-группы.
;; Возвращает список пар (circle . points) для каждой найденной сваи.
(defun gc-pile-find-all-piles (points / remaining piles result)
  (setq remaining points piles '())
  (while (>= (length remaining) 3)
    (setq result (gc-pile-find-one-pile remaining))
    (cond
      ((null result)
       (setq remaining nil))   ; больше нет хороших троек, выход
      (T
       (setq piles (cons (cons (car result) (cadr result)) piles))
       ;; Удаляем найденные точки из remaining
       (foreach pt (cadr result)
         (setq remaining (vl-remove pt remaining))))))
  (reverse piles))

;; Сопоставление нижних и верхних свай по близости XY-центров окружностей.
;; lows, highs — списки '((circle . points) ...).
;; Возвращает: список cons-пар ((low-points . high-points) ...) для c:sv.
(defun gc-pile-pair-piles (lows highs tol / pairs used-high
                           low-c lc-xy best-h best-d hc d)
  (setq pairs '() used-high '())
  (foreach low lows
    (setq low-c (car low))
    (setq lc-xy (list (car low-c) (cadr low-c)))
    (setq best-h nil best-d 1.0e99)
    (foreach high highs
      (if (not (member high used-high))
        (progn
          (setq hc (car high))
          (setq d  (gc-pile-dist-xy lc-xy (list (car hc) (cadr hc))))
          (if (and (<= d tol) (< d best-d))
            (setq best-d d  best-h high)))))
    (cond
      (best-h
       (setq pairs (cons (cons (cdr low) (cdr best-h)) pairs))
       (setq used-high (cons best-h used-high)))))
  (reverse pairs))

;;; ====================================================================
;;; СЛОИ И СТИЛЬ ТЕКСТА
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

;; Fallback цепочка: GOSTB (СПДС) → ISOCPEUR → Standard.
(defun gc-pile-text-style ( / )
  (cond
    ((tblsearch "STYLE" "GOSTB")    "GOSTB")
    ((tblsearch "STYLE" "ISOCPEUR") "ISOCPEUR")
    (T                              "Standard")))

;;; ====================================================================
;;; ОТРИСОВКА
;;; ====================================================================

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
      (setq nx (- uy)     ny ux)
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

;; TEXT с Middle Center относительно pt и заданным углом поворота (рад).
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

;;; ====================================================================
;;; ФОРМАТИРОВАНИЕ ПОДПИСИ
;;; ====================================================================

;; Только целое число (мм/1м), без единиц.
(defun gc-pile-mm-rounded (per-m-mm)
  (rtos (abs per-m-mm) 2 0))

;; Со знаком — только для сводки в консоли.
(defun gc-pile-mm-signed (mm)
  (strcat (if (>= mm 0) "+" "")
          (rtos mm 2 0) " мм"))

;;; ====================================================================
;;; РЕЖИМ 1 — ВСЕ ТОЧКИ СРАЗУ
;;; ====================================================================

;; SPEC-002 v2: режим 1 — поиск всех свай через окружность.
;; Возвращает список ((low-circle low-pts high-circle high-pts) ...) или nil.
;; Работает и для 1 сваи (вырождается в один цикл), и для N свай.
(defun gc-pile-mode1 ( / ss pts n z-groups all-low all-high
                        low-piles high-piles pairs)
  (princ "\nВыделите точки сваи/свай (рамкой). Не-точки игнорируются: ")
  (setq ss (ssget *gc-pile-ssget-filter*))
  (cond
    ((null ss)
     (princ "\n[ОШИБКА] Точки не выбраны.")
     nil)
    (T
     (setq pts (gc-pile-ss-to-points ss))
     (setq n   (length pts))
     (cond
       ((< n 6)
        (princ (strcat "\n[ОШИБКА] Нужно минимум 6 точек. Найдено: " (itoa n)))
        nil)
       (T
        ;; Шаг 1: Z-кластеризация → две группы (нижние и верхние всех свай).
        (setq z-groups (gc-pile-cluster-z pts))
        (cond
          ((null z-groups) nil)
          (T
           (setq all-low  (car  z-groups)
                 all-high (cadr z-groups))
           ;; Шаг 2: жадный поиск свай по окружности отдельно для нижних/верхних.
           (princ "\n[i] Ищу нижние сечения...")
           (setq low-piles  (gc-pile-find-all-piles all-low))
           (princ "\n[i] Ищу верхние сечения...")
           (setq high-piles (gc-pile-find-all-piles all-high))
           (princ (strcat "\n[i] Всего точек: " (itoa n)
                          ". Найдено нижних сечений: " (itoa (length low-piles))
                          ", верхних: "                (itoa (length high-piles))))
           (cond
             ((null low-piles)
              (princ "\n[ОШИБКА] Ни одной окружности с R≈710 мм в нижней группе.") nil)
             ((null high-piles)
              (princ "\n[ОШИБКА] Ни одной окружности с R≈710 мм в верхней группе.") nil)
             (T
              ;; Шаг 3: сопоставление по близости центров.
              (setq pairs (gc-pile-pair-piles low-piles high-piles
                                              *gc-pile-pair-tolerance*))
              (cond
                ((null pairs)
                 (princ "\n[ОШИБКА] Не удалось сопоставить ни одной пары низ↔верх.")
                 nil)
                (T
                 (princ (strcat "\n[i] Найдено свай (пар): " (itoa (length pairs))))
                 (if (or (/= (length low-piles)  (length pairs))
                         (/= (length high-piles) (length pairs)))
                   (princ (strcat "\n[!] Несопоставимыми остались: нижних "
                                  (itoa (- (length low-piles)  (length pairs)))
                                  ", верхних "
                                  (itoa (- (length high-piles) (length pairs))))))
                 pairs)))))))))))

;;; ====================================================================
;;; РЕЖИМ 2 — ПО ГРУППАМ ВРУЧНУЮ
;;; ====================================================================

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
        (princ "\nУкажите точку верха сваи (или ESC — пропустить): ")
        (entsel)
        (setq low-pts  (gc-pile-ss-to-points ss-low))
        (setq high-pts (gc-pile-ss-to-points ss-high))
        (cond
          ((< (length low-pts) 3)
           (princ "\n[ОШИБКА] В нижнем сечении меньше 3 валидных точек.") nil)
          ((< (length high-pts) 3)
           (princ "\n[ОШИБКА] В верхнем сечении меньше 3 валидных точек.") nil)
          (T (list low-pts high-pts))))))))

;;; ====================================================================
;;; ОСНОВНАЯ ОБРАБОТКА — ОТ ГРУПП К ЧЕРТЕЖУ
;;; ====================================================================

(defun gc-pile-process (low-pts high-pts /
                         c-low c-high z-low z-high
                         dx-mm dy-mm dz dx-pm dy-pm
                         tstyle p-low p-end-x p-end-y
                         pt-text-x pt-text-y sx sy sxy
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
     ;; Слои и стиль
     (gc-pile-ensure-layer *gc-l-low*    1)
     (gc-pile-ensure-layer *gc-l-high*   3)
     (gc-pile-ensure-layer *gc-l-arrows* 7)
     (gc-pile-ensure-layer *gc-l-text*   7)
     (setq tstyle (gc-pile-text-style))
     ;; Окружности
     (gc-pile-draw-circle (car c-low)  (cadr c-low)  z-low  (caddr c-low)  *gc-l-low*)
     (gc-pile-draw-circle (car c-high) (cadr c-high) z-high (caddr c-high) *gc-l-high*)
     ;; Отклонения
     (setq dx-mm (* 1000.0 (- (car  c-high) (car  c-low)))
           dy-mm (* 1000.0 (- (cadr c-high) (cadr c-low)))
           dz    (- z-high z-low))
     (if (> (abs dz) 1.0e-6)
       (setq dx-pm (/ dx-mm dz)
             dy-pm (/ dy-mm dz))
       (setq dx-pm dx-mm dy-pm dy-mm))
     ;; Стрелки от центра нижнего, длина = arrow-len, направление по знакам
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
     ;; SPEC-002 v2: подписи в 4 квадранта круга по таблице Шамиля.
     ;; Формула: пусть sx=sign(dx), sy=sign(dy). Тогда:
     ;;   Y-текст в (cx + sxy·d, cy + sy·d)        — sxy = sx·sy
     ;;   X-текст в (cx + sxy·d, cy − sy·d)
     ;; где d = *gc-pile-text-offset* (~0.4 м, внутри круга).
     ;; Проверено на всех 4 случаях (++, −+, +−, −−) — совпадает с таблицей.
     (setq sx  (if (>= dx-mm 0) 1.0 -1.0))
     (setq sy  (if (>= dy-mm 0) 1.0 -1.0))
     (setq sxy (* sx sy))
     (setq pt-text-y (list (+ (car  p-low) (* sxy *gc-pile-text-offset*))
                           (+ (cadr p-low) (* sy  *gc-pile-text-offset*))
                           z-low))
     (setq pt-text-x (list (+ (car  p-low) (* sxy *gc-pile-text-offset*))
                           (- (cadr p-low) (* sy  *gc-pile-text-offset*))
                           z-low))
     (gc-pile-draw-text-rot pt-text-x (gc-pile-mm-rounded dx-pm)
                            tstyle *gc-l-text* 0.0)
     (gc-pile-draw-text-rot pt-text-y (gc-pile-mm-rounded dy-pm)
                            tstyle *gc-l-text* (/ pi 2.0))
     ;; Сводка в консоль
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
       (princ "\n[!] Радиус сильно отличается от 710 мм — проверьте съёмку."))
     (if (or (> (abs dx-pm) *gc-pile-tol-mm-per-m*)
             (> (abs dy-pm) *gc-pile-tol-mm-per-m*))
       (princ (strcat "\n[!] Превышен допуск "
                      (rtos *gc-pile-tol-mm-per-m* 2 0) " мм/1м!")))
     (princ "\n----------------------")
     T)))

;;; ====================================================================
;;; КОМАНДА SV
;;; ====================================================================

(defun c:sv ( / mode-str pairs idx total ok skipped)
  (initget "1 2")
  (setq mode-str (getkword "\nРежим выбора точек [1=все сразу/2=по группам] <1>: "))
  (if (null mode-str) (setq mode-str "1"))
  (princ (strcat "\nРежим: " mode-str))
  (cond
    ((= mode-str "1")
     ;; mode1 возвращает список пар (1+ свай) или nil
     (setq pairs (gc-pile-mode1)))
    (T
     ;; mode2 возвращает одну пару (low high) — оборачиваем в список
     (let ((g (gc-pile-mode2)))
       (if g (setq pairs (list (cons (car g) (cadr g)))) (setq pairs nil)))))
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

(princ "\n[gc] sv.lsp загружен. Команда: SV")
(princ)
