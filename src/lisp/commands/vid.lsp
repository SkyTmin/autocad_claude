;;; vid.lsp -- vydelenie obyektov ramkoy zadannogo razmera (SPEC-005 v1)
;;; Komandy:
;;;   VID               -- korotkiy alias dlya ezhednevnoy raboty.
;;;   GC-SELECT-BY-SIZE -- polnoe imya toy zhe komandy.
;;;
;;; Tochka privyazki -- LEVYY VERHNIY ugol: ramka rastet vpravo i vniz.
;;; Vydelenie -- tolko "sinee" (window): obyekt vydelyaetsya, tolko esli
;;; popal v ramku CELIKOM. Zadetye kraem obyekty ne vydelyayutsya.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/vid.lsp").
;;; Zavisimosti: Visual LISP (vl-string-subst).

(vl-load-com)

;;; ====================================================================
;;; СОСТОЯНИЕ — размеры прошлого запуска
;;; ====================================================================

;; *gc-vid-last-y* / *gc-vid-last-x* намеренно НЕ инициализируются при загрузке:
;; AutoLISP возвращает nil для несвязанного символа, а сброс на nil при каждом
;; APPLOAD стирал бы размеры прошлого запуска.
;; ПОЧЕМУ вообще храним: Шамиль выделяет много участков подряд одним размером —
;; повторный запуск превращается в "Enter, Enter".

;;; ====================================================================
;;; РАЗБОР РАЗМЕРА: "5,300" / "5.300" / "5,3" -> метры
;;; ====================================================================

;; Запятая и точка равнозначны и читаются как обычный десятичный разделитель
;; метров (решение Шамиля, SPEC-005 §2): "5,3" = "5,300" = 5.300 м.
;; ПОЧЕМУ свой парсер, а не getreal: getreal не принимает запятую, а Шамиль
;; вводит размеры именно через запятую, как в ведомостях.
;; Возвращает положительное число метров либо nil, если строка не размер.
(defun gc-vid-parse-size (s / n i ch bad seps digits norm val)
  (setq n      (strlen s)
        i      1
        bad    nil
        seps   0
        digits 0
        norm   "")
  (while (<= i n)
    (setq ch (substr s i 1))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
       (setq digits (1+ digits)
             norm   (strcat norm ch)))
      ((or (= ch ",") (= ch "."))
       (setq seps (1+ seps)
             norm (strcat norm ".")))
      ;; Пробелы игнорируем: "5, 300" — тот же размер, что "5,300".
      ((or (= ch " ") (= ch "\t")) nil)
      (T (setq bad T)))
    (setq i (1+ i)))
  (cond
    (bad          nil)   ; посторонний символ
    ((= digits 0) nil)   ; ни одной цифры
    ((> seps 1)   nil)   ; "5,3,7"
    (T
     (setq val (atof norm))
     ;; Нулевая или отрицательная рамка бессмысленна: площадь = 0.
     (if (> val 1.0e-9) val nil))))

;; Обратный вывод — в привычном виде с запятой: 5.300 -> "5,300".
(defun gc-vid-fmt (m)
  (vl-string-subst "," "." (rtos m 2 3)))

;; Спрашивает размер, пока не получит корректный.
;; default — значение прошлого запуска либо nil.
;; Пустой ввод при наличии default означает "оставить как было".
(defun gc-vid-ask-size (label default / res s val)
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "5, 300"
    ;; молча превратилось бы в "5," = 5.000 м.
    (setq s (getstring T
              (if default
                (strcat "\n" label " <" (gc-vid-fmt default) ">: ")
                (strcat "\n" label ": "))))
    (cond
      ((and (= s "") default)
       (setq res default))
      ((= s "")
       (princ "\n[!] Размер обязателен. Пример ввода: 5,300"))
      (T
       (setq val (gc-vid-parse-size s))
       (if val
         (setq res val)
         (princ (strcat "\n[!] Не понял \"" s
                        "\" — нужен размер вида 5,300 (метры, запятая, миллиметры)"))))))
  res)

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-vid-run ( / pt1 pt2 dy dx x1 y1 x2 y2 ss cnt)
  (princ "\nVID — выделение рамкой заданного размера (угол привязки: левый верхний).")
  (setq pt1 (getpoint "\nУкажите левый верхний угол области выделения: "))
  (cond
    ((null pt1)
     (princ "\n[ОТМЕНА] Угол не указан.")
     nil)
    (T
     ;; Порядок опроса — как просил Шамиль: сначала Y (длина), потом X (ширина).
     (setq dy (gc-vid-ask-size "Размер по Y (сверху вниз), м" *gc-vid-last-y*))
     (setq dx (gc-vid-ask-size "Размер по X (слева направо), м" *gc-vid-last-x*))
     (setq *gc-vid-last-y* dy
           *gc-vid-last-x* dx)
     ;; Левый верхний угол: X растёт вправо, Y убывает вниз.
     (setq x1 (car  pt1)
           y1 (cadr pt1)
           x2 (+ x1 dx)
           y2 (- y1 dy))
     ;; ПОЧЕМУ общий Z у обоих углов: ssget "_W" проецирует рамку на плоскость
     ;; вида, разные Z у углов дают непредсказуемую проекцию.
     (setq pt2 (list x2 y2 (caddr pt1)))
     (princ (strcat "\n[i] Рамка " (gc-vid-fmt dx) " x " (gc-vid-fmt dy)
                    " м (X x Y), угол привязки — левый верхний."))
     (princ (strcat "\n[i] Область: X " (rtos x1 2 3) " ... " (rtos x2 2 3)
                    "   Y " (rtos y2 2 3) " ... " (rtos y1 2 3)))
     ;; "_W" = window: только объекты, попавшие ЦЕЛИКОМ (синяя рамка).
     ;; Подчёркивание защищает от локализованного имени опции.
     (setq ss (ssget "_W" pt1 pt2))
     (cond
       ((null ss)
        (princ "\n[i] В указанной области нет объектов, попадающих целиком.")
        nil)
       (T
        (setq cnt (sslength ss))
        ;; sssetfirst оставляет объекты выделенными с ручками после выхода из
        ;; команды — можно сразу Delete / Move / задать свойства.
        (sssetfirst nil ss)
        (princ (strcat "\n[i] Выделено объектов: " (itoa cnt)))
        ss)))))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если Шамиль нажал Esc посреди ввода.
(defun c:vid ( / *error*)
  (defun *error* (msg)
    (if (and msg
             (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\n[ОШИБКА] VID: " msg))
      (princ "\n[ОТМЕНА] VID прерван."))
    (princ))
  (gc-vid-run)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-select-by-size ( / )
  (c:vid))

(princ "\n[gc] vid.lsp v1 загружен. Команды: VID, GC-SELECT-BY-SIZE")
(princ)
