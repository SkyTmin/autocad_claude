;;; kg.lsp -- kartogramma zemlyanyh mass (SPEC-009 v7)
;;; Komandy:
;;;   KG          -- osnovnaya komanda.
;;;   GC-CARTOGRAM -- polnoe imya toy zhe komandy.
;;;   ЛП          -- to zhe v russkoy raskladke.
;;;
;;; v7: ETAP 2 IZ 5 -- SETKA.
;;;     Po granice ploshchadki stroitsya setka kvadratov s zadannym shagom,
;;;     uglom i bazovoy tochkoy. Kraevye kvadraty libo obrezayutsya granicey,
;;;     libo ostayutsya celymi -- tumbler v okne.
;;;
;;;     PLOSHCHAD KAZHDOGO KVADRATA SCHITAETSYA CHISLOM, a ne tolko risuetsya.
;;;     Ona nuzhna dlya obema na etape 4, i vytaskivat ee obratno s chertezha
;;;     bylo by lishnim shagom s poterey tochnosti.
;;;
;;;     Otsechenie -- algoritm Sazerlenda-Hodgmana: kontur ploshchadki
;;;     posledovatelno otsekaetsya chetyrmya pryamymi kvadrata. On veren dlya
;;;     vypukloy otsekayushchey figury, a kvadrat vypuklyy vsegda.
;;;
;;;     KONTROL: summa ploshchadey kvadratov sveryaetsya s ploshchadyu granicy
;;;     i pechataetsya rashozhdenie. Oshibka v otsechenii vylezet srazu chislom.
;;;
;;;     Posle okna teper odin vopros: Setka / Proverka / Vyhod.
;;;
;;; v6: DVE OSHIBKI, NAYDENNYE NA PERVOM ZHE ZHIVOM PROGONE.
;;;
;;;     1. NOL PRI RABOCHEY OTMETKE. Odno i to zhe znachenie pokazyvalos
;;;        po-raznomu: "+0,000 (nasyp)" i "0,000 (vyemka)". Prichina --
;;;        sravnenie (>= h 0.0) bez dopuska: znak zavisel ot nevidimogo shuma
;;;        v poslednem razryade. Dlya kartogrammy eto ne kosmetika: uzel,
;;;        popavshiy na liniyu nulevyh rabot, otnesetsya to k vyemke,
;;;        to k nasypi, i ves kvadrat poschitaetsya po-raznomu.
;;;        Teper tri klassa s dopuskom, kak v docs/formulas.md.
;;;
;;;     2. ESC PRINIMALSYA ZA OSHIBKU. Na russkom AutoCAD otmena prihodit
;;;        soobshcheniem "Funkciya prervana.", a my sravnivali tolko
;;;        s angliyskimi BREAK/CANCEL/QUIT. Normalnyy vyhod po Esc vyglyadel
;;;        kak sboy komandy.
;;;
;;; v5: ISPRAVLEN PEREBOR POVERHNOSTEY. Podklyuchenie k Civil 3D zarabotalo
;;;     (v4), chertezh i chislo poverhnostey chitalis, no na pervoy zhe
;;;     poverhnosti: "poverhnost #0: Chlen gruppy ne nayden".
;;;     Prichina: bralis cherez (vlax-invoke kollekciya 'Item i). U kollekciy
;;;     Civil 3D "Item" ne metod, a svoystvo s argumentom, libo ego net vovse.
;;;     Teper snachala idet shtatnyy perebor vlax-for cherez perechislitel
;;;     kollekcii -- on Item ne trebuet. Item ostavlen zapasnym putem,
;;;     v dvuh vidah: kak metod i kak svoystvo.
;;;     Zaodno imena i obekty poverhnostey teper hranyatsya paroy, poetomu
;;;     iskat obekt po imeni cherez Item bolshe ne nuzhno voobshche.
;;;
;;; v4: ISPRAVLENO PODKLYUCHENIE K CIVIL 3D. v3 pisala "eto obychnyy AutoCAD"
;;;     na mashine, gde Civil 3D yavno zapushchen.
;;;     Prichina: ispolzovalsya tolko vlax-get-object, a obekt prilozheniya
;;;     Civil 3D ne obyazan byt v tablice zapushchennyh obektov Windows.
;;;     Shtatnyy sposob -- sprosit ego u samogo AutoCAD cherez
;;;     GetInterfaceObject. Teper probuyutsya TRI sposoba na kazhdyy ProgID,
;;;     spisok versiy rasshiren, i komanda pechataet otchet: versiyu CAD,
;;;     kakie ProgID probovalis i chto otvetil kazhdyy.
;;;
;;; v3: ISPRAVLENA OSHIBKA "Chlen gruppy ne nayden" -- komanda padala
;;;     do otkrytiya okna. Prichina: chast COM-vyzovov pri chtenii spiska
;;;     poverhnostey byla BEZ perehvata oshibok, i lyuboy otkaz Civil 3D
;;;     ronyal vsyu komandu.
;;;     Teper KAZHDYY COM-vyzov obernut, i pri otkaze komanda ne padaet,
;;;     a otkryvaet okno i pishet, NA KAKOM SHAGE i s kakim soobshcheniem
;;;     sorvalos. Spisok poverhnostey ne prochitalsya -- pole gasnet,
;;;     no vse ostalnye nastroyki dostupny.
;;;     Zaodno vlax-get-object vmesto vlax-get-or-create-object: vtoroy mog
;;;     ZAPUSTIT eshche odin ekzemplyar Civil 3D vmesto podklyucheniya
;;;     k rabotayushchemu.
;;;
;;; v2: PROVERKA OTMETOK. Posle OK komanda predlagaet potykat po chertezhu
;;;     i pokazyvaet, kakuyu otmetku vernula kazhdaya poverhnost i kakaya
;;;     poluchaetsya rabochaya.
;;;
;;;     POCHEMU ETO SDELANO RANSHE SETKI. Vsya kartogramma stoit na ODNOY
;;;     vneshney operacii -- "day otmetku poverhnosti v tochke XY" (ADR-0005).
;;;     Esli ona ne rabotaet, vse ostalnoe bessmyslenno. Proverit ee otdelno
;;;     stoit minutu, a naytis oshibka posle napisannoy setki i obemov
;;;     budet dolgo i neponyatno gde.
;;;
;;; ETAP 1 IZ 5: DIALOG NASTROEK.
;;; Sejchas komanda otkryvaet okno, sobiraet i zapominaet vse nastroyki
;;; i pechataet ih v konsol. Setku, obemy i vedomost dobavlyaem sleduyushchimi
;;; etapami -- komanda govorit ob etom vsluh, chtoby promezhutochnyy rezultat
;;; ne prinyali za gotovyy (Hard Rule R6).
;;;
;;; POCHEMU DIALOG, A NE KOMANDNAYA STROKA: u kartogrammy okolo tridcati
;;; parametrov, cherez initget oni nechitaemy. Sm. ADR-0006.
;;;
;;; POCHEMU TEKST DCL LEZHIT VNUTRI ETOGO FAYLA: chtoby rasprostranyalsya
;;; ODIN fayl, kak trebuet ADR-0003. Pri otkrytii okna tekst pishetsya
;;; vo vremennyy fayl, posle zakrytiya fayl udalyaetsya.
;;;
;;; Kodirovka fayla: CP1251 bez BOM (ADR-0004). Ne UTF-8!

(vl-load-com)

;;; ====================================================================
;;; НАСТРОЙКИ ПО УМОЛЧАНИЮ
;;; ====================================================================

;; Имя диалога внутри DCL.
(setq *gc-kg-dlg* "gc_kg")

;; Значения при первом запуске. Дальше живут между вызовами до закрытия
;; чертежа: намеренно НЕ сбрасываются при повторной загрузке файла, иначе
;; каждый APPLOAD стирал бы настройки.
(setq *gc-kg-def*
  (list
    (cons "step-x"   "20")        ; шаг сетки вдоль X, м
    (cons "step-y"   "20")        ; шаг сетки вдоль Y, м
    (cons "angle"    "0")         ; угол поворота сетки, град
    (cons "trim"     "1")         ; обрезать краевые квадраты границей
    (cons "h-mark"   "0.5")       ; высота текста отметок, м
    (cons "p-mark"   2)           ; знаков после запятой у отметок
    (cons "h-vol"    "0.5")       ; высота текста объёмов, м
    (cons "p-vol"    1)           ; знаков после запятой у объёмов
    (cons "min-vol"  "0")         ; порог: объём ниже не подписывается, м3
    (cons "use-min"  "0")         ; включён ли порог
    (cons "c-black"  8)           ; цвет чёрной (существующей) отметки
    (cons "c-red"    1)           ; цвет красной (проектной) отметки
    (cons "c-work"   3)           ; цвет рабочей отметки
    (cons "c-plus"   5)           ; цвет насыпи  (+)
    (cons "c-minus"  1)           ; цвет выемки  (-)
    (cons "c-zero"   7)))         ; цвет нулевой зоны

;; Точность в выпадающем списке. Индекс списка = число знаков.
(setq *gc-kg-prec* '("0" "0,0" "0,00" "0,000"))

;; Допуск «рабочая отметка равна нулю», м. 0.0005 = полмиллиметра: ближе
;; этого две отметки после округления до миллиметра неразличимы.
;; То же значение и по той же причине, что в docs/formulas.md.
;;
;; ПОЧЕМУ БЕЗ ДОПУСКА НЕЛЬЗЯ: сравнение (>= h 0.0) относит к насыпи всё,
;; включая ноль, а знак у настоящего нуля зависит от шума в последнем
;; разряде — одно и то же место оказывалось то выемкой, то насыпью.
;; Для картограммы это не косметика: узел на линии нулевых работ попадёт
;; не в свой класс, и весь квадрат посчитается иначе.
(setq *gc-kg-zero-eps* 0.0005)

;;; ====================================================================
;;; МЕЛОЧИ
;;; ====================================================================

(defun gc-kg-get (k)
  (cdr (assoc k *gc-kg-cfg*)))

(defun gc-kg-set (k v)
  (if (assoc k *gc-kg-cfg*)
    (setq *gc-kg-cfg* (subst (cons k v) (assoc k *gc-kg-cfg*) *gc-kg-cfg*))
    (setq *gc-kg-cfg* (cons (cons k v) *gc-kg-cfg*))))

;; Обрезка пробелов без vl-string-trim — не зависим от сборки.
(defun gc-kg-trim (s / a b)
  (setq a 0 b (strlen s))
  (while (and (< a b) (= " " (substr s (1+ a) 1))) (setq a (1+ a)))
  (while (and (> b a) (= " " (substr s b 1)))      (setq b (1- b)))
  (substr s (1+ a) (- b a)))

;; Число из строки. Запятая и точка равнозначны — у Шамиля в чертежах
;; разделитель запятая, а read понимает только точку.
;; Возвращает число либо nil.
(defun gc-kg-num (s / i ch out dot)
  (setq s (gc-kg-trim s) out "" dot nil i 1)
  (if (= s "")
    nil
    (progn
      (while (<= i (strlen s))
        (setq ch (substr s i 1))
        (cond
          ((or (= ch ",") (= ch "."))
           (if dot (setq out nil i (strlen s)) (setq out (strcat out ".") dot T)))
          ((and (= i 1) (= ch "-")) (setq out "-"))
          ((and out (>= (ascii ch) 48) (<= (ascii ch) 57)) (setq out (strcat out ch)))
          (T (setq out nil i (strlen s))))
        (setq i (1+ i)))
      (if (and out (/= out "") (/= out "-") (/= out ".") (/= out "-."))
        (atof out)
        nil))))

;; Число в строку с запятой — так его привык видеть Шамиль.
(defun gc-kg-fmt (x / s i out ch)
  (setq s (rtos x 2 3) out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq out (strcat out (if (= ch ".") "," ch)))
    (setq i (1+ i)))
  out)

;;; ====================================================================
;;; ЧТЕНИЕ ЧЕРТЕЖА
;;; ====================================================================

;; Проверка доступности Visual LISP COM — docs/pitfalls.md -> П6.
(defun gc-kg-com-ok ( / )
  (if (null vlax-get-acad-object) (vl-load-com))
  (if vlax-get-acad-object T nil))

;; Список имён текстовых стилей чертежа.
(defun gc-kg-styles ( / e out)
  (setq out '() e (tblnext "STYLE" T))
  (while e
    (setq out (cons (cdr (assoc 2 e)) out))
    (setq e (tblnext "STYLE")))
  (reverse out))

;; Список имён поверхностей Civil 3D.
;;
;; ПОЧЕМУ перебор ProgID: у каждой версии Civil 3D он свой, а жёстко зашитый
;; номер сломался бы при первом же обновлении. Перебираем известные, берём
;; первый откликнувшийся. Не отозвался ни один — значит либо это обычный
;; AutoCAD, либо COM недоступен; тогда имя поверхности вводится вручную.
;; Безопасное чтение свойства COM.
;; Возвращает (T . значение) при успехе либо (nil . текст-ошибки).
;;
;; ПОЧЕМУ обёрнуто ВСЁ. В v2 часть вызовов была без перехвата, и первый же
;; отказ Civil 3D ронял команду целиком — окно даже не открывалось.
;; COM отказывает по десятку причин, и почти все не наши: не та версия,
;; чертёж не Civil 3D, поверхность занята. Падать из-за этого нельзя.
(defun gc-kg-com-get (obj prop / r)
  (setq r (vl-catch-all-apply 'vlax-get (list obj prop)))
  (if (vl-catch-all-error-p r)
    (cons nil (vl-catch-all-error-message r))
    (cons T r)))

;; Известные имена подключения к Civil 3D. У каждой версии своё, поэтому
;; перебираем: жёстко зашитое сломалось бы при первом обновлении.
(setq *gc-kg-progids*
  '("AeccXUiLand.AeccApplication.13.7" "AeccXUiLand.AeccApplication.13.6"
    "AeccXUiLand.AeccApplication.13.5" "AeccXUiLand.AeccApplication.13.4"
    "AeccXUiLand.AeccApplication.13.3" "AeccXUiLand.AeccApplication.13.2"
    "AeccXUiLand.AeccApplication.13.1" "AeccXUiLand.AeccApplication.13.0"
    "AeccXUiLand.AeccApplication.12.0" "AeccXUiLand.AeccApplication.11.0"
    "AeccXUiLand.AeccApplication.10.6" "AeccXUiLand.AeccApplication.10.5"
    "AeccXUiLand.AeccApplication.10.4" "AeccXUiLand.AeccApplication.10.0"
    "AeccXUiLand.AeccApplication.9.0"  "AeccXUiLand.AeccApplication.8.0"))

;; Системная переменная строкой, с защитой: на разных сборках часть
;; переменных отсутствует.
(defun gc-kg-var (name / r)
  (setq r (vl-catch-all-apply 'getvar (list name)))
  (if (or (vl-catch-all-error-p r) (null r)) "?" (vl-princ-to-string r)))

;; Копим отчёт о попытках подключения.
(defun gc-kg-log (pid how msg / )
  (setq *gc-kg-try-log*
    (cons (strcat "    " pid "  [" how "]  " msg) *gc-kg-try-log*)))

;; Подключение к Civil 3D одним из трёх способов.
;;
;; ПОЧЕМУ ТРИ, А НЕ ОДИН. Объект приложения Civil 3D не обязан быть
;; зарегистрирован в таблице запущенных объектов Windows, поэтому
;; vlax-get-object его часто не находит — именно на этом v3 объявила
;; настоящий Civil 3D «обычным автокадом».
;; Штатный способ — спросить объект у самого AutoCAD через GetInterfaceObject,
;; он и идёт первым. Остальные два запасные: на разных сборках срабатывают
;; разные, а угадывать заранее нечем.
;;
;; Возвращает объект либо nil. Что пробовали и что ответило — копится
;; в *gc-kg-try-log* для отчёта.
(defun gc-kg-connect (pid / acad r)
  (setq r nil)
  ;; 1. GetInterfaceObject у объекта AutoCAD — основной путь для Civil 3D.
  (setq acad (vl-catch-all-apply 'vlax-get-acad-object nil))
  (if (not (vl-catch-all-error-p acad))
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke (list acad 'GetInterfaceObject pid)))
      (if (vl-catch-all-error-p r)
        (progn
          (gc-kg-log pid "GetInterfaceObject" (vl-catch-all-error-message r))
          (setq r nil))
        (gc-kg-log pid "GetInterfaceObject" "ok"))))
  ;; 2. Уже работающий экземпляр из таблицы запущенных объектов.
  (if (null r)
    (progn
      (setq r (vl-catch-all-apply 'vlax-get-object (list pid)))
      (if (vl-catch-all-error-p r)
        (progn
          (gc-kg-log pid "get-object" (vl-catch-all-error-message r))
          (setq r nil))
        (if r (gc-kg-log pid "get-object" "ok")))))
  ;; 3. Последняя попытка. ПОЧЕМУ последняя: этот способ может ЗАПУСТИТЬ
  ;; ещё один экземпляр CAD в фоне вместо подключения к работающему.
  (if (null r)
    (progn
      (setq r (vl-catch-all-apply 'vlax-get-or-create-object (list pid)))
      (if (vl-catch-all-error-p r)
        (progn
          (gc-kg-log pid "get-or-create" (vl-catch-all-error-message r))
          (setq r nil))
        (if r (gc-kg-log pid "get-or-create" "ok")))))
  r)

;; Перебор версий. У каждой версии Civil 3D своё имя подключения, поэтому
;; жёстко зашитое сломалось бы при первом обновлении.
;; Годным считаем только тот объект, у которого реально читается чертёж:
;; подключиться иногда удаётся и к пустышке.
(defun gc-kg-app ( / res r doc)
  (setq res nil *gc-kg-try-log* nil *gc-kg-pid* nil)
  (foreach pid *gc-kg-progids*
    (if (null res)
      (progn
        (setq r (gc-kg-connect pid))
        (if r
          (progn
            (setq doc (gc-kg-com-get r "ActiveDocument"))
            (if (car doc)
              (setq res r *gc-kg-pid* pid)
              (gc-kg-log pid "ActiveDocument" (cdr doc))))))))
  res)

;; Отчёт: что за CAD перед нами и чем закончились попытки.
;; ПОЧЕМУ печатаем при неудаче целиком: гадать по строке «не удалось» можно
;; бесконечно, а тут сразу видно версию и ответ каждой попытки.
(defun gc-kg-connect-report ( / )
  (princ (strcat "\n[i] CAD: " (gc-kg-var "PRODUCT")
                 "  версия " (gc-kg-var "ACADVER")))
  (if *gc-kg-pid*
    (princ (strcat "\n[i] Civil 3D подключён: " *gc-kg-pid*))
    (progn
      (princ "\n[!] Ни одно имя подключения к Civil 3D не отозвалось.")
      (princ "\n    Что пробовали и что ответило:")
      (foreach s (reverse *gc-kg-try-log*) (princ (strcat "\n" s)))))
  (princ))

;; Перебор коллекции штатным перечислителем.
;; ПОЧЕМУ ТАК, А НЕ ЧЕРЕЗ Item: у коллекций Civil 3D "Item" — не метод,
;; а свойство с аргументом, и вызов его как метода даёт «Член группы
;; не найден». Перечислитель есть у всех коллекций и работает всегда.
;; Возвращает список пар (имя . объект).
(defun gc-kg-collect-for (coll / out)
  (setq out nil)
  (vlax-for o coll
    (setq out (cons (cons (vlax-get o 'Name) o) out)))
  (reverse out))

;; Запасной путь: Item как метод.
(defun gc-kg-collect-m (coll / n i o out)
  (setq out nil n (vlax-get coll "Count") i 0)
  (while (< i n)
    (setq o (vlax-invoke coll 'Item i))
    (setq out (cons (cons (vlax-get o 'Name) o) out))
    (setq i (1+ i)))
  (reverse out))

;; Запасной путь: Item как свойство с аргументом.
(defun gc-kg-collect-p (coll / n i o out)
  (setq out nil n (vlax-get coll "Count") i 0)
  (while (< i n)
    (setq o (vlax-get-property coll 'Item i))
    (setq out (cons (cons (vlax-get o 'Name) o) out))
    (setq i (1+ i)))
  (reverse out))

;; Перебрать коллекцию любым способом, который сработает.
;; Возвращает список пар (имя . объект) либо nil; причина — в *gc-kg-surf-why*.
(defun gc-kg-collect (coll / r)
  (setq r nil)
  (foreach way (list (cons "перечислитель" 'gc-kg-collect-for)
                     (cons "Item-метод"    'gc-kg-collect-m)
                     (cons "Item-свойство" 'gc-kg-collect-p))
    (if (null r)
      (progn
        (setq r (vl-catch-all-apply (cdr way) (list coll)))
        (if (vl-catch-all-error-p r)
          (progn
            (gc-kg-log "коллекция" (car way) (vl-catch-all-error-message r))
            (setq r nil))
          (if r (gc-kg-log "коллекция" (car way) "ok"))))))
  r)

;; Список имён поверхностей Civil 3D.
;; Никогда не падает. При отказе возвращает nil, а причину кладёт
;; в *gc-kg-surf-why* — её показываем в окне и печатаем в консоль.
;;
;; Имена и объекты храним ПАРОЙ: тогда достать поверхность по имени —
;; это простой поиск в списке, и лезть в коллекцию второй раз не нужно.
(defun gc-kg-surfaces ( / app r doc surfs pairs)
  (setq *gc-kg-surf-map* nil
        *gc-kg-surf-why* nil)
  (cond
    ((not (gc-kg-com-ok))
     (setq *gc-kg-surf-why* "Visual LISP COM недоступен в этой сборке CAD"))
    ((null (setq app (gc-kg-app)))
     (setq *gc-kg-surf-why*
       "не удалось подключиться к Civil 3D — возможно, это обычный AutoCAD"))
    (T
     (setq r (gc-kg-com-get app "ActiveDocument"))
     (cond
       ((null (car r))
        (setq *gc-kg-surf-why* (strcat "чертёж (ActiveDocument): " (cdr r))))
       (T
        (setq doc (cdr r))
        (setq r (gc-kg-com-get doc "Surfaces"))
        (cond
          ((null (car r))
           (setq *gc-kg-surf-why* (strcat "коллекция поверхностей: " (cdr r))))
          (T
           (setq surfs (cdr r))
           (setq pairs (gc-kg-collect surfs))
           (cond
             (pairs (setq *gc-kg-surf-map* pairs))
             (T
              (setq r (gc-kg-com-get surfs "Count"))
              (setq *gc-kg-surf-why*
                (if (and (car r) (= (cdr r) 0))
                  "в чертеже нет ни одной поверхности"
                  "перебрать поверхности не удалось ни одним способом"))))))))))
  (mapcar 'car *gc-kg-surf-map*))

;; Объект поверхности по имени — просто поиск в списке пар.
(defun gc-kg-surf-obj (name / r)
  (setq r (assoc name *gc-kg-surf-map*))
  (if r (cdr r) nil))

;; Отметка поверхности в точке XY (координаты в МСК).
;; Возвращает число либо nil, если точки на поверхности нет.
;;
;; ПОЧЕМУ через vl-catch-all-apply: за границей поверхности вызов не
;; возвращает nil, а ВЫБРАСЫВАЕТ ошибку. Без перехвата команда падала бы
;; на первом же узле сетки, вышедшем за край съёмки, — а таких узлов
;; на любой площадке полно.
(defun gc-kg-elev (obj x y / r)
  (if (null obj)
    nil
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke (list obj 'FindElevationAtXY x y)))
      (if (vl-catch-all-error-p r) nil r))))

;; Разовая диагностика: почему не удалось прочитать отметку.
;; Печатается ОДИН раз за запуск, иначе завалит консоль на большой сетке.
(defun gc-kg-elev-why (obj x y / r)
  (if (null obj)
    "поверхность не выбрана или не найдена в чертеже"
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke (list obj 'FindElevationAtXY x y)))
      (if (vl-catch-all-error-p r)
        (vl-catch-all-error-message r)
        "ошибки нет"))))

;;; ====================================================================
;;; ТЕКСТ ДИАЛОГА
;;;
;;; Лежит здесь, а не в отдельном .dcl — чтобы распространялся ОДИН файл
;;; (ADR-0003, ADR-0006). Разбит по разделам, чтобы читался.
;;; ====================================================================

(defun gc-kg-dcl-text ( / )
  (list
"gc_kg : dialog { label = \"Картограмма земляных масс\";"
"  : boxed_column { label = \" Поверхности \";"
"    : row {"
"      : column {"
"        : text { label = \"Чёрная (существующая)\"; }"
"        : text { label = \"Красная (проектная)\"; } }"
"      : column {"
"        : popup_list { key = \"s_black\"; width = 34; fixed_width = true; }"
"        : popup_list { key = \"s_red\";   width = 34; fixed_width = true; } } }"
"    : text { key = \"s_note\"; } }"
"  : row {"
"    : boxed_column { label = \" Сетка \";"
"      : edit_box { key = \"step_x\"; label = \"Шаг вдоль X, м \"; edit_width = 8; }"
"      : edit_box { key = \"step_y\"; label = \"Шаг вдоль Y, м \"; edit_width = 8; }"
"      : row {"
"        : edit_box { key = \"angle\"; label = \"Угол, град     \"; edit_width = 8; }"
"        : button   { key = \"pick_angle\"; label = \"Указать\"; fixed_width = true; } }"
"      : row {"
"        : text   { label = \"Базовая точка  \"; }"
"        : button { key = \"pick_base\"; label = \"Указать\"; fixed_width = true; } }"
"      : text   { key = \"base_txt\"; }"
"      : toggle { key = \"trim\"; label = \"Обрезать краевые квадраты границей\"; } }"
"    : boxed_column { label = \" Границы участка \";"
"      : row {"
"        : text   { label = \"Наружная      \"; }"
"        : button { key = \"pick_outer\"; label = \"Выбрать\"; fixed_width = true; } }"
"      : text { key = \"outer_txt\"; }"
"      : row {"
"        : text   { label = \"Внутренние    \"; }"
"        : button { key = \"pick_inner\"; label = \"Выбрать\"; fixed_width = true; } }"
"      : text { key = \"inner_txt\"; }"
"      : row {"
"        : text   { label = \"Хар. линии    \"; }"
"        : button { key = \"pick_lines\"; label = \"Выбрать\"; fixed_width = true; } }"
"      : text { key = \"lines_txt\"; } } }"
"  : boxed_column { label = \" Подписи отметок в узлах \";"
"    : row {"
"      : popup_list { key = \"t_style\"; label = \"Стиль текста \"; width = 22; fixed_width = true; }"
"      : edit_box   { key = \"h_mark\";  label = \" Высота, м \"; edit_width = 6; }"
"      : popup_list { key = \"p_mark\";  label = \" Точность \"; width = 7; fixed_width = true; } }"
"    : row {"
"      : text { label = \"Цвет:\"; }"
"      : text { label = \" чёрной\"; }"
"      : image_button { key = \"c_black\"; width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" красной\"; }"
"      : image_button { key = \"c_red\";   width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" рабочей\"; }"
"      : image_button { key = \"c_work\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; } } }"
"  : boxed_column { label = \" Объёмы \";"
"    : row {"
"      : edit_box   { key = \"h_vol\"; label = \"Высота текста, м \"; edit_width = 6; }"
"      : popup_list { key = \"p_vol\"; label = \" Точность \"; width = 7; fixed_width = true; } }"
"    : row {"
"      : toggle   { key = \"use_min\"; label = \"Не подписывать объём меньше \"; }"
"      : edit_box { key = \"min_vol\"; edit_width = 6; }"
"      : text     { label = \" м3\"; } }"
"    : row {"
"      : text { label = \"Цвет:\"; }"
"      : text { label = \" насыпь +\"; }"
"      : image_button { key = \"c_plus\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" выемка -\"; }"
"      : image_button { key = \"c_minus\"; width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" ноль\"; }"
"      : image_button { key = \"c_zero\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; } } }"
"  : text { key = \"err\"; }"
"  : row {"
"    : ok_button { }"
"    : cancel_button { } }"
"}"))

;; Записать текст диалога во временный файл. Возвращает путь либо nil.
(defun gc-kg-dcl-file ( / p f)
  (setq p (if vl-filename-mktemp
            (vl-filename-mktemp "gckg" nil ".dcl")
            (strcat (getvar "TEMPPREFIX") "gckg.dcl")))
  (setq f (open p "w"))
  (if (null f)
    (progn
      (princ (strcat "\n[ОШИБКА] Не удалось создать временный файл " p))
      (princ "\n    Проверьте права на папку временных файлов.")
      nil)
    (progn
      (foreach s (gc-kg-dcl-text) (write-line s f))
      (close f)
      p)))

;;; ====================================================================
;;; РАБОТА С ОКНОМ
;;; ====================================================================

;; ВНИМАНИЕ: у поля в окне и у настройки РАЗНЫЕ имена — "c_black" и "c-black".
;; Обе функции принимают имя ПОЛЯ и сами переводят его в имя настройки:
;; перепутать местами легко, а ошибка тихая — квадратик просто не найдётся.

;; Залить квадратик кнопки цветом — так виден выбранный цвет.
(defun gc-kg-show-color (tile col / w h)
  (setq w (dimx_tile tile) h (dimy_tile tile))
  (start_image tile)
  (fill_image 0 0 w h col)
  (end_image))

;; Клик по квадратику цвета — штатное окно выбора цвета AutoCAD.
(defun gc-kg-pick-color (tile / ck c)
  (setq ck (gc-kg-key tile))
  (setq c (acad_colordlg (gc-kg-get ck) nil))
  (if c
    (progn
      (gc-kg-set ck c)
      (gc-kg-show-color tile c)))
  c)

;; Заполнить выпадающий список и выставить в нём текущее значение.
(defun gc-kg-fill-list (key items sel / )
  (start_list key)
  (foreach s items (add_list s))
  (end_list)
  (if (and sel (>= sel 0)) (set_tile key (itoa sel))))

;; Номер элемента в списке либо 0.
(defun gc-kg-index-of (x lst / i n res)
  (setq i 0 n (length lst) res 0)
  (while (< i n)
    (if (= x (nth i lst)) (setq res i))
    (setq i (1+ i)))
  res)

;; Выбор объектов для границы. Возвращает набор либо nil.
;; ПОЧЕМУ фильтр по кривым: границей может быть не только полилиния, но и
;; дуга, окружность, эллипс, сплайн (SPEC-009 §5А.1).
(defun gc-kg-pick-curves (prompt one / ss)
  (princ (strcat "\n" prompt))
  (setq ss (ssget (if one "_+.:E:S" "")
                  '((0 . "LWPOLYLINE,POLYLINE,LINE,ARC,CIRCLE,ELLIPSE,SPLINE"))))
  ss)

;; Строка-описание выбранного набора для показа в окне.
(defun gc-kg-ss-txt (ss zero)
  (if ss (strcat "  выбрано: " (itoa (sslength ss))) zero))

;; Проверка полей при нажатии ОК. Возвращает T если всё разобрано.
;; ПОЧЕМУ не закрываем окно при ошибке: пользователь потеряет всё введённое.
;; Пишем причину в строку err и остаёмся.
(defun gc-kg-validate ( / v bad)
  (setq bad nil)
  (foreach pair '(("step_x" . "Шаг вдоль X")
                  ("step_y" . "Шаг вдоль Y")
                  ("h_mark" . "Высота текста отметок")
                  ("h_vol"  . "Высота текста объёмов"))
    (if (null bad)
      (progn
        (setq v (gc-kg-num (get_tile (car pair))))
        (cond
          ((null v)      (setq bad (strcat (cdr pair) ": нужно число")))
          ((<= v 1.0e-9) (setq bad (strcat (cdr pair) ": должно быть больше нуля")))))))
  (if (and (null bad) (null (gc-kg-num (get_tile "angle"))))
    (setq bad "Угол: нужно число"))
  (if (and (null bad) (= "1" (get_tile "use_min")))
    (progn
      (setq v (gc-kg-num (get_tile "min_vol")))
      (cond
        ((null v)   (setq bad "Порог объёма: нужно число"))
        ((< v 0.0)  (setq bad "Порог объёма: не может быть отрицательным")))))
  (if bad
    (progn (set_tile "err" (strcat "[!] " bad)) nil)
    T))

;; Забрать значения полей в настройки.
(defun gc-kg-read-tiles ( / )
  (foreach k '("step_x" "step_y" "angle" "h_mark" "h_vol" "min_vol")
    (gc-kg-set (gc-kg-key k) (get_tile k)))
  (gc-kg-set "trim"    (get_tile "trim"))
  (gc-kg-set "use-min" (get_tile "use_min"))
  (gc-kg-set "p-mark"  (atoi (get_tile "p_mark")))
  (gc-kg-set "p-vol"   (atoi (get_tile "p_vol")))
  (gc-kg-set "style"   (nth (atoi (get_tile "t_style")) *gc-kg-styles*))
  (if *gc-kg-surf-list*
    (progn
      (gc-kg-set "s-black" (nth (atoi (get_tile "s_black")) *gc-kg-surf-list*))
      (gc-kg-set "s-red"   (nth (atoi (get_tile "s_red"))   *gc-kg-surf-list*))))
  T)

;; Имя настройки по имени поля: step_x -> step-x. Разделитель у полей DCL
;; подчёркивание, у наших ключей дефис.
(defun gc-kg-key (k / i out ch)
  (setq out "" i 1)
  (while (<= i (strlen k))
    (setq ch (substr k i 1))
    (setq out (strcat out (if (= ch "_") "-" ch)))
    (setq i (1+ i)))
  out)

;; Открыть окно. Возвращает T если нажали ОК.
(defun gc-kg-dialog ( / path id res)
  (setq *gc-kg-styles*    (gc-kg-styles))
  (setq *gc-kg-surf-list* (gc-kg-surfaces))
  ;; Причину печатаем и в консоль: в окне строка короткая, а тут влезает
  ;; целиком вместе с сообщением самого CAD.
  (cond
    ((and (null *gc-kg-surf-list*) *gc-kg-surf-why*)
     (princ (strcat "\n[!] Поверхности прочитать не удалось: " *gc-kg-surf-why*))
     (gc-kg-connect-report)
     (princ "\n    Окно откроется, остальные настройки доступны."))
    (*gc-kg-surf-list*
     (princ (strcat "\n[i] Поверхностей найдено: "
                    (itoa (length *gc-kg-surf-list*))))))
  (setq path (gc-kg-dcl-file))
  (if (null path)
    nil
    (progn
      (setq id (load_dialog path))
      (cond
        ((< id 0)
         (princ "\n[ОШИБКА] Не удалось загрузить диалог.")
         nil)
        ((not (new_dialog *gc-kg-dlg* id))
         (princ "\n[ОШИБКА] Диалог не открылся.")
         (unload_dialog id)
         nil)
        (T
         ;; --- поверхности
         (if *gc-kg-surf-list*
           (progn
             (gc-kg-fill-list "s_black" *gc-kg-surf-list*
               (gc-kg-index-of (gc-kg-get "s-black") *gc-kg-surf-list*))
             (gc-kg-fill-list "s_red" *gc-kg-surf-list*
               (gc-kg-index-of (gc-kg-get "s-red") *gc-kg-surf-list*))
             (set_tile "s_note" (strcat "  поверхностей в чертеже: "
                                        (itoa (length *gc-kg-surf-list*)))))
           (progn
             (gc-kg-fill-list "s_black" '("нет поверхностей") 0)
             (gc-kg-fill-list "s_red"   '("нет поверхностей") 0)
             (mode_tile "s_black" 1)
             (mode_tile "s_red" 1)
             (set_tile "s_note"
               (if *gc-kg-surf-why*
                 (strcat "  [!] " *gc-kg-surf-why*)
                 "  [!] Поверхности не найдены — расчёт будет недоступен"))))
         ;; --- сетка и подписи
         (foreach k '("step_x" "step_y" "angle" "h_mark" "h_vol" "min_vol")
           (set_tile k (gc-kg-get (gc-kg-key k))))
         (set_tile "trim"    (gc-kg-get "trim"))
         (set_tile "use_min" (gc-kg-get "use-min"))
         (gc-kg-fill-list "p_mark" *gc-kg-prec* (gc-kg-get "p-mark"))
         (gc-kg-fill-list "p_vol"  *gc-kg-prec* (gc-kg-get "p-vol"))
         (gc-kg-fill-list "t_style" *gc-kg-styles*
           (gc-kg-index-of (gc-kg-get "style") *gc-kg-styles*))
         ;; --- цвета
         (foreach k '("c_black" "c_red" "c_work" "c_plus" "c_minus" "c_zero")
           (gc-kg-show-color k (gc-kg-get (gc-kg-key k))))
         ;; --- выбранные объекты
         (set_tile "base_txt"  (if (gc-kg-get "base") "  задана" "  не задана"))
         (set_tile "outer_txt" (gc-kg-ss-txt (gc-kg-get "outer") "  не выбрана"))
         (set_tile "inner_txt" (gc-kg-ss-txt (gc-kg-get "inner") "  нет"))
         (set_tile "lines_txt" (gc-kg-ss-txt (gc-kg-get "lines") "  нет"))
         ;; --- действия
         (foreach k '("c_black" "c_red" "c_work" "c_plus" "c_minus" "c_zero")
           (action_tile k (strcat "(gc-kg-pick-color \"" k "\")")))
         ;; ПОЧЕМУ перед закрытием читаем поля: тыкать по чертежу при открытом
         ;; окне DCL нельзя, окно приходится закрывать. Без этой строки всё
         ;; набранное в полях пропадало бы при каждом «Указать».
         (action_tile "pick_base"  "(progn (gc-kg-read-tiles) (done_dialog 10))")
         (action_tile "pick_angle" "(progn (gc-kg-read-tiles) (done_dialog 11))")
         (action_tile "pick_outer" "(progn (gc-kg-read-tiles) (done_dialog 12))")
         (action_tile "pick_inner" "(progn (gc-kg-read-tiles) (done_dialog 13))")
         (action_tile "pick_lines" "(progn (gc-kg-read-tiles) (done_dialog 14))")
         ;; ОК: сначала проверяем, при ошибке окно не закрываем.
         (action_tile "accept" "(if (gc-kg-validate) (progn (gc-kg-read-tiles) (done_dialog 1)))")
         (action_tile "cancel" "(done_dialog 0)")
         (setq res (start_dialog))
         (unload_dialog id)
         (if (findfile path) (vl-file-delete path))
         res)))))

;; Указание объектов идёт ВНЕ окна: DCL не умеет тыкать по чертежу, пока
;; окно открыто. Поэтому окно закрывается с кодом, мы делаем выбор
;; и открываем окно заново с сохранёнными значениями.
;; Возвращает T если пользователь дошёл до ОК.
(defun gc-kg-dialog-loop ( / res done ok p)
  (setq done nil ok nil)
  (while (not done)
    (setq res (gc-kg-dialog))
    (cond
      ((null res)  (setq done T))
      ((= res 1)   (setq ok T done T))
      ((= res 0)   (princ "\n[i] Отмена, настройки не изменены.") (setq done T))
      ((= res 10)
       (setq p (getpoint "\nБазовая точка сетки: "))
       (if p (gc-kg-set "base" (trans p 1 0))))
      ((= res 11)
       (setq p (getangle "\nУкажите направление сетки: "))
       (if p (gc-kg-set "angle" (gc-kg-fmt (/ (* 180.0 p) pi)))))
      ((= res 12) (gc-kg-set "outer" (gc-kg-pick-curves "Наружная граница участка: " T)))
      ((= res 13) (gc-kg-set "inner" (gc-kg-pick-curves "Внутренние границы (исключения): " nil)))
      ((= res 14) (gc-kg-set "lines" (gc-kg-pick-curves "Характерные линии рельефа: " nil)))
      (T (setq done T))))
  ok)

;;; ====================================================================
;;; ОТЧЁТ О НАСТРОЙКАХ
;;; ====================================================================

(defun gc-kg-report ( / )
  (princ "\n\n--- ПРИНЯТЫЕ НАСТРОЙКИ ---")
  (princ (strcat "\n  поверхность чёрная  : "
                 (if (gc-kg-get "s-black") (gc-kg-get "s-black") "не выбрана")))
  (princ (strcat "\n  поверхность красная : "
                 (if (gc-kg-get "s-red") (gc-kg-get "s-red") "не выбрана")))
  (princ (strcat "\n  сетка               : "
                 (gc-kg-get "step-x") " x " (gc-kg-get "step-y") " м"
                 ", угол " (gc-kg-get "angle") " град"))
  (princ (strcat "\n  краевые квадраты    : "
                 (if (= "1" (gc-kg-get "trim")) "обрезать границей" "оставлять целыми")))
  (princ (strcat "\n  граница наружная    : "
                 (if (gc-kg-get "outer") "выбрана" "НЕ выбрана")))
  (princ (strcat "\n  границы внутренние  : "
                 (if (gc-kg-get "inner")
                   (itoa (sslength (gc-kg-get "inner"))) "нет")))
  (princ (strcat "\n  характерные линии   : "
                 (if (gc-kg-get "lines")
                   (itoa (sslength (gc-kg-get "lines"))) "нет")))
  (princ (strcat "\n  отметки             : стиль " (gc-kg-get "style")
                 ", высота " (gc-kg-get "h-mark") " м"
                 ", точность " (nth (gc-kg-get "p-mark") *gc-kg-prec*)))
  (princ (strcat "\n  объёмы              : высота " (gc-kg-get "h-vol") " м"
                 ", точность " (nth (gc-kg-get "p-vol") *gc-kg-prec*)))
  (if (= "1" (gc-kg-get "use-min"))
    (princ (strcat "\n  порог объёма        : " (gc-kg-get "min-vol") " м3")))
  (princ))

;;; ====================================================================
;;; ПРОВЕРКА ОТМЕТОК
;;;
;;; Вся картограмма стоит на одной внешней операции — «дай отметку
;;; поверхности в точке XY» (ADR-0005). Проверяем её отдельно и заранее.
;;; ====================================================================

;; Число с запятой, три знака — как Шамиль привык видеть отметки.
(defun gc-kg-z (z)
  (if z (strcat (gc-kg-fmt z) " м") "нет данных"))

;; Класс рабочей отметки: выемка, насыпь или ноль.
;; Возвращает "CUT" / "FILL" / "ZERO".
(defun gc-kg-work-class (h)
  (cond
    ((< (abs h) *gc-kg-zero-eps*) "ZERO")
    ((< h 0.0)                    "CUT")
    (T                            "FILL")))

;; Рабочая отметка строкой: знак, число, класс.
;; У нуля знака НЕТ — плюс перед нулём это ошибка, а не оформление.
(defun gc-kg-work-str (h / cls)
  (setq cls (gc-kg-work-class h))
  (cond
    ((= cls "ZERO") (strcat (gc-kg-fmt 0.0) " м  (на нулевой линии)"))
    ((= cls "CUT")  (strcat (gc-kg-fmt h)   " м  (выемка)"))
    (T              (strcat "+" (gc-kg-fmt h) " м  (насыпь)"))))

;; Одна точка: показать чёрную, красную и рабочую отметку.
;; p — точка в МСК. Возвращает T, если обе отметки прочитались.
;;
;; ПОЧЕМУ переменные s-blk и s-red, а не короткие ob и or: «or» —
;; встроенная функция AutoLISP, и локальная переменная с таким именем
;; перекрыла бы её внутри всей функции (docs/pitfalls.md -> П19).
(defun gc-kg-probe-one (p s-blk s-red / zb zr h)
  (setq zb (gc-kg-elev s-blk (car p) (cadr p)))
  (setq zr (gc-kg-elev s-red (car p) (cadr p)))
  (princ (strcat "\n  чёрная  " (gc-kg-z zb)
                 "   красная " (gc-kg-z zr)))
  (cond
    ((and zb zr)
     (setq h (- zr zb))
     (princ (strcat "   рабочая " (gc-kg-work-str h)))
     T)
    (T
     (princ "\n  [!] Точка вне одной из поверхностей — рабочая не считается.")
     nil)))

;; Цикл проверки. Возвращает T, если хоть одна точка прочиталась.
(defun gc-kg-probe ( / s-blk s-red p ok any why)
  (setq s-blk (gc-kg-surf-obj (gc-kg-get "s-black"))
        s-red (gc-kg-surf-obj (gc-kg-get "s-red")))
  (princ "\n\n--- ПРОВЕРКА ОТМЕТОК ---")
  (princ "\nТыкайте по чертежу — покажу, что вернула каждая поверхность.")
  (princ "\nЭто проверка фундамента: на этой операции держится весь расчёт.")
  (princ "\nEnter или Esc — закончить.")
  (setq any nil)
  (while (setq p (getpoint "\nТочка для проверки: "))
    ;; Сразу в МСК: поверхность живёт в мировых координатах
    ;; (docs/pitfalls.md -> П1).
    (setq p (trans p 1 0))
    (setq ok (gc-kg-probe-one p s-blk s-red))
    (if ok (setq any T))
    ;; Причину печатаем один раз, иначе завалит консоль.
    (if (and (not ok) (not any) (null why))
      (progn
        (setq why (gc-kg-elev-why s-blk (car p) (cadr p)))
        (princ (strcat "\n  [i] Ответ CAD по чёрной поверхности: " why)))))
  (if any
    (princ "\n[i] Отметки читаются — фундамент держит, можно строить сетку.")
    (princ "\n[!] Ни одной отметки прочитать не удалось. Причины выше."))
  any)

;;; ====================================================================
;;; ЭТАП 2. СЕТКА
;;;
;;; Задача этапа: по границе площадки построить сетку квадратов с заданным
;;; шагом, углом и базовой точкой, а краевые квадраты либо обрезать границей,
;;; либо оставить целыми.
;;;
;;; ПОЧЕМУ ОТСЕЧЕНИЕ СДЕЛАНО СВОИМ КОДОМ, А НЕ КОМАНДОЙ CAD.
;;; Площадь краевого квадрата нужна ЧИСЛОМ для объёма (этап 4), а не только
;;; линией на чертеже. Отсечение штатной командой дало бы картинку, но не
;;; число, и площадь пришлось бы вычислять обратно с чертежа.
;;;
;;; КАК ЭТО СЧИТАЕТСЯ. Алгоритм Сазерленда-Ходгмана: контур площадки
;;; последовательно отсекается четырьмя прямыми квадрата. Он корректен, когда
;;; отсекающая фигура выпуклая, а квадрат выпуклый всегда -- поэтому
;;; отсекаем контур квадратом, а не наоборот.
;;;
;;; ПРОВЕРКА. Сумма площадей всех квадратов сверяется с площадью границы
;;; и печатается расхождение. Ошибка в отсечении вылезет сразу же числом,
;;; а не через два этапа в неверном объёме.
;;; ====================================================================

;; Округление вниз и вверх. Штатный fix отбрасывает дробную часть В СТОРОНУ
;; НУЛЯ, поэтому на отрицательных координатах он даёт не тот номер квадрата.
(defun gc-kg-floor (x / n)
  (setq n (fix x))
  (if (and (< x 0.0) (/= (float n) x)) (1- n) n))

(defun gc-kg-ceil (x / n)
  (setq n (fix x))
  (if (and (> x 0.0) (/= (float n) x)) (1+ n) n))

;; Плоская точка. Вся геометрия картограммы двумерная, а от CAD точки
;; приходят трёхмерными: смешивать нельзя, distance посчитает не то.
(defun gc-kg-2d (p) (list (car p) (cadr p)))

;; Площадь замкнутого многоугольника по формуле трапеций (модуль).
(defun gc-kg-area (pts / s a b)
  (setq s 0.0)
  (if (and pts (cdr pts) (cddr pts))
    (progn
      (setq a (last pts))
      (foreach b pts
        (setq s (+ s (- (* (car a) (cadr b)) (* (car b) (cadr a)))))
        (setq a b))))
  (/ (abs s) 2.0))

;; Габариты списка точек: (minx miny maxx maxy).
(defun gc-kg-bbox (pts / x0 y0 x1 y1)
  (setq x0 (caar pts) y0 (cadar pts) x1 x0 y1 y0)
  (foreach p pts
    (setq x0 (min x0 (car p)) x1 (max x1 (car p))
          y0 (min y0 (cadr p)) y1 (max y1 (cadr p))))
  (list x0 y0 x1 y1))

;; С нужной ли стороны прямой лежит точка. axis: 0 = X, 1 = Y.
(defun gc-kg-inside (p axis val keep / c)
  (setq c (if (= axis 0) (car p) (cadr p)))
  (if keep (>= c val) (<= c val)))

;; Точка пересечения отрезка a-b с прямой axis = val.
(defun gc-kg-isect (a b axis val / ca cb k)
  (setq ca (if (= axis 0) (car a) (cadr a))
        cb (if (= axis 0) (car b) (cadr b)))
  (if (equal ca cb 1.0e-12)
    b
    (progn
      (setq k (/ (- val ca) (- cb ca)))
      (list (+ (car a)  (* k (- (car b)  (car a))))
            (+ (cadr a) (* k (- (cadr b) (cadr a))))))))

;; Отсечение многоугольника одной полуплоскостью.
(defun gc-kg-clip-half (pts axis val keep / out a b ia ib)
  (setq out nil)
  (if pts
    (progn
      (setq a (last pts))
      (setq ia (gc-kg-inside a axis val keep))
      (foreach b pts
        (setq ib (gc-kg-inside b axis val keep))
        (cond
          ((and ia ib) (setq out (cons b out)))
          (ia          (setq out (cons (gc-kg-isect a b axis val) out)))
          (ib          (setq out (cons b (cons (gc-kg-isect a b axis val) out)))))
        (setq a b ia ib))))
  (reverse out))

;; Отсечение прямоугольником. Четыре полуплоскости подряд.
(defun gc-kg-clip-rect (pts x0 y0 x1 y1)
  (setq pts (gc-kg-clip-half pts 0 x0 T))
  (setq pts (gc-kg-clip-half pts 0 x1 nil))
  (setq pts (gc-kg-clip-half pts 1 y0 T))
  (setq pts (gc-kg-clip-half pts 1 y1 nil))
  pts)

;; Выбросить совпадающие подряд точки. Отсечение их плодит, а полилиния
;; с нулевыми рёбрами потом мешает при штриховке.
(defun gc-kg-dedup (pts / out prev)
  (setq out nil prev nil)
  (foreach p pts
    (if (or (null prev) (> (distance prev p) 1.0e-9))
      (progn (setq out (cons p out)) (setq prev p))))
  (setq out (reverse out))
  (if (and (cdr out) (< (distance (car out) (last out)) 1.0e-9))
    (reverse (cdr (reverse out)))
    out))

;;; --------------------------------------------------------------------
;;; Система координат сетки: начало в базовой точке, ось X вдоль угла.
;;; В ней квадраты выровнены по осям, и отсечение сводится к сравнению
;;; координат. Повёрнутый квадрат в МСК потребовал бы общего пересечения
;;; отрезков -- лишний источник ошибок.
;;; --------------------------------------------------------------------

(defun gc-kg-set-frame (base ang)
  (setq *gc-kg-gb* (gc-kg-2d base)
        *gc-kg-gc* (cos ang)
        *gc-kg-gs* (sin ang)))

(defun gc-kg-to-grid (p / dx dy)
  (setq dx (- (car p)  (car  *gc-kg-gb*))
        dy (- (cadr p) (cadr *gc-kg-gb*)))
  (list (+ (* dx *gc-kg-gc*) (* dy *gc-kg-gs*))
        (- (* dy *gc-kg-gc*) (* dx *gc-kg-gs*))))

(defun gc-kg-to-wcs (p / x y)
  (setq x (car p) y (cadr p))
  (list (+ (car  *gc-kg-gb*) (- (* x *gc-kg-gc*) (* y *gc-kg-gs*)))
        (+ (cadr *gc-kg-gb*) (+ (* x *gc-kg-gs*) (* y *gc-kg-gc*)))))

;;; --------------------------------------------------------------------
;;; Чтение контура с чертежа
;;; --------------------------------------------------------------------

;; Сколько хорд на дуговой сегмент. При шаге сетки в метры этого хватает:
;; стрелка прогиба уходит за миллиметр только на радиусах меньше метра,
;; а таких у границы площадки не бывает.
(setq *gc-kg-arc-seg* 12)

;; Точка кривой по параметру, МСК. nil при отказе.
(defun gc-kg-cp (e prm / r)
  (setq r (vl-catch-all-apply 'vlax-curve-getPointAtParam (list e prm)))
  (if (or (vl-catch-all-error-p r) (null r)) nil (gc-kg-2d r)))

;; Прямой ли сегмент: середина по параметру лежит на хорде.
(defun gc-kg-seg-straight-p (e prm / a b m)
  (setq a (gc-kg-cp e (float prm))
        b (gc-kg-cp e (+ (float prm) 1.0))
        m (gc-kg-cp e (+ (float prm) 0.5)))
  (if (and a b m)
    (< (distance m (list (/ (+ (car a) (car b)) 2.0)
                         (/ (+ (cadr a) (cadr b)) 2.0)))
       (max 1.0e-6 (* (distance a b) 1.0e-4)))
    T))

;; Контур объекта списком 2D-точек в МСК. Дуги разбиваются хордами.
;; Точки берутся через vlax-curve, а не из entget: там они лежат в системе
;; объекта, и для наклонённой полилинии это были бы не те координаты
;; (docs/pitfalls.md -> П1).
(defun gc-kg-ent-pts (e / et n i k p out)
  (setq et (cdr (assoc 0 (entget e))) out nil)
  (setq n (vl-catch-all-apply 'vlax-curve-getEndParam (list e)))
  (cond
    ((or (vl-catch-all-error-p n) (null n) (<= n 0)) (setq out nil))
    ((member et '("LWPOLYLINE" "POLYLINE"))
     (setq i 0)
     (while (< i n)
       (if (setq p (gc-kg-cp e (float i))) (setq out (cons p out)))
       (if (not (gc-kg-seg-straight-p e i))
         (progn
           (setq k 1)
           (while (< k *gc-kg-arc-seg*)
             (setq p (gc-kg-cp e (+ (float i) (/ (float k) (float *gc-kg-arc-seg*)))))
             (if p (setq out (cons p out)))
             (setq k (1+ k)))))
       (setq i (1+ i)))
     (if (setq p (gc-kg-cp e (float n))) (setq out (cons p out)))
     (setq out (gc-kg-dedup (reverse out))))
    (T
     ;; окружность, эллипс, сплайн, дуга -- равномерная выборка по параметру
     (setq k 0)
     (while (<= k 96)
       (setq p (gc-kg-cp e (* n (/ (float k) 96.0))))
       (if p (setq out (cons p out)))
       (setq k (1+ k)))
     (setq out (gc-kg-dedup (reverse out)))))
  out)

;; Контур площадки. Граница не выбрана в окне -- просим прямоугольник,
;; чтобы команда работала и без подготовленной полилинии.
(defun gc-kg-outer-pts ( / ss e pts p1 p2)
  (setq ss (gc-kg-get "outer"))
  (cond
    ((and ss (> (sslength ss) 0))
     (setq e (ssname ss 0))
     (setq pts (gc-kg-ent-pts e))
     (cond
       ((or (null pts) (< (length pts) 3))
        (princ "\n[!] Граница не читается как замкнутый контур.")
        nil)
       (T pts)))
    (T
     (princ "\n[i] Наружная граница в окне не выбрана - задайте прямоугольник.")
     (setq p1 (getpoint "\nПервый угол площадки: "))
     (if (null p1)
       nil
       (progn
         (setq p2 (getcorner p1 "\nПротивоположный угол: "))
         (if (null p2)
           nil
           ;; углы строим в ПСК и только потом переводим каждый в МСК:
           ;; если ПСК повёрнута, смешивать координаты до перевода нельзя
           ;; (docs/pitfalls.md -> П1).
           (mapcar '(lambda (q) (gc-kg-2d (trans q 1 0)))
                   (list p1
                         (list (car p2) (cadr p1))
                         p2
                         (list (car p1) (cadr p2))))))))))

;; Внутренние границы-исключения списком контуров.
(defun gc-kg-holes-pts ( / ss i out pts)
  (setq ss (gc-kg-get "inner") out nil)
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq pts (gc-kg-ent-pts (ssname ss i)))
        (if (and pts (> (length pts) 2)) (setq out (cons pts out)))
        (setq i (1+ i)))))
  (reverse out))

;;; --------------------------------------------------------------------
;;; Рисование
;;; --------------------------------------------------------------------

;; Слой: создать, если его нет. Возвращает имя.
(defun gc-kg-layer (name col / )
  (if (null (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name)
                   (cons 70 0)
                   (cons 62 col)
                   '(6 . "Continuous"))))
  name)

;; Замкнутая полилиния по точкам системы сетки.
;; Группа 210 не пишется: без неё система объекта совпадает с МСК,
;; и точки ложатся туда, куда посчитаны (docs/pitfalls.md -> П1).
(defun gc-kg-draw-poly (pts lay / d)
  (setq pts (gc-kg-dedup pts))
  (if (> (length pts) 2)
    (progn
      (setq d (list '(0 . "LWPOLYLINE")
                    '(100 . "AcDbEntity")
                    (cons 8 lay)
                    '(100 . "AcDbPolyline")
                    (cons 90 (length pts))
                    '(70 . 1)))
      (foreach p pts
        (setq d (append d (list (cons 10 (gc-kg-to-wcs p))))))
      (entmake d))))

;;; --------------------------------------------------------------------
;;; Построение
;;; --------------------------------------------------------------------

;; Предел на число квадратов. Не вкусовщина: при шаге, задетом случайно
;; (0,2 вместо 20), счёт уходит на сотни тысяч объектов и CAD встаёт.
(setq *gc-kg-max-cells* 20000)

(defun gc-kg-build ( / outer holes ang sx sy base trim bb gp gh
                       i0 j0 i1 j1 nc i j cx cy cx1 cy1
                       poly ar hr hps cells total lay eps aout ce)
  (setq outer (gc-kg-outer-pts))
  (if (null outer)
    (progn (princ "\n[!] Площадка не задана - сетка не построена.") nil)
    (progn
      (setq holes (gc-kg-holes-pts))
      (setq ang (gc-kg-num (gc-kg-get "angle")))
      (if (null ang) (setq ang 0.0))
      (setq ang (/ (* pi ang) 180.0))
      (setq sx (gc-kg-num (gc-kg-get "step-x"))
            sy (gc-kg-num (gc-kg-get "step-y")))
      (setq trim (= "1" (gc-kg-get "trim")))
      ;; Базовая точка не указана - берём левый нижний угол габаритов
      ;; в системе сетки. Тогда нумерация квадратов начинается с нуля
      ;; и не зависит от того, где в чертеже лежит площадка.
      (setq base (gc-kg-get "base"))
      (if (null base)
        (progn
          (gc-kg-set-frame '(0.0 0.0) ang)
          (setq bb (gc-kg-bbox (mapcar 'gc-kg-to-grid outer)))
          (setq base (gc-kg-to-wcs (list (car bb) (cadr bb))))))
      (gc-kg-set-frame base ang)
      (setq gp (mapcar 'gc-kg-to-grid outer))
      (setq gh (mapcar '(lambda (h) (mapcar 'gc-kg-to-grid h)) holes))
      (setq bb (gc-kg-bbox gp))
      (setq i0 (gc-kg-floor (/ (car   bb) sx))
            j0 (gc-kg-floor (/ (cadr  bb) sy))
            i1 (gc-kg-ceil  (/ (caddr bb) sx))
            j1 (gc-kg-ceil  (/ (cadddr bb) sy)))
      (setq nc (* (- i1 i0) (- j1 j0)))
      (if (> nc *gc-kg-max-cells*)
        (progn
          (princ (strcat "\n[!] При шаге " (gc-kg-get "step-x") " x "
                         (gc-kg-get "step-y") " м на эту площадку ложится "
                         (itoa nc) " квадратов."))
          (princ (strcat "\n    Предел " (itoa *gc-kg-max-cells*)
                         ". Увеличьте шаг или уменьшите площадку."))
          nil)
        (progn
          (setq cells nil total 0.0 eps (* 1.0e-6 sx sy))
          (setq j j0)
          (while (< j j1)
            (setq i i0)
            (while (< i i1)
              (setq cx (* i sx) cy (* j sy) cx1 (+ cx sx) cy1 (+ cy sy))
              (setq poly (gc-kg-clip-rect gp cx cy cx1 cy1))
              (setq ar (gc-kg-area poly))
              (setq hr 0.0 hps nil)
              (foreach h gh
                (setq ce (gc-kg-clip-rect h cx cy cx1 cy1))
                (if (> (gc-kg-area ce) eps)
                  (progn (setq hr (+ hr (gc-kg-area ce)))
                         (setq hps (cons ce hps)))))
              (setq ar (- ar hr))
              (if (> ar eps)
                (progn
                  (setq cells
                    (cons (list i j ar
                                (list (list cx cy) (list cx1 cy)
                                      (list cx1 cy1) (list cx cy1))
                                poly hps)
                          cells))
                  (setq total (+ total ar))))
              (setq i (1+ i)))
            (setq j (1+ j)))
          (setq cells (reverse cells))
          (if (null cells)
            (progn
              (princ "\n[!] Ни один квадрат не попал внутрь границы.")
              (princ "\n    Проверьте, замкнута ли граница и тот ли объект выбран.")
              nil)
            (progn
              ;; --- рисуем
              (setq lay (gc-kg-layer "GC-Картограмма-Сетка" 8))
              (setvar "CMDECHO" 0)
              (command "_.UNDO" "_BEGIN")
              (foreach c cells
                (if (and trim (< (nth 2 c) (- (* sx sy) eps)))
                  (progn
                    (gc-kg-draw-poly (nth 4 c) lay)
                    (foreach h (nth 5 c) (gc-kg-draw-poly h lay)))
                  (gc-kg-draw-poly (nth 3 c) lay)))
              (command "_.UNDO" "_END")
              ;; --- запоминаем для следующих этапов
              (setq *gc-kg-cells* cells
                    *gc-kg-grid-par* (list (gc-kg-2d base) ang sx sy))
              ;; --- контроль: площадь по сетке против площади границы
              (setq aout (gc-kg-area outer))
              (foreach h holes (setq aout (- aout (gc-kg-area h))))
              (princ (strcat "\n\n--- СЕТКА ПОСТРОЕНА ---"))
              (princ (strcat "\n  квадратов        : " (itoa (length cells))
                             (if trim "  (краевые обрезаны границей)"
                                      "  (краевые целые)")))
              (princ (strcat "\n  слой             : " lay))
              (princ (strcat "\n  площадь по сетке : " (gc-kg-fmt total) " м2"))
              (princ (strcat "\n  площадь границы  : " (gc-kg-fmt aout) " м2"))
              (if (> aout 1.0e-9)
                (princ (strcat "\n  расхождение      : "
                               (gc-kg-fmt (* 100.0 (/ (abs (- total aout)) aout)))
                               " %"
                               (if trim
                                 "  (при обрезке должно быть около нуля)"
                                 "  (при целых квадратах сетка больше площадки - так и надо)"))))
              (princ "\n[i] Один Ctrl+Z убирает всю сетку целиком.")
              T)))))))

;;; --------------------------------------------------------------------
;;; Меню действий
;;;
;;; Один вопрос, три ответа, Enter всегда что-то делает и говорит что.
;;; Слепых переключателей нет (docs/pitfalls.md -> П23).
;;; --------------------------------------------------------------------

(defun gc-kg-menu ( / k dflt done)
  (setq done nil dflt "Сетка")
  (while (not done)
    (initget "Сетка Проверка Выход")
    (setq k (getkword (strcat "\nЧто делаем? [Сетка/Проверка/Выход] <" dflt ">: ")))
    (if (null k) (setq k dflt))
    (cond
      ((= k "Сетка")    (gc-kg-build) (setq dflt "Выход"))
      ((= k "Проверка") (gc-kg-probe) (setq dflt "Выход"))
      (T (setq done T))))
  (princ))

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-kg-defaults ( / )
  (if (null *gc-kg-cfg*) (setq *gc-kg-cfg* *gc-kg-def*)))

(defun gc-kg-intro ( / )
  (princ "\n\n=== KG — картограмма земляных масс ===")
  (princ "\nСетка квадратов, отметки в узлах, объёмы выемки и насыпи,")
  (princ "\nлиния нулевых работ и ведомость.")
  (princ "\n")
  (princ "\n[i] ЭТАП 2 ИЗ 5: настройки, сетка квадратов, проверка отметок.")
  (princ "\n    Окно собирает и запоминает все параметры. После него — выбор:")
  (princ "\n      Сетка    — построить квадраты по границе площадки;")
  (princ "\n      Проверка — потыкать по чертежу и увидеть отметки поверхностей.")
  (princ "\n    Отметки в узлах, объёмы и ведомость добавляются этапами 3–5.")
  (princ "\n    Сетка НЕ проверена в Civil 3D — это первый её запуск."))

(defun gc-kg-run ( / )
  (gc-kg-defaults)
  (gc-kg-intro)
  (if (gc-kg-dialog-loop)
    (progn
      (gc-kg-report)
      (princ "\n\n[i] Настройки сохранены до закрытия чертежа.")
      (if (and (gc-kg-get "s-black") (gc-kg-get "s-red"))
        (princ "\n[i] Поверхности выбраны — доступны и сетка, и проверка отметок.")
        (princ "\n[!] Поверхности не выбраны — проверка отметок работать не будет."))
      (gc-kg-menu)))
  (princ "\n[i] KG завершена.")
  (princ))

;;; ====================================================================
;;; КОМАНДА
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если нажали Esc посреди ввода.
;; Отмена это не ошибка.
;; ПОЧЕМУ проверяем и русские слова: на локализованном AutoCAD выход по Esc
;; приходит сообщением «Функция прервана.», и сравнение только с английскими
;; BREAK/CANCEL/QUIT принимало нормальный выход за сбой команды.
;; Русские варианты проверяем БЕЗ strcase: полагаться на то, что он верно
;; поднимет регистр кириллицы в любой сборке, не стоит.
(defun gc-kg-cancel-p (msg)
  (if (null msg)
    T
    (or (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")
        (wcmatch msg "*прерван*,*Прерван*,*ПРЕРВАН*,*отмен*,*Отмен*,*ОТМЕН*"))))

(defun c:kg ( / *error*)
  (defun *error* (msg)
    (if (gc-kg-cancel-p msg)
      (princ "\n[ОТМЕНА] KG прерван.")
      (princ (strcat "\n[ОШИБКА] KG: " msg)))
    (princ))
  (gc-kg-run)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-cartogram ( / )
  (c:kg))

;;; ====================================================================
;;; ИМЯ КОМАНДЫ В РУССКОЙ РАСКЛАДКЕ
;;; ====================================================================

;; Те же клавиши в ЙЦУКЕН: K -> Л, G -> П. См. docs/pitfalls.md -> П15.
(defun c:лп ( / ) (c:kg))
(defun c:ЛП ( / ) (c:kg))
(princ "\n[gc] kg.lsp v7 загружен. Команда: KG | рус. раскладка: ЛП")
(princ "\n     Этап 2 из 5: окно настроек, сетка квадратов, проверка отметок.")
(princ)
