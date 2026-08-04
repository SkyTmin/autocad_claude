;;; vo.lsp -- otklonenie fakticheskoy tochki ot proektnoy otmetki (SPEC-006 v3)
;;; Komandy:
;;;   VO                  -- edinstvennaya komanda, vse nastroyki vnutri.
;;;   GC-HEIGHT-DEVIATION -- polnoe imya toy zhe komandy.
;;;
;;; PRICHINA imeni VO, a ne H: "H" -- shtatnyy alias HATCH v AutoCAD, i
;;; opredelenie c:h perekrylo by shtrihovku.
;;;
;;; v3: ISPRAVLENA prichina, pochemu opciya [Proekt] "srazu podstavlyala
;;;     proshluyu otmetku". V v1 tam byla CEPOCHKA iz dvuh vlozhennyh
;;;     zaprosov, u kazhdogo svoyo umolchanie:
;;;         getkword "Proektnaya otmetka [Obyekt/Vvod] <Vvod>"
;;;         -> getstring "Proektnaya otmetka, m <4,398>"
;;;     Dva Enter'a podryad molcha ostavlyali staroe znachenie, hotya
;;;     Shamil zhal [Proekt] imenno chtoby ego pomenyat.
;;;     Teper zapros ODIN: chislo vvoditsya pryamo v nem, O / T -- eto
;;;     alternativy (vzyat s obyekta / vzyat klikom), a u Enter net
;;;     umolchaniya "podstavit proshloe" -- on lish vyhodit i vsluh
;;;     soobshchaet, chto otmetka ne izmenena.
;;;     Opcii vernuty na russkie slova (v2 oshibochno perevodila ih na cifry:
;;;     gipoteza pro kirillicu v initget okazalas nevernoy -- opciya [Vysota]
;;;     u Shamilya rabotala).
;;;     Otdelnaya komanda VOS ubrana: vse nastroyki dostupny iz VO.
;;;     Dobavleny opcii [Rezhim] i [Sposob] -- prostye pereklyuchateli.
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
;;; СТРОКИ И ЧИСЛА
;;; ====================================================================

;; Обрезка пробелов по краям без vl-string-trim — чтобы не зависеть от того,
;; как конкретная сборка обрабатывает не-ASCII.
(defun gc-vo-trim (s / )
  (while (and (> (strlen s) 0) (= (substr s 1 1) " "))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) " "))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; Сравнение введённого слова со списком допустимых написаний.
;; ПОЧЕМУ списком, а не strcase: strcase кириллицу приводит к одному регистру
;; не во всех сборках AutoCAD, поэтому перечисляем варианты явно —
;; и русские, и латинские на случай непереключённой раскладки.
(defun gc-vo-is-word (s variants)
  (if (member s variants) T nil))

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

;; Отметка для показа: до первого задания её ещё нет.
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
    "одна отметка на все точки"))

(defun gc-vo-fact-src-name ( / )
  (if (= *gc-vo-fact-src* "PT")
    "кликом по месту (нужна объектная привязка)"
    "выбором объекта"))

(defun gc-vo-apply-proj (z / )
  (setq *gc-vo-proj-z* z)
  (princ (strcat "\n[i] Проектная отметка теперь " (gc-vo-fmt z) " м"))
  z)

;;; ПРОЕКТНАЯ ОТМЕТКА.
;;; Тот самый запрос, который в v1 «сразу подставлял прошлую отметку».
;;; ПРИЧИНА была в цепочке из двух вложенных запросов, у каждого своё
;;; умолчание: getkword "[Объект/Ввод] <Ввод>" -> getstring "<4,398>".
;;; Два Enter'а подряд молча оставляли старое значение, хотя Шамиль жал
;;; [Проект] именно чтобы его поменять.
;;; Теперь запрос ОДИН, число вводится прямо в нём, у Enter нет умолчания
;;; «подставить прошлое» — он лишь выходит и вслух говорит, что не изменил.
(defun gc-vo-set-proj ( / done s z val)
  (princ "\n\n--- ПРОЕКТНАЯ ОТМЕТКА ---")
  (princ (strcat "\nСейчас: " (gc-vo-proj-disp)))
  (princ "\nЧто можно ввести:")
  (princ "\n  число  — сама отметка, например 4,398 (это 4 м 398 мм)")
  (princ "\n  О      — взять высоту с объекта: щёлкнете по нему")
  (princ "\n  Т      — взять высоту кликом по месту (нужна привязка)")
  (setq done nil)
  (while (not done)
    (setq s (gc-vo-trim
              (getstring T "\nОтметка, либо О, либо Т (Enter — ничего не менять): ")))
    (cond
      ;; Enter — выход БЕЗ изменения, но всегда с явным сообщением, что
      ;; именно осталось. Молча подставлять прошлое значение нельзя: ровно
      ;; это в v1 выглядело как «кнопка сама выбрала старую отметку».
      ((= s "")
       (if *gc-vo-proj-z*
         (progn
           (princ (strcat "\n[i] Отметка НЕ изменена, осталась "
                          (gc-vo-fmt *gc-vo-proj-z*) " м"))
           (setq done T))
         (princ "\n[!] Отметка ещё не задана — введите число, О или Т.")))
      ((gc-vo-is-word s '("о" "О" "o" "O" "объект" "Объект" "ОБЪЕКТ"))
       (setq z (gc-vo-pick-z-object "\nВыберите объект, его высота станет отметкой: "))
       (if z
         (progn (gc-vo-apply-proj z) (setq done T))
         (princ "\n[!] Объект не выбран. Введите число, О или Т.")))
      ((gc-vo-is-word s '("т" "Т" "t" "T" "точка" "Точка" "ТОЧКА"))
       (setq z (gc-vo-pick-z-point "\nУкажите точку, её высота станет отметкой: "))
       (if z
         (progn (gc-vo-apply-proj z) (setq done T))
         (princ "\n[!] Точка не указана. Введите число, О или Т.")))
      (T
       (setq val (gc-vo-parse-num s))
       (if val
         (progn (gc-vo-apply-proj val) (setq done T))
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 4,398,"
                        " либо О, либо Т."))))))
  *gc-vo-proj-z*)

;; ПОЧЕМУ переключатель, а не вложенное меню: у опции всего два состояния,
;; и любое вложенное меню — лишний шанс застрять, как это было с [Проект] в v1.
(defun gc-vo-toggle-proj-mode ( / )
  (setq *gc-vo-proj-mode* (if (= *gc-vo-proj-mode* "ASK") "TPL" "ASK"))
  (princ (strcat "\n[i] Режим отметки: " (gc-vo-proj-mode-name)))
  (if (= *gc-vo-proj-mode* "ASK")
    (princ (strcat "\n    Перед каждой фактической точкой команда спросит"
                   " проектную.\n    Подходит для уклона, лестницы, разных"
                   " отметок по осям."))
    (princ (strcat "\n    Одна отметка сравнивается со всеми точками."
                   "\n    Подходит для плиты, площадки, одного горизонта.")))
  ;; В режиме одной отметки она обязана быть задана — иначе считать не от чего.
  (if (and (= *gc-vo-proj-mode* "TPL") (null *gc-vo-proj-z*))
    (gc-vo-set-proj))
  *gc-vo-proj-mode*)

(defun gc-vo-toggle-fact-src ( / )
  (setq *gc-vo-fact-src* (if (= *gc-vo-fact-src* "PT") "OBJ" "PT"))
  (princ (strcat "\n[i] Способ выбора точек: " (gc-vo-fact-src-name)))
  (if (= *gc-vo-fact-src* "PT")
    (princ (strcat "\n    Щёлкаете место в модели, высота берётся из точки"
                   " клика.\n    ВНИМАНИЕ: нужна включённая объектная привязка"
                   " (Узел, Конточка).\n    Без неё вернётся высота плоскости"
                   " построений — обычно 0 — и\n    отклонение будет неверным,"
                   " а команда об этом не узнает."))
    (princ (strcat "\n    Щёлкаете прямо по объекту точки съёмки, берётся его"
                   " высота Z.\n    Промах мимо объекта команда заметит"
                   " и переспросит.")))
  *gc-vo-fact-src*)

(defun gc-vo-set-text-h ( / res s val)
  (princ "\n\n--- ВЫСОТА ТЕКСТА ПОДПИСИ ---")
  (princ "\nВысота символов подписи в метрах чертежа.")
  (princ "\nНапример 0,100 — это 100 мм на чертеже.")
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "0, 100"
    ;; молча превратилось бы в "0," = 0 м.
    (setq s (gc-vo-trim
              (getstring T (strcat "\nВысота текста, м <"
                                   (gc-vo-fmt *gc-vo-text-h*) ">: "))))
    (cond
      ((= s "") (setq res *gc-vo-text-h*))
      (T
       (setq val (gc-vo-parse-num s))
       (cond
         ((null val)
          (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 0,100")))
         ((<= val 1.0e-9)
          (princ "\n[!] Высота текста должна быть больше нуля."))
         (T (setq res val))))))
  (setq *gc-vo-text-h* res)
  (princ (strcat "\n[i] Высота текста теперь " (gc-vo-fmt *gc-vo-text-h*) " м"))
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
;;; ЗАПРОС ТОЧКИ
;;; ====================================================================

;; Спрашивает точку способом из настроек.
;; Возвращает: число — высота выбранной точки,
;;             строка — нажата опция (Проект / Режим / Способ / Высота),
;;             nil    — Enter/Esc, выход из команды.
(defun gc-vo-prompt-z (prompt / res sel z)
  (setq res nil)
  (while (null res)
    ;; Латинские дубли — на случай непереключённой раскладки.
    (initget "Проект Режим Способ Высота Proekt Rezhim Sposob Vysota")
    (cond
      ((= *gc-vo-fact-src* "PT")
       (setq sel (getpoint prompt))
       (cond
         ((null sel)          (setq res 'EXIT))
         ((= (type sel) 'STR) (setq res sel))
         (T                   (setq res (caddr sel)))))
      (T
       (setq sel (entsel prompt))
       (cond
         ;; ERRNO 7 = промах мимо объекта: переспрашиваем, а не выходим.
         ((and (null sel) (= (getvar "ERRNO") 7))
          (princ "\n[!] Мимо объекта. Щёлкните точно по объекту."))
         ((null sel)          (setq res 'EXIT))
         ((= (type sel) 'STR) (setq res sel))
         (T
          (setq z (gc-vo-entity-z (car sel)))
          (if z
            (setq res z)
            (princ "\n[!] У этого объекта нет высоты. Выберите другой.")))))))
  (if (equal res 'EXIT) nil res))

;; Обработка нажатой опции.
(defun gc-vo-handle-option (kw / )
  (cond
    ((member kw '("Проект" "Proekt")) (gc-vo-set-proj))
    ((member kw '("Режим"  "Rezhim")) (gc-vo-toggle-proj-mode))
    ((member kw '("Способ" "Sposob")) (gc-vo-toggle-fact-src))
    ((member kw '("Высота" "Vysota")) (gc-vo-set-text-h))
    (T (princ (strcat "\n[!] Опция \"" kw "\" не распознана."))))
  T)

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
  (princ "\nВ запросе точки доступны опции:")
  (princ "\n  Проект — задать проектную отметку (число, объект или клик)")
  (princ "\n  Режим  — одна отметка на все точки / спрашивать каждый раз")
  (princ "\n  Способ — выбирать точки объектом / кликом по месту")
  (princ "\n  Высота — высота текста подписи")
  (princ "\n  Enter  — выход"))

(defun gc-vo-status ( / )
  (princ (strcat "\n\n--- VO | отметка: "
                 (if (= *gc-vo-proj-mode* "ASK")
                   "спрашивается каждый раз"
                   (gc-vo-proj-disp))
                 " | точки: "
                 (if (= *gc-vo-fact-src* "PT") "кликом" "объектом")
                 " | текст: " (gc-vo-fmt *gc-vo-text-h*) " м ---")))

(defun gc-vo-run ( / done step-ok r z-proj z-fact dev-mm txt pt prm)
  (gc-vo-defaults)
  (gc-vo-intro)
  ;; В режиме одной отметки она нужна до старта; в режиме ASK — не нужна.
  (if (and (= *gc-vo-proj-mode* "TPL") (null *gc-vo-proj-z*))
    (gc-vo-set-proj))
  (setq prm  " [Проект/Режим/Способ/Высота]: "
        done nil)
  (while (not done)
    (gc-vo-status)
    (setq step-ok T
          z-proj  nil)
    ;; --- Шаг 1: проектная отметка (только в режиме «спрашивать каждый раз»)
    (if (= *gc-vo-proj-mode* "ASK")
      (progn
        (setq r (gc-vo-prompt-z (strcat "\nПРОЕКТНАЯ точка" prm)))
        (cond
          ((null r)          (setq done T step-ok nil))
          ((= (type r) 'STR) (gc-vo-handle-option r) (setq step-ok nil))
          (T
           (setq z-proj r)
           (princ (strcat "\n[i] Проект этой точки: " (gc-vo-fmt z-proj) " м")))))
      (setq z-proj *gc-vo-proj-z*))
    ;; --- Шаг 2: фактическая точка
    (if step-ok
      (progn
        (setq r (gc-vo-prompt-z (strcat "\nФАКТИЧЕСКАЯ точка" prm)))
        (cond
          ((null r)          (setq done T))
          ((= (type r) 'STR) (gc-vo-handle-option r))
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
;;; КОМАНДА
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

(princ "\n[gc] vo.lsp v3 загружен. Команда: VO")
(princ)
