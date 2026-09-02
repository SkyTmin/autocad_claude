;;; rs.lsp -- razvorot uzhe narisovannyh strelok (SPEC-008 v1)
;;; Komandy:
;;;   RS                -- osnovnaya komanda (Razvorot Strelki).
;;;   GC-REVERSE-ARROW  -- polnoe imya toy zhe komandy.
;;;   KY                -- to zhe samoe v russkoy raskladke.
;;;
;;; ZACHEM. U OL do versii v8 byla oshibka: ostrie strelki vsegda smotrelo
;;; v odnu storonu ot pryamoy, nezavisimo ot togo, s kakoy storony lezhit
;;; fakticheskaya tochka. Oshibku ispravili, no shemy, nachrchennye do etogo,
;;; ostalis s nevernymi strelkami. Perecherchivat shemu zanovo komandoy OL --
;;; eto zanovo tykat po kazhdoy tochke. Etot fayl pravit to, chto UZHE
;;; narisovano.
;;;
;;; CHTO DELAET. Menyaet mestami koncy strelki: ostrie perehodit na drugoy
;;; konec, sama strelka ostaetsya tam zhe. Povtornyy zapusk vozvrashchaet
;;; kak bylo -- eto tumbler.
;;;
;;; CIFRU NE TROGAET, i eto ne uproshchenie, a sledstvie geometrii OL:
;;; podpis stavitsya ot SEREDINY strelki, a ugol teksta normalizuetsya
;;; v (-90; 90]. Pri razvorote seredina ne dvigaetsya, a napravlenie menyaetsya
;;; na 180 gradusov -- posle normalizacii eto TOT ZHE ugol. Znachit i tochka
;;; vstavki, i povorot cifry ostayutsya prezhnimi. Provereno chislenno
;;; na 120 uglah s shagom 3 gradusa: rashozhdenie nulevoe.
;;;
;;; PSK: komanda chitaet i pishet DXF, to est MSK. Tochki ot polzovatelya
;;; dlya geometrii ne berutsya voobshche, poetomu perevod koordinat ne nuzhen
;;; (sm. docs/pitfalls.md -> P1). Vyborka ramkoy idet v PSK -- eto shtatno.
;;;
;;; Kodirovka fayla: CP1251 bez BOM (ADR-0004). Ne UTF-8!

;;; ====================================================================
;;; НАСТРОЙКИ
;;; ====================================================================

;; Допуск на "ширина равна нулю". Ширины хранятся числами с плавающей
;; точкой, точное сравнение с нулём ненадёжно.
(setq *gc-rs-eps* 1.0e-9)

;; Фильтр выборки. Наши стрелки — только LWPOLYLINE, всё остальное
;; отсеивается до подсчёта, чтобы не пугать пользователя счётчиком
;; пропущенных объектов, которые он и не собирался разворачивать.
(setq *gc-rs-ssget-filter* '((0 . "LWPOLYLINE")))

;; Способ выбора: "SS" — рамкой, "ONE" — по одной.
(setq *gc-rs-mode* nil)

;;; ====================================================================
;;; РАЗБОР ПОЛИЛИНИИ
;;; ====================================================================

;; Сравнение с нулём с допуском.
(defun gc-rs-zerop (x)
  (if (null x) T (< (abs x) *gc-rs-eps*)))

;; Разбор LWPOLYLINE на вершины.
;; Возвращает список блоков, по одному на вершину:
;;   (точка начальная-ширина конечная-ширина кривизна)
;;
;; ПОЧЕМУ блоками, а не отдельными списками групп: в DXF ширины и кривизна
;; идут ПОСЛЕ своей вершины, и какие-то из них могут отсутствовать, если
;; равны нулю. Привязка "группа 40 относится к последней встреченной
;; вершине" — единственный надёжный способ их сопоставить.
(defun gc-rs-vertices (ed / blocks cur g)
  (setq blocks '()
        cur    nil)
  (foreach g ed
    (cond
      ((= (car g) 10)
       (if cur (setq blocks (cons cur blocks)))
       (setq cur (list (cdr g) 0.0 0.0 0.0)))
      ;; Группы ширины и кривизны до первой вершины не бывает, но проверка
      ;; на cur защищает от неожиданного порядка групп в чужом чертеже.
      ((and cur (= (car g) 40))
       (setq cur (list (car cur) (cdr g) (caddr cur) (nth 3 cur))))
      ((and cur (= (car g) 41))
       (setq cur (list (car cur) (cadr cur) (cdr g) (nth 3 cur))))
      ((and cur (= (car g) 42))
       (setq cur (list (car cur) (cadr cur) (caddr cur) (cdr g))))))
  (if cur (setq blocks (cons cur blocks)))
  (reverse blocks))

;; Наша ли это стрелка.
;; Признаки — ровно 3 вершины, незамкнутая, у средней вершины начальная
;; ширина больше нуля (это наконечник), у крайних ноль, кривизны нет.
;;
;; ПОЧЕМУ слой не проверяем: схема Шамиля может лежать на любом слое,
;; а под это же описание попадают стрелки SV — они рисуются такой же
;; полилинией. Проверять слой значило бы отказать в работе без причины.
(defun gc-rs-arrow-p (ed / vs closed flags)
  (setq flags  (cdr (assoc 70 ed)))
  (setq closed (if flags (= 1 (logand flags 1)) nil))
  (setq vs     (gc-rs-vertices ed))
  (cond
    (closed nil)
    ((/= (length vs) 3) nil)
    ;; Кривизна: разворот порядка точек перевернул бы дугу на другую сторону.
    ;; Наши стрелки прямые, поэтому такую полилинию просто не трогаем.
    ((not (and (gc-rs-zerop (nth 3 (nth 0 vs)))
               (gc-rs-zerop (nth 3 (nth 1 vs)))
               (gc-rs-zerop (nth 3 (nth 2 vs)))))
     nil)
    ;; Наконечник — на средней вершине, крайние тонкие.
    ((and (gc-rs-zerop (cadr (nth 0 vs)))
          (> (cadr (nth 1 vs)) *gc-rs-eps*)
          (gc-rs-zerop (cadr (nth 2 vs))))
     T)
    (T nil)))

;;; ====================================================================
;;; РАЗВОРОТ
;;; ====================================================================

;; Разворот одной стрелки.
;;
;; КАК ЭТО РАБОТАЕТ. Ширина в LWPOLYLINE задаётся ПОСЕГМЕНТНО и привязана
;; к позиции вершины, а не к самой точке. Поэтому достаточно переставить
;; в обратном порядке только КООРДИНАТЫ, оставив ширины на своих местах:
;;
;;   было:  поз.1 = хвост (0)   поз.2 = середина (наконечник)  поз.3 = остриё (0)
;;   стало: поз.1 = остриё (0)  поз.2 = та же середина          поз.3 = хвост (0)
;;
;; Середина у стрелки из трёх вершин одна и та же в обоих случаях, поэтому
;; наконечник просто оказывается направленным в другую сторону, а сам след
;; стрелки не смещается ни на миллиметр.
;;
;; Возвращает T при успехе, nil если чертёж отказал в правке.
(defun gc-rs-flip (ent / ed pts newpts res i g)
  (setq ed (entget ent))
  ;; Собираем координаты в порядке следования.
  (setq pts '())
  (foreach g ed
    (if (= (car g) 10) (setq pts (cons (cdr g) pts))))
  (setq pts    (reverse pts))
  (setq newpts (reverse pts))
  ;; Подставляем обратно: i-я по счёту группа 10 получает i-ю точку
  ;; из развёрнутого списка. Все прочие группы идут как есть.
  (setq res '()
        i   0)
  (foreach g ed
    (if (= (car g) 10)
      (progn
        (setq res (cons (cons 10 (nth i newpts)) res))
        (setq i   (1+ i)))
      (setq res (cons g res))))
  (setq res (reverse res))
  ;; entmod возвращает nil и молчит, если чертёж отказал — например, слой
  ;; заблокирован. Молчание тут недопустимо, см. docs/pitfalls.md -> П4.
  (if (entmod res)
    (progn (entupd ent) T)
    nil))

;; Разворот всех стрелок из набора. Возвращает (развёрнуто пропущено отказано).
(defun gc-rs-flip-ss (ss / i n ent ed ok skip fail)
  (setq ok 0 skip 0 fail 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq ed  (entget ent))
    (cond
      ((not (gc-rs-arrow-p ed)) (setq skip (1+ skip)))
      ((gc-rs-flip ent)         (setq ok   (1+ ok)))
      (T                        (setq fail (1+ fail))))
    (setq i (1+ i)))
  (list ok skip fail))

;; Отчёт по итогам. Вынесен отдельно, чтобы оба режима говорили одинаково.
(defun gc-rs-report (res / ok skip fail)
  (setq ok   (nth 0 res)
        skip (nth 1 res)
        fail (nth 2 res))
  (princ (strcat "\n[Итог] развёрнуто стрелок: " (itoa ok)))
  (if (> skip 0)
    (progn
      (princ (strcat " | пропущено (не наши): " (itoa skip)))
      (princ "\n    Стрелкой считается полилиния из 3 вершин с наконечником")
      (princ "\n    на средней вершине. Обычные полилинии не трогаем.")))
  (if (> fail 0)
    (progn
      (princ (strcat "\n[!] Не удалось развернуть: " (itoa fail)))
      (princ "\n    Чаще всего это ЗАБЛОКИРОВАННЫЙ слой — разблокируйте его")
      (princ "\n    и повторите.")))
  (princ))

;;; ====================================================================
;;; РЕЖИМЫ ВЫБОРА
;;; ====================================================================

(defun gc-rs-mode-name ( / )
  (if (= *gc-rs-mode* "ONE") "по одной" "рамкой"))

(defun gc-rs-set-mode (m)
  (setq *gc-rs-mode* m)
  (princ (strcat "\n[i] Способ выбора: " (gc-rs-mode-name)))
  T)

;; Выбор рамкой. Возвращает T — продолжать работу.
(defun gc-rs-step-ss ( / ss)
  (princ "\nВыделите стрелки рамкой: ")
  (setq ss (ssget *gc-rs-ssget-filter*))
  (if (null ss)
    (princ "\n[i] Ничего не выбрано.")
    (gc-rs-report (gc-rs-flip-ss ss)))
  T)

;; Выбор по одной. Возвращает T — продолжать, nil — выйти из команды.
;;
;; ПОЧЕМУ через ERRNO: entsel возвращает nil и при промахе, и при Enter.
;; ERRNO 7 = промах (переспрашиваем), иначе — осознанный выход.
(defun gc-rs-step-one ( / sel ent ed done res)
  (setq done nil res T)
  (while (not done)
    (setq sel (entsel "\nУкажите стрелку <Enter — назад к кнопкам>: "))
    (cond
      ((null sel)
       (if (= (getvar "ERRNO") 7)
         (princ "\n[!] Мимо объекта. Щёлкните точно по стрелке.")
         (setq done T)))
      (T
       (setq ent (car sel)
             ed  (entget ent))
       (cond
         ((/= (cdr (assoc 0 ed)) "LWPOLYLINE")
          (princ "\n[!] Это не наша стрелка (нужна полилиния). Выберите другую."))
         ((not (gc-rs-arrow-p ed))
          (princ "\n[!] Полилиния не похожа на нашу стрелку:")
          (princ "\n    нужны 3 вершины и наконечник на средней."))
         ((gc-rs-flip ent)
          (princ "\n[i] Развёрнута."))
         (T
          (princ "\n[!] Не удалось развернуть — вероятно, слой заблокирован."))))))
  res)

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-rs-defaults ( / )
  (if (null *gc-rs-mode*) (setq *gc-rs-mode* "SS")))

(defun gc-rs-intro ( / )
  (princ "\n\n=== RS — разворот уже нарисованных стрелок ===")
  (princ "\nОстриё переходит на другой конец, стрелка остаётся на месте.")
  (princ "\nЦифра не трогается: при развороте её место и угол не меняются.")
  (princ "\nПовторный разворот возвращает стрелку как было.")
  (princ "\nКнопки в строке запроса:")
  (princ "\n  Рамкой — выбрать много стрелок разом")
  (princ "\n  Одна   — щёлкать по одной")
  (princ "\n  Выход  — закончить")
  (princ "\nКнопку можно щёлкнуть мышью или набрать её первую букву."))

(defun gc-rs-status ( / )
  (princ (strcat "\n\n--- RS | способ: " (gc-rs-mode-name) " ---")))

;; Обработка нажатой кнопки. Возвращает T — продолжать, nil — выйти.
;;
;; ПОЧЕМУ ключевые слова продублированы одной буквой: для кириллицы AutoCAD
;; не распознаёт заглавную букву как допустимое сокращение и требует набрать
;; слово целиком. Отдельное ключевое слово «Р» решает это — работает и клик
;; по кнопке, и «Р», и «Рамкой». См. docs/pitfalls.md -> П7.
(defun gc-rs-do-option (kw / )
  (cond
    ((member kw '("Рамкой" "Р")) (gc-rs-set-mode "SS"))
    ((member kw '("Одна"   "О")) (gc-rs-set-mode "ONE"))
    ((member kw '("Выход"  "В")) nil)
    (T (princ (strcat "\n[!] Кнопка \"" kw "\" не распознана.")) T)))

(defun gc-rs-run ( / done kw)
  (gc-rs-defaults)
  (gc-rs-intro)
  (setq done nil)
  (while (not done)
    (gc-rs-status)
    (initget "Рамкой Р Одна О Выход В")
    (setq kw (getkword
               (strcat "\nДальше [Рамкой/Одна/Выход]"
                       " <Enter — выбрать стрелки>: ")))
    (cond
      ;; Enter — сразу к работе выбранным способом, без лишнего шага.
      ((null kw)
       (if (= *gc-rs-mode* "ONE")
         (gc-rs-step-one)
         (gc-rs-step-ss)))
      ((null (gc-rs-do-option kw)) (setq done T))))
  (princ "\n[i] RS завершена.")
  (princ))

;;; ====================================================================
;;; КОМАНДА
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если Шамиль нажал Esc посреди ввода.
(defun c:rs ( / *error*)
  (defun *error* (msg)
    ;; Отмена это не ошибка. На локализованном AutoCAD выход по Esc приходит
    ;; сообщением «Функция прервана.», поэтому кроме английских BREAK/CANCEL/
    ;; QUIT проверяем русские слова — и БЕЗ strcase: полагаться на то, что он
    ;; верно поднимет регистр кириллицы в любой сборке, не стоит.
    (if (or (null msg)
            (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")
            (wcmatch msg "*прерван*,*Прерван*,*ПРЕРВАН*,*отмен*,*Отмен*,*ОТМЕН*"))
      (princ "\n[ОТМЕНА] RS прерван.")
      (princ (strcat "\n[ОШИБКА] RS: " msg)))
    (princ))
  (gc-rs-run)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-reverse-arrow ( / )
  (c:rs))

;;; ====================================================================
;;; ИМЯ КОМАНДЫ В РУССКОЙ РАСКЛАДКЕ
;;; ====================================================================

;; Шамиль часто набирает команду, забыв переключить раскладку. Регистрируем
;; те же буквы на тех же клавишах ЙЦУКЕН — руки набирают одно движение,
;; а команда запускается при любой раскладке. См. docs/pitfalls.md -> П15.

;; RS -> КЫ
(defun c:кы ( / ) (c:rs))
(defun c:КЫ ( / ) (c:rs))
(princ "\n[gc] rs.lsp v1 загружен. Команда: RS | рус. раскладка: КЫ")
(princ)
