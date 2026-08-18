;;; vid.lsp -- vydelenie obyektov ramkoy zadannogo razmera (SPEC-005 v6)
;;; Komandy:
;;;   VID               -- korotkiy alias dlya ezhednevnoy raboty.
;;;   GC-SELECT-BY-SIZE -- polnoe imya toy zhe komandy.
;;;
;;; Tochka privyazki -- LEVYY VERHNIY ugol: ramka rastet vpravo i vniz.
;;;
;;; v6: KNOPKI VERNULIS. v5 ubrala initget sovsem -- eto byla oshibka:
;;;     tolko initget delaet opcii KLIKABELNYMI v komandnoy stroke.
;;;     Nastoyashchaya prichina, pochemu nabrannaya bukva ne srabatyvala:
;;;     AutoCAD opredelyaet dopustimoe sokrashchenie klyuchevogo slova po
;;;     ZAGLAVNOY bukve vnutri nego, a u kirillicy on ee ne raspoznaet --
;;;     poetomu trebovalos nabrat slovo CELIKOM ("Razmery").
;;;     Reshenie: registriruem I slovo, I odnu bukvu:
;;;         (initget "Razmery R Tip T")
;;;     Enter po-prezhnemu otkryvaet zapasnoe tekstovoe menyu.
;;;
;;; v5 (otmenena): KLYUCHEVYE SLOVA initget UBRANY SOVSEM. U Shamilya oni ne
;;;     srabatyvali (podtverzhdeno na vo.lsp): nabrannaya bukva ne
;;;     raspoznavalas kak opciya, zapros proglatyval ee i prinimal
;;;     sleduyushchiy klik za ukazanie ugla.
;;;     Teper zapros prinimaet TOLKO klik ili Enter. Enter otkryvaet menyu,
;;;     gde vvod chitaetsya getstring i razbiraetsya nami -- eto ne zavisit
;;;     ni ot initget, ni ot raskladki, ni ot kodirovki.
;;;     V menyu prinimayutsya i cifra, i russkaya bukva, i slovo celikom.
;;;
;;; v4: opcii vozvrashcheny na russkie slova [Razmery/Tip].
;;;     v3 perevodila ih na cifry iz-za oshibochnoy gipotezy, budto
;;;     kirillicheskie klyuchevye slova initget ne rabotayut. Gipoteza
;;;     oprovergnuta: u Shamilya opciya [Vysota] v vo.lsp rabotala.
;;;     Nastoyashchaya prichina toy polomki byla drugaya i k vid.lsp
;;;     otnosheniya ne imela -- sm. vo.lsp v3.
;;;
;;; v2: 1) Razmery stali SHABLONOM: zadayutsya odin raz, dalshe kazhdyy zapusk
;;;        eto odin klik. Oprosy vozvrashchayutsya tolko po zaprosu [Razmery].
;;;     2) Dobavlen vybor tipa vydeleniya [Tip]: sinee (celikom) / zelenoe
;;;        (kasanie). Dlya uzkoy polosy sinee beret pochti nichego.
;;;     3) ssget "_W" zamenen na "_WP"/"_CP" -- yavnyy chetyrehugolnik.
;;;        PRICHINA: "_W" stroit pryamougolnik po dvum uglam i pri povernutoy
;;;        PSK ne povorachivaetsya vmeste s chertezhom.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/vid.lsp").
;;; Zavisimosti: Visual LISP (vl-string-subst).

(vl-load-com)

;;; ====================================================================
;;; ШАБЛОН — размеры и тип выделения живут между запусками
;;; ====================================================================

;; *gc-vid-size-y* / *gc-vid-size-x* / *gc-vid-mode* намеренно НЕ
;; инициализируются при загрузке: AutoLISP возвращает nil для несвязанного
;; символа, а сброс на nil при каждом APPLOAD стирал бы шаблон.
;; ПОЧЕМУ шаблон: Шамиль выделяет десятки одинаковых участков подряд.
;; Ввод размеров каждый раз — та самая рутина, ради которой писалась команда.
;; *gc-vid-mode*: "W" — синее (целиком), "C" — зелёное (касание).

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
;; default — текущее значение шаблона либо nil.
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
;;; НАСТРОЙКА ШАБЛОНА
;;; ====================================================================

;; Порядок опроса — как просил Шамиль: сначала Y (длина), потом X (ширина).
(defun gc-vid-set-sizes ( / )
  (setq *gc-vid-size-y*
        (gc-vid-ask-size "Размер по Y (сверху вниз), м" *gc-vid-size-y*))
  (setq *gc-vid-size-x*
        (gc-vid-ask-size "Размер по X (слева направо), м" *gc-vid-size-x*))
  (princ (strcat "\n[i] Шаблон сохранён: "
                 (gc-vid-fmt *gc-vid-size-x*) " x "
                 (gc-vid-fmt *gc-vid-size-y*) " м (X x Y)."))
  T)

(defun gc-vid-mode-name ( / )
  (if (= *gc-vid-mode* "C")
    "ЗЕЛЁНОЕ (всё, чего коснулась рамка)"
    "СИНЕЕ (только попавшие целиком)"))

;; Обрезка пробелов по краям без vl-string-trim — чтобы не зависеть от того,
;; как конкретная сборка обрабатывает не-ASCII.
(defun gc-vid-trim (s / )
  (while (and (> (strlen s) 0) (= (substr s 1 1) " "))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) " "))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; ПОЧЕМУ меню по Enter, а не опции [Размеры/Тип] в самом запросе точки:
;; ключевые слова initget у Шамиля не срабатывали — набранная буква не
;; распознавалась как опция, запрос проглатывал её и принимал следующий клик
;; за указание угла. Здесь ввод читает getstring, а разбираем его мы сами:
;; это не зависит ни от initget, ни от раскладки, ни от кодировки.
;; Принимается и цифра, и русская буква, и слово целиком.
;; Возвращает "BACK" (вернуться к выделению) либо "EXIT" (выйти из команды).
(defun gc-vid-menu ( / done s res)
  (setq res "BACK" done nil)
  (while (not done)
    (princ "\n\n--- МЕНЮ VID ---")
    (princ (strcat "\n  рамка : " (gc-vid-fmt *gc-vid-size-x*) " x "
                   (gc-vid-fmt *gc-vid-size-y*) " м (X x Y)"))
    (princ (strcat "\n  тип   : " (gc-vid-mode-name)))
    (princ "\n")
    (princ "\n  1 или Р — размеры рамки")
    (princ "\n  2 или Т — тип выделения: синее / зелёное")
    (princ "\n  0 или К — выйти из команды")
    (princ "\n  Enter   — вернуться к выделению")
    (setq s (gc-vid-trim (getstring T "\nВыбор: ")))
    (cond
      ((= s "") (setq res "BACK" done T))
      ((member s '("1" "р" "Р" "r" "R" "размеры" "Размеры" "размер"))
       (gc-vid-set-sizes))
      ((member s '("2" "т" "Т" "t" "T" "тип" "Тип"))
       (gc-vid-toggle-mode))
      ((member s '("0" "к" "К" "k" "K" "q" "Q" "выход" "Выход"))
       (setq res "EXIT" done T))
      (T (princ (strcat "\n[!] Не понял \"" s
                        "\". Введите 1, 2, 0 или просто Enter.")))))
  res)

(defun gc-vid-toggle-mode ( / )
  (setq *gc-vid-mode* (if (= *gc-vid-mode* "C") "W" "C"))
  (princ (strcat "\n[i] Тип выделения: " (gc-vid-mode-name)))
  T)

;;; ====================================================================
;;; ВЫДЕЛЕНИЕ
;;; ====================================================================

(defun gc-vid-select (pt / x1 y1 z x2 y2 poly ss cnt)
  (setq x1 (car  pt)
        y1 (cadr pt)
        z  (caddr pt))
  ;; Левый верхний угол: X растёт вправо, Y убывает вниз.
  (setq x2 (+ x1 *gc-vid-size-x*)
        y2 (- y1 *gc-vid-size-y*))
  ;; ПОЧЕМУ четырёхугольник, а не два угла через "_W": "_W" строит
  ;; прямоугольник по осям и при повёрнутой ПСК не поворачивается вместе
  ;; с чертежом — рамка уезжает. Явные 4 угла задаются в текущей ПСК и
  ;; поворачиваются корректно. Общий Z держит углы в одной плоскости.
  (setq poly (list (list x1 y1 z)
                   (list x2 y1 z)
                   (list x2 y2 z)
                   (list x1 y2 z)))
  (princ (strcat "\n[i] Область ПСК: X " (rtos x1 2 3) " ... " (rtos x2 2 3)
                 "   Y " (rtos y2 2 3) " ... " (rtos y1 2 3)))
  ;; Узкая полоса + синий режим = почти пустой результат: объект шире полосы
  ;; целиком в неё не влезает. Предупреждаем до выборки, а не после.
  (if (and (/= *gc-vid-mode* "C")
           (< (min *gc-vid-size-x* *gc-vid-size-y*) 0.100))
    (princ (strcat "\n[!] Рамка узкая, а тип СИНИЙ — попадут только объекты"
                   " уже самой рамки.\n    Для полосы обычно нужен ЗЕЛЁНЫЙ:"
                   " нажмите кнопку Тип.")))
  (setq ss (if (= *gc-vid-mode* "C")
             (ssget "_CP" poly)
             (ssget "_WP" poly)))
  (cond
    ((null ss)
     (princ "\n[i] Ничего не выделено.")
     nil)
    (T
     (setq cnt (sslength ss))
     ;; sssetfirst оставляет объекты выделенными с ручками после выхода из
     ;; команды — можно сразу Delete / Move / задать свойства.
     (sssetfirst nil ss)
     (princ (strcat "\n[i] Выделено объектов: " (itoa cnt)))
     ss)))

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-vid-run ( / inp done)
  ;; Первый запуск за сеанс: шаблона ещё нет — спрашиваем размеры.
  (if (or (null *gc-vid-size-y*) (null *gc-vid-size-x*))
    (gc-vid-set-sizes))
  (if (null *gc-vid-mode*) (setq *gc-vid-mode* "W"))
  (setq done nil)
  (while (not done)
    (princ (strcat "\nVID: рамка "
                   (gc-vid-fmt *gc-vid-size-x*) " x "
                   (gc-vid-fmt *gc-vid-size-y*) " м (X x Y)  |  тип "
                   (gc-vid-mode-name)))
    ;; Ключевые слова продублированы одной буквой: для кириллицы AutoCAD
    ;; не распознаёт заглавную букву как допустимое сокращение и требует
    ;; набрать слово целиком. Отдельное ключевое слово «Р» решает это —
    ;; работает и клик по кнопке, и «Р», и «Размеры».
    ;; ПОЧЕМУ listp, а не (= (type x) 'STR): сравнение символов через =
    ;; в AutoLISP ненадёжно. getpoint возвращает nil, список или строку.
    (initget "Размеры Р Тип Т")
    (setq inp (getpoint "\nЛевый верхний угол области [Размеры/Тип]: "))
    (cond
      ;; Enter — запасное текстовое меню на случай, если кнопки не отработают.
      ((null inp)
       (if (= (gc-vid-menu) "EXIT")
         (progn (princ "\n[i] VID завершён.") (setq done T))))
      ((listp inp)
       (gc-vid-select inp)
       (setq done T))
      ((member inp '("Размеры" "Р")) (gc-vid-set-sizes))
      ((member inp '("Тип" "Т"))     (gc-vid-toggle-mode))
      (T (princ (strcat "\n[!] Кнопка \"" inp "\" не распознана.")))))
  (princ))

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

(princ "\n[gc] vid.lsp v6 загружен. Команды: VID, GC-SELECT-BY-SIZE")
(princ)
