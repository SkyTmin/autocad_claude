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

(setq *gc-pile-r-norm*       0.710)   ; норма радиуса сваи, м (Ø1420мм / 2)
(setq *gc-pile-r-warn*       0.050)   ; превышение |R−norm| → предупреждение
(setq *gc-pile-arrow-len*    0.400)   ; длина Leader, м (можно увеличить/уменьшить)
(setq *gc-pile-tol-mm-per-m* 20.0)    ; норматив 20 мм/1м
(setq *gc-pile-text-h*       0.100)   ; высота текста, м
(setq *gc-pile-text-margin*  0.050)   ; отступ текста от стрелки, м

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
;;; КЛАСТЕРИЗАЦИЯ ПО Z — АДАПТИВНАЯ (2 САМЫХ БОЛЬШИХ РАЗРЫВА)
;;; ====================================================================

;; ПОЧЕМУ адаптивно: ранее использовали фиксированный порог 100 мм, что
;; ломалось при бо́льшем разбросе по Z (получалось 4+ групп). Сейчас
;; всегда находим ровно 3 группы (или 2 при 6 точках), независимо от
;; абсолютной разности высот.
(defun gc-pile-cluster-z (points / sorted n i gaps cuts)
  (setq sorted (vl-sort points '(lambda (a b) (< (caddr a) (caddr b)))))
  (setq n (length sorted))
  (cond
    ((< n 6) nil)
    (T
     ;; Считаем разрывы: пары (индекс_слева, размер_разрыва).
     (setq i 0 gaps '())
     (while (< i (1- n))
       (setq gaps (cons
                    (list i (- (caddr (nth (1+ i) sorted))
                               (caddr (nth i        sorted))))
                    gaps))
       (setq i (1+ i)))
     ;; Сортируем разрывы по убыванию размера.
     (setq gaps (vl-sort gaps '(lambda (a b) (> (cadr a) (cadr b)))))
     (cond
       ((= n 6)
        ;; Ровно 6 точек — 1 разрез → 2 группы (без верхушки).
        (setq cuts (list (car (car gaps)))))
       (T
        ;; ≥7 точек — 2 разреза → 3 группы.
        (setq cuts (vl-sort (list (car (car gaps)) (car (cadr gaps))) '<))))
     (gc-pile-split-by-cuts sorted cuts))))

;; Делит отсортированный список по индексам разрезов.
;; cuts — отсортированный по возрастанию список индексов i, после которых режем.
(defun gc-pile-split-by-cuts (sorted cuts / groups current i)
  (setq groups '() current '() i 0)
  (foreach pt sorted
    (setq current (cons pt current))
    (if (member i cuts)
      (progn
        (setq groups (cons (reverse current) groups))
        (setq current '())))
    (setq i (1+ i)))
  (if current (setq groups (cons (reverse current) groups)))
  (reverse groups))

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

(defun gc-pile-mode1 ( / ss pts groups n)
  (princ "\nВыделите все точки сваи (низ + верх + верхушка): ")
  (setq ss (ssget))
  (cond
    ((null ss)
     (princ "\n[ОШИБКА] Точки не выбраны.")
     nil)
    (T
     (setq pts (gc-pile-ss-to-points ss))
     (setq n (length pts))
     (cond
       ((< n 6)
        (princ (strcat "\n[ОШИБКА] Нужно минимум 6 точек (3 низ + 3 верх). Найдено: "
                       (itoa n)))
        nil)
       (T
        (setq groups (gc-pile-cluster-z pts))
        (cond
          ((null groups)
           (princ "\n[ОШИБКА] Не удалось кластеризовать точки.") nil)
          ((= (length groups) 2)
           (princ (strcat "\n[i] Точек: " (itoa n)
                          " → нижнее: "  (itoa (length (car groups)))
                          ", верхнее: "  (itoa (length (cadr groups)))
                          " (верхушки нет)."))
           (cond
             ((< (length (car  groups)) 3)
              (princ "\n[ОШИБКА] В нижней группе меньше 3 точек.") nil)
             ((< (length (cadr groups)) 3)
              (princ "\n[ОШИБКА] В верхней группе меньше 3 точек.") nil)
             (T (list (car groups) (cadr groups)))))
          ((= (length groups) 3)
           (princ (strcat "\n[i] Точек: " (itoa n)
                          " → нижнее: "  (itoa (length (car groups)))
                          ", верхнее: "  (itoa (length (cadr groups)))
                          ", верх сваи: " (itoa (length (caddr groups)))
                          " (игнорируется по спеке)."))
           (cond
             ((< (length (car  groups)) 3)
              (princ "\n[ОШИБКА] В нижнем сечении меньше 3 точек.") nil)
             ((< (length (cadr groups)) 3)
              (princ "\n[ОШИБКА] В верхнем сечении меньше 3 точек.") nil)
             (T (list (car groups) (cadr groups)))))
          (T
           (princ (strcat "\n[ОШИБКА] Получено групп по Z: "
                          (itoa (length groups))))
           nil)))))))

;;; ====================================================================
;;; РЕЖИМ 2 — ПО ГРУППАМ ВРУЧНУЮ
;;; ====================================================================

(defun gc-pile-mode2 ( / ss-low ss-high low-pts high-pts)
  (princ "\nВыделите точки нижнего сечения: ")
  (setq ss-low (ssget))
  (cond
    ((null ss-low) (princ "\n[ОШИБКА] Нижнее сечение не выбрано.") nil)
    (T
     (princ "\nВыделите точки верхнего сечения: ")
     (setq ss-high (ssget))
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
                         mid-x mid-y pt-text-x pt-text-y
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
     ;; Подписи: позиция + поворот по правилам Шамиля
     ;;   X-стрелка (горизонт.) — текст под серединой, ротация 0
     ;;   Y↑                     — текст слева от середины, ротация 90°
     ;;   Y↓                     — текст справа от середины, ротация 90°
     (setq mid-x (list (/ (+ (car p-low) (car p-end-x)) 2.0)
                       (cadr p-low)
                       z-low))
     (setq mid-y (list (car p-low)
                       (/ (+ (cadr p-low) (cadr p-end-y)) 2.0)
                       z-low))
     ;; Текст X — под серединой
     (setq pt-text-x (list (car mid-x)
                           (- (cadr mid-x)
                              (+ (* 0.5 *gc-pile-text-h*)
                                 *gc-pile-text-margin*))
                           z-low))
     (gc-pile-draw-text-rot pt-text-x
                            (gc-pile-mm-rounded dx-pm)
                            tstyle *gc-l-text* 0.0)
     ;; Текст Y — слева (если ↑) или справа (если ↓), повёрнут на 90°
     (setq pt-text-y
       (if (>= dy-mm 0)
         (list (- (car mid-y)
                  (+ (* 0.5 *gc-pile-text-h*) *gc-pile-text-margin*))
               (cadr mid-y) z-low)
         (list (+ (car mid-y)
                  (+ (* 0.5 *gc-pile-text-h*) *gc-pile-text-margin*))
               (cadr mid-y) z-low)))
     (gc-pile-draw-text-rot pt-text-y
                            (gc-pile-mm-rounded dy-pm)
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

(defun c:sv ( / mode-str groups)
  (initget "1 2")
  (setq mode-str (getkword "\nРежим выбора точек [1=все сразу/2=по группам] <1>: "))
  (if (null mode-str) (setq mode-str "1"))
  (princ (strcat "\nРежим: " mode-str))
  (setq groups (if (= mode-str "1")
                 (gc-pile-mode1)
                 (gc-pile-mode2)))
  (if groups
    (gc-pile-process (car groups) (cadr groups))
    (princ "\nКоманда отменена."))
  (princ))

(princ "\n[gc] sv.lsp загружен. Команда: SV")
(princ)
