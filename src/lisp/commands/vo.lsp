;;; vo.lsp -- otklonenie fakticheskoy tochki ot proektnoy otmetki (SPEC-006 v5)
;;; Komandy:
;;;   VO                  -- edinstvennaya komanda, vse nastroyki vnutri.
;;;   GC-HEIGHT-DEVIATION -- polnoe imya toy zhe komandy.
;;;
;;; PRICHINA imeni VO, a ne H: "H" -- shtatnyy alias HATCH v AutoCAD, i
;;; opredelenie c:h perekrylo by shtrihovku.
;;;
;;; v5: KNOPKI VERNULIS. v4 ubrala initget sovsem -- eto byla oshibka:
;;;     tolko initget delaet opcii KLIKABELNYMI v komandnoy stroke.
;;;     Nastoyashchaya prichina, pochemu v v3 nabrannoe "P" ne srabatyvalo:
;;;     AutoCAD opredelyaet dopustimoe sokrashchenie klyuchevogo slova po
;;;     ZAGLAVNOY bukve vnutri nego, a u kirillicy on ee ne raspoznaet --
;;;     poetomu trebovalos nabrat slovo CELIKOM ("Otmetka"), i odinochnoe
;;;     "O" ne sovpadalo ni s chem.
;;;     Reshenie: registriruem I slovo, I odnu bukvu:
;;;         (initget "Otmetka O Rezhim R Sposob S Tekst T")
;;;     Teper rabotaet i klik po knopke, i "O", i "Otmetka".
;;;     Vse varianty dispetcherizuyutsya v odno deystvie.
;;;
;;;     Knopka [Otmetka] otkryvaet vlozhennye knopki [Vruchnuyu/Obyekt]:
;;;       Vruchnuyu -- prosit vvesti novuyu otmetku chislom;
;;;       Obyekt    -- shchelkaete obyekt, ego Z stanovitsya otmetkoy.
;;;     U zaprosa chisla NET umolchaniya <4,398>: imenno pokazannoe
;;;     umolchanie v v1 pri Enter molcha ostavlyalo proshloe znachenie.
;;;
;;;     Tip proverok: vezde (listp x) vmesto (= (type x) 'STR) -- sravnenie
;;;     simvolov cherez = v AutoLISP nenadezhno.
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

;; Сравнение ответа со списком допустимых написаний.
;; ПОЧЕМУ списком, а не strcase: strcase кириллицу приводит к одному регистру
;; не во всех сборках AutoCAD, поэтому перечисляем варианты явно.
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
;; ERRNO 7 = промах (переспрашиваем), иначе — осознанный отказ.
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

;;; ====================================================================
;;; ПРОЕКТНАЯ ОТМЕТКА
;;; ====================================================================

(defun gc-vo-apply-proj (z / )
  (setq *gc-vo-proj-z* z)
  (princ (strcat "\n[i] Проектная отметка теперь " (gc-vo-fmt z) " м"))
  z)

;; Ввод отметки числом.
;; ПОЧЕМУ у запроса НЕТ умолчания <4,398>: именно показанное умолчание в v1
;; при нажатии Enter молча подставляло прошлое значение, и кнопка выглядела
;; сломанной. Здесь Enter — это явная отмена с сообщением, а не тихий возврат
;; старой отметки.
(defun gc-vo-ask-proj-manual ( / done s val)
  (princ "\nВведите новую проектную отметку в метрах.")
  (princ "\nНапример 4,398 — это 4 метра 398 миллиметров.")
  (princ "\nЗапятая и точка равнозначны, отрицательные отметки допустимы.")
  (setq done nil)
  (while (not done)
    (setq s (gc-vo-trim (getstring T "\nНовая проектная отметка, м: ")))
    (cond
      ((= s "")
       (if *gc-vo-proj-z*
         (progn
           (princ (strcat "\n[i] Отмена. Отметка осталась " (gc-vo-proj-disp)))
           (setq done T))
         (princ "\n[!] Отметка ещё не задана — введите число, например 4,398")))
      (T
       (setq val (gc-vo-parse-num s))
       (if val
         (progn (gc-vo-apply-proj val) (setq done T))
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 4,398"))))))
  *gc-vo-proj-z*)

;; Кнопка [Отметка] -> вложенные кнопки [Вручную/Объект].
;; Регистрируем и слово, и одну букву: для кириллицы AutoCAD не распознаёт
;; заглавную букву как сокращение и требует слово целиком, поэтому одиночная
;; «В» без отдельного ключевого слова не совпала бы ни с чем.
(defun gc-vo-set-proj ( / kw z)
  (princ (strcat "\n\n--- ПРОЕКТНАЯ ОТМЕТКА --- сейчас: " (gc-vo-proj-disp)))
  (princ "\n  Вручную — ввести отметку числом")
  (princ "\n  Объект  — щёлкнуть объект, его высота Z станет отметкой")
  (initget "Вручную В Объект О")
  (setq kw (getkword "\nКак задать [Вручную/Объект] (Enter — отмена): "))
  (cond
    ((null kw)
     (princ (strcat "\n[i] Отмена. Отметка осталась " (gc-vo-proj-disp)))
     ;; Отметки нет вообще — дальше считать было бы не от чего.
     (if (null *gc-vo-proj-z*)
       (progn
         (princ "\n[!] Но отметка ещё не задана — задайте её.")
         (gc-vo-set-proj))))
    ((gc-vo-is-word kw '("Вручную" "В"))
     (gc-vo-ask-proj-manual))
    (T
     (setq z (gc-vo-pick-z-object
               "\nВыберите объект — его высота Z станет проектной отметкой: "))
     (if z
       (gc-vo-apply-proj z)
       (progn
         (princ "\n[!] Объект не выбран, отметка не изменена.")
         (if (null *gc-vo-proj-z*) (gc-vo-set-proj))))))
  *gc-vo-proj-z*)

;;; ====================================================================
;;; ОСТАЛЬНЫЕ НАСТРОЙКИ
;;; ====================================================================

(defun gc-vo-proj-mode-name ( / )
  (if (= *gc-vo-proj-mode* "ASK")
    "спрашивать проектную точку каждый раз"
    "одна отметка на все точки"))

(defun gc-vo-fact-src-name ( / )
  (if (= *gc-vo-fact-src* "PT")
    "кликом по месту (нужна объектная привязка)"
    "выбором объекта"))

;; ПОЧЕМУ переключатель, а не вложенное меню: у опции всего два состояния,
;; и любое вложенное меню — лишний шанс застрять.
(defun gc-vo-toggle-proj-mode ( / )
  (setq *gc-vo-proj-mode* (if (= *gc-vo-proj-mode* "ASK") "TPL" "ASK"))
  (princ (strcat "\n[i] Режим отметки: " (gc-vo-proj-mode-name)))
  (if (= *gc-vo-proj-mode* "ASK")
    (princ (strcat "\n    Перед каждой фактической точкой команда спросит"
                   " проектную.\n    Подходит для уклона, лестницы, разных"
                   " отметок по осям."))
    (princ (strcat "\n    Одна отметка сравнивается со всеми точками."
                   "\n    Подходит для плиты, площадки, одного горизонта.")))
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
      ;; Здесь умолчание уместно: значение всегда задано, и Enter означает
      ;; «оставить», а не «я хотел поменять, но ничего не произошло».
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
;;; ЗАПАСНОЕ ТЕКСТОВОЕ МЕНЮ (по Enter)
;;; ====================================================================

;; Страховка на случай, если кнопки почему-то не отработают: здесь ввод
;; читается getstring и разбирается нашим кодом, без участия initget.
;; Возвращает T — продолжать работу, nil — выйти из команды.
(defun gc-vo-menu ( / done s res)
  (setq res T done nil)
  (while (not done)
    (princ "\n\n--- МЕНЮ VO ---")
    (princ (strcat "\n  отметка : "
                   (if (= *gc-vo-proj-mode* "ASK")
                     "спрашивается у каждой точки"
                     (gc-vo-proj-disp))))
    (princ (strcat "\n  точки   : " (gc-vo-fact-src-name)))
    (princ (strcat "\n  текст   : " (gc-vo-fmt *gc-vo-text-h*) " м"))
    (princ "\n")
    (princ "\n  1 или О — проектная отметка")
    (princ "\n  2 или Р — режим отметки: одна на все / спрашивать каждый раз")
    (princ "\n  3 или С — способ выбора точек: объектом / кликом")
    (princ "\n  4 или Т — высота текста подписи")
    (princ "\n  0 или К — выйти из команды")
    (princ "\n  Enter   — вернуться к точкам")
    (setq s (gc-vo-trim (getstring T "\nВыбор: ")))
    (cond
      ((= s "") (setq done T))
      ((gc-vo-is-word s '("1" "о" "О" "o" "O" "отметка" "Отметка"))
       (gc-vo-set-proj))
      ((gc-vo-is-word s '("2" "р" "Р" "r" "R" "режим" "Режим"))
       (gc-vo-toggle-proj-mode))
      ((gc-vo-is-word s '("3" "с" "С" "s" "S" "c" "C" "способ" "Способ"))
       (gc-vo-toggle-fact-src))
      ((gc-vo-is-word s '("4" "т" "Т" "t" "T" "текст" "Текст" "высота"))
       (gc-vo-set-text-h))
      ((gc-vo-is-word s '("0" "к" "К" "k" "K" "q" "Q" "выход" "Выход"))
       (setq res nil done T))
      (T (princ (strcat "\n[!] Не понял \"" s
                        "\". Введите 1, 2, 3, 4, 0 или просто Enter.")))))
  res)

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
;;             строка — нажата кнопка (или "MENU", если нажат Enter).
;; Промах мимо объекта из запроса НЕ выходит.
;;
;; ПОЧЕМУ ключевые слова продублированы одной буквой: для кириллицы AutoCAD
;; не распознаёт заглавную букву как допустимое сокращение и требует набрать
;; слово целиком. Отдельное ключевое слово «О» решает это — работает и клик
;; по кнопке, и «О», и «Отметка».
;;
;; ПОЧЕМУ listp, а не (= (type x) 'STR): сравнение символов через = в
;; AutoLISP ненадёжно. entsel возвращает nil, список (ename точка) или строку.
(defun gc-vo-prompt-z (prompt / res sel z)
  (setq res nil)
  (while (null res)
    (initget "Отметка О Режим Р Способ С Текст Т")
    (cond
      ((= *gc-vo-fact-src* "PT")
       (setq sel (getpoint prompt))
       (cond
         ((null sel)  (setq res "MENU"))
         ((listp sel) (setq res (caddr sel)))
         (T           (setq res sel))))
      (T
       (setq sel (entsel prompt))
       (cond
         ;; ERRNO 7 = промах мимо объекта: переспрашиваем, а не выходим.
         ((and (null sel) (= (getvar "ERRNO") 7))
          (princ "\n[!] Мимо объекта. Щёлкните точно по объекту."))
         ((null sel) (setq res "MENU"))
         ((listp sel)
          (setq z (gc-vo-entity-z (car sel)))
          (if z
            (setq res z)
            (princ "\n[!] У этого объекта нет высоты. Выберите другой.")))
         (T (setq res sel))))))
  res)

;; Обработка нажатой кнопки. Возвращает T — продолжать, nil — выйти.
(defun gc-vo-do-option (kw / )
  (cond
    ((gc-vo-is-word kw '("MENU"))          (gc-vo-menu))
    ((gc-vo-is-word kw '("Отметка" "О"))   (gc-vo-set-proj) T)
    ((gc-vo-is-word kw '("Режим"  "Р"))    (gc-vo-toggle-proj-mode) T)
    ((gc-vo-is-word kw '("Способ" "С"))    (gc-vo-toggle-fact-src) T)
    ((gc-vo-is-word kw '("Текст"  "Т"))    (gc-vo-set-text-h) T)
    (T (princ (strcat "\n[!] Кнопка \"" kw "\" не распознана.")) T)))

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
  (princ "\nКнопки в строке запроса:")
  (princ "\n  Отметка — задать проектную отметку: вручную или с объекта")
  (princ "\n  Режим   — одна отметка на все точки / спрашивать каждый раз")
  (princ "\n  Способ  — выбирать точки объектом / кликом по месту")
  (princ "\n  Текст   — высота текста подписи")
  (princ "\nКнопку можно щёлкнуть мышью или набрать её первую букву.")
  (princ "\nEnter — запасное текстовое меню, Esc — выход."))

(defun gc-vo-status ( / )
  (princ (strcat "\n\n--- VO | отметка: "
                 (if (= *gc-vo-proj-mode* "ASK")
                   "спрашивается у каждой точки"
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
  (setq prm  " [Отметка/Режим/Способ/Текст]: "
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
          ((numberp r)
           (setq z-proj r)
           (princ (strcat "\n[i] Проект этой точки: " (gc-vo-fmt z-proj) " м")))
          (T
           (if (null (gc-vo-do-option r)) (setq done T))
           (setq step-ok nil))))
      (setq z-proj *gc-vo-proj-z*))
    ;; --- Шаг 2: фактическая точка
    (if step-ok
      (progn
        (setq r (gc-vo-prompt-z (strcat "\nФАКТИЧЕСКАЯ точка" prm)))
        (cond
          ((numberp r)
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
               (princ (strcat "\n[i] Поставлена подпись " txt)))))
          (T
           (if (null (gc-vo-do-option r)) (setq done T)))))))
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

(princ "\n[gc] vo.lsp v5 загружен. Команда: VO")
(princ)
