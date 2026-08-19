;;; ol.lsp -- otklonenie fakticheskih tochek ot proektnoy pryamoy (SPEC-007 v9)
;;; Komandy:
;;;   OL                -- osnovnaya komanda (Otklonenie ot Linii).
;;;   GC-LINE-DEVIATION -- polnoe imya toy zhe komandy.
;;;
;;; v9: v rezhime "Mesto" poyavilsya ZHIVOY PREDPROSMOTR: poka dvigaesh mysh,
;;;     pod kursorom vidno, gde vstanet strelka i ramka na meste cifry.
;;;     Sdelano na grread + grvecs: getpoint ne umeet risovat proizvolnuyu
;;;     grafiku pod kursorom. Kazhdyy kadr -- redraw (steret proshlyy)
;;;     i grvecs (narisovat novyy).
;;;     Vsya geometriya vynesena v gc-ol-geom, chtoby predprosmotr i realnaya
;;;     otrisovka ne mogli razyehatsya.
;;;
;;; v8: RAZDELENY DVE RAZNYE VESHCHI, kotorye ranshe putalis.
;;;     1) STORONA -- GDE risuetsya strelka: sleva ili sprava ot pryamoy.
;;;        Eto RUCHNAYA nastroyka, chtoby vse podpisi legli po odnu storonu
;;;        i chertezh ne ryabil. Vozvrashchena (v6 ee oshibochno ubrala).
;;;     2) NAPRAVLENIE ostrie -- iz ZNAKA otkloneniya, a ne iz nastroyki.
;;;        Tochka na vybrannoy storone -> ostrie ot pryamoy naruzhu;
;;;        s protivopolozhnoy -> ostrie k pryamoy. Na plite eto srazu vidno:
;;;        betona menshe -- strelka v odnu storonu, bolshe -- v druguyu.
;;;     Knopka [Napravlenie] teper -- globalnyy razvorot etogo soglasheniya,
;;;     esli ono okazalos ne tem.
;;;
;;; v7: tretiy rezhim -- "Mesto". Snachala tykaete fakticheskuyu tochku,
;;;     potom sami ukazyvaete, gde ee podpisat. Ukazannoe mesto snositsya
;;;     na pryamuyu, poetomu strelka vse ravno nachinaetsya na pryamoy,
;;;     a velichina i storona berutsya ot samoy tochki.
;;;     Nuzhno, kogda tochki stoyat plotno i podpisi naprotiv kazhdoy
;;;     nalezayut drug na druga -- teper ih mozhno raznesti vdol pryamoy.
;;;     Knopka [Rezhim] otkryvaet zapros [Odna/Mesto/Pachka] vmesto slepogo
;;;     pereklyucheniya: rezhimov stalo tri.
;;;
;;; v6: STORONA STRELKI BOLSHE NE NASTROYKA -- ona vsegda ta, s kakoy stoit
;;;     fakticheskaya tochka. Znak otkloneniya zadaet normal, i strelka
;;;     vsegda pokazyvaet NA tochku. Ranshe storona byla obshchey nastroykoy
;;;     na vsyu pryamuyu, i dlya tochek s drugoy storony strelka smotrela
;;;     v protivopolozhnuyu ot nih storonu -- ukazyvala v pustotu.
;;;     Knopka [Storona] zamenena na [Napravlenie]: kuda smotrit ostrie --
;;;     na tochku (po umolchaniyu) ili na pryamuyu.
;;;
;;; v5: zashchita ot otsutstviya Visual LISP COM (oshibka "no function
;;;     definition: VLAX-ENAME->VLA-OBJECT"). XY obychnoy tochki teper
;;;     beretsya iz DXF-gruppy 10 BEZ COM; COM nuzhen tolko dlya COGO Point.
;;;
;;; v4: strelka rastet OT PRYAMOY, a ne ot tochki. Nachalo strelki -- na
;;;     pryamoy, v osnovanii perpendikulyara iz fakticheskoy tochki; ostrie
;;;     smotrit ot pryamoy na vybrannuyu storonu. Ranshe ostrie bylo v samoy
;;;     tochke, a hvost uhodil v storonu -- eto bylo nevernoe prochtenie
;;;     obrazca (po odnim koordinatam strelki oba varianta neotlichimy).
;;;
;;; v3: v paketnom rezhime poyavilis knopki. Ranshe tam byl srazu ssget,
;;;     a ssget ne podderzhivaet klyuchevye slova initget -- poetomu smenit
;;;     proektnuyu pryamuyu dlya novogo uchastka bylo nelzya, ne vyhodya iz
;;;     komandy: povtornyy zapusk OL srazu prosil vybrat tochki.
;;;     Teper pered vyborkoy idet zapros s knopkami, Enter vedet k vyborke.
;;;     Takzhe dobavlena knopka [Vyhod] v oba rezhima.
;;;
;;; v2: dva rezhima raboty, pereklyuchatel [Rezhim]:
;;;     -- po odnoy tochke: klik -- srazu podpis, knopki v stroke zaprosa;
;;;     -- pachkoy: vydelyaete mnogo tochek ramkoy, podpisyvayutsya vse srazu.
;;;     V rezhime "pachkoy" knopok net: ssget ne podderzhivaet klyuchevye
;;;     slova initget, poetomu nastroyki otkryvayutsya po Enter vmesto vyborki.
;;;
;;; Geometriya vyvedena iz obrazca Shamilya (menuGEO) pri vysote teksta 0.200:
;;;   strelka  -- polilinia iz 3 vershin, dlina 0.400 = 2*h;
;;;   nakonechnik -- vtoraya polovina, shirina 0.0800 -> 0 = 0.4*h -> 0;
;;;   tekst    -- Middle Center, smeshchen na 0.200 = 1*h po perpendikulyaru
;;;               ot sredney vershiny, povernut vdol strelki.
;;; Proverka po koordinatam obrazca: smeshchenie teksta (-0.0030, +0.2000)
;;; est rovno 0.200 * perpendikulyar k napravleniyu strelki (0.99989, 0.01500).
;;;
;;; Vsya grafika privyazana k vysote teksta -- menyaesh Tekst, vse masshtabiruetsya.
;;;
;;; Klyuchevye slova initget dublirovany odnoy bukvoy: dlya kirillicy AutoCAD
;;; ne raspoznaet zaglavnuyu bukvu kak sokrashchenie i trebuet slovo celikom.
;;; Sm. pravilo 1 v status/HANDOFF.md.
;;;
;;; Helpery razbora chisla namerenno dublirovany iz vo.lsp -- sm.
;;; docs/decisions/0003-standalone-command-files.md. Fayl gruzitsya nezavisimo.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/ol.lsp").
;;; Zavisimosti: Visual LISP (vl-string-subst).

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ
;;; ====================================================================

(setq *gc-ol-layer*       "GC-Отклонения-От-Линии")
(setq *gc-ol-layer-color* 7)
(setq *gc-ol-text-h-init* 0.200) ; высота текста по умолчанию (просил Шамиль)

;; Пропорции от высоты текста — все выведены из образца menuGEO.
(setq *gc-ol-arrow-k*  2.0)  ; длина стрелки       = 2.0 * h  (0.400 при h=0.2)
(setq *gc-ol-head-k*   0.4)  ; ширина наконечника  = 0.4 * h  (0.080 при h=0.2)
(setq *gc-ol-text-k*   1.0)  ; смещение текста     = 1.0 * h  (0.200 при h=0.2)

;; Фильтр для ssget в режиме «пачкой»: только точки и COGO Points.
;; Тот же, что в sv.lsp — защищает от захвата уже нарисованных стрелок и подписей.
;; Цвета временной графики предпросмотра: контур стрелки и рамка цифры.
;; Яркие и разные, чтобы не спутать с самим чертежом.
(setq *gc-ol-preview-color*  1)   ; красный — стрелка
(setq *gc-ol-preview-color2* 3)   ; зелёный — рамка на месте цифры

(setq *gc-ol-ssget-filter* '((0 . "POINT,AECC*POINT,AEC*POINT")))

;;; НАСТРОЙКИ — живут до закрытия чертежа:
;;;   *gc-ol-a* / *gc-ol-b* — концы проектной прямой
;;;   *gc-ol-side*          — "L" стрелки слева от прямой / "R" справа
;;;   *gc-ol-rev*           — T = направление остриё развёрнуто
;;;   *gc-ol-flip*          — T = цифра с другой стороны стрелки
;;;   *gc-ol-mode*          — "ONE" по одной / "PLACE" с выбором места /
;;;                           "BATCH" пачкой рамкой
;;;   *gc-ol-text-h*        — высота текста, м
;;; Намеренно НЕ инициализируются при загрузке: AutoLISP возвращает nil для
;;; несвязанного символа, а сброс при каждом APPLOAD стирал бы настройки.

;;; ====================================================================
;;; СТРОКИ И ЧИСЛА
;;; ====================================================================

;; Обрезка пробелов по краям без vl-string-trim — чтобы не зависеть от того,
;; как конкретная сборка обрабатывает не-ASCII.
(defun gc-ol-trim (s / )
  (while (and (> (strlen s) 0) (= (substr s 1 1) " "))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) " "))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; ПОЧЕМУ списком, а не strcase: strcase кириллицу приводит к одному регистру
;; не во всех сборках AutoCAD, поэтому перечисляем варианты явно.
(defun gc-ol-is-word (s variants)
  (if (member s variants) T nil))

;; Запятая и точка равнозначны, пробелы игнорируются.
;; ПОЧЕМУ свой парсер, а не getreal: getreal не принимает запятую.
;; Возвращает положительное число либо nil.
(defun gc-ol-parse-size (s / n i ch bad seps digits norm val)
  (setq n (strlen s) i 1 bad nil seps 0 digits 0 norm "")
  (while (<= i n)
    (setq ch (substr s i 1))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
       (setq digits (1+ digits) norm (strcat norm ch)))
      ((or (= ch ",") (= ch "."))
       (setq seps (1+ seps) norm (strcat norm ".")))
      ((or (= ch " ") (= ch "\t")) nil)
      (T (setq bad T)))
    (setq i (1+ i)))
  (cond
    (bad          nil)
    ((= digits 0) nil)
    ((> seps 1)   nil)
    (T
     (setq val (atof norm))
     (if (> val 1.0e-9) val nil))))

;; Обратный вывод — в привычном виде с запятой: 0.200 -> "0,200".
(defun gc-ol-fmt (m)
  (vl-string-subst "," "." (rtos m 2 3)))

;; Округление до целого «от нуля»: 2.5 -> 3.
;; ПОЧЕМУ не rtos: rtos зависит от настроек единиц чертежа (DIMZIN),
;; а подпись должна быть одинаковой в любом DWG.
(defun gc-ol-round (x)
  (if (>= x 0.0)
    (fix (+ x 0.5))
    (- (fix (+ (- x) 0.5)))))

;;; ====================================================================
;;; ГЕОМЕТРИЯ ПРЯМОЙ
;;; ====================================================================

;; Единичный вектор из p в q либо nil, если точки совпали.
(defun gc-ol-unit (p q / dx dy len)
  (setq dx  (- (car  q) (car  p))
        dy  (- (cadr q) (cadr p))
        len (sqrt (+ (* dx dx) (* dy dy))))
  (if (< len 1.0e-9)
    nil
    (list (/ dx len) (/ dy len))))

;; Знаковое перпендикулярное смещение точки от прямой A->B, м.
;; Положительное — точка СЛЕВА от направления A->B (векторное произведение).
;; Знак нужен только для сообщения в консоль: в подписи его нет (решение Шамиля).
(defun gc-ol-signed-offset (p / u vx vy)
  (setq u (gc-ol-unit *gc-ol-a* *gc-ol-b*))
  (if (null u)
    nil
    (progn
      (setq vx (- (car  p) (car  *gc-ol-a*))
            vy (- (cadr p) (cadr *gc-ol-a*)))
      (- (* (car u) vy) (* (cadr u) vx)))))

;; Основание перпендикуляра из точки p на прямую A->B — точка НА прямой.
;; Именно отсюда растёт стрелка (решение Шамиля: «начало стрелки на линии»).
;; ПОЧЕМУ переменная proj, а не t: T в AutoLISP — это «истина», занятое имя.
(defun gc-ol-foot (p / u vx vy proj)
  (setq u (gc-ol-unit *gc-ol-a* *gc-ol-b*))
  (if (null u)
    nil
    (progn
      (setq vx (- (car  p) (car  *gc-ol-a*))
            vy (- (cadr p) (cadr *gc-ol-a*)))
      ;; Проекция вектора A->p на направление прямой.
      (setq proj (+ (* (car u) vx) (* (cadr u) vy)))
      (list (+ (car  *gc-ol-a*) (* (car  u) proj))
            (+ (cadr *gc-ol-a*) (* (cadr u) proj))))))

;;; ====================================================================
;;; НАСТРОЙКИ
;;; ====================================================================

;; СТОРОНА — где рисуется стрелка. Задаётся вручную, чтобы все подписи
;; лежали по одну сторону прямой и чертёж не рябил.
(defun gc-ol-side-name ( / )
  (if (= *gc-ol-side* "R")
    "справа от прямой"
    "слева от прямой"))

;; РАЗВОРОТ — глобальная инверсия направления остриё. Само направление
;; определяется знаком отклонения (см. gc-ol-label), а этот переключатель
;; меняет соглашение на противоположное, если оно оказалось не тем.
(defun gc-ol-rev-name ( / )
  (if *gc-ol-rev*
    "развёрнуто (наоборот)"
    "обычное"))

(defun gc-ol-flip-name ( / )
  (if *gc-ol-flip* "снизу от стрелки" "сверху от стрелки"))

(defun gc-ol-mode-name ( / )
  (cond
    ((= *gc-ol-mode* "BATCH") "пачкой — много точек рамкой")
    ((= *gc-ol-mode* "PLACE") "по одной, место подписи указываю сам")
    (T                        "по одной, подпись напротив точки")))

;; ПОЧЕМУ отдельный запрос, а не циклическое переключение: режимов стало три,
;; и вслепую перебирать их кнопкой неудобно — не видно, куда попадёшь.
(defun gc-ol-toggle-mode ( / kw)
  (princ "\n\n--- РЕЖИМ РАБОТЫ ---")
  (princ "\n  Одна  — тыкаете точку, стрелка встаёт напротив неё")
  (princ "\n  Место — тыкаете точку, потом сами указываете, где её подписать.")
  (princ "\n          Нужно, когда точки стоят плотно и подписи налезают")
  (princ "\n          друг на друга: разносите их вдоль прямой.")
  (princ "\n  Пачка — выделяете много точек рамкой, подписываются все разом")
  (initget "Одна О Место М Пачка П")
  (setq kw (getkword
             (strcat "\nРежим [Одна/Место/Пачка] <"
                     (cond ((= *gc-ol-mode* "BATCH") "Пачка")
                           ((= *gc-ol-mode* "PLACE") "Место")
                           (T                        "Одна"))
                     ">: ")))
  (cond
    ((null kw) nil)                                  ; Enter — оставить как было
    ((gc-ol-is-word kw '("Место" "М")) (setq *gc-ol-mode* "PLACE"))
    ((gc-ol-is-word kw '("Пачка" "П")) (setq *gc-ol-mode* "BATCH"))
    (T                                 (setq *gc-ol-mode* "ONE")))
  (princ (strcat "\n[i] Режим: " (gc-ol-mode-name)))
  (if (= *gc-ol-mode* "BATCH")
    (princ (strcat "\n    Кнопки в пакетном режиме показываются ПЕРЕД выборкой:"
                   "\n    там же меняется прямая при переходе на новый участок."
                   "\n    Enter в том запросе сразу ведёт к выборке рамкой.")))
  *gc-ol-mode*)

;;; ====================================================================
;;; ВЫБОР ТОЧЕК ПАЧКОЙ
;;; ====================================================================

;; XY объекта. COGO Point Civil 3D отдаёт координаты через Easting/Northing,
;; обычная точка — через DXF-группу 10, блок — через InsertionPoint.
;; Проверяет, доступен ли Visual LISP COM, и при необходимости догружает его.
;; ПОЧЕМУ нужно: бывает ошибка "no function definition: VLAX-ENAME->VLA-OBJECT",
;; то есть (vl-load-com) в шапке файла не отработал. Ссылка на несвязанный
;; символ в AutoLISP возвращает nil и не падает — так и проверяем.
(defun gc-ol-com-ok ( / )
  (if (null vlax-ename->vla-object) (vl-load-com))
  (if vlax-ename->vla-object T nil))

;; XY объекта.
;; ПОРЯДОК ВАЖЕН. DXF-группа 10 есть у обычной точки и не требует COM —
;; пробуем её первой. COM трогаем только для COGO Point Civil 3D и блоков.
(defun gc-ol-entity-xy (ent / obj ed typ p10)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed))
        p10 (cdr (assoc 10 ed)))
  (cond
    ;; COGO Point — координаты только через COM.
    ((wcmatch typ "AECC*POINT,AEC*POINT")
     (if (gc-ol-com-ok)
       (progn
         (setq obj (vlax-ename->vla-object ent))
         (cond
           ((vlax-property-available-p obj 'Easting)
            (list (vla-get-Easting obj) (vla-get-Northing obj)))
           ((vlax-property-available-p obj 'InsertionPoint)
            (setq p10 (vlax-safearray->list
                        (vlax-variant-value (vla-get-InsertionPoint obj))))
            (list (car p10) (cadr p10)))
           (T nil)))
       nil))
    ;; Обычная точка — из DXF, без COM.
    ((and p10 (cadr p10)) (list (car p10) (cadr p10)))
    ;; Остальное — через COM, если он есть.
    ((gc-ol-com-ok)
     (setq obj (vlax-ename->vla-object ent))
     (if (vlax-property-available-p obj 'InsertionPoint)
       (progn
         (setq p10 (vlax-safearray->list
                     (vlax-variant-value (vla-get-InsertionPoint obj))))
         (list (car p10) (cadr p10)))
       nil))
    (T nil)))

(defun gc-ol-ss-points (ss / i n ent c pts skipped)
  (setq pts '() skipped 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c (gc-ol-entity-xy ent))
    (if c
      (setq pts (cons c pts))
      (setq skipped (1+ skipped)))
    (setq i (1+ i)))
  (if (> skipped 0)
    (progn
      (princ (strcat "\n[!] Пропущено объектов без координат: " (itoa skipped)))
      (if (null (gc-ol-com-ok))
        (princ (strcat "\n[!] Visual LISP COM недоступен в этой версии CAD."
                       "\n    COGO Point Civil 3D без него прочитать нельзя."
                       "\n    Обычные точки (POINT) читаются и без него.")))))
  (reverse pts))

;; Сторона спрашивается сразу после выбора прямой — как в menuGEO.
;; Сторона спрашивается сразу после прямой: с какой стороны от неё лягут
;; все стрелки с подписями. Куда смотрит остриё — вопрос отдельный, оно
;; определяется знаком отклонения, а не этой настройкой.
;; ПОЧЕМУ «Лево/Право», а не «Слева/Справа»: у последних одна и та же первая
;; буква «С», и сокращение стало бы неоднозначным.
(defun gc-ol-ask-side ( / kw)
  (princ "\nС какой стороны прямой рисовать стрелки с подписями.")
  (princ "\nСторона считается по направлению от 1-й указанной точки ко 2-й.")
  (initget "Лево Л Право П")
  (setq kw (getkword (strcat "\nСторона [Лево/Право] <"
                             (if (= *gc-ol-side* "R") "Право" "Лево")
                             ">: ")))
  (cond
    ((null kw) nil)                               ; Enter — оставить как было
    ((gc-ol-is-word kw '("Право" "П")) (setq *gc-ol-side* "R"))
    (T                                 (setq *gc-ol-side* "L")))
  (princ (strcat "\n[i] Стрелки рисуются " (gc-ol-side-name)))
  *gc-ol-side*)

;; Выбор проектной прямой двумя точками, затем сразу направление остриё.
(defun gc-ol-ask-line ( / a b done)
  (princ "\n\n--- ПРОЕКТНАЯ ПРЯМАЯ ---")
  (princ "\nУкажите две точки. Прямая считается бесконечной: фактическая")
  (princ "\nточка может лежать и за пределами отрезка между ними.")
  (setq done nil)
  (while (not done)
    (setq a (getpoint "\nНачало проектной прямой: "))
    (cond
      ((null a)
       (princ "\n[i] Отмена.")
       (setq done T))
      (T
       (setq b (getpoint a "\nКонец проектной прямой: "))
       (cond
         ((null b) (princ "\n[i] Отмена."))
         ((null (gc-ol-unit a b))
          (princ "\n[!] Точки совпали — прямая не определена. Укажите заново."))
         (T
          (setq *gc-ol-a* a
                *gc-ol-b* b)
          (princ (strcat "\n[i] Прямая задана, длина отрезка "
                         (gc-ol-fmt (distance a b)) " м"))
          ;; Направление остриё спрашивается сразу после прямой.
          (if (null *gc-ol-side*) (setq *gc-ol-side* "L"))
          (gc-ol-ask-side)
          (setq done T))))))
  *gc-ol-a*)

(defun gc-ol-toggle-side ( / )
  (setq *gc-ol-side* (if (= *gc-ol-side* "R") "L" "R"))
  (princ (strcat "\n[i] Стрелки теперь " (gc-ol-side-name)))
  *gc-ol-side*)

(defun gc-ol-toggle-rev ( / )
  (setq *gc-ol-rev* (not *gc-ol-rev*))
  (princ (strcat "\n[i] Направление остриё: " (gc-ol-rev-name)))
  (princ "\n    Направление задаётся знаком отклонения; этот переключатель")
  (princ "\n    меняет соглашение на противоположное.")
  *gc-ol-rev*)

(defun gc-ol-toggle-flip ( / )
  (setq *gc-ol-flip* (not *gc-ol-flip*))
  (princ (strcat "\n[i] Цифра теперь " (gc-ol-flip-name)))
  *gc-ol-flip*)

(defun gc-ol-set-text-h ( / res s val)
  (princ "\n\n--- ВЫСОТА ТЕКСТА ---")
  (princ "\nВысота цифры в метрах чертежа. От неё считается вся графика:")
  (princ "\n  длина стрелки = 2 x высота, наконечник = 0.4 x высота,")
  (princ "\n  смещение цифры от стрелки = 1 x высота.")
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "0, 200"
    ;; молча превратилось бы в "0," = 0 м.
    (setq s (gc-ol-trim
              (getstring T (strcat "\nВысота текста, м <"
                                   (gc-ol-fmt *gc-ol-text-h*) ">: "))))
    (cond
      ((= s "") (setq res *gc-ol-text-h*))
      (T
       (setq val (gc-ol-parse-size s))
       (if val
         (setq res val)
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 0,200"))))))
  (setq *gc-ol-text-h* res)
  (princ (strcat "\n[i] Высота текста " (gc-ol-fmt *gc-ol-text-h*)
                 " м, длина стрелки " (gc-ol-fmt (* *gc-ol-arrow-k* res)) " м"))
  *gc-ol-text-h*)

;;; ====================================================================
;;; ОТРИСОВКА
;;; ====================================================================

(defun gc-ol-ensure-layer (name color)
  (if (null (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name)
                   '(70 . 0)
                   (cons 62 color)
                   '(6 . "Continuous")))))

;; Fallback цепочка. МГС первым — этот стиль стоит в образце Шамиля.
(defun gc-ol-text-style ( / )
  (cond
    ((tblsearch "STYLE" "МГС")      "МГС")
    ((tblsearch "STYLE" "GOSTB")    "GOSTB")
    ((tblsearch "STYLE" "ISOCPEUR") "ISOCPEUR")
    (T                              "Standard")))

;; Стрелка = LWPOLYLINE из 3 вершин. Ширина задаётся ПОСЕГМЕНТНО:
;; группа 40 — начальная ширина сегмента, начинающегося в этой вершине,
;; группа 41 — конечная. Поэтому наконечник задаётся на средней вершине:
;; сегмент v1->v2 нулевой ширины (тонкий хвост), v2->v3 от head до 0 (остриё).
(defun gc-ol-draw-arrow (v1 v2 v3 head / )
  (entmake
    (list '(0 . "LWPOLYLINE")
          '(100 . "AcDbEntity")
          (cons 8 *gc-ol-layer*)
          '(100 . "AcDbPolyline")
          '(90 . 3)
          '(70 . 0)
          (cons 38 0.0)
          (cons 10 (list (car v1) (cadr v1))) (cons 40 0.0)  (cons 41 0.0)
          (cons 10 (list (car v2) (cadr v2))) (cons 40 head) (cons 41 0.0)
          (cons 10 (list (car v3) (cadr v3))) (cons 40 0.0)  (cons 41 0.0))))

;; 72=1 / 73=2 — Middle Center: как в образце («Середина по центру»).
(defun gc-ol-draw-text (pt txt rot / )
  (entmake (list '(0 . "TEXT")
                 (cons 8 *gc-ol-layer*)
                 (cons 7 (gc-ol-text-style))
                 (cons 10 pt)
                 (cons 40 *gc-ol-text-h*)
                 (cons 1 txt)
                 (cons 50 rot)
                 (cons 72 1)
                 (cons 11 pt)
                 (cons 73 2))))

;; Строит стрелку с подписью для фактической точки p.
;; p  — фактическая точка, от неё считается отклонение и сторона стрелки.
;; at — где ставить подпись; nil = напротив точки. Точка сносится на прямую,
;;      поэтому стрелка в любом случае начинается на прямой.
;; ПОЧЕМУ так: на одной прямой точки могут стоять плотно, и подписи напротив
;; каждой налезают друг на друга. Разнеся их вдоль прямой, чертёж читается.
;; Считает ВСЮ геометрию подписи одним местом, чтобы предпросмотр и реальная
;; отрисовка не могли разъехаться.
;; p  — фактическая точка, at — место подписи (nil = напротив точки).
;; Возвращает (v1 v2 v3 tp ang head txt dev) либо nil, если прямая не задана.
(defun gc-ol-geom (p at / u n f h len head v1 v2 v3 ux uy ang td nx ny tp
                     off dev sside outward txt)
  (setq u (gc-ol-unit *gc-ol-a* *gc-ol-b*))
  (if (null u)
    nil
    (progn
      (setq h    *gc-ol-text-h*
            len  (* *gc-ol-arrow-k* h)
            head (* *gc-ol-head-k*  h))
      ;; Знаковое отклонение: положительное — точка слева от направления
      ;; прямой, отрицательное — справа.
      (setq dev (gc-ol-signed-offset p))
      ;; СТОРОНА, где лежит стрелка, — из настройки. Все подписи по одну
      ;; сторону прямой, чтобы чертёж не рябил.
      (setq n (list (- (cadr u)) (car u)))          ; левая нормаль
      (if (= *gc-ol-side* "R")
        (setq n (list (- (car n)) (- (cadr n)))))
      ;; НАПРАВЛЕНИЕ остриё — из ЗНАКА отклонения, а не из настройки.
      ;; В этом весь смысл: стрелка показывает, в какую сторону ушёл факт.
      ;; Точка на выбранной стороне  -> остриё от прямой наружу.
      ;; Точка с противоположной     -> остриё к прямой.
      (setq sside (if (= *gc-ol-side* "R") -1.0 1.0))
      (setq outward (>= (* dev sside) 0.0))
      (if *gc-ol-rev* (setq outward (not outward)))
      ;; Стрелка всегда занимает одну и ту же полосу от прямой на выбранную
      ;; сторону; меняется только то, куда смотрит остриё.
      (setq f (gc-ol-foot (if at at p)))
      (setq v2 (list (+ (car  f) (* (car  n) (/ len 2.0)))
                     (+ (cadr f) (* (cadr n) (/ len 2.0)))))
      (if outward
        (progn
          (setq v1 (list (car f) (cadr f)))
          (setq v3 (list (+ (car  f) (* (car  n) len))
                         (+ (cadr f) (* (cadr n) len))))
          (setq ux (car  n)
                uy (cadr n)))
        (progn
          (setq v1 (list (+ (car  f) (* (car  n) len))
                         (+ (cadr f) (* (cadr n) len))))
          (setq v3 (list (car f) (cadr f)))
          (setq ux (- (car  n))
                uy (- (cadr n)))))
      ;; Поворот текста вдоль стрелки. Нормализуем, чтобы цифра не вставала
      ;; вверх ногами: угол приводим в (-90°; 90°].
      (setq ang (atan uy ux))
      (if (or (> ang (/ pi 2.0)) (<= ang (- (/ pi 2.0))))
        (setq ang (+ ang pi)))
      ;; Смещение считаем от НОРМАЛИЗОВАННОГО направления — тогда цифра всегда
      ;; с одной и той же визуальной стороны, а Переворот её перекидывает.
      (setq td (list (cos ang) (sin ang)))
      (setq nx (- (cadr td))
            ny (car td))
      (if *gc-ol-flip*
        (setq nx (- nx) ny (- ny)))
      (setq off (* *gc-ol-text-k* h))
      (setq tp (list (+ (car v2) (* nx off))
                     (+ (cadr v2) (* ny off))
                     0.0))
      ;; Величина отклонения — модуль, без знака (решение Шамиля).
      (setq txt (itoa (gc-ol-round (* 1000.0 (abs dev)))))
      (list v1 v2 v3 tp ang head txt dev))))

(defun gc-ol-label (p at / g dev txt)
  (setq g (gc-ol-geom p at))
  (cond
    ((null g)
     (princ "\n[ОШИБКА] Проектная прямая не задана.")
     nil)
    (T
     (setq txt (nth 6 g)
           dev (nth 7 g))
     (gc-ol-ensure-layer *gc-ol-layer* *gc-ol-layer-color*)
     (gc-ol-draw-arrow (nth 0 g) (nth 1 g) (nth 2 g) (nth 5 g))
     (gc-ol-draw-text  (nth 3 g) txt (nth 4 g))
     (princ (strcat "\n[i] Отклонение от прямой: " txt " мм ("
                    (if (>= dev 0.0) "точка слева" "точка справа")
                    " от направления)"))
     txt)))

;;; ====================================================================
;;; ЖИВОЙ ПРЕДПРОСМОТР МЕСТА ПОДПИСИ
;;; ====================================================================

;; Список временных векторов для grvecs: контур стрелки и рамка на месте
;; цифры. Формат grvecs — (цвет точка1 точка2 цвет точка3 точка4 ...).
;; ПОЧЕМУ контур, а не заливка: grvecs рисует только отрезки, поэтому
;; наконечник показываем двумя «крыльями» и основанием.
(defun gc-ol-preview-vecs (p at / g v1 v2 v3 tp h w ux uy len px py a b
                             c1 c2 t1 t2 t3 t4)
  (setq g (gc-ol-geom p at))
  (if (null g)
    nil
    (progn
      (setq v1 (nth 0 g) v2 (nth 1 g) v3 (nth 2 g) tp (nth 3 g)
            w  (nth 5 g)
            h  *gc-ol-text-h*)
      ;; Направление стрелки и перпендикуляр к ней.
      (setq ux  (- (car  v3) (car  v1))
            uy  (- (cadr v3) (cadr v1))
            len (sqrt (+ (* ux ux) (* uy uy))))
      (if (< len 1.0e-9)
        nil
        (progn
          (setq ux (/ ux len) uy (/ uy len))
          (setq px (- uy) py ux)
          ;; «Крылья» наконечника на средней вершине.
          (setq a (list (+ (car  v2) (* px (/ w 2.0)))
                        (+ (cadr v2) (* py (/ w 2.0)))))
          (setq b (list (- (car  v2) (* px (/ w 2.0)))
                        (- (cadr v2) (* py (/ w 2.0)))))
          ;; Рамка размером с цифру — видно, куда она встанет.
          (setq t1 (list (+ (car tp) (* (+ ux px) (/ h 2.0)))
                         (+ (cadr tp) (* (+ uy py) (/ h 2.0)))))
          (setq t2 (list (+ (car tp) (* (- ux px) (/ h 2.0)))
                         (+ (cadr tp) (* (- uy py) (/ h 2.0)))))
          (setq t3 (list (- (car tp) (* (+ ux px) (/ h 2.0)))
                         (- (cadr tp) (* (+ uy py) (/ h 2.0)))))
          (setq t4 (list (- (car tp) (* (- ux px) (/ h 2.0)))
                         (- (cadr tp) (* (- uy py) (/ h 2.0)))))
          (setq c1 *gc-ol-preview-color*
                c2 *gc-ol-preview-color2*)
          (list c1 v1 v2          ; хвост
                c1 a  v3          ; крыло наконечника
                c1 b  v3          ; второе крыло
                c1 a  b           ; основание наконечника
                c2 t1 t2          ; рамка цифры
                c2 t2 t3
                c2 t3 t4
                c2 t4 t1))))))

;; Живой предпросмотр: пока двигаешь мышь, показывает, где встанет стрелка.
;; ПОЧЕМУ grread, а не getpoint: getpoint не умеет показывать произвольную
;; графику под курсором. grread отдаёт координаты на каждом движении, grvecs
;; рисует временные векторы, а redraw их стирает перед следующим кадром.
;; Возвращает точку либо nil, если пользователь отказался.
(defun gc-ol-pick-place (p txt / gr code res pt vecs)
  (princ (strcat "\nГде поставить подпись — отклонение " txt
                 " мм (место сносится на прямую): "))
  (setq res nil)
  (while (null res)
    (setq gr   (grread T 15 0)
          code (car gr))
    (cond
      ;; 5 — мышь движется: стираем прошлый кадр и рисуем новый.
      ((= code 5)
       (setq pt (cadr gr))
       (redraw)
       (setq vecs (gc-ol-preview-vecs p pt))
       (if vecs (grvecs vecs)))
      ;; 3 — клик левой кнопкой, место выбрано.
      ((= code 3)
       (redraw)
       (setq res (cadr gr)))
      ;; всё остальное — клавиша или другая кнопка мыши: отказ.
      (T
       (redraw)
       (setq res 'CANCEL))))
  (if (equal res 'CANCEL) nil res))

;;; ====================================================================
;;; ЗАПАСНОЕ ТЕКСТОВОЕ МЕНЮ (по Enter)
;;; ====================================================================

;; Страховка на случай, если кнопки не отработают: здесь ввод читается
;; getstring и разбирается нашим кодом, без участия initget.
;; Возвращает T — продолжать работу, nil — выйти из команды.
(defun gc-ol-menu ( / done s res)
  (setq res T done nil)
  (while (not done)
    (princ "\n\n--- МЕНЮ OL ---")
    (princ (strcat "\n  прямая  : "
                   (if *gc-ol-a* "задана" "ещё не задана")))
    (princ (strcat "\n  сторона : " (gc-ol-side-name)))
    (princ (strcat "\n  остриё  : " (gc-ol-rev-name)))
    (princ (strcat "\n  цифра   : " (gc-ol-flip-name)))
    (princ (strcat "\n  текст   : " (gc-ol-fmt *gc-ol-text-h*) " м"))
    (princ (strcat "\n  режим   : " (gc-ol-mode-name)))
    (princ "\n")
    (princ "\n  1 или Л — заново указать проектную прямую")
    (princ "\n  2 или С — сторона: стрелки слева / справа от прямой")
    (princ "\n  6 или Н — направление остриё: обычное / развёрнутое")
    (princ "\n  3 или П — перевернуть цифру на другую сторону стрелки")
    (princ "\n  4 или Т — высота текста")
    (princ "\n  5 или Р — режим: одна / место сам / пачкой рамкой")
    (princ "\n  0 или К — выйти из команды")
    (princ "\n  Enter   — вернуться к точкам")
    (setq s (gc-ol-trim (getstring T "\nВыбор: ")))
    (cond
      ((= s "") (setq done T))
      ((gc-ol-is-word s '("1" "л" "Л" "l" "L" "линия" "Линия" "прямая"))
       (gc-ol-ask-line))
      ((gc-ol-is-word s '("2" "с" "С" "s" "S" "c" "C" "сторона" "Сторона"))
       (gc-ol-toggle-side))
      ((gc-ol-is-word s '("6" "н" "Н" "n" "N" "направление" "Направление"))
       (gc-ol-toggle-rev))
      ((gc-ol-is-word s '("3" "п" "П" "p" "P" "переворот" "Переворот"))
       (gc-ol-toggle-flip))
      ((gc-ol-is-word s '("4" "т" "Т" "t" "T" "текст" "Текст" "высота"))
       (gc-ol-set-text-h))
      ((gc-ol-is-word s '("5" "р" "Р" "r" "R" "режим" "Режим"))
       (gc-ol-toggle-mode))
      ((gc-ol-is-word s '("0" "к" "К" "k" "K" "q" "Q" "выход" "Выход"))
       (setq res nil done T))
      (T (princ (strcat "\n[!] Не понял \"" s
                        "\". Введите 1, 2, 3, 4, 0 или просто Enter.")))))
  res)

;;; ====================================================================
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-ol-defaults ( / )
  (if (null *gc-ol-side*)   (setq *gc-ol-side*   "L"))
  (if (null *gc-ol-mode*)   (setq *gc-ol-mode*   "ONE"))
  (if (null *gc-ol-text-h*) (setq *gc-ol-text-h* *gc-ol-text-h-init*)))

(defun gc-ol-intro ( / )
  (princ "\n\n=== OL — отклонение фактических точек от проектной прямой ===")
  (princ "\nПрямая задаётся двумя точками. По каждой снятой точке считается")
  (princ "\nперпендикулярное расстояние до прямой и подписывается у стрелки.")
  (princ "\nКнопки в строке запроса:")
  (princ "\n  Линия     — заново указать прямую")
  (princ "\n  Сторона   — с какой стороны прямой лежат стрелки")
  (princ "\n  Направление — развернуть остриё, если смотрит не туда")
  (princ "\n  Переворот — цифра над / под стрелкой")
  (princ "\n  Текст     — высота цифры, от неё считается вся графика")
  (princ "\n  Режим     — одна точка / место подписи сам / пачкой рамкой")
  (princ "\nКнопку можно щёлкнуть мышью или набрать её первую букву.")
  (princ "\nEnter — запасное текстовое меню, Esc — выход.")
  (princ "\nВ пакетном режиме кнопки показываются ПЕРЕД выборкой рамкой:")
  (princ "\nтам же меняется прямая при переходе на новый участок."))

(defun gc-ol-status ( / )
  (princ (strcat "\n\n--- OL | прямая: "
                 (if *gc-ol-a* "задана" "НЕ задана")
                 " | сторона: " (if (= *gc-ol-side* "R") "справа" "слева")
                 " | остриё: " (if *gc-ol-rev* "развёрнуто" "обычное")
                 " | цифра: " (if *gc-ol-flip* "снизу" "сверху")
                 " | текст: " (gc-ol-fmt *gc-ol-text-h*) " м"
                 " | режим: " (cond ((= *gc-ol-mode* "BATCH") "пачкой")
                                    ((= *gc-ol-mode* "PLACE") "место сам")
                                    (T "по одной"))
                 " ---")))

;; Обработка нажатой кнопки. Возвращает T — продолжать, nil — выйти.
(defun gc-ol-do-option (kw / )
  (cond
    ((gc-ol-is-word kw '("MENU"))              (gc-ol-menu))
    ((gc-ol-is-word kw '("Линия" "Л"))         (gc-ol-ask-line) T)
    ((gc-ol-is-word kw '("Сторона" "С"))       (gc-ol-toggle-side) T)
    ((gc-ol-is-word kw '("Направление" "Н"))   (gc-ol-toggle-rev) T)
    ((gc-ol-is-word kw '("Переворот" "П"))     (gc-ol-toggle-flip) T)
    ((gc-ol-is-word kw '("Текст" "Т"))         (gc-ol-set-text-h) T)
    ((gc-ol-is-word kw '("Режим" "Р"))         (gc-ol-toggle-mode) T)
    (T (princ (strcat "\n[!] Кнопка \"" kw "\" не распознана.")) T)))

;; Режим «по одной точке»: клик — сразу подпись.
;; Возвращает T — продолжать, nil — выйти из команды.
(defun gc-ol-single-step (prm / p)
  ;; Ключевые слова продублированы одной буквой — см. шапку файла.
  ;; ПОЧЕМУ listp, а не (= (type x) 'STR): сравнение символов через =
  ;; в AutoLISP ненадёжно. getpoint возвращает nil, список или строку.
  (initget "Линия Л Сторона С Направление Н Переворот П Текст Т Режим Р Выход В")
  (setq p (getpoint (strcat "\nФактическая точка" prm)))
  (cond
    ;; Enter — запасное текстовое меню.
    ((null p)  (gc-ol-menu))
    ((listp p) (gc-ol-label p nil) T)
    ((gc-ol-is-word p '("Выход" "В")) nil)
    (T         (gc-ol-do-option p))))

;; Режим «пачкой»: выделяем много точек рамкой, подписываем все разом.
;; ПОЧЕМУ здесь нет кнопок: ssget не поддерживает ключевые слова initget,
;; поэтому настройки открываются по Enter вместо выборки.
;; Возвращает T — продолжать, nil — выйти из команды.
;; Режим «Место»: сначала фактическая точка, потом место подписи —
;; с живым предпросмотром под курсором.
;; Возвращает T — продолжать, nil — выйти из команды.
(defun gc-ol-place-step (prm / p g at)
  (initget "Линия Л Сторона С Направление Н Переворот П Текст Т Режим Р Выход В")
  (setq p (getpoint (strcat "\nФактическая точка" prm)))
  (cond
    ((null p) (gc-ol-menu))
    ((listp p)
     ;; Величина известна сразу — показываем её в подсказке, пока выбираешь
     ;; место: от места она не зависит, только от самой точки.
     (setq g (gc-ol-geom p nil))
     (if (null g)
       (princ "\n[ОШИБКА] Проектная прямая не задана.")
       (progn
         (setq at (gc-ol-pick-place p (nth 6 g)))
         (if (null at)
           (princ "\n[!] Место не указано, подпись не поставлена.")
           (gc-ol-label p at))))
     T)
    ((gc-ol-is-word p '("Выход" "В")) nil)
    (T (gc-ol-do-option p))))

(defun gc-ol-batch-select ( / ss pts n ok)
  (princ "\nВыделите фактические точки рамкой: ")
  (setq ss (ssget *gc-ol-ssget-filter*))
  (cond
    ((null ss)
     (princ "\n[i] Ничего не выбрано.")
     T)
    (T
     (setq pts (gc-ol-ss-points ss))
     (setq n (length pts) ok 0)
     (foreach p pts
       (if (gc-ol-label p nil) (setq ok (1+ ok))))
     (princ (strcat "\n[Итог] подписано точек: " (itoa ok)
                    " из " (itoa n)))
     T)))

;; ПОЧЕМУ кнопки вынесены в отдельный запрос ПЕРЕД выборкой: ssget не
;; поддерживает ключевые слова initget, поэтому в самом запросе выборки
;; кнопок быть не может. Без этого шага в пакетном режиме нельзя было
;; сменить проектную прямую для следующего участка, не выходя из команды.
;; Enter сразу ведёт к выборке — на участок это один лишний Enter.
(defun gc-ol-batch-step ( / kw)
  (initget "Линия Л Сторона С Направление Н Переворот П Текст Т Режим Р Выход В")
  (setq kw (getkword
             (strcat "\nДальше [Линия/Сторона/Направление/Переворот/Текст/Режим/Выход]"
                     " <Enter — выбрать точки>: ")))
  (cond
    ((null kw)                          (gc-ol-batch-select))
    ((gc-ol-is-word kw '("Выход" "В"))  nil)
    (T                                  (gc-ol-do-option kw))))

(defun gc-ol-run ( / done prm)
  (gc-ol-defaults)
  (gc-ol-intro)
  ;; Без прямой считать не от чего.
  (if (null *gc-ol-a*) (gc-ol-ask-line))
  (setq prm  " [Линия/Сторона/Направление/Переворот/Текст/Режим/Выход]: "
        done nil)
  (while (not done)
    (cond
      ((null *gc-ol-a*)
       (princ "\n[i] Проектная прямая не задана — выход.")
       (setq done T))
      (T
       (gc-ol-status)
       (if (null (cond
                   ((= *gc-ol-mode* "BATCH") (gc-ol-batch-step))
                   ((= *gc-ol-mode* "PLACE") (gc-ol-place-step prm))
                   (T                        (gc-ol-single-step prm))))
         (setq done T)))))
  (princ "\n[i] OL завершена.")
  (princ))

;;; ====================================================================
;;; КОМАНДА
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если Шамиль нажал Esc посреди ввода.
(defun c:ol ( / *error*)
  (defun *error* (msg)
    (if (and msg
             (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\n[ОШИБКА] OL: " msg))
      (princ "\n[ОТМЕНА] OL прерван."))
    (princ))
  (gc-ol-run)
  (princ))

;; Полное имя по docs/conventions.md: короткий алиас плюс gc-имя.
(defun c:gc-line-deviation ( / )
  (c:ol))

(princ "\n[gc] ol.lsp v9 загружен. Команда: OL")
(princ)
