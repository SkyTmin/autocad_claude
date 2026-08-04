;;; vo.lsp -- otklonenie fakticheskoy tochki ot proektnoy otmetki (SPEC-006 v2)
;;; Komandy:
;;;   VO                  -- osnovnaya komanda (Vysotnoe Otklonenie).
;;;   VOS                 -- srazu nastroyki VO.
;;;   GC-HEIGHT-DEVIATION -- polnoe imya komandy VO.
;;;
;;; PRICHINA imeni VO, a ne H: "H" -- shtatnyy alias HATCH v AutoCAD, i
;;; opredelenie c:h perekrylo by shtrihovku.
;;;
;;; v2: KRITICHNYY FIX -- knopka [Proekt] v v1 ne rabotala.
;;;     Prichina: klyuchevye slova initget kirillicey nenadezhny. AutoCAD
;;;     ne raspoznaet kirillicheskuyu zaglavnuyu bukvu kak sokrashchenie
;;;     klyuchevogo slova, poetomu "P" ni s chem ne sovpadalo. V sv.lsp eta
;;;     problema uzhe reshalas perehodom na cifry (initget "1 2 3").
;;;     Reshenie: VSE menyu VO na cifrah -- oni ASCII i ne zavisyat ni ot
;;;     raskladki klaviatury, ni ot kodirovki.
;;;     Takzhe v v2: rezhim proektnoy otmetki (shablon / sprashivat kazhdyy
;;;     raz), vybor istochnika vysoty fakta (obyekt / klik s privyazkoy),
;;;     razvernutye poyasneniya vo vseh menyu.
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

(setq *gc-vo-layer*       "GC-Высотные-Отклонения")
(setq *gc-vo-layer-color* 7)
(setq *gc-vo-text-h-init* 0.100) ; высота текста, предлагаемая в первый раз

;;; НАСТРОЙКИ — живут между запусками до закрытия чертежа:
;;;   *gc-vo-proj-z*     — проектная отметка, м
;;;   *gc-vo-proj-mode*  — "TPL" одна отметка на все точки / "ASK" спрашивать
;;;   *gc-vo-fact-src*   — "OBJ" выбор объекта / "PT" клик с привязкой
;;;   *gc-vo-text-h*     — высота текста, м
;;; Намеренно НЕ инициализируются при загрузке: AutoLISP возвращает nil для
;;; несвязанного символа, а сброс на nil при каждом APPLOAD стирал бы настройки.

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

;; Отметка для показа в меню: до первого задания её ещё нет.
(defun gc-vo-proj-disp ( / )
  (if *gc-vo-proj-z*
    (strcat (gc-vo-fmt *gc-vo-proj-z*) " м")
    "ещё не задана"))

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
;;; МЕНЮ — всё на цифрах
;;; ====================================================================

;; ПОЧЕМУ цифры, а не слова вроде [Проект/Высота]: кириллические ключевые
;; слова initget не работают. AutoCAD ищет в ключевом слове заглавную
;; латинскую букву, чтобы понять допустимое сокращение; в «Проект» её нет,
;; и нажатие «П» не совпадает ни с чем — кнопка молча ничего не делает.
;; Ровно этот баг был в v1. Цифры — ASCII, они не зависят ни от раскладки
;; клавиатуры, ни от кодировки файла.

;; "1 2 3" -> "1/2/3" для показа в подсказке.
(defun gc-vo-keys-disp (keys / s)
  (setq s keys)
  (while (vl-string-search " " s)
    (setq s (vl-string-subst "/" " " s)))
  s)

;; title  — заголовок меню
;; lines  — список строк-пунктов (печатаются как есть)
;; keys   — строка для initget, например "1 2 3"
;; defkey — что вернуть, если пользователь нажал Enter
(defun gc-vo-menu (title lines keys defkey / kw)
  (princ (strcat "\n\n=== " title " ==="))
  (foreach ln lines (princ (strcat "\n" ln)))
  (initget keys)
  (setq kw (getkword (strcat "\nВаш выбор [" (gc-vo-keys-disp keys)
                             "] <" defkey ">: ")))
  (if kw kw defkey))

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

;; Выбор объекта и чтение его высоты. Возвращает Z либо nil при отказе.
;; ПОЧЕМУ через ERRNO: entsel возвращает nil и при промахе, и при Enter.
;; ERRNO 7 = промах (переспрашиваем), иначе — осознанный выход.
(defun gc-vo-pick-z-object (prompt / res sel z)
  (setq res nil)
  (while (null res)
    (setq sel (entsel prompt))
    (cond
      ((null sel)
       (if (= (getvar "ERRNO") 7)
         (princ "\n[!] Мимо объекта. Щёлкните точно по объекту.")
         (setq res 'CANCEL)))
      (T
       (setq z (gc-vo-entity-z (car sel)))
       (if z
         (setq res z)
         (princ "\n[!] У этого объекта нет высоты. Выберите другой.")))))
  (if (equal res 'CANCEL) nil res))

;; Высота из точки клика. Работает только с включённой объектной привязкой.
(defun gc-vo-pick-z-point (prompt / p)
  (setq p (getpoint prompt))
  (if p (caddr p) nil))

;;; ====================================================================
;;; НАСТРОЙКИ
;;; ====================================================================

(defun gc-vo-proj-mode-name ( / )
  (if (= *gc-vo-proj-mode* "ASK")
    "спрашивать проектную точку каждый раз"
    "одна отметка на все точки (шаблон)"))

(defun gc-vo-fact-src-name ( / )
  (if (= *gc-vo-fact-src* "PT")
    "кликом по месту (нужна объектная привязка)"
    "выбором объекта (надёжнее)"))

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
          (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 4,398")))
         ((and positive-only (<= val 1.0e-9))
          (princ "\n[!] Высота текста должна быть больше нуля."))
         (T (setq res val))))))
  res)

(defun gc-vo-set-proj-manual ( / )
  (princ "\nВведите проектную отметку в метрах.")
  (princ "\nНапример 4,398 — это 4 метра 398 миллиметров.")
  (princ "\nЗапятая и точка равнозначны, отрицательные отметки допустимы.")
  (setq *gc-vo-proj-z*
        (gc-vo-ask-num "Проектная отметка, м" *gc-vo-proj-z* nil))
  (princ (strcat "\n[i] Проектная отметка: " (gc-vo-fmt *gc-vo-proj-z*) " м"))
  *gc-vo-proj-z*)

(defun gc-vo-apply-proj (z / )
  (cond
    (z
     (setq *gc-vo-proj-z* z)
     (princ (strcat "\n[i] Проектная отметка: " (gc-vo-fmt z) " м")))
    (T
     (princ "\n[!] Отменено, отметка не изменена.")
     ;; Отметки нет вообще — иначе дальше считали бы от nil.
     (if (null *gc-vo-proj-z*) (gc-vo-set-proj-manual))))
  *gc-vo-proj-z*)

(defun gc-vo-set-proj ( / choice)
  (setq choice
    (gc-vo-menu
      "ПРОЕКТНАЯ ОТМЕТКА"
      (list
        (strcat "  Сейчас: " (gc-vo-proj-disp))
        ""
        "  1 = ввести число вручную"
        "      Например 4,398 — это 4 метра 398 миллиметров."
        "      Запятая и точка равнозначны, минус допустим."
        ""
        "  2 = взять с объекта"
        "      Щёлкнете по объекту — его высота Z станет проектной отметкой."
        "      Подходит для COGO Point, точки, круга, линии, блока."
        ""
        "  3 = взять кликом по месту"
        "      Щёлкнете место в модели — возьмётся высота точки клика."
        "      ВАЖНО: включите объектную привязку (Узел, Конточка),"
        "      иначе вернётся высота плоскости построений, обычно 0.")
      "1 2 3" "1"))
  (cond
    ((= choice "1") (gc-vo-set-proj-manual))
    ((= choice "2")
     (gc-vo-apply-proj
       (gc-vo-pick-z-object
         "\nВыберите объект, его высота станет проектной отметкой: ")))
    (T
     (gc-vo-apply-proj
       (gc-vo-pick-z-point
         "\nУкажите точку, её высота станет проектной отметкой: "))))
  *gc-vo-proj-z*)

(defun gc-vo-set-proj-mode ( / choice)
  (setq choice
    (gc-vo-menu
      "РЕЖИМ ПРОЕКТНОЙ ОТМЕТКИ"
      (list
        (strcat "  Сейчас: " (gc-vo-proj-mode-name))
        ""
        "  1 = ОДНА отметка на все точки (шаблон)"
        "      Задали один раз — дальше команда её не спрашивает."
        "      Каждая фактическая точка сравнивается с этой отметкой."
        "      Подходит, когда весь участок на одном горизонте:"
        "      плита, площадка, один уровень."
        ""
        "  2 = СПРАШИВАТЬ проектную точку каждый раз"
        "      Перед каждой фактической точкой команда сначала попросит"
        "      проектную. Подходит, когда у каждой точки свой проект:"
        "      уклон, лестница, разные отметки по осям.")
      "1 2"
      (if (= *gc-vo-proj-mode* "ASK") "2" "1")))
  (setq *gc-vo-proj-mode* (if (= choice "2") "ASK" "TPL"))
  (princ (strcat "\n[i] Режим: " (gc-vo-proj-mode-name)))
  ;; В режиме шаблона отметка обязана быть задана до начала работы.
  (if (and (= *gc-vo-proj-mode* "TPL") (null *gc-vo-proj-z*))
    (gc-vo-set-proj))
  *gc-vo-proj-mode*)

(defun gc-vo-set-fact-src ( / choice)
  (setq choice
    (gc-vo-menu
      "КАК ВЫБИРАТЬ ТОЧКИ"
      (list
        (strcat "  Сейчас: " (gc-vo-fact-src-name))
        ""
        "  1 = ВЫБОРОМ ОБЪЕКТА — надёжнее"
        "      Щёлкаете прямо по объекту точки съёмки, берётся его высота Z."
        "      Промахнётесь мимо объекта — команда заметит и переспросит."
        "      Ошибиться высотой практически невозможно."
        ""
        "  2 = КЛИКОМ ПО МЕСТУ — быстрее"
        "      Щёлкаете место в модели, высота берётся из точки клика."
        "      ВАЖНО: нужна включённая объектная привязка (Узел, Конточка)."
        "      Без привязки или при промахе вернётся высота плоскости"
        "      построений — обычно 0 — и отклонение будет неверным,"
        "      причём команда об этом не узнает.")
      "1 2"
      (if (= *gc-vo-fact-src* "PT") "2" "1")))
  (setq *gc-vo-fact-src* (if (= choice "2") "PT" "OBJ"))
  (princ (strcat "\n[i] Выбор точек: " (gc-vo-fact-src-name)))
  *gc-vo-fact-src*)

(defun gc-vo-set-text-h ( / )
  (princ "\n\n=== ВЫСОТА ТЕКСТА ПОДПИСИ ===")
  (princ "\nВысота символов подписи в метрах чертежа.")
  (princ "\nНапример 0,100 — это 100 мм на чертеже.")
  (setq *gc-vo-text-h*
        (gc-vo-ask-num "Высота текста, м"
                       (if *gc-vo-text-h* *gc-vo-text-h* *gc-vo-text-h-init*)
                       T))
  (princ (strcat "\n[i] Высота текста: " (gc-vo-fmt *gc-vo-text-h*) " м"))
  *gc-vo-text-h*)

(defun gc-vo-settings ( / choice done)
  (gc-vo-defaults)
  (setq done nil)
  (while (not done)
    (setq choice
      (gc-vo-menu
        "НАСТРОЙКИ VO"
        (list
          "  1 = проектная отметка"
          (strcat "      сейчас: " (gc-vo-proj-disp))
          ""
          "  2 = режим проектной отметки"
          (strcat "      сейчас: " (gc-vo-proj-mode-name))
          ""
          "  3 = как выбирать точки"
          (strcat "      сейчас: " (gc-vo-fact-src-name))
          ""
          "  4 = высота текста подписи"
          (strcat "      сейчас: " (gc-vo-fmt *gc-vo-text-h*) " м")
          ""
          "  5 = закрыть настройки и вернуться к работе")
        "1 2 3 4 5" "5"))
    (cond
      ((= choice "1") (gc-vo-set-proj))
      ((= choice "2") (gc-vo-set-proj-mode))
      ((= choice "3") (gc-vo-set-fact-src))
      ((= choice "4") (gc-vo-set-text-h))
      (T (setq done T))))
  (princ))

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
;;; ЗАПРОС ТОЧКИ
;;; ====================================================================

;; Спрашивает точку способом из настроек и возвращает её высоту.
;; Возвращает: число    — высота выбранной точки,
;;             "SET"    — пользователь нажал 1, нужны настройки,
;;             nil      — Enter/Esc, выход.
(defun gc-vo-prompt-z (prompt / res sel z)
  (setq res nil)
  (while (null res)
    (initget "1")
    (cond
      ((= *gc-vo-fact-src* "PT")
       (setq sel (getpoint prompt))
       (cond
         ((null sel)                (setq res 'EXIT))
         ((= (type sel) 'STR)       (setq res 'SET))
         (T                         (setq res (caddr sel)))))
      (T
       (setq sel (entsel prompt))
       (cond
         ;; ERRNO 7 = промах мимо объекта: переспрашиваем, а не выходим.
         ((and (null sel) (= (getvar "ERRNO") 7))
          (princ "\n[!] Мимо объекта. Щёлкните точно по объекту."))
         ((null sel)          (setq res 'EXIT))
         ((= (type sel) 'STR) (setq res 'SET))
         (T
          (setq z (gc-vo-entity-z (car sel)))
          (if z
            (setq res z)
            (princ "\n[!] У этого объекта нет высоты. Выберите другой.")))))))
  (cond
    ((equal res 'EXIT) nil)
    ((equal res 'SET)  "SET")
    (T                 res)))

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-vo-defaults ( / )
  (if (null *gc-vo-proj-mode*) (setq *gc-vo-proj-mode* "TPL"))
  (if (null *gc-vo-fact-src*)  (setq *gc-vo-fact-src*  "OBJ"))
  (if (null *gc-vo-text-h*)    (setq *gc-vo-text-h*    *gc-vo-text-h-init*)))

(defun gc-vo-intro ( / )
  (princ "\n\n=== VO — отклонение фактической высоты от проектной ===")
  (princ "\nПодписывает, насколько точка выше (+) или ниже (-) проекта, в мм.")
  (princ "\nВ любом запросе точки: 1 — настройки, Enter — выход."))

(defun gc-vo-status ( / )
  (princ (strcat "\n\n--- VO | проект: "
                 (if (= *gc-vo-proj-mode* "ASK")
                   "спрашивается каждый раз"
                   (gc-vo-proj-disp))
                 " | точки: "
                 (if (= *gc-vo-fact-src* "PT") "кликом" "объектом")
                 " | текст: " (gc-vo-fmt *gc-vo-text-h*) " м ---")))

(defun gc-vo-run ( / done step-ok r z-proj z-fact dev-mm txt pt)
  (gc-vo-defaults)
  (gc-vo-intro)
  ;; В режиме шаблона отметка нужна до старта; в режиме ASK — не нужна.
  (if (and (= *gc-vo-proj-mode* "TPL") (null *gc-vo-proj-z*))
    (gc-vo-set-proj))
  (setq done nil)
  (while (not done)
    (gc-vo-status)
    (setq step-ok T
          z-proj  nil)
    ;; --- Шаг 1: проектная отметка (только в режиме "спрашивать каждый раз")
    (if (= *gc-vo-proj-mode* "ASK")
      (progn
        (setq r (gc-vo-prompt-z
                  "\nПРОЕКТНАЯ точка (1 - настройки, Enter - выход): "))
        (cond
          ((null r)         (setq done T step-ok nil))
          ((equal r "SET")  (gc-vo-settings) (setq step-ok nil))
          (T
           (setq z-proj r)
           (princ (strcat "\n[i] Проект этой точки: " (gc-vo-fmt z-proj) " м")))))
      (setq z-proj *gc-vo-proj-z*))
    ;; --- Шаг 2: фактическая точка
    (if step-ok
      (progn
        (setq r (gc-vo-prompt-z
                  "\nФАКТИЧЕСКАЯ точка (1 - настройки, Enter - выход): "))
        (cond
          ((null r)        (setq done T))
          ((equal r "SET") (gc-vo-settings))
          (T
           (setq z-fact r)
           (setq dev-mm (gc-vo-round (* 1000.0 (- z-fact z-proj))))
           (setq txt    (gc-vo-fmt-dev dev-mm))
           (princ (strcat "\n[i] Факт " (gc-vo-fmt z-fact)
                          "  -  проект " (gc-vo-fmt z-proj)
                          "  =  " txt))
           ;; --- Шаг 3: место подписи
           (setq pt (getpoint "\nКуда поставить подпись: "))
           (if (null pt)
             ;; Не выходим из команды: вычисление сделано, Шамиль мог просто
             ;; промахнуться — возвращаемся к следующей точке.
             (princ "\n[!] Место не указано, подпись не поставлена.")
             (progn
               (gc-vo-draw-text pt txt)
               (princ (strcat "\n[i] Поставлена подпись " txt)))))))))
  (princ "\n[i] VO завершена.")
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

;; Отдельный вход в настройки — на случай, если удобнее открыть их сразу.
(defun c:vos ( / *error*)
  (defun *error* (msg)
    (if (and msg
             (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\n[ОШИБКА] VOS: " msg))
      (princ "\n[ОТМЕНА] VOS прерван."))
    (princ))
  (gc-vo-settings)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-height-deviation ( / )
  (c:vo))

(princ "\n[gc] vo.lsp v2 загружен. Команды: VO (работа), VOS (настройки)")
(princ)
