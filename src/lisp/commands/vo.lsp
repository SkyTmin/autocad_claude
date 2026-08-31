;;; vo.lsp -- otklonenie fakticheskoy tochki ot proektnoy otmetki (SPEC-006 v15)
;;; Komandy:
;;;   VO                  -- edinstvennaya komanda, vse nastroyki vnutri.
;;;   GC-HEIGHT-DEVIATION -- polnoe imya toy zhe komandy.
;;;
;;; PRICHINA imeni VO, a ne H: "H" -- shtatnyy alias HATCH v AutoCAD, i
;;; opredelenie c:h perekrylo by shtrihovku.
;;;
;;; v15: KNOPKA "NAYTI" -- otbor tochek po vysote. Vvodite otmetku, vybiraete
;;;      Vyshe ili Nizhe, i tochki po etu storonu ot otmetki okazyvayutsya
;;;      vydelennymi s ruchkami -- srazu mozhno Delete, Move, svoystva.
;;;      Komanda pri etom ZAVERSHAETSYA: poka ona rabotaet, s vydeleniem
;;;      nichego ne sdelaesh, tak chto derzhat polzovatelya vnutri bessmyslenno.
;;;      Tochki rovno na otmetke (v predelah 0.5 mm) ne popadayut ni v "vyshe",
;;;      ni v "nizhe" -- ih chislo soobshchaetsya otdelno, chtoby ne bylo
;;;      voprosa "pochemu eta tochka ne vybralas".
;;;      Otmetka otbora hranitsya OTDELNO ot proektnoy: knopka ne dolzhna
;;;      molcha menyat chuzhuyu nastroyku (docs/pitfalls.md -> П23).
;;;
;;; v14: PERESOBRANO UPRAVLENIE. Do v14 nastroyki nakaplivalis po odnoy
;;;      i nachali konfliktovat: "Rezhim" (odna otmetka / sprashivat kazhdyy
;;;      raz), "Sposob" (obektom / klikom) i knopka-deystvie "Pachkoy" byli
;;;      nezavisimy, no na dele zaviseli drug ot druga. Pachkoy molcha
;;;      perebivala dve drugie nastroyki, a Sposob v ney voobshche ne
;;;      primenyalsya. Shamil: "kasha-malasha, polnostyu peresobrat".
;;;
;;;      DVA PRINCIPA NOVOGO UPRAVLENIYA.
;;;
;;;      1. ODIN REZHIM RABOTY, vse ostalnoe emu podchineno.
;;;         Odnoy  -- tykayu tochku, sam ukazyvayu mesto podpisi.
;;;         Ramkoy -- vydelyayu vse tochki, podpisi vstayut sami.
;;;         Parami -- proektnaya tochka, potom fakticheskaya (uklon, lestnica).
;;;         Knopki pokazyvayutsya TOLKO te, chto rabotayut v etom rezhime.
;;;         Poetomu konfliktovat bolshe nechemu: v Ramkoy net "Sposoba"
;;;         (tam ssget), v Parami net "Otmetki" (ona u kazhdoy pary svoya),
;;;         v Odnoy i Parami net "Zazora" (mesto ukazyvaesh sam).
;;;
;;;      2. NIKAKIH SLEPYH PEREKLYUCHATELEY. Ranshe "Rezhim" i "Sposob"
;;;         perekidyvalis po nazhatiyu, i bylo ne vidno, kuda popadesh.
;;;         Teper kazhdaya takaya knopka otkryvaet SVOI knopki s nazvaniyami,
;;;         kak eto uzhe sdelano u "Otmetki" s v5.
;;;
;;; v13: PAKETNYY REZHIM -- knopka "Pachkoy". Vydelil vse tochki ramkoy,
;;;      nazhal Enter -- podpisi vstali u kazhdoy srazu. Ranshe tochki
;;;      vybiralis tolko po odnoy, i na bolshoy syomke eto dolgo.
;;;      Podpis stavitsya LEVEE tochki na zazor (po umolchaniyu 20 mm),
;;;      vyravnivanie Middle Right -- zazor ostaetsya odinakovym nezavisimo
;;;      ot togo, dlinnaya cifra ili korotkaya. Zazor menyaetsya knopkoy "Zazor".
;;;      Smeshchenie i povorot teksta schitayutsya OT TEKUSHCHEY PSK, poetomu
;;;      "levee" -- eto levee NA EKRANE, a cifra chitaetsya gorizontalno
;;;      pri lyuboy povernutoy PSK. Povorot teper takoy zhe i v rezhime
;;;      po odnoy tochke: ranshe stoyal zhestkiy 0, i v povernutoy PSK
;;;      podpis vyglyadela naklonennoy.
;;;
;;; v12: GLAVNOE ISPRAVLENIE -- PSK (UCS). Sm. podrobnyy razbor v ol.lsp v13.
;;;      Korotko: getpoint otdaet tochku v TEKUSHCHEY PSK, a entmake kladet
;;;      obekt v MSK. V chertezhe s povernutoy ili sdvinutoy PSK podpis
;;;      sozdavalas ne tam, kuda tykali, chasto voobshche za predelami ekrana --
;;;      i eto vyglyadelo kak "nichego ne narisovalos".
;;;      Teper mesto podpisi i vysota Z perevodyatsya v MSK cherez (trans p 1 0).
;;;      Poputno: annotativnyy stil bolshe ne vybiraetsya, a kazhdyy entmake
;;;      proveryaetsya i govorit vsluh, esli obekt ne sozdalsya.
;;;
;;; v11: komandy zaregistrirovany i v russkoy raskladke -- te zhe bukvy
;;;      na teh zhe klavishah YCUKEN. Shamil chasto nabiraet komandu,
;;;      zabyv pereklyuchit raskladku: vmesto OL poluchaetsya SHCHD.
;;;
;;; v10: vybor tekstovogo stilya -- tolko s PEREMENNOY vysotoy, inache
;;;      AutoCAD ignoriruet zadannuyu vysotu. Sm. ol.lsp v11.
;;;
;;; v9: proverka chertezha pri zapuske -- sloy i tekstovyy stil. Sm. ol.lsp v10.
;;;
;;; v8: stil teksta privedyon k ol.lsp -- v cepochku podbora dobavlen "MGS"
;;;     pervym, chtoby cifry vyglyadeli odinakovo vo vseh komandah.
;;;
;;; v7: zashchita ot otsutstviya Visual LISP COM (oshibka "no function
;;;     definition: VLAX-ENAME->VLA-OBJECT"). Vysota obychnoy tochki teper
;;;     beretsya iz DXF-gruppy 10 BEZ COM; COM nuzhen tolko dlya COGO Point
;;;     i blokov, i ego nalichie proveryaetsya.
;;;
;;; v6: Zadanie otmetki cherez knopku [Otmetka] teper SAMO pereklyuchaet
;;;     rezhim na "odna otmetka na vse tochki". Ranshe, esli byl vklyuchen
;;;     rezhim "sprashivat kazhdyy raz", vvedennaya vruchnuyu otmetka nikak
;;;     ne ispolzovalas i komanda prodolzhala trebovat proektnuyu tochku
;;;     obyektom pered kazhdoy fakticheskoy.
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

;; Зазор между точкой и подписью в пакетном режиме, м. 0.020 = 20 мм.
(setq *gc-vo-gap-init*    0.020)

;; Что считать фактической точкой при выборе рамкой. Тот же фильтр, что в
;; ol.lsp: обычные точки AutoCAD и COGO Point Civil 3D. Всё остальное
;; в выборку не попадает — иначе подписи налипли бы на линии и тексты.
(setq *gc-vo-ssget-filter* '((0 . "POINT,AECC*POINT,AEC*POINT")))

;; Допуск «точка ровно на отметке», м. 0.0005 = полмиллиметра: ближе этого
;; две отметки после округления до миллиметра неразличимы.
(setq *gc-vo-find-eps*    0.0005)

;;; НАСТРОЙКИ — живут между запусками до закрытия чертежа:
;;;   *gc-vo-proj-z*     — проектная отметка, м
;;;   *gc-vo-mode*       — режим работы: "ONE" одной / "SS" рамкой / "PAIR" парами
;;;   *gc-vo-fact-src*   — "OBJ" выбор объекта / "PT" клик с привязкой
;;;   *gc-vo-text-h*     — высота текста, м
;;;   *gc-vo-gap*        — зазор от точки до подписи в пакетном режиме, м
;;;   *gc-vo-find-z*     — отметка последнего отбора «Найти», м
;;;   *gc-vo-find-side*  — сторона отбора: "UP" выше / "DOWN" ниже
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
;; Проверяет, доступен ли Visual LISP COM, и при необходимости догружает его.
;; ПОЧЕМУ нужно: бывает ошибка "no function definition: VLAX-ENAME->VLA-OBJECT",
;; то есть (vl-load-com) в шапке файла не отработал. Ссылка на несвязанный
;; символ в AutoLISP возвращает nil и не падает — так и проверяем.
(defun gc-vo-com-ok ( / )
  (if (null vlax-ename->vla-object) (vl-load-com))
  (if vlax-ename->vla-object T nil))

;; Высота объекта.
;; ПОРЯДОК ВАЖЕН. DXF-группа 10 есть у обычной точки и не требует COM —
;; пробуем её первой. COM трогаем только для COGO Point Civil 3D и блоков.
;; Так команда работает и там, где Visual LISP COM недоступен.
(defun gc-vo-entity-z (ent / obj ed typ p10 z)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed))
        p10 (cdr (assoc 10 ed))
        z   nil)
  ;; COGO Point и LWPOLYLINE отдают высоту только через Elevation.
  (if (and (or (wcmatch typ "AECC*POINT,AEC*POINT")
               (= typ "LWPOLYLINE")
               (null p10)
               (null (caddr p10)))
           (gc-vo-com-ok))
    (progn
      (setq obj (vlax-ename->vla-object ent))
      (if (vlax-property-available-p obj 'Elevation)
        (setq z (vla-get-Elevation obj)))
      (if (and (null z) (vlax-property-available-p obj 'InsertionPoint))
        (setq z (caddr (vlax-safearray->list
                         (vlax-variant-value (vla-get-InsertionPoint obj))))))))
  ;; Обычная точка, окружность, текст, линия — из DXF, без COM.
  (if (and (null z) p10 (caddr p10))
    (setq z (caddr p10)))
  z)

;; Координаты объекта целиком: (X Y Z) либо nil.
;; Нужны в пакетном режиме — там подпись ставится у самой точки, а не
;; в место, указанное мышью, поэтому кроме высоты нужен и план.
;; ПОРЯДОК ТОТ ЖЕ, что в gc-vo-entity-z: сначала DXF, COM только если без
;; него никак (docs/pitfalls.md -> П6).
;; Координаты из DXF и из COM приходят в МСК, entmake тоже пишет в МСК,
;; поэтому здесь перевод систем не нужен (docs/pitfalls.md -> П1).
(defun gc-vo-entity-xyz (ent / obj ed typ p10 z xy)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed))
        p10 (cdr (assoc 10 ed))
        xy  nil)
  (cond
    ;; COGO Point — план только через COM.
    ((wcmatch typ "AECC*POINT,AEC*POINT")
     (if (gc-vo-com-ok)
       (progn
         (setq obj (vlax-ename->vla-object ent))
         (cond
           ((vlax-property-available-p obj 'Easting)
            (setq xy (list (vla-get-Easting obj) (vla-get-Northing obj))))
           ((vlax-property-available-p obj 'InsertionPoint)
            (setq p10 (vlax-safearray->list
                        (vlax-variant-value (vla-get-InsertionPoint obj))))
            (setq xy (list (car p10) (cadr p10))))))))
    ;; Обычная точка — из DXF, без COM.
    ((and p10 (cadr p10))
     (setq xy (list (car p10) (cadr p10)))))
  (setq z (gc-vo-entity-z ent))
  (if (and xy z) (list (car xy) (cadr xy) z) nil))

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
  ;; Режим здесь НЕ трогаем. До v14 задание отметки молча переключало режим,
  ;; и это была часть той самой каши. Теперь кнопка «Отметка» вообще не
  ;; показывается в режиме «Парами», где отметка не используется, поэтому
  ;; и переключать нечего.
  (if (= *gc-vo-mode* "PAIR")
    (progn
      (princ "\n[!] Сейчас режим «Парами» — общая отметка в нём не участвует.")
      (princ "\n    Чтобы считать от неё, смените режим кнопкой Режим.")))
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

;;; --------------------------------------------------------------------
;;; РЕЖИМ РАБОТЫ — ГЛАВНАЯ НАСТРОЙКА, ЕЙ ПОДЧИНЕНО ВСЁ ОСТАЛЬНОЕ
;;;
;;; До v14 было три независимых настройки, которые на деле зависели друг
;;; от друга, и они дрались между собой. Теперь развилка одна:
;;;
;;;   Одной  — тыкаю точку, сам указываю место подписи. Отметка общая.
;;;   Рамкой — выделяю все точки рамкой, подписи встают сами. Отметка общая.
;;;   Парами — проектная точка, затем фактическая. Общая отметка не нужна.
;;;
;;; Что применимо в каком режиме:
;;;
;;;   настройка          Одной   Рамкой   Парами
;;;   Отметка (общая)      +       +        -      (в Парами своя у каждой пары)
;;;   Способ выбора        +       -        +      (в Рамкой выбор рамкой)
;;;   Зазор                -       +        -      (в остальных место указываю сам)
;;;   Текст                +       +        +
;;;
;;; Кнопки показываются ТОЛЬКО применимые. Поэтому нажать неподходящую
;;; настройку невозможно, и конфликтовать нечему.
;;; --------------------------------------------------------------------

(defun gc-vo-mode-name ( / )
  (cond
    ((= *gc-vo-mode* "SS")   "рамкой — все точки разом")
    ((= *gc-vo-mode* "PAIR") "парами — проектная и фактическая точка")
    (T                       "одной — точка, затем место подписи")))

(defun gc-vo-mode-word ( / )
  (cond ((= *gc-vo-mode* "SS") "Рамкой") ((= *gc-vo-mode* "PAIR") "Парами")
        (T "Одной")))

;; ПОЧЕМУ вложенный запрос, а не переключение по нажатию: у слепого
;; переключателя не видно, куда попадёшь. Шамиль: «а то хрен знает, на что
;; ты нажимаешь». Тот же приём уже работает у кнопки «Отметка» с v5.
(defun gc-vo-set-mode ( / kw)
  (princ (strcat "\n\n--- РЕЖИМ РАБОТЫ --- сейчас: " (gc-vo-mode-name)))
  (princ "\n  Одной  — щёлкаете точку, потом указываете место подписи.")
  (princ "\n           Сравнивается с общей проектной отметкой.")
  (princ "\n  Рамкой — выделяете все точки рамкой, подписи встают сами")
  (princ "\n           левее каждой точки. Тоже от общей отметки.")
  (princ "\n  Парами — сначала проектная точка, потом фактическая, и так")
  (princ "\n           каждый раз. Для уклона, лестницы, разных отметок.")
  (initget "Одной О Рамкой Р Парами П")
  (setq kw (getkword (strcat "\nРежим [Одной/Рамкой/Парами] <"
                             (gc-vo-mode-word) ">: ")))
  (cond
    ;; Enter — оставить как было, но сказать об этом вслух: молчаливый
    ;; возврат прежнего значения уже был дефектом (docs/pitfalls.md -> П8).
    ((null kw)
     (princ (strcat "\n[i] Отмена. Режим остался: " (gc-vo-mode-name))))
    (T
     (setq *gc-vo-mode*
       (cond ((gc-vo-is-word kw '("Рамкой" "Р")) "SS")
             ((gc-vo-is-word kw '("Парами" "П")) "PAIR")
             (T                                  "ONE")))
     (princ (strcat "\n[i] Режим: " (gc-vo-mode-name)))
     (cond
       ((= *gc-vo-mode* "SS")
        (princ "\n    Кнопки показываются ПЕРЕД выборкой: ssget не умеет их")
        (princ "\n    показывать сам. Enter в том запросе ведёт к выборке."))
       ((= *gc-vo-mode* "PAIR")
        (princ "\n    Общая отметка в этом режиме не используется."))
       (T nil))
     ;; Отметка нужна в Одной и Рамкой — спросим сразу, а не посреди работы.
     (if (and (/= *gc-vo-mode* "PAIR") (null *gc-vo-proj-z*))
       (gc-vo-set-proj))))
  *gc-vo-mode*)

(defun gc-vo-fact-src-name ( / )
  (if (= *gc-vo-fact-src* "PT")
    "кликом по месту (нужна объектная привязка)"
    "выбором объекта"))

(defun gc-vo-fact-src-word ( / )
  (if (= *gc-vo-fact-src* "PT") "Кликом" "Объектом"))

;; Тоже вложенный запрос, а не переключатель — по той же причине.
(defun gc-vo-set-fact-src ( / kw)
  (princ (strcat "\n\n--- КАК ВЫБИРАТЬ ТОЧКИ --- сейчас: "
                 (gc-vo-fact-src-name)))
  (princ "\n  Объектом — щёлкаете прямо по объекту точки съёмки, берётся")
  (princ "\n             его высота Z. Промах команда заметит и переспросит.")
  (princ "\n  Кликом   — щёлкаете место в модели, высота берётся из точки")
  (princ "\n             клика. НУЖНА объектная привязка (Узел, Конточка):")
  (princ "\n             без неё вернётся высота плоскости построений, обычно")
  (princ "\n             0, и отклонение будет неверным — молча.")
  (initget "Объектом О Кликом К")
  (setq kw (getkword (strcat "\nКак выбирать [Объектом/Кликом] <"
                             (gc-vo-fact-src-word) ">: ")))
  (cond
    ((null kw)
     (princ (strcat "\n[i] Отмена. Осталось: " (gc-vo-fact-src-name))))
    (T
     (setq *gc-vo-fact-src*
       (if (gc-vo-is-word kw '("Кликом" "К")) "PT" "OBJ"))
     (princ (strcat "\n[i] Точки выбираются " (gc-vo-fact-src-name)))))
  *gc-vo-fact-src*)

(defun gc-vo-set-gap ( / res s val)
  (princ "\n\n--- ЗАЗОР ОТ ТОЧКИ ДО ПОДПИСИ ---")
  (princ "\nНа сколько подпись отступает влево от точки в пакетном режиме.")
  (princ "\nВ метрах чертежа: 0,020 — это 20 мм.")
  (princ "\nЗазор считается до КРАЯ цифры, поэтому длинные и короткие")
  (princ "\nзначения отстоят от точки одинаково.")
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле
    ;; (docs/pitfalls.md -> П13).
    (setq s (gc-vo-trim
              (getstring T (strcat "\nЗазор, м <"
                                   (gc-vo-fmt *gc-vo-gap*) ">: "))))
    (cond
      ;; Умолчание уместно: значение всегда задано, Enter = «оставить».
      ((= s "") (setq res *gc-vo-gap*))
      (T
       (setq val (gc-vo-parse-num s))
       (cond
         ((null val)
          (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 0,020")))
         ((< val 0.0)
          (princ "\n[!] Зазор не может быть отрицательным."))
         (T (setq res val))))))
  (setq *gc-vo-gap* res)
  (princ (strcat "\n[i] Зазор теперь " (gc-vo-fmt *gc-vo-gap*) " м"))
  *gc-vo-gap*)

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
    (princ (strcat "\n  режим   : " (gc-vo-mode-name)))
    (princ (strcat "\n  отметка : "
                   (if (= *gc-vo-mode* "PAIR")
                     "не нужна — у каждой пары своя"
                     (gc-vo-proj-disp))))
    (princ (strcat "\n  точки   : "
                   (if (= *gc-vo-mode* "SS")
                     "выбираются рамкой"
                     (gc-vo-fact-src-name))))
    (princ (strcat "\n  текст   : " (gc-vo-fmt *gc-vo-text-h*) " м"))
    (princ (strcat "\n  зазор   : " (gc-vo-fmt *gc-vo-gap*) " м"
                   (if (= *gc-vo-mode* "SS") "" "  (в этом режиме не нужен)")))
    (princ "\n")
    (princ "\n  1 или Р — режим работы: одной / рамкой / парами")
    (princ "\n  2 или О — проектная отметка")
    (princ "\n  3 или С — как выбирать точки: объектом / кликом")
    (princ "\n  4 или Т — высота текста подписи")
    (princ "\n  5 или З — зазор от точки до подписи в режиме «рамкой»")
    (princ "\n  6 или Н — найти точки выше / ниже заданной отметки")
    (princ "\n  0 или К — выйти из команды")
    (princ "\n  Enter   — вернуться к работе")
    (setq s (gc-vo-trim (getstring T "\nВыбор: ")))
    (cond
      ((= s "") (setq done T))
      ((gc-vo-is-word s '("1" "р" "Р" "r" "R" "режим" "Режим"))
       (gc-vo-set-mode))
      ((gc-vo-is-word s '("2" "о" "О" "o" "O" "отметка" "Отметка"))
       (gc-vo-set-proj))
      ((gc-vo-is-word s '("3" "с" "С" "s" "S" "c" "C" "способ" "Способ"))
       (gc-vo-set-fact-src))
      ((gc-vo-is-word s '("4" "т" "Т" "t" "T" "текст" "Текст" "высота"))
       (gc-vo-set-text-h))
      ((gc-vo-is-word s '("5" "з" "З" "зазор" "Зазор" "отступ"))
       (gc-vo-set-gap))
      ((gc-vo-is-word s '("6" "н" "Н" "n" "N" "найти" "Найти" "отбор"))
       (if (null (gc-vo-find)) (setq res nil done T)))
      ((gc-vo-is-word s '("0" "к" "К" "k" "K" "q" "Q" "выход" "Выход"))
       (setq res nil done T))
      (T (princ (strcat "\n[!] Не понял \"" s
                        "\". Введите 1-6, 0 или просто Enter.")))))
  res)

;;; ====================================================================
;;; ПСК И МСК
;;; ====================================================================

;; ПОЧЕМУ это важно. getpoint отдаёт точку в ТЕКУЩЕЙ ПСК, а entmake кладёт
;; объект в МСК. Пока ПСК совпадает с мировой, разницы нет. Стоит ПСК
;; повернуть или сдвинуть — те же числа означают уже другое место,
;; и подпись создаётся в стороне, часто далеко за экраном. Снаружи это
;; выглядит как «команда отработала, а на чертеже ничего нет».
;; Высота Z из getpoint — тоже в ПСК: при наклонённой или поднятой ПСК
;; отметка получалась бы неверной.
;; Поэтому точку от пользователя сразу переводим в МСК.

;; Дополняем точку до трёхмерной: trans ждёт полноценную точку.
(defun gc-vo-3d (p)
  (list (car p) (cadr p) (if (caddr p) (caddr p) 0.0)))

;; Угол оси X текущей ПСК, выраженный в МСК.
;; Текст, повёрнутый на этот угол, читается на экране горизонтально при
;; любой повёрнутой ПСК. Раньше в подписи стоял жёсткий 0, и в повёрнутой
;; ПСК цифра выглядела наклонённой.
;; Флаг T у trans означает «это вектор направления, а не точка»: переносить
;; начало координат не надо, поворачивать — надо.
(defun gc-vo-ucs-ang ( / v)
  (setq v (trans '(1.0 0.0 0.0) 1 0 T))
  (atan (cadr v) (car v)))

;; Вектор «влево на gap» в МСК. Влево — как видит пользователь, то есть
;; против оси X текущей ПСК, а не мировой.
(defun gc-vo-left-vec (gap / )
  (trans (list (- gap) 0.0 0.0) 1 0 T))

;; ПСК -> МСК. 1 = ПСК, 0 = МСК.
(defun gc-vo-w (p)
  (if p (trans (gc-vo-3d p) 1 0) nil))

;; Совпадает ли ПСК с МСК. Нужно только для сообщения пользователю.
(defun gc-vo-wcs-p ( / o x)
  (setq o (getvar "UCSORG")
        x (getvar "UCSXDIR"))
  (and o x
       (< (distance o '(0.0 0.0 0.0)) 1.0e-9)
       (< (distance x '(1.0 0.0 0.0)) 1.0e-9)))

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
;; Стиль с ФИКСИРОВАННОЙ высотой (группа 40 не ноль) не годится: AutoCAD
;; игнорирует высоту, заданную командой, и вся графика перестаёт
;; масштабироваться. У Шамиля в одном чертеже так и вышло — ISOCPEUR
;; с высотой 0.240.
;; Поэтому берём первый стиль из цепочки, у которого высота ПЕРЕМЕННАЯ,
;; а если все кандидаты фиксированные — заводим собственный "GC-Текст"
;; с тем же шрифтом и нулевой высотой.
(defun gc-vo-style-var-h-p (name / e h)
  (setq e (tblsearch "STYLE" name))
  (if e
    (progn
      (setq h (cdr (assoc 40 e)))
      (if (or (null h) (< (abs h) 1.0e-9)) T nil))
    nil))

;; Имя файла шрифта у стиля — чтобы свой стиль выглядел как привычный.
(defun gc-vo-style-font (name / e)
  (setq e (tblsearch "STYLE" name))
  (if e (cdr (assoc 3 e)) nil))

(defun gc-vo-make-own-style ( / font cand)
  (if (null (tblsearch "STYLE" "GC-Текст"))
    (progn
      ;; Шрифт берём у первого существующего кандидата, иначе стандартный.
      (foreach c '("МГС" "GOSTB" "ISOCPEUR" "Standard")
        (if (and (null font) (tblsearch "STYLE" c))
          (setq font (gc-vo-style-font c))))
      (if (or (null font) (= font "")) (setq font "isocp.shx"))
      (entmake (list '(0 . "STYLE")
                     '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbTextStyleTableRecord")
                     (cons 2 "GC-Текст")
                     '(70 . 0)
                     '(40 . 0.0)     ; переменная высота — то, что нам нужно
                     '(41 . 1.0)
                     '(50 . 0.0)
                     '(71 . 0)
                     '(42 . 2.5)
                     (cons 3 font)
                     '(4 . "")))
      (if (tblsearch "STYLE" "GC-Текст")
        (progn
          (princ (strcat "\n[i] Создан текстовый стиль " "GC-Текст"
                         " (шрифт " font ", высота переменная):"))
          (princ "\n    у всех подходящих стилей чертежа высота фиксирована")
          (princ "\n    или они аннотативные — с такими текст не виден.")))))
  ;; ПОЧЕМУ проверяем ещё раз: если entmake стиля не прошёл, а мы всё равно
  ;; вернём "GC-Текст", то КАЖДЫЙ entmake текста со ссылкой на несуществующий
  ;; стиль молча провалится — и подписей не будет, без единого сообщения.
  (if (tblsearch "STYLE" "GC-Текст")
    "GC-Текст"
    (progn
      (princ "\n[!] Не удалось создать стиль GC-Текст. Беру Standard.")
      (princ "\n    Если у Standard фиксированная высота или он аннотативный,")
      (princ "\n    подписи могут выглядеть не так — задайте стиль вручную.")
      "Standard")))

;; Стиль годится, если он есть, высота у него переменная И он НЕ аннотативный.
;; ПОЧЕМУ аннотативный не годится: такой текст показывается только при
;; выбранном масштабе аннотаций. Если масштаб не задан или не совпадает,
;; текст создаётся, но его не видно вообще. Раньше мы про это только
;; предупреждали, а стиль всё равно брали. Теперь пропускаем.
(defun gc-vo-style-ok-p (name / )
  (if (gc-vo-style-var-h-p name)
    (if (gc-vo-style-annotative-p name) nil T)
    nil))

;; Цепочка подбора. Берём первый стиль, который прошёл проверку.
(defun gc-vo-text-style ( / res)
  (foreach c '("МГС" "GOSTB" "ISOCPEUR" "Standard")
    (if (and (null res) (gc-vo-style-ok-p c))
      (setq res c)))
  (if res res (gc-vo-make-own-style)))

;; entmake молча возвращает nil, если чертёж отказал в создании объекта
;; (нет слоя, нет стиля, слой заблокирован). Молчание — худшее, что может
;; быть: команда «отработала», а на чертеже пусто. Говорим вслух.
(defun gc-vo-emake (lst what / e)
  (setq e (entmake lst))
  (if (null e)
    (progn
      (princ (strcat "\n[ОШИБКА] Чертёж не принял " what "."))
      (princ "\n    Смотрите сообщения о слое и текстовом стиле выше.")
      nil)
    e))

;; Общая отрисовка подписи с заданным выравниванием.
;; hj — группа 72 (0 влево, 1 по центру, 2 вправо), vj — группа 73
;; (2 = по середине). При ненулевом выравнивании AutoCAD берёт положение
;; из группы 11, поэтому обе группы 10 и 11 задаём одной точкой.
;; Поворот — угол ПСК: цифра читается горизонтально на экране.
(defun gc-vo-draw-text-al (pt txt hj vj / )
  (gc-vo-ensure-layer *gc-vo-layer* *gc-vo-layer-color*)
  (gc-vo-emake (list '(0 . "TEXT")
                 (cons 8 *gc-vo-layer*)
                 (cons 7 (gc-vo-text-style))
                 (cons 10 pt)
                 (cons 40 *gc-vo-text-h*)
                 (cons 1 txt)
                 (cons 50 (gc-vo-ucs-ang))
                 (cons 72 hj)
                 (cons 11 pt)
                 (cons 73 vj))
    "цифру"))

;; Режим по одной точке: подпись встаёт по центру указанного места.
(defun gc-vo-draw-text (pt txt / )
  (gc-vo-draw-text-al pt txt 1 2))

;; Пакетный режим: подпись слева от точки, её ПРАВЫЙ край — на зазоре
;; от точки. Выравнивание Middle Right (72=2, 73=2).
;; ПОЧЕМУ по правому краю, а не по центру: при центре зазор «съедала» бы
;; сама цифра, и «-14» отстояло бы от точки не так, как «+2».
(defun gc-vo-draw-text-left-of (pt txt / tp)
  (setq tp (mapcar '+ pt (gc-vo-left-vec *gc-vo-gap*)))
  (gc-vo-draw-text-al tp txt 2 2))

;;; ====================================================================
;;; ПАКЕТНЫЙ РЕЖИМ — ВСЕ ТОЧКИ РАЗОМ
;;; ====================================================================

;; Режим «Рамкой» считает все точки от ОДНОЙ проектной отметки: спрашивать
;; проектную точку к каждой фактической тут бессмысленно. Отметку требуем
;; заранее — на входе в режим, а не посреди выборки.
;; Возвращает отметку либо nil, если пользователь отказался её задать.
(defun gc-vo-batch-proj ( / )
  (if (null *gc-vo-proj-z*) (gc-vo-set-proj))
  *gc-vo-proj-z*)

;; Подписывает все точки набора. Возвращает (подписано пропущено).
(defun gc-vo-batch-label (ss z-proj / i n ent c ok skip dev txt)
  (setq ok 0 skip 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c   (gc-vo-entity-xyz ent))
    (if (null c)
      (setq skip (1+ skip))
      (progn
        (setq dev (gc-vo-round (* 1000.0 (- (caddr c) z-proj))))
        (setq txt (gc-vo-fmt-dev dev))
        (if (gc-vo-draw-text-left-of c txt)
          (setq ok (1+ ok))
          (setq skip (1+ skip)))))
    (setq i (1+ i)))
  (list ok skip))

;; Выбор рамкой и подпись всех точек. Возвращает T — продолжать работу.
(defun gc-vo-batch ( / z-proj ss res)
  (princ "\n\n--- РАМКОЙ: ВСЕ ТОЧКИ РАЗОМ ---")
  (setq z-proj (gc-vo-batch-proj))
  (if (null z-proj)
    (princ "\n[!] Проектная отметка не задана — рамкой считать не от чего.")
    (progn
      (princ (strcat "\nПроект: " (gc-vo-fmt z-proj) " м. Подпись встанет левее"
                     " точки на " (gc-vo-fmt *gc-vo-gap*) " м."))
      (princ "\nВыделите фактические точки рамкой и нажмите Enter: ")
      (setq ss (ssget *gc-vo-ssget-filter*))
      (if (null ss)
        (princ "\n[i] Ничего не выбрано.")
        (progn
          (setq res (gc-vo-batch-label ss z-proj))
          (princ (strcat "\n[Итог] подписано точек: " (itoa (car res))))
          (if (> (cadr res) 0)
            (progn
              (princ (strcat " | пропущено: " (itoa (cadr res))))
              (princ "\n    Пропускаются объекты без координат или без высоты.")
              (if (null (gc-vo-com-ok))
                (progn
                  (princ "\n[!] Visual LISP COM недоступен в этой версии CAD.")
                  (princ "\n    COGO Point Civil 3D без него прочитать нельзя,")
                  (princ "\n    обычные точки (POINT) читаются и без него.")))))))))
  T)

;;; ====================================================================
;;; НАЙТИ — ОТБОР ТОЧЕК ПО ВЫСОТЕ
;;; ====================================================================

;; Задача Шамиля: «выбираю высоту, ввожу 4.900 и после выбрать ниже по этой
;; отметке или выше. И точки, которые ниже или выше, выбираются».
;;
;; ПОЧЕМУ отдельная отметка, а не проектная: кнопка не должна молча менять
;; чужую настройку — это ровно та ошибка, из-за которой пересобирали
;; управление в v14 (docs/pitfalls.md -> П23). Проектная отметка лишь
;; ПРЕДЛАГАЕТСЯ как умолчание при первом отборе: чаще всего искать надо
;; именно относительно неё.

(defun gc-vo-find-side-name ( / )
  (if (= *gc-vo-find-side* "DOWN") "ниже" "выше"))

;; Отметка отбора. Умолчание показываем только если есть что предложить,
;; и всегда печатаем, что в итоге взято: молчаливая подстановка прошлого
;; значения уже была дефектом (docs/pitfalls.md -> П8).
;; Возвращает число либо nil при отказе.
(defun gc-vo-ask-find-z ( / dflt res s val)
  (setq dflt (cond (*gc-vo-find-z*) (*gc-vo-proj-z*) (T nil)))
  (princ "\n\n--- НАЙТИ ТОЧКИ ПО ВЫСОТЕ ---")
  (princ "\nВведите отметку, относительно которой отбирать, в метрах.")
  (princ "\nНапример 4,900. Запятая и точка равнозначны.")
  (if (and dflt (null *gc-vo-find-z*))
    (princ "\nПредлагается текущая проектная отметка — можно ввести другую."))
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле (П13).
    (setq s (gc-vo-trim
              (getstring T (strcat "\nОтметка отбора, м"
                                   (if dflt (strcat " <" (gc-vo-fmt dflt) ">") "")
                                   ": "))))
    (cond
      ((= s "")
       (if dflt
         (setq res dflt)
         (progn
           (princ "\n[i] Отбор отменён: отметка не задана.")
           (setq res 'CANCEL))))
      (T
       (setq val (gc-vo-parse-num s))
       (if val
         (setq res val)
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 4,900"))))))
  (if (equal res 'CANCEL) nil res))

;; Сторона отбора. Отдельными кнопками с названиями, а не переключателем.
;; Возвращает "UP" / "DOWN" либо nil при отказе.
(defun gc-vo-ask-find-side (z / kw)
  (princ (strcat "\n\nОтносительно отметки " (gc-vo-fmt z) " м:"))
  (princ "\n  Выше — точки, у которых Z больше этой отметки")
  (princ "\n  Ниже — точки, у которых Z меньше этой отметки")
  (princ (strcat "\nТочки ровно на отметке (в пределах "
                 (rtos (* 1000.0 *gc-vo-find-eps*) 2 1)
                 " мм) не попадут ни туда, ни туда."))
  (initget "Выше В Ниже Н")
  (setq kw (getkword (strcat "\nОтобрать [Выше/Ниже] <"
                             (if (= *gc-vo-find-side* "DOWN") "Ниже" "Выше")
                             ">: ")))
  (cond
    ((null kw)
     ;; Enter — берём то, что показано в подсказке, и говорим об этом вслух.
     (princ (strcat "\n[i] Взято: " (gc-vo-find-side-name)))
     *gc-vo-find-side*)
    ((gc-vo-is-word kw '("Ниже" "Н")) (setq *gc-vo-find-side* "DOWN"))
    (T                                (setq *gc-vo-find-side* "UP"))))

;; Откуда брать точки: выделенные рамкой либо весь чертёж.
;; ПОЧЕМУ спрашиваем: на большом чертеже «все точки ниже 4,900» — это может
;; быть половина съёмки с других участков. Enter оставляет прежнее поведение
;; «искать везде», но выбор осознанный.
(defun gc-vo-find-source ( / ss)
  (princ "\n\nГде искать: выделите область рамкой")
  (princ "\nили нажмите Enter, чтобы искать по всему чертежу.")
  (princ "\nВыберите объекты: ")
  (setq ss (ssget *gc-vo-ssget-filter*))
  (if ss
    (progn
      (princ (strcat "\n[i] Ищем среди выделенных точек: " (itoa (sslength ss))))
      ss)
    (progn
      (setq ss (ssget "_X" *gc-vo-ssget-filter*))
      (if ss
        (princ (strcat "\n[i] Ищем по всему чертежу, точек: "
                       (itoa (sslength ss))))
        (princ "\n[!] В чертеже нет точек."))
      ss)))

;; Отбор. Возвращает набор отобранных точек либо nil.
;; Заодно считает, сколько точек оказалось ровно на отметке и сколько
;; пришлось пропустить без высоты — молча терять объекты нельзя.
(defun gc-vo-find-filter (ss z side / i n ent c out same skip dz)
  (setq out (ssadd) same 0 skip 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c   (gc-vo-entity-xyz ent))
    (if (null c)
      (setq skip (1+ skip))
      (progn
        (setq dz (- (caddr c) z))
        (cond
          ((< (abs dz) *gc-vo-find-eps*) (setq same (1+ same)))
          ((if (= side "DOWN") (< dz 0.0) (> dz 0.0)) (ssadd ent out))
          (T nil))))
    (setq i (1+ i)))
  (if (> same 0)
    (princ (strcat "\n[i] Ровно на отметке: " (itoa same)
                   " — они не отобраны ни как выше, ни как ниже.")))
  (if (> skip 0)
    (princ (strcat "\n[!] Пропущено объектов без высоты: " (itoa skip))))
  (if (> (sslength out) 0) out nil))

;; Кнопка «Найти». Возвращает T — продолжать работу, nil — выйти из команды.
;;
;; ПОЧЕМУ после удачного отбора команда ЗАВЕРШАЕТСЯ: пока VO работает,
;; с выделением ничего не сделать — ни удалить, ни подвинуть, ни свойства
;; задать. Держать пользователя внутри команды с готовым выделением
;; бессмысленно. Отбор ничего не нашёл — остаёмся, чтобы можно было сразу
;; повторить с другой отметкой.
(defun gc-vo-find ( / z side ss out)
  (setq z (gc-vo-ask-find-z))
  (cond
    ((null z) T)
    (T
     (setq *gc-vo-find-z* z)
     (setq side (gc-vo-ask-find-side z))
     (setq ss (gc-vo-find-source))
     (cond
       ((null ss) T)
       (T
        (princ (strcat "\n[i] Отбор: точки " (gc-vo-find-side-name)
                       " отметки " (gc-vo-fmt z) " м"))
        (setq out (gc-vo-find-filter ss z side))
        (cond
          ((null out)
           (princ (strcat "\n[i] Подходящих точек не нашлось. Попробуйте"
                          " другую отметку или сторону."))
           T)
          (T
           ;; sssetfirst оставляет объекты выделенными с ручками после выхода
           ;; из команды — сразу можно Delete / Move / задать свойства.
           (sssetfirst nil out)
           (princ (strcat "\n[i] Отобрано точек: " (itoa (sslength out))))
           (princ "\n[i] Они выделены. VO завершена, чтобы с ними можно было")
           (princ "\n    работать: удалить, подвинуть, задать свойства.")
           nil)))))))

;;; ====================================================================
;;; КНОПКИ — СВОЙ НАБОР НА КАЖДЫЙ РЕЖИМ
;;; ====================================================================

;; ПОЧЕМУ набор кнопок зависит от режима: настройка, которая в этом режиме
;; ни на что не влияет, не должна быть доступна. Именно её нажатие и создавало
;; ощущение, что режимы конфликтуют между собой.
;;
;; ПОЧЕМУ каждое слово продублировано одной буквой: для кириллицы AutoCAD
;; не распознаёт заглавную букву как сокращение и требует слово целиком
;; (docs/pitfalls.md -> П7). Первые буквы у всех кнопок разные:
;; Р, О, С, Т, З, Н, В.
;;
;; «Найти» есть во всех режимах: отбор по высоте ни от одной настройки
;; не зависит и ни одну не меняет.

(defun gc-vo-keys ( / )
  (cond
    ((= *gc-vo-mode* "SS")
     "Режим Р Отметка О Текст Т Зазор З Найти Н Выход В")
    ((= *gc-vo-mode* "PAIR")
     "Режим Р Способ С Текст Т Найти Н Выход В")
    (T
     "Режим Р Отметка О Способ С Текст Т Найти Н Выход В")))

(defun gc-vo-prm ( / )
  (cond
    ((= *gc-vo-mode* "SS")   " [Режим/Отметка/Текст/Зазор/Найти/Выход]")
    ((= *gc-vo-mode* "PAIR") " [Режим/Способ/Текст/Найти/Выход]")
    (T                       " [Режим/Отметка/Способ/Текст/Найти/Выход]")))

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
    (initget (gc-vo-keys))
    (cond
      ((= *gc-vo-fact-src* "PT")
       (setq sel (getpoint prompt))
       (cond
         ((null sel)  (setq res "MENU"))
         ;; Z берём из МСК: в наклонённой или поднятой ПСК то же число
         ;; означало бы другую высоту, и отклонение вышло бы неверным.
         ((listp sel) (setq res (caddr (gc-vo-w sel))))
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
;; Обработка нажатой кнопки. Возвращает T — продолжать, nil — выйти.
;; Каждая кнопка-настройка открывает СВОИ кнопки, ни одна не переключается
;; вслепую по нажатию.
(defun gc-vo-do-option (kw / )
  (cond
    ((gc-vo-is-word kw '("MENU"))          (gc-vo-menu))
    ((gc-vo-is-word kw '("Режим"   "Р"))   (gc-vo-set-mode) T)
    ((gc-vo-is-word kw '("Отметка" "О"))   (gc-vo-set-proj) T)
    ((gc-vo-is-word kw '("Способ"  "С"))   (gc-vo-set-fact-src) T)
    ((gc-vo-is-word kw '("Текст"   "Т"))   (gc-vo-set-text-h) T)
    ((gc-vo-is-word kw '("Зазор"   "З"))   (gc-vo-set-gap) T)
    ((gc-vo-is-word kw '("Найти"   "Н"))   (gc-vo-find))
    ((gc-vo-is-word kw '("Выход"   "В"))   nil)
    (T (princ (strcat "\n[!] Кнопка \"" kw "\" не распознана.")) T)))


;;; ====================================================================
;;; ПРОВЕРКА ЧЕРТЕЖА
;;; ====================================================================

;; ПОЧЕМУ это нужно: «команда отработала, а на чертеже ничего нет» — почти
;; всегда свойство КОНКРЕТНОГО чертежа, а не кода. Отсюда и «в одном чертеже
;; не работает, в других работает». Частые причины:
;;   1. слой выключен или заморожен — объекты создаются, но их не видно;
;;   2. слой заблокирован;
;;   3. текстовый стиль аннотативный — без масштаба аннотаций текст не
;;      отображается вовсе;
;;   4. у стиля фиксированная высота — заданная нами высота игнорируется.
;; Проверяем один раз за запуск команды и говорим вслух.

;; Слой выключен (отрицательный цвет), заморожен (бит 1) или заблокирован
;; (бит 4). Выключенный и замороженный включаем: иначе команда рисует
;; в пустоту, и это выглядит как «ничего не происходит».
(defun gc-vo-check-layer (lay / e flags col off frozen locked ent ed)
  (setq e (tblsearch "LAYER" lay))
  (if e
    (progn
      (setq flags  (cdr (assoc 70 e))
            col    (cdr (assoc 62 e)))
      (setq frozen (= 1 (logand flags 1))
            locked (= 4 (logand flags 4))
            off    (< col 0))
      (if (or off frozen)
        (progn
          (princ (strcat "\n[!] Слой " lay
                         (if off " был ВЫКЛЮЧЕН" "")
                         (if frozen " был ЗАМОРОЖЕН" "")
                         "."))
          (princ "\n    Объекты создавались, но их не было видно.")
          (setq ent (tblobjname "LAYER" lay)
                ed  (entget ent))
          (if off
            (setq ed (subst (cons 62 (abs col)) (assoc 62 ed) ed)))
          (if frozen
            (setq ed (subst (cons 70 (- flags 1)) (assoc 70 ed) ed)))
          (entmod ed)
          (princ "\n    Слой включён — перезапустите команду.")))
      (if locked
        (princ (strcat "\n[!] Слой " lay " ЗАБЛОКИРОВАН: объекты создадутся,"
                       "\n    но выделить и править их будет нельзя.")))))
  T)

;; Аннотативный стиль хранит признак в XDATA приложения AcadAnnotative.
(defun gc-vo-style-annotative-p (name / o ed)
  (setq o (tblobjname "STYLE" name))
  (if o
    (if (assoc -3 (entget o '("AcadAnnotative"))) T nil)
    nil))

(defun gc-vo-check-style ( / name)
  ;; Высоту больше не проверяем: gc-vo-text-style сам берёт только стиль
  ;; с переменной высотой, а если таких нет — заводит собственный.
  (setq name (gc-vo-text-style))
  (princ (strcat "\n[i] Текстовый стиль: " name))
  (if (gc-vo-style-annotative-p name)
    (progn
      (princ (strcat "\n[!] Стиль " name " АННОТАТИВНЫЙ."))
      (princ "\n    Такой текст не отображается, пока в чертеже не выбран")
      (princ "\n    масштаб аннотаций. Если подписей не видно — включите")
      (princ "\n    масштаб аннотаций в строке состояния.")))
  name)

;; ПСК больше не мешает работе (место подписи переводится в МСК), но сказать
;; о ней стоит: если подписи встанут не там, где ждали, это первая подсказка.
(defun gc-vo-check-ucs ( / )
  (if (gc-vo-wcs-p)
    (princ "\n[i] ПСК: мировая.")
    (progn
      (princ "\n[i] ПСК: пользовательская (повёрнута или сдвинута).")
      (princ "\n    Учтено — подписи ставятся туда, куда вы указываете."))))

(defun gc-vo-check-env ( / )
  (gc-vo-check-layer *gc-vo-layer*)
  (gc-vo-check-style)
  (gc-vo-check-ucs)
  (princ))

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-vo-defaults ( / )
  (if (null *gc-vo-mode*)      (setq *gc-vo-mode*      "ONE"))
  (if (null *gc-vo-fact-src*)  (setq *gc-vo-fact-src*  "OBJ"))
  (if (null *gc-vo-text-h*)    (setq *gc-vo-text-h*    *gc-vo-text-h-init*))
  (if (null *gc-vo-gap*)       (setq *gc-vo-gap*       *gc-vo-gap-init*))
  (if (null *gc-vo-find-side*) (setq *gc-vo-find-side* "UP")))

(defun gc-vo-intro ( / )
  (princ "\n\n=== VO — отклонение фактической высоты от проектной ===")
  (princ "\nПодписывает, насколько точка выше (+) или ниже (-) проекта, в мм.")
  (princ "\n")
  (princ "\nГлавная развилка — РЕЖИМ РАБОТЫ, всё остальное подчинено ему:")
  (princ "\n  Одной  — щёлкаете точку, потом указываете место подписи")
  (princ "\n  Рамкой — выделяете все точки разом, подписи встают сами")
  (princ "\n  Парами — проектная точка, затем фактическая (уклон, лестница)")
  (princ "\n")
  (princ "\nКнопки настроек показываются ТОЛЬКО те, что работают в текущем")
  (princ "\nрежиме, поэтому мешать друг другу им нечем:")
  (princ "\n  Отметка — общая проектная отметка   (Одной, Рамкой)")
  (princ "\n  Способ  — точки объектом или кликом (Одной, Парами)")
  (princ "\n  Зазор   — отступ подписи от точки   (Рамкой)")
  (princ "\n  Текст   — высота текста            (везде)")
  (princ "\n")
  (princ "\nОтдельно от режимов:")
  (princ "\n  Найти   — отобрать точки выше или ниже заданной отметки.")
  (princ "\n            Найденные остаются выделенными, команда завершается,")
  (princ "\n            чтобы с ними сразу можно было работать.")
  (princ "\n")
  (princ "\nКаждая настройка открывает свои кнопки с названиями — вслепую")
  (princ "\nничего не переключается.")
  (princ "\nКнопку можно щёлкнуть мышью или набрать её первую букву.")
  (princ "\nEnter — запасное текстовое меню, Выход или Esc — выход."))

;; В строке состояния показываем ТОЛЬКО то, что в этом режиме работает.
;; Иначе она сама вводила бы в заблуждение: зазор при указании места вручную
;; ни на что не влияет, а общая отметка не участвует в режиме «Парами».
(defun gc-vo-status ( / )
  (princ (strcat "\n\n--- VO | режим: " (gc-vo-mode-word)
                 (cond
                   ((= *gc-vo-mode* "SS")
                    (strcat " | отметка: " (gc-vo-proj-disp)
                            " | зазор: " (gc-vo-fmt *gc-vo-gap*) " м"))
                   ((= *gc-vo-mode* "PAIR")
                    (strcat " | точки: " (gc-vo-fact-src-word)))
                   (T
                    (strcat " | отметка: " (gc-vo-proj-disp)
                            " | точки: " (gc-vo-fact-src-word))))
                 " | текст: " (gc-vo-fmt *gc-vo-text-h*) " м ---")))

;; Считает и ставит подпись в месте, указанном мышью.
;; Общая часть режимов «Одной» и «Парами» — раньше этот кусок был вписан
;; прямо в цикл дважды по-разному, и в этом была часть путаницы.
(defun gc-vo-place (z-fact z-proj / dev-mm txt pt)
  (setq dev-mm (gc-vo-round (* 1000.0 (- z-fact z-proj))))
  (setq txt    (gc-vo-fmt-dev dev-mm))
  (princ (strcat "\n[i] Факт " (gc-vo-fmt z-fact)
                 "  -  проект " (gc-vo-fmt z-proj)
                 "  =  " txt))
  ;; Сразу в МСК: entmake кладёт объект в мировые координаты,
  ;; см. блок «ПСК И МСК».
  (setq pt (gc-vo-w (getpoint "\nКуда поставить подпись: ")))
  (if (null pt)
    ;; Не выходим из команды: вычисление сделано, Шамиль мог просто
    ;; промахнуться — возвращаемся к следующей точке.
    (princ "\n[!] Место не указано, подпись не поставлена.")
    (progn
      (gc-vo-draw-text pt txt)
      (princ (strcat "\n[i] Поставлена подпись " txt))))
  T)

;; --- Режим «Одной»: точка -> место подписи. Отметка общая.
;; Возвращает T — продолжать, nil — выйти.
(defun gc-vo-step-one ( / r)
  (setq r (gc-vo-prompt-z (strcat "\nФактическая точка" (gc-vo-prm) ": ")))
  (cond
    ((numberp r) (gc-vo-place r *gc-vo-proj-z*))
    (T           (gc-vo-do-option r))))

;; --- Режим «Парами»: проектная точка -> фактическая -> место подписи.
;; Возвращает T — продолжать, nil — выйти.
;; ПОЧЕМУ отдельной функцией: у пары два запроса, и на первом тоже могут
;; нажать кнопку. Раньше это решалось флагом step-ok посреди общего цикла,
;; и читать такой цикл было тяжело.
(defun gc-vo-step-pair ( / r z-proj)
  (setq r (gc-vo-prompt-z (strcat "\nПРОЕКТНАЯ точка" (gc-vo-prm) ": ")))
  (cond
    ((not (numberp r)) (gc-vo-do-option r))
    (T
     (setq z-proj r)
     (princ (strcat "\n[i] Проект этой точки: " (gc-vo-fmt z-proj) " м"))
     (setq r (gc-vo-prompt-z (strcat "\nФАКТИЧЕСКАЯ точка" (gc-vo-prm) ": ")))
     (cond
       ((numberp r) (gc-vo-place r z-proj))
       (T           (gc-vo-do-option r))))))

;; --- Режим «Рамкой»: кнопки, затем выборка рамкой и подпись всех точек.
;; Возвращает T — продолжать, nil — выйти.
;; ПОЧЕМУ кнопки в отдельном запросе ПЕРЕД выборкой: ssget не поддерживает
;; ключевые слова initget, показать кнопки в самом запросе выборки нельзя
;; (docs/pitfalls.md -> П18). Enter сразу ведёт к выборке — это один лишний
;; Enter на участок.
(defun gc-vo-step-ss ( / kw)
  (initget (gc-vo-keys))
  (setq kw (getkword (strcat "\nДальше" (gc-vo-prm)
                             " <Enter — выделить точки>: ")))
  (cond
    ((null kw) (gc-vo-batch))
    (T         (gc-vo-do-option kw))))

(defun gc-vo-run ( / done)
  (gc-vo-defaults)
  (gc-vo-intro)
  ;; Проверяем чертёж до работы: слой и стиль могут молча съесть всю графику.
  (gc-vo-ensure-layer *gc-vo-layer* *gc-vo-layer-color*)
  (gc-vo-check-env)
  ;; Общая отметка нужна в «Одной» и «Рамкой»; в «Парами» она не участвует.
  (if (and (/= *gc-vo-mode* "PAIR") (null *gc-vo-proj-z*))
    (gc-vo-set-proj))
  (setq done nil)
  (while (not done)
    (gc-vo-status)
    ;; Один шаг режима. Каждый возвращает T — продолжать, nil — выйти.
    (if (null
          (cond
            ((= *gc-vo-mode* "SS")   (gc-vo-step-ss))
            ((= *gc-vo-mode* "PAIR") (gc-vo-step-pair))
            (T                       (gc-vo-step-one))))
      (setq done T)))
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

;;; ====================================================================
;;; ИМЕНА КОМАНД В РУССКОЙ РАСКЛАДКЕ
;;; ====================================================================

;; Шамиль часто набирает команду, забыв переключить раскладку: вместо
;; OL получается ЩД. Регистрируем те же команды под кириллическими
;; именами — это буквы на ТЕХ ЖЕ клавишах в ЙЦУКЕН, поэтому руки
;; набирают одно движение, а команда запускается при любой раскладке.
;; ПОЧЕМУ и строчные, и прописные: AutoCAD приводит ввод к верхнему
;; регистру не всегда предсказуемо для кириллицы — регистрируем оба.

;; VO -> МЩ
(defun c:мщ ( / ) (c:vo))
(defun c:МЩ ( / ) (c:vo))
(princ "\n[gc] vo.lsp v15 загружен. Команда: VO | рус. раскладка: МЩ")
(princ)
