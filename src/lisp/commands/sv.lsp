;;; sv.lsp -- obrabotka svay (SPEC-001 / SPEC-002 v5)
;;; Komanda SV: po tochkam takheomedra -- dva kruga (niz/verkh secheniya)
;;; i strelki otkloneniy mezhdu centrami s celochisl. podpisyami (mm/1m).
;;;
;;; v5: kodirova CP1251 (sovmestimo s Civil 3D na russkom Windows),
;;;     ispravlen vybor rezhima cherez knopki (getkword [1/2]).
;;;
;;; Specifikaciya: specs/001-pile-deviation.md, specs/002-pile-multi-batch.md
;;; Zagruzka: APPLOAD ili (load "put/k/sv.lsp").
;;; Zavisimosti: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ — Шамиль может править эти значения вручную в начале файла
;;; ====================================================================

(setq *gc-pile-r-norm*           0.710) ; норма радиуса сваи, м (D1420мм / 2)
(setq *gc-pile-r-warn*           0.050) ; превышение |R-norm| -> предупреждение
(setq *gc-pile-arrow-len*        0.400) ; длина Leader, м
(setq *gc-pile-tol-mm-per-m*    20.0)   ; норматив 20 мм/1м
(setq *gc-pile-text-h*           0.100) ; высота текста, м
(setq *gc-pile-text-margin*      0.050) ; legacy
(setq *gc-pile-text-along*       0.200) ; v3: смещение текста ВДОЛЬ стрелки от центра, м
(setq *gc-pile-text-lateral*     0.100) ; v3: смещение текста ПЕРПЕНДИКУЛЯРНО стрелке, м
(setq *gc-pile-z-cluster*        0.050) ; порог "одной высоты" по Z, м
(setq *gc-pile-fit-tol*          0.050) ; допуск |R-norm| при поиске свай, м
(setq *gc-pile-fit-radius-eps*   0.050) ; запас сверх R при сборе точек сваи, м
(setq *gc-pile-pair-tolerance*   0.500) ; допуск сопоставления низ<->верх (XY), м
(setq *gc-pile-pair-dz-min*      0.300) ; минимальный dZ между сечениями одной сваи, м
(setq *gc-pile-pair-dz-max*      5.000) ; максимальный dZ между сечениями одной сваи, м

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

;; v3: глобальная Z-кластеризация удалена — она не подходит для свай
;; на разной глубине (см. SPEC-002 v3 §11). Поиск идёт через сечения
;; в gc-pile-find-all-sections ниже.

;;; ====================================================================
;;; SPEC-002 v4: ПОИСК ВСЕХ СЕЧЕНИЙ + ГРУППИРОВКА В СВАИ
;;; ====================================================================

;; ПОЧЕМУ v4 после v3: два бага в v3.
;;
;; Баг производительности: gc-pile-find-one-section делал C(N,3) по ВСЕМУ
;; массиву точек. При 100 точках это ~160 000 троек — в AutoLISP занимает
;; десятки секунд. Фикс: сортировка по Z + Z-оконный перебор. Тройка валидна
;; только если Z[k]-Z[i] <= z-cluster. Для 100 точек в 10 группах по 10 ->
;; ~1 200 троек вместо 160 000 (~130x быстрее).
;;
;; Баг диагностики: когда сечение не найдено, код молча возвращал nil.
;; Пользователь не знал — неверный диаметр сваи или что-то другое. Теперь
;; при неудаче выводится лучший найденный R (даже если не попал в допуск).

;; Расстояние между точками в плане (XY).
(defun gc-pile-dist-xy (p1 p2 / dx dy)
  (setq dx (- (car p1) (car p2))
        dy (- (cadr p1) (cadr p2)))
  (sqrt (+ (* dx dx) (* dy dy))))

;; Среднее XY-центроида списка точек: возвращает (cx cy).
(defun gc-pile-centroid-xy (pts)
  (list (gc-pile-avg (mapcar 'car  pts))
        (gc-pile-avg (mapcar 'cadr pts))))

;; Поиск ОДНОГО сечения в массиве точек.
;; v4: сортируем по Z, перебираем только тройки внутри Z-окна (<= z-cluster).
;; CDR-итерация вместо nth — O(1) на шаг, нет квадратичного overhead.
;; Возвращает (list circle section-points) или nil.
;; При неудаче печатает лучший найденный R — для диагностики диаметра.
(defun gc-pile-find-one-section (pts / sorted best best-err diag-r
                                       lst-i lst-j lst-k p1 p2 p3
                                       circ err cx cy r limit
                                       section z-mean)
  (cond
    ((< (length pts) 3) nil)
    (T
     ;; Сортировка по Z — ключ к Z-оконному перебору
     (setq sorted (vl-sort pts '(lambda (a b) (< (caddr a) (caddr b)))))
     (setq best nil best-err 1.0e99 diag-r nil)
     ;; Тройной CDR-цикл: i <= j <= k, останавливаемся как только Z[k]-Z[i] > порог
     (setq lst-i sorted)
     (while lst-i
       (setq p1    (car lst-i)
             lst-j (cdr lst-i))
       (while (and lst-j
                   (<= (- (caddr (car lst-j)) (caddr p1))
                       *gc-pile-z-cluster*))
         (setq p2    (car lst-j)
               lst-k (cdr lst-j))
         (while (and lst-k
                     (<= (- (caddr (car lst-k)) (caddr p1))
                         *gc-pile-z-cluster*))
           (setq p3   (car lst-k)
                 circ (gc-pile-circle-3 p1 p2 p3))
           (if circ
             (progn
               (setq err (abs (- (caddr circ) *gc-pile-r-norm*)))
               ;; Запоминаем лучший R независимо от допуска (для диагностики)
               (if (or (null diag-r) (< err (abs (- diag-r *gc-pile-r-norm*))))
                 (setq diag-r (caddr circ)))
               (if (and (<= err *gc-pile-fit-tol*) (< err best-err))
                 (setq best-err err best circ))))
           (setq lst-k (cdr lst-k)))
         (setq lst-j (cdr lst-j)))
       (setq lst-i (cdr lst-i)))
     (cond
       ((null best)
        ;; Диагностика: что мешает найти сечение
        (if diag-r
          (princ (strcat
            "\n[?] Лучший R в выборке: " (rtos (* diag-r 1000.0) 2 0)
            " мм  (ищем " (rtos (* *gc-pile-r-norm* 1000.0) 2 0)
            " ±" (rtos (* *gc-pile-fit-tol* 1000.0) 2 0) " мм)."
            "\n    Если диаметр вашей сваи другой — измените *gc-pile-r-norm*"
            " в начале sv.lsp."))
          (princ "\n[?] Ни одной тройки точек в одном Z-слое не найдено. Проверьте отметки Z."))
        nil)
       (T
        (setq cx (car best) cy (cadr best) r (caddr best))
        (setq limit (+ r *gc-pile-fit-radius-eps*))
        ;; Все точки в радиусе R+eps от центра
        (setq section (vl-remove-if-not
                        '(lambda (p) (<= (gc-pile-dist-xy p (list cx cy)) limit))
                        pts))
        (cond
          ((< (length section) 3) nil)
          (T
           ;; Оставляем только точки на том же Z что и сечение
           (setq z-mean (gc-pile-avg (mapcar 'caddr section)))
           (setq section (vl-remove-if-not
                           '(lambda (p) (<= (abs (- (caddr p) z-mean))
                                            *gc-pile-z-cluster*))
                           section))
           (cond
             ((< (length section) 3) nil)
             (T (list best section)))))))))

;; Жадно ищет ВСЕ сечения во всём массиве точек.
;; Возвращает список '((circle z section-points) ...).
(defun gc-pile-find-all-sections (points / remaining sections result
                                          circ section z-mean)
  (setq remaining points sections '())
  (while (>= (length remaining) 3)
    (setq result (gc-pile-find-one-section remaining))
    (cond
      ((null result)
       (setq remaining nil))
      (T
       (setq circ    (car  result)
             section (cadr result))
       (setq z-mean  (gc-pile-avg (mapcar 'caddr section)))
       (setq sections (cons (list circ z-mean section) sections))
       (foreach pt section
         (setq remaining (vl-remove pt remaining))))))
  (reverse sections))

;; Группирует список сечений в сваи: сечения с близкими XY-центрами
;; (<= pair-tolerance) — одна свая. Внутри сваи берём 2 крайних по Z как
;; нижнее/верхнее. Возвращает список cons-пар ((low-pts . high-pts) ...).
(defun gc-pile-group-sections-into-piles (sections / unused piles
                                          seed pile-secs s d
                                          sorted lo hi pulled changed)
  (setq unused sections piles '())
  (while unused
    (setq seed     (car unused))
    (setq unused   (cdr unused))
    (setq pile-secs (list seed))
    ;; Жадно добавляем ВСЕ сечения с близким XY-центром (с любым из уже принятых)
    (setq changed T)
    (while changed
      (setq changed nil pulled '())
      (foreach s unused
        (foreach acc pile-secs
          (if (and (not (member s pulled))
                   (<= (gc-pile-dist-xy
                         (list (car (car s))    (cadr (car s)))
                         (list (car (car acc)) (cadr (car acc))))
                       *gc-pile-pair-tolerance*))
            (setq pulled (cons s pulled)))))
      (if pulled
        (progn
          (foreach s pulled
            (setq pile-secs (cons s pile-secs))
            (setq unused    (vl-remove s unused)))
          (setq changed T))))
    ;; В одной свае может быть 1, 2 или больше сечений.
    ;; Берём с min Z и max Z. Между ними должна быть разница в разумном диапазоне.
    (cond
      ((>= (length pile-secs) 2)
       (setq sorted (vl-sort pile-secs '(lambda (a b) (< (cadr a) (cadr b)))))
       (setq lo (car sorted))
       (setq hi (last sorted))
       (setq d (- (cadr hi) (cadr lo)))
       (if (and (>= d *gc-pile-pair-dz-min*)
                (<= d *gc-pile-pair-dz-max*))
         (setq piles (cons (cons (caddr lo) (caddr hi)) piles))
         (princ (strcat "\n[!] Свая (X~"
                        (rtos (car (car lo)) 2 1)
                        ", Y~" (rtos (cadr (car lo)) 2 1)
                        "): dZ=" (rtos d 2 2) " м вне диапазона ["
                        (rtos *gc-pile-pair-dz-min* 2 2) "; "
                        (rtos *gc-pile-pair-dz-max* 2 2) "] — пропуск."))))
      (T
       (princ (strcat "\n[!] Свая (X~"
                      (rtos (car (car seed)) 2 1)
                      ", Y~" (rtos (cadr (car seed)) 2 1)
                      "): найдено только 1 сечение — пропуск.")))))
  (reverse piles))

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

;; Fallback цепочка: GOSTB (СПДС) -> ISOCPEUR -> Standard.
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

;; SPEC-002 v3: режим 1 — поиск ВСЕХ сечений в одном массиве точек, потом
;; группировка в сваи по близости XY-центров. Работает на сваях с РАЗНЫМИ Z
;; (погружение на разную глубину), и для 1 сваи (вырождается).
;; Возвращает список cons-пар ((low-pts . high-pts) ...) или nil.
(defun gc-pile-mode1 ( / ss pts n sections piles)
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
        ;; Показываем диаметр и Z-диапазон — помогает диагностировать
        (princ (strcat "\n[i] Точек: " (itoa n)
                       "  |  Диаметр сваи: "
                       (rtos (* 2.0 *gc-pile-r-norm* 1000.0) 2 0) " мм"
                       "  |  Z: "
                       (rtos (apply 'min (mapcar 'caddr pts)) 2 3)
                       " — "
                       (rtos (apply 'max (mapcar 'caddr pts)) 2 3) " м"))
        (princ "\n[i] Ищу сечения...")
        (setq sections (gc-pile-find-all-sections pts))
        (princ (strcat "\n[i] Найдено сечений: " (itoa (length sections))))
        (cond
          ((< (length sections) 2)
           (princ (strcat "\n[ОШИБКА] Нужно минимум 2 сечения, найдено: "
                          (itoa (length sections)) "."))
           (princ (strcat "\n[?] Текущий диаметр сваи: "
                          (rtos (* 2.0 *gc-pile-r-norm* 1000.0) 2 0)
                          " мм (радиус *gc-pile-r-norm* = "
                          (rtos *gc-pile-r-norm* 2 3) " м)."))
           (princ "\n[?] Если диаметр другой — исправьте *gc-pile-r-norm* в начале sv.lsp.")
           nil)
          (T
           ;; Шаг 2: группируем сечения в сваи по XY-центру.
           (setq piles (gc-pile-group-sections-into-piles sections))
           (cond
             ((null piles)
              (princ "\n[ОШИБКА] Не удалось собрать ни одной сваи (низ+верх).")
              nil)
             (T
              (princ (strcat "\n[i] Сформировано свай: " (itoa (length piles))))
              piles)))))))))

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
     ;; SPEC-002 v3: подписи РЯДОМ со стрелками, в нужном квадранте по таблице.
     ;; Y-стрелка идёт от центра вертикально по знаку dy; подпись на середине
     ;; стрелки (along=text-along по Y от центра в направлении sy) со
     ;; смещением вбок (lateral=text-lateral по X в направлении sxy).
     ;; X-стрелка — симметрично: along по X в sx, lateral по Y в -sy.
     ;; Формула покрывает все 4 случая (++, -+, +-, --).
     (setq sx  (if (>= dx-mm 0) 1.0 -1.0))
     (setq sy  (if (>= dy-mm 0) 1.0 -1.0))
     (setq sxy (* sx sy))
     (setq pt-text-y
       (list (+ (car  p-low) (* sxy *gc-pile-text-lateral*))
             (+ (cadr p-low) (* sy  *gc-pile-text-along*))
             z-low))
     (setq pt-text-x
       (list (+ (car  p-low) (* sx  *gc-pile-text-along*))
             (- (cadr p-low) (* sy  *gc-pile-text-lateral*))
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
  (princ "\n  1 = все точки сразу (автоопределение свай)")
  (princ "\n  2 = по группам вручную (нижнее/верхнее сечение)")
  (initget "1 2")
  (setq mode-str (getkword "\nРежим [1/2] <1>: "))
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

(princ "\n[gc] sv.lsp v5 загружен. Команда: SV")
(princ)
