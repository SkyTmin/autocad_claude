;;; vo.lsp -- otklonenie fakticheskoy tochki ot proektnoy otmetki (SPEC-006 v1)
;;; Komandy:
;;;   VO                  -- korotkiy alias (Vysotnoe Otklonenie).
;;;   GC-HEIGHT-DEVIATION -- polnoe imya toy zhe komandy.
;;;
;;; PRICHINA imeni VO, a ne H: "H" -- shtatnyy alias HATCH v AutoCAD, i
;;; opredelenie c:h perekrylo by shtrihovku.
;;;
;;; Proektnaya otmetka i vysota teksta -- SHABLON: zadayutsya odin raz,
;;; dalshe kazhdaya tochka eto dva klika. Menyayutsya opciyami [Proekt]/[Vysota].
;;;
;;; Helpery razbora chisla i chteniya vysoty namerenno dublirovany iz
;;; sv.lsp / vid.lsp -- sm. docs/decisions/0003-standalone-command-files.md.
;;; Fayl gruzitsya nezavisimo i ne trebuet drugih faylov proekta.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/vo.lsp").
;;; Zavisimosti: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ
;;; ====================================================================

(setq *gc-vo-layer*          "GC-Высотные-Отклонения")
(setq *gc-vo-layer-color*    7)
(setq *gc-vo-text-h-init*    0.100) ; высота текста, предлагаемая в первый раз

;;; ШАБЛОН — живёт между запусками:
;;;   *gc-vo-proj-z*  — проектная отметка, м
;;;   *gc-vo-text-h*  — высота текста, м
;;; Намеренно НЕ инициализируются при загрузке: AutoLISP возвращает nil для
;;; несвязанного символа, а сброс на nil при каждом APPLOAD стирал бы шаблон.

;;; ====================================================================
;;; РАЗБОР ЧИСЛА: "4,398" / "4.398" / "-1,25" -> метры
;;; ====================================================================

;; Запятая и точка равнозначны, пробелы игнорируются, знак допустим.
;; ПОЧЕМУ свой парсер, а не getreal: getreal не принимает запятую, а Шамиль
;; вводит отметки именно через запятую, как в ведомостях.
;; Возвращает число (ноль и минус допустимы) либо nil, если строка не число.
(defun gc-vo-parse-num (s / n i ch bad seps digits sign sgn-seen norm)
  (setq n        (strlen s)
        i        1
        bad      nil
        seps     0
        digits   0
        sign     1.0
        sgn-seen nil
        norm     "")
  (while (<= i n)
    (setq ch (substr s i 1))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
       (setq digits (1+ digits)
             norm   (strcat norm ch)))
      ((or (= ch ",") (= ch "."))
       (setq seps (1+ seps)
             norm (strcat norm ".")))
      ((or (= ch " ") (= ch "\t")) nil)
      ;; Знак — только до первой цифры и только один раз.
      ((and (or (= ch "-") (= ch "+"))
            (= digits 0) (= seps 0) (null sgn-seen))
       (setq sgn-seen T)
       (if (= ch "-") (setq sign -1.0)))
      (T (setq bad T)))
    (setq i (1+ i)))
  (cond
    (bad          nil)   ; посторонний символ
    ((= digits 0) nil)   ; ни одной цифры
    ((> seps 1)   nil)   ; "4,3,9"
    (T (* sign (atof norm)))))

;; Обратный вывод — в привычном виде с запятой: 4.398 -> "4,398".
(defun gc-vo-fmt (m)
  (vl-string-subst "," "." (rtos m 2 3)))

;; Округление до целого «от нуля»: 2.5 -> 3, -2.5 -> -3.
;; ПОЧЕМУ не rtos: rtos зависит от настроек единиц чертежа (DIMZIN),
;; а подпись должна быть одинаковой в любом DWG.
(defun gc-vo-round (x)
  (if (>= x 0.0)
    (fix (+ x 0.5))
    (- (fix (+ (- x) 0.5)))))

;; Подпись отклонения: только знак и число, без единиц (требование Шамиля).
;; Ноль пишется без знака.
(defun gc-vo-fmt-dev (mm)
  (cond
    ((> mm 0) (strcat "+" (itoa mm)))
    ((< mm 0) (itoa mm))          ; itoa сам ставит минус
    (T        "0")))

;;; ====================================================================
;;; ЧТЕНИЕ ВЫСОТЫ ИЗ ОБЪЕКТА
;;; ====================================================================

;; Порядок проб важен:
;; 1. Elevation — COGO Point Civil 3D и LWPOLYLINE отдают высоту здесь.
;; 2. DXF-группа 10 — обычная точка, окружность, текст, линия.
;; 3. InsertionPoint — блоки.
;; Coordinates намеренно НЕ используется: у LWPOLYLINE это плоские пары
;; (x y x y …), и третий элемент оказался бы Y второй вершины, а не высотой.
(defun gc-vo-entity-z (ent / obj ed p10 z)
  (setq obj (vlax-ename->vla-object ent)
        z   nil)
  (if (vlax-property-available-p obj 'Elevation)
    (setq z (vla-get-Elevation obj)))
  (if (null z)
    (progn
      (setq ed  (entget ent))
      (setq p10 (cdr (assoc 10 ed)))
      (if (and p10 (caddr p10))
        (setq z (caddr p10)))))
  (if (null z)
    (if (vlax-property-available-p obj 'InsertionPoint)
      (setq z (caddr (vlax-safearray->list
                       (vlax-variant-value (vla-get-InsertionPoint obj)))))))
  z)

;; Выбор объекта и чтение его высоты. Возвращает Z либо nil, если
;; пользователь вышел по Enter/Esc.
;; ПОЧЕМУ через ERRNO: entsel возвращает nil и при промахе, и при Enter.
;; ERRNO 7 = промах (переспрашиваем), иначе — осознанный выход.
(defun gc-vo-pick-z (prompt / res sel z)
  (setq res nil)
  (while (null res)
    (setq sel (entsel prompt))
    (cond
      ((null sel)
       (if (= (getvar "ERRNO") 7)
         (princ "\n[!] Мимо объекта — попробуйте ещё раз.")
         (setq res 'CANCEL)))
      (T
       (setq z (gc-vo-entity-z (car sel)))
       (if z
         (setq res z)
         (princ "\n[!] У объекта нет высоты — выберите другой.")))))
  (if (equal res 'CANCEL) nil res))

;;; ====================================================================
;;; НАСТРОЙКА ШАБЛОНА
;;; ====================================================================

;; positive-only = T для высоты текста: нулевой или минусовый текст не бывает.
(defun gc-vo-ask-num (label default positive-only / res s val)
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "4, 398"
    ;; молча превратилось бы в "4," = 4.000 м.
    (setq s (getstring T
              (if default
                (strcat "\n" label " <" (gc-vo-fmt default) ">: ")
                (strcat "\n" label ": "))))
    (cond
      ((and (= s "") default)
       (setq res default))
      ((= s "")
       (princ "\n[!] Значение обязательно. Пример ввода: 4,398"))
      (T
       (setq val (gc-vo-parse-num s))
       (cond
         ((null val)
          (princ (strcat "\n[!] Не понял \"" s "\" — нужно число вида 4,398")))
         ((and positive-only (<= val 1.0e-9))
          (princ "\n[!] Высота текста должна быть больше нуля."))
         (T (setq res val))))))
  res)

(defun gc-vo-set-proj-manual ( / )
  (setq *gc-vo-proj-z* (gc-vo-ask-num "Проектная отметка, м" *gc-vo-proj-z* nil))
  (princ (strcat "\n[i] Проектная отметка: " (gc-vo-fmt *gc-vo-proj-z*) " м"))
  *gc-vo-proj-z*)

(defun gc-vo-set-proj ( / kw z)
  ;; Латинские дубли — на случай непереключённой раскладки.
  (initget "Объект Ввод Obyekt Vvod")
  (setq kw (getkword "\nПроектная отметка [Объект/Ввод] <Ввод>: "))
  (if (null kw) (setq kw "Ввод"))
  (cond
    ((member kw '("Объект" "Obyekt"))
     (setq z (gc-vo-pick-z "\nВыберите объект с нужной высотой: "))
     (cond
       (z
        (setq *gc-vo-proj-z* z)
        (princ (strcat "\n[i] Проектная отметка с объекта: "
                       (gc-vo-fmt z) " м")))
       (T
        (princ "\n[!] Объект не выбран — отметка не изменена.")
        ;; Шаблона ещё нет вообще — иначе дальше считали бы от nil.
        (if (null *gc-vo-proj-z*) (gc-vo-set-proj-manual)))))
    (T (gc-vo-set-proj-manual)))
  *gc-vo-proj-z*)

(defun gc-vo-set-text-h ( / )
  (setq *gc-vo-text-h*
        (gc-vo-ask-num "Высота текста, м"
                       (if *gc-vo-text-h* *gc-vo-text-h* *gc-vo-text-h-init*)
                       T))
  (princ (strcat "\n[i] Высота текста: " (gc-vo-fmt *gc-vo-text-h*) " м"))
  *gc-vo-text-h*)

;;; ====================================================================
;;; ОТРИСОВКА ПОДПИСИ
;;; ====================================================================

(defun gc-vo-ensure-layer (name color)
  (if (null (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name)
                   '(70 . 0)
                   (cons 62 color)
                   '(6 . "Continuous")))))

;; Fallback цепочка: GOSTB (СПДС) -> ISOCPEUR -> Standard.
(defun gc-vo-text-style ( / )
  (cond
    ((tblsearch "STYLE" "GOSTB")    "GOSTB")
    ((tblsearch "STYLE" "ISOCPEUR") "ISOCPEUR")
    (T                              "Standard")))

;; 72=1 / 73=2 — выравнивание Middle Center: подпись встаёт по центру клика.
(defun gc-vo-draw-text (pt txt / )
  (gc-vo-ensure-layer *gc-vo-layer* *gc-vo-layer-color*)
  (entmake (list '(0 . "TEXT")
                 (cons 8 *gc-vo-layer*)
                 (cons 7 (gc-vo-text-style))
                 (cons 10 pt)
                 (cons 40 *gc-vo-text-h*)
                 (cons 1 txt)
                 (cons 50 0.0)
                 (cons 72 1)
                 (cons 11 pt)
                 (cons 73 2))))

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-vo-run ( / done sel z-fact dev-mm txt pt)
  ;; Первый запуск за сеанс: шаблона ещё нет.
  (if (null *gc-vo-proj-z*) (gc-vo-set-proj))
  (if (null *gc-vo-text-h*) (gc-vo-set-text-h))
  (setq done nil)
  (while (not done)
    (princ (strcat "\nVO: проект " (gc-vo-fmt *gc-vo-proj-z*)
                   " м  |  высота текста " (gc-vo-fmt *gc-vo-text-h*) " м"))
    (initget "Проект Высота Proekt Vysota")
    (setq sel (entsel "\nФактическая точка [Проект/Высота]: "))
    (cond
      ((null sel)
       ;; ERRNO 7 = промах мимо объекта, всё остальное = осознанный выход.
       (if (= (getvar "ERRNO") 7)
         (princ "\n[!] Мимо объекта — попробуйте ещё раз.")
         (progn
           (princ "\n[i] VO завершена.")
           (setq done T))))
      ((member sel '("Проект" "Proekt")) (gc-vo-set-proj))
      ((member sel '("Высота" "Vysota")) (gc-vo-set-text-h))
      ((= (type sel) 'STR)
       (princ "\n[!] Не понял ответ. Выберите точку либо опцию Проект/Высота."))
      (T
       (setq z-fact (gc-vo-entity-z (car sel)))
       (if (null z-fact)
         (princ "\n[!] У объекта нет высоты — выберите другой.")
         (progn
           (setq dev-mm (gc-vo-round (* 1000.0 (- z-fact *gc-vo-proj-z*))))
           (setq txt    (gc-vo-fmt-dev dev-mm))
           (princ (strcat "\n[i] Факт " (gc-vo-fmt z-fact)
                          "  -  проект " (gc-vo-fmt *gc-vo-proj-z*)
                          "  =  " txt))
           (setq pt (getpoint "\nТочка вставки подписи: "))
           (if (null pt)
             ;; Не выходим из команды: вычисление сделано, Шамиль мог просто
             ;; промахнуться — возвращаемся к выбору следующей точки.
             (princ "\n[!] Точка вставки не указана — подпись не поставлена.")
             (progn
               (gc-vo-draw-text pt txt)
               (princ (strcat "\n[i] Подпись " txt " поставлена.")))))))))
  (princ))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если Шамиль нажал Esc посреди ввода.
(defun c:vo ( / *error*)
  (defun *error* (msg)
    (if (and msg
             (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\n[ОШИБКА] VO: " msg))
      (princ "\n[ОТМЕНА] VO прерван."))
    (princ))
  (gc-vo-run)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-height-deviation ( / )
  (c:vo))

(princ "\n[gc] vo.lsp v1 загружен. Команды: VO, GC-HEIGHT-DEVIATION")
(princ)
