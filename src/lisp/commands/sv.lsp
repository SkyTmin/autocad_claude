;;; sv.lsp -- obrabotka svay (SPEC-001 / SPEC-002 / SPEC-003 / SPEC-004 / SPEC-010 v29)
;;; Komandy:
;;;   SV  -- rezhimy 1/2/3/4 (4: naklonnye svai, ellipsy).
;;;   SVP -- sechenie svai na zadannoy otmetke + proektnoe otklonenie.
;;;
;;; v29: SV 4 - treugolnik na 1 m i uglovoy razmer (gradusy/minuty).
;;;      Komponenta X/Y vybiraetsya po blizosti modulya k 222 mm/m.
;;;
;;; v28: proektnye ELLIPSE - vybor i centr v SV 4 / SV 3 / SVP.
;;;
;;; v27: SV 4 - scenariy SV 3: otmetka sreza, proekt, ellips sreza.
;;;      Sinie otkloneniya +Y 1.700, belye proektnye +Y 2.600.
;;;
;;; v26: SV 4 - ellipsy naklonnyh svay 1:4.5, podbor po vsem tochkam.
;;;      Proverku v Civil 3D vypolnyaet polzovatel.
;;;
;;; v25: VOZVRASHCHENO RASPOLOZHENIE CIFR, deystvovavshee do v20.
;;;      v20 unificirovala podpisi SV s ol.lsp: cifra X vsegda sverhu,
;;;      cifra Y vsegda sleva. Dlya OL eto verno -- tam strelka ODNA.
;;;      V SV strelok DVE i oni shodyatsya v ugol "G". Postoyannaya storona
;;;      zagonyaet odnu iz cifr VNUTR etogo ugla, gde ona nalezaet na vtoruyu
;;;      strelku. Shamil prines foto: do i kak nado.
;;;      Teper obe cifry snova uhodyat vo VNESHNIE chetverti:
;;;      vdol svoey strelki -- na ee seredinu, poperek -- na vysotu teksta
;;;      v storonu, PROTIVOPOLOZHNUYU vtoroy strelke.
;;;      Masshtab sohranen ot v21: vse vyvoditsya iz vysoty teksta.
;;;      Strelki, shrift i knopka Tekst ne menyayutsya.
;;;
;;; v24: 1) ANNOTATIVNYY stil bolshe ne vybiraetsya. Takoy tekst viden tolko
;;;         pri vybrannom masshtabe annotaciy -- inache sozdaetsya, no ne
;;;         otobrazhaetsya. Ranshe pro eto tolko preduprezhdali.
;;;      2) Sozdanie sobstvennogo stilya GC-Tekst teper proveryaetsya. Esli
;;;         entmake stilya ne proshel, a imya vse ravno vozvrashchalos, to
;;;         KAZHDYY entmake teksta so ssylkoy na nesushchestvuyushchiy stil
;;;         molcha provalivalsya -- i podpisey ne bylo, bez soobshcheniy.
;;;      3) Kazhdyy entmake proveryaetsya i govorit vsluh, esli chertezh
;;;         otkazal v sozdanii obekta. SV rabotaet v MSK (koordinaty berutsya
;;;         iz DXF), poetomu pravka PSK iz ol.lsp v13 emu ne nuzhna.
;;;
;;; v23: komandy zaregistrirovany i v russkoy raskladke -- te zhe bukvy
;;;      na teh zhe klavishah YCUKEN. Shamil chasto nabiraet komandu,
;;;      zabyv pereklyuchit raskladku: vmesto OL poluchaetsya SHCHD.
;;;
;;; v22: vybor tekstovogo stilya -- tolko s PEREMENNOY vysotoy, inache
;;;      AutoCAD ignoriruet zadannuyu vysotu. Sm. ol.lsp v11.
;;;
;;; v21: vysota teksta stala VEDUSHCHIM razmerom, kak v ol.lsp: dlina strelki
;;;      = 2 x vysota, nakonechnik = 0.4 x vysota, smeshchenie cifry = 1 x
;;;      vysota. Ranshe dlina strelki byla zafiksirovana 0.400 pri tekste
;;;      0.100 -- sootnoshenie 1:4, i cifra vyglyadela melkoy ryadom so
;;;      strelkoy. Teper 1:2, kak u OL. Umolchanie teksta 0.100 -> 0.200,
;;;      dlina strelki pri etom ostalas 0.400.
;;;      Dobavlena knopka [Tekst] v zapros rezhima: menyaet vysotu i tem samym
;;;      masshtabiruet vsyu grafiku. Znachenie obshchee dlya SV i SVP.
;;;
;;; v20: raspolozhenie cifr privedeno k ol.lsp. Ranshe storona podpisi
;;;      schitalas ot znakov otkloneniya i zavisela ot kvadranta -- cifra
;;;      prygala to nad strelkoy, to pod ney. Teper smeshchenie beretsya ot
;;;      NORMALIZOVANNOGO napravleniya strelki, i storona postoyannaya:
;;;      u gorizontalnoy strelki cifra vsegda sverhu, u vertikalnoy -- sleva.
;;;      Konstanty *gc-pile-text-along* / *gc-pile-text-lateral* udaleny:
;;;      smeshchenie vyvoditsya iz dliny strelki i vysoty teksta.
;;;
;;; v19: stil teksta privedyon k ol.lsp -- v cepochku podbora dobavlen "MGS"
;;;      pervym. Imenno etot stil stoit v chertezhah Shamilya, a SV bez nego
;;;      padal na GOSTB/Standard -- otsyuda drugoy shrift u cifr.
;;;
;;; v18: strelki pererisovany v stile ol.lsp -- LWPOLYLINE iz 3 vershin
;;;      s plavno suzhayushchimsya nakonechnikom vmesto LINE + treugolnik
;;;      SOLID. Proporcii iz obrazca menuGEO: shirina nakonechnika 0.2 ot
;;;      dliny strelki (0.080 pri 0.400), nakonechnik vo vtoroy polovine.
;;;
;;; v17: zashchita ot otsutstviya Visual LISP COM. U Kosti vyletala oshibka
;;;      "no function definition: VLAX-ENAME->VLA-OBJECT" -- (vl-load-com)
;;;      v shapke fayla ne otrabotal. Teper koordinaty obychnoy tochki
;;;      berutsya iz DXF-gruppy 10 BEZ COM, a COM trogaetsya tolko dlya
;;;      COGO Point Civil 3D, prichem s proverkoy i vnyatnym soobshcheniem.
;;;
;;; v16: ubrano verhnee ogranichenie dZ mezhdu nizhnim i verhnim secheniem.
;;;      Svai s bolshim raznosom po vysote, naprimer Z 1.000 -> 12.000,
;;;      obrabatyvayutsya vo vseh avtomaticheskih rezhimah.
;;; v15: ispravlen perenos grafiki SV 3: "vverh" = po osi +Y, ne po Z.
;;;      SV-otkloneniya v mode 3 risuyutsya sinim so sdvigom +Y 1.700 m.
;;;      SVP-proektnye otkloneniya v mode 3 risuyutsya belym so sdvigom +Y 2.600 m.
;;; v14: SV mode 3 = SV mode 1 + SVP za odin zapusk.
;;; v13: SVP schitaet otklonenie ot proektnogo centra k novomu secheniyu.
;;; v12: dobavlena komanda SVP (SPEC-003).
;;; v11: gc-pile-strip-hm udalyaet paru otmetchikov vysoty tolko esli ona
;;;      yavno izolirovana nad secheniem.
;;;
;;; Zagruzka: APPLOAD ili (load "put/k/sv.lsp").
;;; Zavisimosti: Visual LISP COM.

(vl-load-com)

;;; ====================================================================
;;; КОНСТАНТЫ
;;; ====================================================================

(setq *gc-pile-r-norm*             0.710) ; норма радиуса сваи, м
(setq *gc-pile-r-warn*             0.050)
;; ВЫСОТА ТЕКСТА ЗАДАЁТ ВСЮ ГРАФИКУ — как в ol.lsp. Длина стрелки и ширина
;; наконечника считаются от неё, поэтому цифра и стрелка всегда в одной
;; пропорции. Меняется кнопкой [Текст] в запросе режима.
(setq *gc-pile-arrow-k*            2.0)   ; длина стрелки = 2.0 x высота текста
;; Ширина наконечника = доля от длины стрелки. 0.2 x 0.400 = 0.080 —
;; ровно как в образце menuGEO, тот же вид, что у стрелок ol.lsp.
(setq *gc-pile-arrow-head-k*       0.2)
(setq *gc-pile-tol-mm-per-m*      20.0)
(setq *gc-pile-text-h*             0.200) ; высота текста, м — ведущий размер
;; *gc-pile-text-along* и *gc-pile-text-lateral* удалены в v20: смещение
;; подписи теперь выводится из геометрии, как в ol.lsp — вдоль стрелки это
;; ровно её середина, поперёк — высота текста. Отдельные константы только
;; расходились бы с реальным размером стрелки.
(setq *gc-pile-z-cluster*          0.050)
(setq *gc-pile-xy-cluster*         1.800)
(setq *gc-pile-pair-dz-min*        0.300)
(setq *gc-pile-hm-pair-dz-max*     0.002)
(setq *gc-pile-hm-gap-min*         0.010)
(setq *gc-pile-project-match-max*  2.000)
(setq *gc-pile-sv3-sv-dev-dy*      1.700)
(setq *gc-pile-sv3-prj-dev-dy*     2.600)

(setq *gc-pile-ssget-filter*
      '((0 . "POINT,AECC*POINT,AEC*POINT")))

(setq *gc-pile-project-ssget-filter*
      '((0 . "CIRCLE,ELLIPSE,POINT,AECC*POINT,AEC*POINT")))

(setq *gc-l-low*                "GC-Сваи-Низ")
(setq *gc-l-high*               "GC-Сваи-Верх")
(setq *gc-l-arrows*             "GC-Сваи-Отклонения")
(setq *gc-l-text*               "GC-Сваи-Текст")
(setq *gc-l-cut*                "GC-Сваи-Срез")
(setq *gc-l-project-arrows*     "GC-Сваи-Проект-Отклонения")
(setq *gc-l-project-text*       "GC-Сваи-Проект-Текст")
(setq *gc-l-sv3-arrows*         "GC-Сваи-SV3-Синие-Отклонения")
(setq *gc-l-sv3-text*           "GC-Сваи-SV3-Синий-Текст")
(setq *gc-l-sv3-project-arrows* "GC-Сваи-SV3-Проект-Отклонения")
(setq *gc-l-sv3-project-text*   "GC-Сваи-SV3-Проект-Текст")

;;; ====================================================================
;;; ИЗВЛЕЧЕНИЕ КООРДИНАТ
;;; ====================================================================

;; Проверяет, доступен ли Visual LISP COM, и при необходимости догружает его.
;; ПОЧЕМУ нужно: у Кости вылетала ошибка
;;   "no function definition: VLAX-ENAME->VLA-OBJECT"
;; то есть (vl-load-com) в шапке файла не отработал. Ссылка на несвязанный
;; символ в AutoLISP возвращает nil и не падает, поэтому наличие функции
;; можно проверить прямо так.
(defun gc-pile-com-ok ( / )
  (if (null vlax-ename->vla-object) (vl-load-com))
  (if vlax-ename->vla-object T nil))

;; Координаты объекта: (x y z).
;; ПОРЯДОК ВАЖЕН. Сначала пробуем DXF-группу 10 — она есть у обычной точки
;; и не требует Visual LISP COM вообще. COM трогаем только для COGO Point
;; Civil 3D, где координаты доступны лишь через Easting/Northing.
;; Так команда продолжает работать даже там, где COM недоступен.
(defun gc-pile-get-coords (ent / ed typ p10 obj)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed))
        p10 (cdr (assoc 10 ed)))
  (cond
    ;; COGO Point — только через COM.
    ((wcmatch typ "AECC*POINT,AEC*POINT")
     (if (gc-pile-com-ok)
       (progn
         (setq obj (vlax-ename->vla-object ent))
         (cond
           ((vlax-property-available-p obj 'Easting)
            (list (vla-get-Easting obj)
                  (vla-get-Northing obj)
                  (vla-get-Elevation obj)))
           ((vlax-property-available-p obj 'Coordinates)
            (vlax-safearray->list
              (vlax-variant-value (vla-get-Coordinates obj))))
           ((vlax-property-available-p obj 'InsertionPoint)
            (vlax-safearray->list
              (vlax-variant-value (vla-get-InsertionPoint obj))))
           (T nil)))
       nil))
    ;; Обычная точка и всё, у чего есть группа 10 — без COM.
    ((and p10 (caddr p10)) p10)
    ;; Остальное — пробуем COM, если он есть.
    ((gc-pile-com-ok)
     (setq obj (vlax-ename->vla-object ent))
     (cond
       ((vlax-property-available-p obj 'Coordinates)
        (vlax-safearray->list
          (vlax-variant-value (vla-get-Coordinates obj))))
       ((vlax-property-available-p obj 'InsertionPoint)
        (vlax-safearray->list
          (vlax-variant-value (vla-get-InsertionPoint obj))))
       (T nil)))
    (T nil)))

(defun gc-pile-get-project-center (ent / ed typ c)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed)))
  (cond
    ((member typ '("CIRCLE" "ELLIPSE"))
     (setq c (cdr (assoc 10 ed)))
     (if c (list (car c) (cadr c) (if (caddr c) (caddr c) 0.0)) nil))
    ((wcmatch typ "POINT,AECC*POINT,AEC*POINT")
     (setq c (gc-pile-get-coords ent))
     (if c (list (car c) (cadr c) (if (caddr c) (caddr c) 0.0)) nil))
    (T nil)))

(defun gc-pile-ss-to-points (ss / i n pts ent c skipped)
  (setq pts '() skipped 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c (gc-pile-get-coords ent))
    (if c
      (setq pts (cons c pts))
      (setq skipped (1+ skipped)))
    (setq i (1+ i)))
  (if (> skipped 0)
    (progn
      (princ (strcat "\n[!] Пропущено объектов без координат: " (itoa skipped)))
      (if (null (gc-pile-com-ok))
        (princ (strcat "\n[!] Visual LISP COM недоступен в этой версии CAD."
                       "\n    COGO Point Civil 3D без него прочитать нельзя."
                       "\n    Обычные точки (POINT) читаются и без него.")))))
  (reverse pts))

(defun gc-pile-ss-to-project-centers (ss / i n centers ent c skipped)
  (setq centers '() skipped 0 i 0 n (sslength ss))
  (while (< i n)
    (setq ent (ssname ss i))
    (setq c (gc-pile-get-project-center ent))
    (if c
      (setq centers (cons c centers))
      (setq skipped (1+ skipped)))
    (setq i (1+ i)))
  (if (> skipped 0)
    (princ (strcat "\n[!] SVP: пропущено проектных объектов без координат: "
                   (itoa skipped))))
  (reverse centers))

(defun gc-pile-read-project-centers ( / ss centers)
  (princ "\nВыделите проектные круги, эллипсы или точки (Enter — без проектных отклонений): ")
  (setq ss (ssget *gc-pile-project-ssget-filter*))
  (if ss
    (progn
      (setq centers (gc-pile-ss-to-project-centers ss))
      (princ (strcat "\n[i] Проектных центров выбрано: " (itoa (length centers))))
      centers)
    (progn
      (princ "\n[!] Проектные объекты не выбраны: проектные отклонения не строятся.")
      nil)))

;;; ====================================================================
;;; ГЕОМЕТРИЯ
;;; ====================================================================

(defun gc-pile-circle-3 (p1 p2 p3 / ax ay bx by d ux uy)
  (setq ax (- (car p2)  (car p1))
        ay (- (cadr p2) (cadr p1))
        bx (- (car p3)  (car p1))
        by (- (cadr p3) (cadr p1)))
  (setq d (* 2.0 (- (* ax by) (* ay bx))))
  (if (< (abs d) 1.0e-9)
    nil
    (progn
      (setq ux (/ (- (* by (+ (* ax ax) (* ay ay)))
                     (* ay (+ (* bx bx) (* by by))))
                  d)
            uy (/ (- (* ax (+ (* bx bx) (* by by)))
                     (* bx (+ (* ax ax) (* ay ay))))
                  d))
      (list (+ (car p1)  ux)
            (+ (cadr p1) uy)
            (sqrt (+ (* ux ux) (* uy uy)))))))

(defun gc-pile-avg (lst / sum)
  (setq sum 0.0)
  (foreach v lst (setq sum (+ sum v)))
  (/ sum (float (length lst))))

(defun gc-pile-strip-hm (zg / sorted top1 top2 top3 rest)
  (if (< (length zg) 5)
    zg
    (progn
      (setq sorted (vl-sort zg '(lambda (a b) (> (caddr a) (caddr b)))))
      (setq top1 (car sorted)
            top2 (cadr sorted)
            top3 (caddr sorted)
            rest (cddr sorted))
      (if (and (< (abs (- (caddr top1) (caddr top2))) *gc-pile-hm-pair-dz-max*)
               (>= (- (caddr top2) (caddr top3)) *gc-pile-hm-gap-min*))
        (progn
          (princ (strcat "\n[i] Удалена пара отметчиков высоты"
                         " (Z~" (rtos (caddr top1) 2 3)
                         " м, зазор до сечения "
                         (rtos (* 1000 (- (caddr top2) (caddr top3))) 2 1)
                         " мм)"))
          rest)
        zg))))

(defun gc-pile-combos3 (lst / n i j k res)
  (setq res '() n (length lst) i 0)
  (while (< i (- n 2))
    (setq j (1+ i))
    (while (< j (- n 1))
      (setq k (1+ j))
      (while (< k n)
        (setq res (cons (list (nth i lst) (nth j lst) (nth k lst)) res))
        (setq k (1+ k)))
      (setq j (1+ j)))
    (setq i (1+ i)))
  res)

(defun gc-pile-best-circle (points / triples best best-err circ err)
  (if (< (length points) 3)
    nil
    (progn
      (setq triples (gc-pile-combos3 points))
      (setq best nil best-err 1.0e99)
      (foreach tr triples
        (setq circ (gc-pile-circle-3 (car tr) (cadr tr) (caddr tr)))
        (if circ
          (progn
            (setq err (abs (- (caddr circ) *gc-pile-r-norm*)))
            (if (< err best-err)
              (setq best-err err best circ)))))
      best)))

(defun gc-pile-dist-xy (p1 p2 / dx dy)
  (setq dx (- (car p1) (car p2))
        dy (- (cadr p1) (cadr p2)))
  (sqrt (+ (* dx dx) (* dy dy))))

(defun gc-pile-take-nearest-project (target projects limit / best best-dist rest p d)
  (if (null projects)
    (list nil projects nil)
    (progn
      (setq best nil best-dist 1.0e99 rest '())
      (foreach p projects
        (setq d (gc-pile-dist-xy target p))
        (if (< d best-dist)
          (progn
            (if best (setq rest (cons best rest)))
            (setq best p best-dist d))
          (setq rest (cons p rest))))
      (if (and best (<= best-dist limit))
        (list best (reverse rest) best-dist)
        (list nil projects best-dist)))))

(defun gc-pile-cluster-by-xy (pts / clusters remaining cur grow keep)
  (setq remaining pts clusters '())
  (while remaining
    (setq cur (list (car remaining))
          remaining (cdr remaining))
    (setq grow T)
    (while grow
      (setq grow nil keep '())
      (foreach p remaining
        (if (vl-some
              '(lambda (m) (<= (gc-pile-dist-xy p m) *gc-pile-xy-cluster*))
              cur)
          (progn (setq cur (cons p cur) grow T))
          (setq keep (cons p keep))))
      (setq remaining (reverse keep)))
    (setq clusters (cons cur clusters)))
  (reverse clusters))

(defun gc-pile-cluster-by-z (pts / sorted groups cur-group cur-z pt)
  (setq sorted (vl-sort pts '(lambda (a b) (< (caddr a) (caddr b)))))
  (setq groups '() cur-group '() cur-z nil)
  (foreach pt sorted
    (cond
      ((null cur-z)
       (setq cur-z (caddr pt) cur-group (list pt)))
      ((<= (- (caddr pt) cur-z) *gc-pile-z-cluster*)
       (setq cur-group (cons pt cur-group)))
      (T
       (setq groups (cons (reverse cur-group) groups))
       (setq cur-z (caddr pt) cur-group (list pt)))))
  (if cur-group
    (setq groups (cons (reverse cur-group) groups)))
  (reverse groups))

;;; ====================================================================
;;; СЛОИ И ОТРИСОВКА
;;; ====================================================================

(defun gc-pile-ensure-layer (name color)
  (if (null (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name)
                   '(70 . 0)
                   (cons 62 color)
                   '(6 . "Continuous")))))

;; Стиль с ФИКСИРОВАННОЙ высотой (группа 40 не ноль) не годится: AutoCAD
;; игнорирует высоту, заданную командой, и вся графика перестаёт
;; масштабироваться. У Шамиля в одном чертеже так и вышло — ISOCPEUR
;; с высотой 0.240.
;; Поэтому берём первый стиль из цепочки, у которого высота ПЕРЕМЕННАЯ,
;; а если все кандидаты фиксированные — заводим собственный "GC-Текст"
;; с тем же шрифтом и нулевой высотой.
(defun gc-pile-style-var-h-p (name / e h)
  (setq e (tblsearch "STYLE" name))
  (if e
    (progn
      (setq h (cdr (assoc 40 e)))
      (if (or (null h) (< (abs h) 1.0e-9)) T nil))
    nil))

;; Имя файла шрифта у стиля — чтобы свой стиль выглядел как привычный.
(defun gc-pile-style-font (name / e)
  (setq e (tblsearch "STYLE" name))
  (if e (cdr (assoc 3 e)) nil))

(defun gc-pile-make-own-style ( / font cand)
  (if (null (tblsearch "STYLE" "GC-Текст"))
    (progn
      ;; Шрифт берём у первого существующего кандидата, иначе стандартный.
      (foreach c '("МГС" "GOSTB" "ISOCPEUR" "Standard")
        (if (and (null font) (tblsearch "STYLE" c))
          (setq font (gc-pile-style-font c))))
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
      "Standard")))

;; Аннотативный стиль хранит признак в XDATA приложения AcadAnnotative.
(defun gc-pile-style-annotative-p (name / o)
  (setq o (tblobjname "STYLE" name))
  (if o
    (if (assoc -3 (entget o '("AcadAnnotative"))) T nil)
    nil))

;; Стиль годится, если он есть, высота у него переменная И он НЕ аннотативный.
;; ПОЧЕМУ аннотативный не годится: такой текст показывается только при
;; выбранном масштабе аннотаций. Если масштаб не задан или не совпадает,
;; текст создаётся, но его не видно вообще.
(defun gc-pile-style-ok-p (name / )
  (if (gc-pile-style-var-h-p name)
    (if (gc-pile-style-annotative-p name) nil T)
    nil))

;; Цепочка подбора. Берём первый стиль, который прошёл проверку.
(defun gc-pile-text-style ( / res)
  (foreach c '("МГС" "GOSTB" "ISOCPEUR" "Standard")
    (if (and (null res) (gc-pile-style-ok-p c))
      (setq res c)))
  (if res res (gc-pile-make-own-style)))

;; entmake молча возвращает nil, если чертёж отказал в создании объекта
;; (нет слоя, нет стиля, слой заблокирован). Молчание — худшее, что может
;; быть: команда «отработала», а на чертеже пусто. Говорим вслух.
(defun gc-pile-emake (lst what / e)
  (setq e (entmake lst))
  (if (null e)
    (progn
      (princ (strcat "\n[ОШИБКА] Чертёж не принял " what "."))
      (princ "\n    Проверьте слой (не заблокирован ли) и текстовый стиль.")
      nil)
    e))

(defun gc-pile-draw-circle (cx cy z r layer)
  (gc-pile-emake (list '(0 . "CIRCLE")
                 (cons 8 layer)
                 (cons 10 (list cx cy z))
                 (cons 40 r))
    "окружность"))

;; Стрелка = LWPOLYLINE из 3 вершин: тонкий хвост, затем плавно сужающийся
;; наконечник во второй половине. Раньше здесь была LINE плюс треугольник
;; SOLID — выглядело грубее. Теперь тот же вид, что в ol.lsp, а пропорции
;; взяты из образца menuGEO: наконечник шириной 0.2 от длины стрелки
;; (0.080 при длине 0.400) и занимает вторую половину.
;;
;; Ширина задаётся ПОСЕГМЕНТНО: группа 40 — начальная ширина сегмента,
;; начинающегося в этой вершине, группа 41 — конечная. Поэтому наконечник
;; описывается на средней вершине.
;;
;; LWPOLYLINE плоская, высота хранится в группе 38 — берём Z начала, чтобы
;; стрелка легла на ту же отметку, что и раньше LINE.
(defun gc-pile-draw-arrow (start end layer / dx dy len ux uy mid head z)
  (setq dx  (- (car  end) (car  start))
        dy  (- (cadr end) (cadr start))
        len (sqrt (+ (* dx dx) (* dy dy))))
  (if (> len 1.0e-9)
    (progn
      (setq ux (/ dx len)
            uy (/ dy len))
      (setq mid (list (+ (car  start) (* ux (/ len 2.0)))
                      (+ (cadr start) (* uy (/ len 2.0)))))
      (setq head (* *gc-pile-arrow-head-k* len))
      (setq z (if (caddr start) (caddr start) 0.0))
      (gc-pile-emake
        (list '(0 . "LWPOLYLINE")
              '(100 . "AcDbEntity")
              (cons 8 layer)
              '(100 . "AcDbPolyline")
              '(90 . 3)
              '(70 . 0)
              (cons 38 z)
              (cons 10 (list (car start) (cadr start))) (cons 40 0.0)  (cons 41 0.0)
              (cons 10 (list (car mid)   (cadr mid)))   (cons 40 head) (cons 41 0.0)
              (cons 10 (list (car end)   (cadr end)))   (cons 40 0.0)  (cons 41 0.0))
        "стрелку"))))

(defun gc-pile-draw-text-rot (pt text style layer rotation)
  (gc-pile-emake (list '(0 . "TEXT")
                 (cons 8 layer)
                 (cons 7 style)
                 (cons 10 pt)
                 (cons 40 *gc-pile-text-h*)
                 (cons 1 text)
                 (cons 50 rotation)
                 (cons 72 1)
                 (cons 11 pt)
                 (cons 73 2))
    "надпись"))

(defun gc-pile-mm-rounded (mm)
  (rtos (abs mm) 2 0))

(defun gc-pile-mm-signed (mm)
  (strcat (if (>= mm 0) "+" "")
          (rtos mm 2 0) " мм"))

;; Длина стрелки выводится из высоты текста — те же пропорции, что в ol.lsp.
(defun gc-pile-arrow-len ( / )
  (* *gc-pile-arrow-k* *gc-pile-text-h*))


;;; --------------------------------------------------------------------
;;; РАСПОЛОЖЕНИЕ ЦИФР У ПАРЫ СТРЕЛОК
;;;
;;; Стрелки X и Y растут из одной базовой точки и образуют угол «Г».
;;; Вокруг этого угла четыре четверти: две заняты самими стрелками,
;;; две свободны. Цифры ставятся в СВОБОДНЫЕ:
;;;
;;;   вдоль своей стрелки  — на её середину;
;;;   поперёк              — на высоту текста в сторону, ПРОТИВОПОЛОЖНУЮ
;;;                          второй стрелке.
;;;
;;; ПОЧЕМУ не «всегда сверху / всегда слева», как в ol.lsp.
;;; В OL стрелка ОДНА, и постоянная сторона там правильна: подписи ложатся
;;; единообразно и чертёж не рябит. В SV стрелок ДВЕ. Постоянная сторона
;;; неизбежно загоняет одну из цифр внутрь угла, где она налезает на вторую
;;; стрелку: при X вправо и Y вверх цифра X «всегда сверху» садится прямо
;;; на вертикальную стрелку. Это и сломала v20, унифицировав SV с OL.
;;;
;;; Знаки sx и sy здесь — не «зависимость от квадранта», от которой мы уходили
;;; в v20, а единственный способ узнать, где лежит соседняя стрелка.
;;;
;;; Правило действовало до v20 и возвращено в v25 по фото Шамиля «до и как
;;; надо». Величины те же, что и раньше, но выражены через высоту текста,
;;; чтобы кнопка «Текст» масштабировала всё разом (это осталось от v21):
;;;   вдоль  = половина длины стрелки = *gc-pile-arrow-k* * h / 2
;;;   поперёк = высота текста         = h
;;; При h = 0.200 это даёт 0.200 и 0.200 — как в исходном чертеже.
;;; --------------------------------------------------------------------

(defun gc-pile-draw-xy-deviation (base-pt dir-dx-mm dir-dy-mm label-x-mm label-y-mm
                                  arrow-layer text-layer color /
                                  tstyle sx sy p-end-x p-end-y
                                  along lat pt-text-x pt-text-y)
  (gc-pile-ensure-layer arrow-layer color)
  (gc-pile-ensure-layer text-layer color)
  (setq tstyle (gc-pile-text-style))
  (setq sx (if (>= dir-dx-mm 0) 1.0 -1.0))
  (setq sy (if (>= dir-dy-mm 0) 1.0 -1.0))
  (setq p-end-x (list (+ (car base-pt) (* (gc-pile-arrow-len) sx))
                      (cadr base-pt)
                      (caddr base-pt)))
  (setq p-end-y (list (car base-pt)
                      (+ (cadr base-pt) (* (gc-pile-arrow-len) sy))
                      (caddr base-pt)))
  (gc-pile-draw-arrow base-pt p-end-x arrow-layer)
  (gc-pile-draw-arrow base-pt p-end-y arrow-layer)
  ;; См. блок «РАСПОЛОЖЕНИЕ ЦИФР У ПАРЫ СТРЕЛОК» выше.
  (setq along (/ (gc-pile-arrow-len) 2.0)
        lat   *gc-pile-text-h*)
  ;; Цифра X: вдоль стрелки X, поперёк — прочь от стрелки Y.
  (setq pt-text-x (list (+ (car  base-pt) (* sx along))
                        (- (cadr base-pt) (* sy lat))
                        (caddr base-pt)))
  ;; Цифра Y: вдоль стрелки Y, поперёк — прочь от стрелки X.
  (setq pt-text-y (list (- (car  base-pt) (* sx lat))
                        (+ (cadr base-pt) (* sy along))
                        (caddr base-pt)))
  ;; Повороты постоянные: цифра X читается по горизонтали, цифра Y — снизу
  ;; вверх. Вверх ногами ни одна не встаёт, поэтому нормализация угла,
  ;; нужная в OL для произвольного направления, здесь ни к чему.
  (gc-pile-draw-text-rot pt-text-x (gc-pile-mm-rounded label-x-mm)
                         tstyle text-layer 0.0)
  (gc-pile-draw-text-rot pt-text-y (gc-pile-mm-rounded label-y-mm)
                         tstyle text-layer (/ pi 2.0))
  T)

(defun gc-pile-draw-project-deviation (project-pt target-pt / dx-mm dy-mm p-base)
  (setq p-base (list (car project-pt) (cadr project-pt) (caddr target-pt)))
  (setq dx-mm (* 1000.0 (- (car target-pt)  (car project-pt)))
        dy-mm (* 1000.0 (- (cadr target-pt) (cadr project-pt))))
  (gc-pile-draw-xy-deviation p-base dx-mm dy-mm dx-mm dy-mm
                             *gc-l-project-arrows* *gc-l-project-text* 2)
  (princ (strcat "\nПроектное отклонение: dX = " (gc-pile-mm-signed dx-mm)
                 "   dY = " (gc-pile-mm-signed dy-mm)))
  T)

(defun gc-pile-draw-project-deviation-sv3 (project-pt target-pt / dx-mm dy-mm p-base)
  (setq p-base (list (car project-pt)
                     (+ (cadr project-pt) *gc-pile-sv3-prj-dev-dy*)
                     (caddr target-pt)))
  (setq dx-mm (* 1000.0 (- (car target-pt)  (car project-pt)))
        dy-mm (* 1000.0 (- (cadr target-pt) (cadr project-pt))))
  (gc-pile-draw-xy-deviation p-base dx-mm dy-mm dx-mm dy-mm
                             *gc-l-sv3-project-arrows*
                             *gc-l-sv3-project-text*
                             7)
  (princ (strcat "\nПроектное отклонение со сдвигом +Y 2600 мм: dX = "
                 (gc-pile-mm-signed dx-mm)
                 "   dY = " (gc-pile-mm-signed dy-mm)))
  T)

;;; ====================================================================
;;; ОБРАБОТКА СЕЧЕНИЙ
;;; ====================================================================

(defun gc-pile-section-data (low-pts high-pts tag / c-low c-high z-low z-high)
  (setq c-low  (gc-pile-best-circle low-pts))
  (setq c-high (gc-pile-best-circle high-pts))
  (cond
    ((null c-low)
     (princ (strcat "\n[ОШИБКА] " tag ": не удалось построить круг по нижним точкам."))
     nil)
    ((null c-high)
     (princ (strcat "\n[ОШИБКА] " tag ": не удалось построить круг по верхним точкам."))
     nil)
    (T
     (setq z-low  (gc-pile-avg (mapcar 'caddr low-pts))
           z-high (gc-pile-avg (mapcar 'caddr high-pts)))
     (list c-low c-high z-low z-high))))

(defun gc-pile-draw-sv-graphics (data arrow-layer text-layer color y-offset label /
                                  c-low c-high z-low z-high dx-mm dy-mm dz dx-pm dy-pm
                                  base-pt dev-low dev-high)
  (setq c-low  (nth 0 data)
        c-high (nth 1 data)
        z-low  (nth 2 data)
        z-high (nth 3 data))
  (gc-pile-ensure-layer *gc-l-low* 1)
  (gc-pile-ensure-layer *gc-l-high* 3)
  (gc-pile-draw-circle (car c-low)  (cadr c-low)  z-low  (caddr c-low)  *gc-l-low*)
  (gc-pile-draw-circle (car c-high) (cadr c-high) z-high (caddr c-high) *gc-l-high*)
  (setq dx-mm (* 1000.0 (- (car c-high)  (car c-low)))
        dy-mm (* 1000.0 (- (cadr c-high) (cadr c-low)))
        dz    (- z-high z-low))
  (if (> (abs dz) 1.0e-6)
    (setq dx-pm (/ dx-mm dz)
          dy-pm (/ dy-mm dz))
    (setq dx-pm dx-mm
          dy-pm dy-mm))
  (setq base-pt (list (car c-low) (+ (cadr c-low) y-offset) z-low))
  (gc-pile-draw-xy-deviation base-pt dx-mm dy-mm dx-pm dy-pm
                             arrow-layer text-layer color)
  (setq dev-low  (* 1000.0 (- (caddr c-low)  *gc-pile-r-norm*)))
  (setq dev-high (* 1000.0 (- (caddr c-high) *gc-pile-r-norm*)))
  (princ (strcat "\n--- " label ": свая обработана ---"))
  (princ (strcat "\nНиз:  ("
                 (rtos (car c-low) 2 3) ", "
                 (rtos (cadr c-low) 2 3) ", "
                 (rtos z-low 2 3) ")  R = "
                 (rtos (caddr c-low) 2 3)
                 " м (отклонение от нормы "
                 (gc-pile-mm-signed dev-low) ")"))
  (princ (strcat "\nВерх: ("
                 (rtos (car c-high) 2 3) ", "
                 (rtos (cadr c-high) 2 3) ", "
                 (rtos z-high 2 3) ")  R = "
                 (rtos (caddr c-high) 2 3)
                 " м (отклонение от нормы "
                 (gc-pile-mm-signed dev-high) ")"))
  (princ (strcat "\ndX = " (gc-pile-mm-signed dx-mm)
                 " (" (rtos (abs dx-pm) 2 0) " мм/1м)"
                 "   dY = " (gc-pile-mm-signed dy-mm)
                 " (" (rtos (abs dy-pm) 2 0) " мм/1м)"))
  (princ (strcat "\ndZ между сечениями = " (rtos dz 2 3) " м"))
  (if (> (abs y-offset) 1.0e-9)
    (princ (strcat "\n[i] Графика отклонений смещена по +Y на "
                   (rtos (* y-offset 1000.0) 2 0) " мм.")))
  (if (or (> (caddr c-low)  (+ *gc-pile-r-norm* *gc-pile-r-warn*))
          (< (caddr c-low)  (- *gc-pile-r-norm* *gc-pile-r-warn*))
          (> (caddr c-high) (+ *gc-pile-r-norm* *gc-pile-r-warn*))
          (< (caddr c-high) (- *gc-pile-r-norm* *gc-pile-r-warn*)))
    (princ "\n[!] Радиус сильно отличается от нормы — проверьте съёмку."))
  (if (or (> (abs dx-pm) *gc-pile-tol-mm-per-m*)
          (> (abs dy-pm) *gc-pile-tol-mm-per-m*))
    (princ (strcat "\n[!] Превышен допуск "
                   (rtos *gc-pile-tol-mm-per-m* 2 0) " мм/1м!")))
  (princ "\n----------------------")
  T)

(defun gc-pile-draw-target-cut (data target-z / c-low c-high z-low z-high dz k target-x target-y target-pt)
  (setq c-low  (nth 0 data)
        c-high (nth 1 data)
        z-low  (nth 2 data)
        z-high (nth 3 data)
        dz     (- z-high z-low))
  (if (<= (abs dz) 1.0e-6)
    (progn
      (princ "\n[ОШИБКА] SVP: dZ между сечениями слишком мал для расчета.")
      nil)
    (progn
      (setq k (/ (- target-z z-low) dz))
      (setq target-x (+ (car c-low) (* k (- (car c-high) (car c-low)))))
      (setq target-y (+ (cadr c-low) (* k (- (cadr c-high) (cadr c-low)))))
      (setq target-pt (list target-x target-y target-z))
      (gc-pile-ensure-layer *gc-l-cut* 4)
      (gc-pile-draw-circle target-x target-y target-z *gc-pile-r-norm* *gc-l-cut*)
      (princ "\n--- SVP: сечение построено ---")
      (princ (strcat "\nZ среза: " (rtos target-z 2 3) " м"
                     "  |  Центр: ("
                     (rtos target-x 2 3) ", "
                     (rtos target-y 2 3) ", "
                     (rtos target-z 2 3) ")"
                     "  |  R = " (rtos *gc-pile-r-norm* 2 3) " м"))
      (princ (strcat "\nОпорные Z: низ=" (rtos z-low 2 3)
                     " м, верх=" (rtos z-high 2 3)
                     " м, k=" (rtos k 2 3)))
      target-pt)))

(defun gc-pile-process (low-pts high-pts / data)
  (setq data (gc-pile-section-data low-pts high-pts "SV"))
  (if data
    (gc-pile-draw-sv-graphics data *gc-l-arrows* *gc-l-text* 7 0.0 "SV")
    nil))

(defun gc-pile-process-extension (low-pts high-pts target-z / data)
  (setq data (gc-pile-section-data low-pts high-pts "SVP"))
  (if data
    (gc-pile-draw-target-cut data target-z)
    nil))

(defun gc-pile-process-sv3 (low-pts high-pts target-z / data target-pt)
  (setq data (gc-pile-section-data low-pts high-pts "SV 3"))
  (if data
    (progn
      (gc-pile-draw-sv-graphics data
                                *gc-l-sv3-arrows*
                                *gc-l-sv3-text*
                                5
                                *gc-pile-sv3-sv-dev-dy*
                                "SV 3 / SV")
      (setq target-pt (gc-pile-draw-target-cut data target-z))
      target-pt)
    nil))

;;; ====================================================================
;;; ПОДГОТОВКА ПАР СЕЧЕНИЙ
;;; ====================================================================

(defun gc-pile-pair-from-cluster (pile-pts / z-groups valid-secs zg clean-zg
                                   circ z-mean sorted-secs lo hi dz z-list)
  (cond
    ((< (length pile-pts) 6) nil)
    (T
     (setq z-groups (gc-pile-cluster-by-z pile-pts))
     (setq valid-secs '())
     (foreach zg z-groups
       (setq clean-zg (gc-pile-strip-hm zg))
       (if (>= (length clean-zg) 3)
         (progn
           (setq circ (gc-pile-best-circle clean-zg))
           (if circ
             (progn
               (setq z-mean (gc-pile-avg (mapcar 'caddr clean-zg)))
               (setq valid-secs (cons (cons z-mean clean-zg) valid-secs)))))))
     (cond
       ((< (length valid-secs) 2)
        (setq z-list (apply 'strcat
                       (mapcar '(lambda (p) (strcat (rtos (caddr p) 2 3) " "))
                               pile-pts)))
        (princ (strcat "\n[!] Свая X~" (rtos (caar pile-pts) 2 1)
                       " Y~" (rtos (cadar pile-pts) 2 1)
                       ": сечений найдено " (itoa (length valid-secs))
                       " (нужно >=2) — пропуск."
                       "\n    Z всех точек: " z-list))
        nil)
       (T
        (setq sorted-secs
              (vl-sort valid-secs '(lambda (a b) (< (car a) (car b)))))
        (setq lo (car sorted-secs)
              hi (last sorted-secs))
        (setq dz (- (car hi) (car lo)))
        (cond
          ((< dz *gc-pile-pair-dz-min*)
           (princ (strcat "\n[!] Свая X~" (rtos (caar pile-pts) 2 1)
                          ": dZ=" (rtos dz 2 3) " м < "
                          (rtos *gc-pile-pair-dz-min* 2 2) " м — пропуск."))
           nil)
          (T (cons (cdr lo) (cdr hi)))))))))

(defun gc-pile-mode1 ( / ss pts n xy-clusters pairs pile-pts pair)
  (princ "\nВыделите точки свай (рамкой). Не-точки игнорируются: ")
  (setq ss (ssget *gc-pile-ssget-filter*))
  (cond
    ((null ss)
     (princ "\n[ОШИБКА] Точки не выбраны.")
     nil)
    (T
     (setq pts (gc-pile-ss-to-points ss))
     (setq n (length pts))
     (cond
       ((< n 6)
        (princ (strcat "\n[ОШИБКА] Нужно минимум 6 точек (2 сечения x 3). Найдено: "
                       (itoa n)))
        nil)
       (T
        (princ (strcat "\n[i] Точек выбрано: " (itoa n)
                       "  |  Диаметр сваи: "
                       (rtos (* 2.0 *gc-pile-r-norm* 1000.0) 2 0) " мм"
                       "  |  Z: "
                       (rtos (apply 'min (mapcar 'caddr pts)) 2 3)
                       " — "
                       (rtos (apply 'max (mapcar 'caddr pts)) 2 3) " м"))
        (setq xy-clusters (gc-pile-cluster-by-xy pts))
        (princ (strcat "\n[i] Выявлено XY-кластеров (свай): "
                       (itoa (length xy-clusters))))
        (setq pairs '())
        (foreach pile-pts xy-clusters
          (setq pair (gc-pile-pair-from-cluster pile-pts))
          (if pair (setq pairs (cons pair pairs))))
        (cond
          ((null pairs)
           (princ "\n[ОШИБКА] Ни одной сваи не удалось сформировать.")
           nil)
          (T
           (princ (strcat "\n[i] Свай для обработки: " (itoa (length pairs))))
           (reverse pairs))))))))

(defun gc-pile-mode2 ( / ss-low ss-high low-pts high-pts)
  (princ "\nВыделите точки нижнего сечения: ")
  (setq ss-low (ssget *gc-pile-ssget-filter*))
  (cond
    ((null ss-low)
     (princ "\n[ОШИБКА] Нижнее сечение не выбрано.")
     nil)
    (T
     (princ "\nВыделите точки верхнего сечения: ")
     (setq ss-high (ssget *gc-pile-ssget-filter*))
     (cond
       ((null ss-high)
        (princ "\n[ОШИБКА] Верхнее сечение не выбрано.")
        nil)
       (T
        (setq low-pts  (gc-pile-ss-to-points ss-low))
        (setq high-pts (gc-pile-ss-to-points ss-high))
        (cond
          ((< (length low-pts) 3)
           (princ "\n[ОШИБКА] В нижнем сечении меньше 3 валидных точек.")
           nil)
          ((< (length high-pts) 3)
           (princ "\n[ОШИБКА] В верхнем сечении меньше 3 валидных точек.")
           nil)
          (T (list low-pts high-pts))))))))

;;; ====================================================================
;;; ОБЩИЙ РАННЕР SVP / SV 3
;;; ====================================================================

(defun gc-pile-run-project-match (target-pt project-centers draw-mode /
                                  match project-pt match-dist)
  (setq match (gc-pile-take-nearest-project
                target-pt
                project-centers
                *gc-pile-project-match-max*))
  (setq project-pt (car match)
        project-centers (cadr match)
        match-dist (caddr match))
  (if project-pt
    (progn
      (princ (strcat "\n[i] Проектный центр: расстояние до среза "
                     (rtos match-dist 2 3) " м"))
      (if (member draw-mode '("SV3" "SV4"))
        (gc-pile-draw-project-deviation-sv3 project-pt target-pt)
        (gc-pile-draw-project-deviation project-pt target-pt))
      (list project-centers 1 0))
    (progn
      (if match-dist
        (princ (strcat "\n[!] SVP: ближайший проектный центр дальше "
                       (rtos *gc-pile-project-match-max* 2 3)
                       " м (расстояние " (rtos match-dist 2 3)
                       " м) — проектное отклонение пропущено."))
        (princ "\n[!] SVP: проектный центр не найден — проектное отклонение пропущено."))
      (list project-centers 0 1))))

(defun gc-pile-run-svp-core (pairs target-z project-centers draw-mode / project-mode
                             total idx ok skipped dev-ok dev-skipped p target-pt res)
  (setq project-mode (not (null project-centers)))
  (setq total (length pairs) idx 1 ok 0 skipped 0 dev-ok 0 dev-skipped 0)
  (foreach p pairs
    (princ (strcat "\n=== " draw-mode ": Свая " (itoa idx) " / " (itoa total) " ==="))
    (setq target-pt
      (cond
        ((= draw-mode "SV3") (gc-pile-process-sv3 (car p) (cdr p) target-z))
        ((= draw-mode "SV4") (gc-pile-process-sv4 (car p) (cdr p) target-z))
        (T (gc-pile-process-extension (car p) (cdr p) target-z))))
    (if target-pt
      (progn
        (setq ok (1+ ok))
        (if project-mode
          (cond
            ((null project-centers)
             (setq dev-skipped (1+ dev-skipped))
             (princ "\n[!] Нет свободного проектного центра — проектное отклонение пропущено."))
            (T
             (setq res (gc-pile-run-project-match target-pt project-centers draw-mode))
             (setq project-centers (car res))
             (setq dev-ok (+ dev-ok (cadr res)))
             (setq dev-skipped (+ dev-skipped (caddr res)))))))
      (setq skipped (1+ skipped)))
    (setq idx (1+ idx)))
  (princ (strcat "\n[Итог " draw-mode "] построено сечений: " (itoa ok)
                 "  пропущено сечений: " (itoa skipped)
                 "  всего свай: " (itoa total)))
  (if project-mode
    (princ (strcat "\n[Итог " draw-mode "] проектных отклонений: " (itoa dev-ok)
                   "  пропущено отклонений: " (itoa dev-skipped)))
    (princ (strcat "\n[Итог " draw-mode "] проектные отклонения не строились: проектные объекты не выбраны.")))
  T)

(defun gc-pile-run-sv3 ( / pairs target-z project-centers)
  (princ "\nSV 3: SV 1 + SVP за один запуск.")
  (setq pairs (gc-pile-mode1))
  (cond
    ((null pairs)
     (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z для среза, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq project-centers (gc-pile-read-project-centers))
        (gc-pile-run-svp-core pairs target-z project-centers "SV3"))))))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

;;; ====================================================================
;;; ВЫСОТА ТЕКСТА — кнопка [Текст]
;;; ====================================================================

;; Обрезка пробелов по краям без vl-string-trim — чтобы не зависеть от того,
;; как конкретная сборка обрабатывает не-ASCII.
(defun gc-pile-trim (s / )
  (while (and (> (strlen s) 0) (= (substr s 1 1) " "))
    (setq s (substr s 2)))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) " "))
    (setq s (substr s 1 (1- (strlen s)))))
  s)

;; Запятая и точка равнозначны, пробелы игнорируются.
;; ПОЧЕМУ свой парсер, а не getreal: getreal не принимает запятую, а Шамиль
;; вводит размеры именно через запятую.
(defun gc-pile-parse-size (s / n i ch bad seps digits norm val)
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

(defun gc-pile-fmt (m)
  (vl-string-subst "," "." (rtos m 2 3)))

(defun gc-pile-set-text-h ( / res s val)
  (princ "\n\n--- ВЫСОТА ТЕКСТА ---")
  (princ "\nВысота цифры в метрах чертежа. От неё считается вся графика:")
  (princ "\n  длина стрелки = 2 x высота, наконечник = 0.4 x высота,")
  (princ "\n  смещение цифры от стрелки = 1 x высота.")
  (princ "\nЗначение общее для SV и SVP.")
  (setq res nil)
  (while (null res)
    ;; getstring с флагом T — иначе ввод обрывается на пробеле и "0, 200"
    ;; молча превратилось бы в "0," = 0 м.
    (setq s (gc-pile-trim
              (getstring T (strcat "\nВысота текста, м <"
                                   (gc-pile-fmt *gc-pile-text-h*) ">: "))))
    (cond
      ((= s "") (setq res *gc-pile-text-h*))
      (T
       (setq val (gc-pile-parse-size s))
       (if val
         (setq res val)
         (princ (strcat "\n[!] Не понял \"" s "\". Нужно число вида 0,200"))))))
  (setq *gc-pile-text-h* res)
  (princ (strcat "\n[i] Высота текста " (gc-pile-fmt *gc-pile-text-h*)
                 " м, длина стрелки " (gc-pile-fmt (gc-pile-arrow-len)) " м"))
  *gc-pile-text-h*)

;;; SV 4: горизонтальные сечения наклонного цилиндра (SPEC-010).
;;; Наклон 1:4.5 подтвержден: 1 м в плане на 4.5 м по высоте.
(setq *gc-pile-sv4-slope* (/ 1.0 4.5))
(setq *gc-pile-sv4-rms-warn* 0.010)

;; Повторно выбранная точка не должна менять вес измерения.
(defun gc-pile-e-unique (pts / out p found other)
  (setq out nil)
  (foreach p pts
    (setq found nil)
    (foreach other out
      (if (equal p other 1.0e-8) (setq found T)))
    (if (not found) (setq out (cons p out))))
  (reverse out))

;; Все вычисления около среднего, а не на геодезических миллионных XY.
;; После сжатия вдоль большой оси эллипс становится окружностью.
;; Результат: (cx cy малая-полуось большая-полуось угол Z radial-RMS).
(defun gc-pile-e-fit (pts ang / co si ratio mx my mz uv p dx dy u v
                         mu mv xx yy xy xr yr rr det cx cy rad sum n)
  (setq n (float (length pts))
        co (cos ang) si (sin ang)
        ratio (sqrt (+ 1.0 (* *gc-pile-sv4-slope* *gc-pile-sv4-slope*)))
        mx (gc-pile-avg (mapcar 'car pts))
        my (gc-pile-avg (mapcar 'cadr pts))
        mz (gc-pile-avg (mapcar 'caddr pts))
        uv nil)
  (foreach p pts
    (setq dx (- (car p) mx) dy (- (cadr p) my))
    ;; Точки сняты на чуть разных Z: приводим их к средней плоскости.
    (setq u (/ (- (+ (* co dx) (* si dy))
                    (* *gc-pile-sv4-slope* (- (caddr p) mz))) ratio)
          v (+ (* (- si) dx) (* co dy)))
    (setq uv (cons (list u v) uv)))
  (setq mu (gc-pile-avg (mapcar 'car uv))
        mv (gc-pile-avg (mapcar 'cadr uv))
        xx 0.0 yy 0.0 xy 0.0 xr 0.0 yr 0.0 rr 0.0)
  (foreach p uv
    (setq u (- (car p) mu) v (- (cadr p) mv)
          rad (+ (* u u) (* v v))
          xx (+ xx (* u u)) yy (+ yy (* v v)) xy (+ xy (* u v))
          xr (+ xr (* u rad)) yr (+ yr (* v rad)) rr (+ rr rad)))
  (setq det (- (* xx yy) (* xy xy)))
  (if (or (< (+ xx yy) 1.0e-10)
          (<= det (* 1.0e-7 (+ xx yy) (+ xx yy))))
    nil
    (progn
      (setq cx (/ (- (* xr yy) (* yr xy)) (* 2.0 det))
            cy (/ (- (* yr xx) (* xr xy)) (* 2.0 det)))
      (setq rad (sqrt (+ (/ rr n) (* cx cx) (* cy cy)))
            cx (+ cx mu) cy (+ cy mv) sum 0.0)
      (foreach p uv
        (setq u (- (car p) cx) v (- (cadr p) cy)
              rr (sqrt (+ (* u u) (* v v))))
        ;; Радиальная невязка в исходной плоскости, в метрах.
        (if (> rr 1.0e-12)
          (setq sum (+ sum (* (- rr rad) (- rr rad)
                              (/ (+ (* ratio ratio u u) (* v v)) (* rr rr)))))
          (setq sum (+ sum (* rad rad)))))
      (list (+ mx (* co ratio cx) (* (- si) cy))
            (+ my (* si ratio cx) (* co cy))
            rad (* ratio rad) ang mz (sqrt (/ sum n))))))

;; Поперечный сдвиг центров штрафуется: большая ось направлена вдоль сваи.
;; Обратное направление тоже штрафуется, поскольку поправка за Z имеет знак.
(defun gc-pile-e-candidate (lo hi ang / el eh dx dy dz cross along score)
  (setq el (gc-pile-e-fit lo ang) eh (gc-pile-e-fit hi ang))
  (if (and el eh)
    (progn
      (setq dx (- (car eh) (car el)) dy (- (cadr eh) (cadr el))
            dz (- (nth 5 eh) (nth 5 el))
            cross (/ (- (* (cos ang) dy) (* (sin ang) dx)) dz)
            along (min 0.0 (/ (+ (* (cos ang) dx) (* (sin ang) dy)) dz)))
      (setq score (+ (expt (nth 6 el) 2) (expt (nth 6 eh) 2)
                     (expt (- (nth 2 el) *gc-pile-r-norm*) 2)
                     (expt (- (nth 2 eh) *gc-pile-r-norm*) 2)
                     (* *gc-pile-r-norm* *gc-pile-r-norm*
                        (+ (* cross cross) (* along along)))))
      (list score ang el eh))
    nil))

(defun gc-pile-e-sections-ok (lo hi / zlo zhi)
  (cond
    ((or (< (length lo) 3) (< (length hi) 3))
     (princ "\n[!] SV 4: нужно минимум 3 различные точки в каждом сечении.") nil)
    (T
     (setq zlo (mapcar 'caddr lo) zhi (mapcar 'caddr hi))
     (cond
       ((or (> (- (apply 'max zlo) (apply 'min zlo)) *gc-pile-z-cluster*)
            (> (- (apply 'max zhi) (apply 'min zhi)) *gc-pile-z-cluster*))
        (princ "\n[!] SV 4: разброс Z в сечении больше 50 мм. Разделите сечения.") nil)
       ((< (- (gc-pile-avg zhi) (gc-pile-avg zlo)) *gc-pile-pair-dz-min*)
        (princ "\n[!] SV 4: верх должен быть выше низа минимум на 0,300 м.") nil)
       (T T)))))

(defun gc-pile-e-best (low-pts high-pts / lo hi best cand ang step idx base)
  (setq lo (gc-pile-e-unique low-pts) hi (gc-pile-e-unique high-pts))
  (if (gc-pile-e-sections-ok lo hi)
    (progn
      (setq best nil step (/ pi 36.0) idx 0)
      ;; Полный оборот нужен из-за знака высотной поправки.
      (repeat 72
        (setq ang (* idx step) cand (gc-pile-e-candidate lo hi ang))
        (if (and cand (or (null best) (< (car cand) (car best))))
          (setq best cand))
        (setq idx (1+ idx)))
      (if best
        (progn
          (repeat 4
            (setq base (cadr best) step (/ step 5.0) idx -5)
            (repeat 11
              (setq ang (+ base (* idx step)) cand (gc-pile-e-candidate lo hi ang))
              (if (and cand (< (car cand) (car best))) (setq best cand))
              (setq idx (1+ idx))))
          (list (nth 2 best) (nth 3 best)))
        (progn
          (princ "\n[!] SV 4: точки совпадают, лежат на прямой или дуга слишком узкая.")
          nil)))
    nil))

(defun gc-pile-draw-ellipse (e layer / a ang)
  (setq a (nth 3 e) ang (nth 4 e))
  (gc-pile-emake
    (list '(0 . "ELLIPSE") '(100 . "AcDbEntity") (cons 8 layer)
          '(100 . "AcDbEllipse")
          (cons 10 (list (car e) (cadr e) (nth 5 e)))
          (cons 11 (list (* a (cos ang)) (* a (sin ang)) 0.0))
          '(210 0.0 0.0 1.0) (cons 40 (/ (nth 2 e) a))
          '(41 . 0.0) (cons 42 (* 2.0 pi))) "эллипс"))

(defun gc-pile-e-report (e name)
  (princ (strcat "\n" name ": центр (" (rtos (car e) 2 3) ", "
    (rtos (cadr e) 2 3) ", " (rtos (nth 5 e) 2 3) ")"
    "; малая полуось = " (rtos (nth 2 e) 2 6)
    " м; большая = " (rtos (nth 3 e) 2 6)
    " м; невязка = " (rtos (* 1000.0 (nth 6 e)) 2 1) " мм"))
  (if (or (> (nth 6 e) *gc-pile-sv4-rms-warn*)
          (> (abs (- (nth 2 e) *gc-pile-r-norm*)) *gc-pile-r-warn*))
    (princ "\n[!] Сечение плохо согласуется с диаметром/точками. Проверьте выбор и съемку.")))

;; Продление центра - как в SV 3. Размер среза номинальный, направление
;; большой оси общее с найденными сечениями (SPEC-010).
(defun gc-pile-e-cut-data (data target-z / el eh dz k radius ratio)
  (setq el (car data) eh (cadr data) dz (- (nth 5 eh) (nth 5 el)))
  (if (<= (abs dz) 1.0e-6)
    (progn (princ "\n[ОШИБКА] SV 4: dZ слишком мал для расчета среза.") nil)
    (progn
      (setq k (/ (- target-z (nth 5 el)) dz)
            radius *gc-pile-r-norm*
            ratio (sqrt (+ 1.0 (* *gc-pile-sv4-slope* *gc-pile-sv4-slope*))))
      (list (+ (car el) (* k (- (car eh) (car el))))
            (+ (cadr el) (* k (- (cadr eh) (cadr el))))
            radius (* radius ratio) (nth 4 el) target-z 0.0))))

(defun gc-pile-e-draw-cut (data target-z / cut target-pt)
  (setq cut (gc-pile-e-cut-data data target-z))
  (if cut
    (progn
      (gc-pile-ensure-layer *gc-l-cut* 4)
      (if (gc-pile-draw-ellipse cut *gc-l-cut*)
        (progn
          (setq target-pt (list (car cut) (cadr cut) target-z))
          (princ (strcat "\n--- SV 4: эллипс на отметке среза построен ---"
                         "\nZ среза: " (rtos target-z 2 3) " м | Центр: ("
                         (rtos (car cut) 2 3) ", " (rtos (cadr cut) 2 3) ")"
                         "\nПолуоси среза: " (rtos (nth 2 cut) 2 6) " / "
                         (rtos (nth 3 cut) 2 6) " м"))
          target-pt)
        nil))
    nil))


;;; СХЕМА УГЛА НА 1 М (SV 4). Геометрия и выбор компоненты - в МСК.
(setq *gc-l-sv4-angle* "GC-Сваи-SV4-Угол")
(setq *gc-pile-angle-style* "GC-SV4-Angle")

;; Близость сравнивается с 222, как запросил Шамиль. Сам угол считаем
;; по неокругленному значению, а не по целому числу на синей подписи.
(defun gc-pile-e-angle-values (dx-mm dy-mm dz / x y axis chosen)
  (if (<= (abs dz) 1.0e-6)
    nil
    (progn
      (setq x (/ dx-mm dz) y (/ dy-mm dz))
      (if (<= (abs (- (abs x) 222.0)) (abs (- (abs y) 222.0)))
        (setq axis "X" chosen x)
        (setq axis "Y" chosen y))
      (list axis chosen (atan (/ (abs chosen) 1000.0))))))

;; Через общее число минут: округление 59.5 минут переносит градус.
;; Это формат отчета/нулевого случая. DIMENSION показывает свое измерение.
(defun gc-pile-e-angle-format (rad / total deg mins)
  (setq total (fix (+ 0.5 (* (abs rad) (/ 10800.0 pi))))
        deg (fix (/ total 60.0)) mins (- total (* deg 60)))
  (strcat (itoa deg) "°" (if (< mins 10) "0" "") (itoa mins) "'"))

;; Возвращает (ось мм/м угол A B C точка-дуги точка-текста).
;; Размер вертикали не масштабируется высотой текста: это всегда 1 метр.
(defun gc-pile-e-angle-layout (data target-z / el eh cut vals right h ox oy z run ang)
  (setq el (car data) eh (cadr data)
        cut (gc-pile-e-cut-data data target-z)
        vals (gc-pile-e-angle-values
               (* 1000.0 (- (car eh) (car el)))
               (* 1000.0 (- (cadr eh) (cadr el)))
               (- (nth 5 eh) (nth 5 el))))
  (if (and cut vals)
    (progn
      (setq h *gc-pile-text-h*
            right (max (+ (car el) (nth 3 el))
                       (+ (car eh) (nth 3 eh)) (+ (car cut) (nth 3 cut)))
            ox (+ right (max 0.5 (* 2.0 h)))
            oy (+ (cadr el) *gc-pile-sv3-sv-dev-dy*) z (nth 5 el)
            run (/ (abs (cadr vals)) 1000.0) ang (caddr vals))
      (append vals
        (list (list ox oy z) (list ox (+ oy 1.0) z)
              (list (+ ox run) (+ oy 1.0) z)
              (list (+ ox (* 0.8 (sin (/ ang 2.0))))
                    (+ oy (* 0.8 (cos (/ ang 2.0)))) z)
              (list (+ ox run (max 0.8 (* 4.0 h))) (+ oy 0.65) z))))
    nil))

;; Собственный неаннотативный стиль: текущие DIMSTYLE/DIMSCALE не меняем.
;; Проверяем таблицу после entmake, чтобы размер не ссылался на пустое имя.
(defun gc-pile-e-angle-ensure-style (tstyle / name)
  (setq name *gc-pile-angle-style*)
  (if (null (tblsearch "DIMSTYLE" name))
    (gc-pile-emake
      (list '(0 . "DIMSTYLE") '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbDimStyleTableRecord") (cons 2 name) '(70 . 0)
            '(40 . 1.0) '(41 . 0.1) '(140 . 0.2)
            '(275 . 1) '(179 . 2) '(79 . 0)
            '(73 . 1) '(74 . 1) '(77 . 0) '(279 . 1)
            '(289 . 0) '(174 . 0) '(172 . 0)
            '(75 . 1) '(76 . 1) '(142 . 0.0)
            (cons 340 (tblobjname "STYLE" tstyle))) "размерный стиль угла"))
  (if (tblsearch "DIMSTYLE" name) name nil))

;; Размерные настройки задаются на самом объекте: следующий запуск с
;; другой высотой текста не меняет ранее построенные схемы.
(defun gc-pile-e-angle-dxf (info text-handle / h overrides)
  (setq h *gc-pile-text-h*)
  (setq overrides
    (list "ACAD" '(1000 . "DSTYLE") '(1002 . "{")
          '(1070 . 40) '(1040 . 1.0)
          '(1070 . 140) (cons 1040 h)
          '(1070 . 41) (cons 1040 (* 0.5 h))
          '(1070 . 147) (cons 1040 (* 0.25 h))
          '(1070 . 340) (cons 1005 text-handle)
          '(1070 . 275) '(1070 . 1)    ; DMS
          '(1070 . 179) '(1070 . 2)    ; до целой минуты
          '(1070 . 79) '(1070 . 0)     ; не скрывать нулевые минуты
          '(1070 . 73) '(1070 . 1) '(1070 . 74) '(1070 . 1)
          '(1070 . 77) '(1070 . 0) '(1070 . 279) '(1070 . 1)
          '(1070 . 289) '(1070 . 0) '(1070 . 174) '(1070 . 0)
          '(1070 . 172) '(1070 . 0) '(1070 . 175) '(1070 . 0)
          '(1070 . 75) '(1070 . 1) '(1070 . 76) '(1070 . 1)
          '(1070 . 281) '(1070 . 0) '(1070 . 282) '(1070 . 0)
          '(1070 . 142) '(1040 . 0.0)
          '(1070 . 176) '(1070 . 256) '(1070 . 177) '(1070 . 256)
          '(1070 . 178) '(1070 . 256)
          '(1002 . "}")))
  (list '(0 . "DIMENSION") '(100 . "AcDbEntity")
        (cons 8 *gc-l-sv4-angle*) '(100 . "AcDbDimension")
        (cons 10 (nth 6 info)) (cons 11 (nth 7 info))
        '(70 . 165) '(71 . 5) '(1 . "<>")
        (cons 3 *gc-pile-angle-style*) '(210 0.0 0.0 1.0)
        '(100 . "AcDb3PointAngularDimension")
        (cons 13 (nth 4 info)) (cons 14 (nth 5 info)) (cons 15 (nth 3 info))
        (list -3 overrides)))

(defun gc-pile-e-angle-draw (data target-z / info origin top tip tstyle handle ok)
  (setq info (gc-pile-e-angle-layout data target-z))
  (if info
    (progn
      (setq origin (nth 3 info) top (nth 4 info) tip (nth 5 info)
            tstyle (gc-pile-text-style))
      (gc-pile-ensure-layer *gc-l-sv4-angle* 7)
      (princ (strcat "\nУгол на 1 м: выбрана " (car info) " = "
                     (rtos (cadr info) 2 3) " мм/м; угол "
                     (gc-pile-e-angle-format (caddr info))))
      (if (< (abs (cadr info)) 1.0e-9)
        ;; У нулевого угла лучи совпадают: не создаем ложный малый угол.
        (setq ok
          (and (gc-pile-emake
                 (list '(0 . "LINE") (cons 8 *gc-l-sv4-angle*)
                       (cons 10 origin) (cons 11 top)) "вертикаль 1 м")
               (gc-pile-draw-text-rot (nth 7 info) "0°00'"
                                      tstyle *gc-l-sv4-angle* 0.0)))
        (progn
          (setq handle (cdr (assoc 5 (entget (tblobjname "STYLE" tstyle)))))
          (if (and handle (gc-pile-e-angle-ensure-style tstyle))
            (setq ok
              (and (gc-pile-emake
                     (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
                           (cons 8 *gc-l-sv4-angle*) '(100 . "AcDbPolyline")
                           '(90 . 3) '(70 . 1) (cons 38 (caddr origin))
                           (cons 10 (list (car origin) (cadr origin)))
                           (cons 10 (list (car top) (cadr top)))
                           (cons 10 (list (car tip) (cadr tip)))) "треугольник наклона")
                   (gc-pile-emake (gc-pile-e-angle-dxf info handle) "угловой размер")))
            (setq ok nil))))
      (if (null ok) (princ "\n[!] SV 4: угловая схема не построена полностью."))
      ok)
    nil))

(defun gc-pile-process-sv4 (lo hi target-z / data el eh dx dy dz slope base target-pt)
  (setq data (gc-pile-e-best lo hi))
  (if data
    (progn
      (setq el (car data) eh (cadr data)
            dx (* 1000.0 (- (car eh) (car el)))
            dy (* 1000.0 (- (cadr eh) (cadr el)))
            dz (- (nth 5 eh) (nth 5 el))
            slope (/ (sqrt (+ (* dx dx) (* dy dy))) dz)
            base (list (car el) (+ (cadr el) *gc-pile-sv3-sv-dev-dy*) (nth 5 el)))
      (gc-pile-ensure-layer *gc-l-low* 1)
      (gc-pile-ensure-layer *gc-l-high* 3)
      (if (and (gc-pile-draw-ellipse el *gc-l-low*)
               (gc-pile-draw-ellipse eh *gc-l-high*))
        (progn
          (gc-pile-draw-xy-deviation base dx dy (/ dx dz) (/ dy dz)
                                    *gc-l-sv3-arrows* *gc-l-sv3-text* 5)
          (gc-pile-e-report el "Низ")
          (gc-pile-e-report eh "Верх")
          (princ (strcat "\ndX = " (gc-pile-mm-signed dx)
                         "; dY = " (gc-pile-mm-signed dy)
                         "; dZ = " (rtos dz 2 3) " м"
                         "\nСмещение центров: " (rtos slope 2 1)
                         " мм/м; номинал 222,2 мм/м. Синие подписи: мм/м по X и Y."
                         "\nСиние отклонения смещены по +Y на 1700 мм, как в SV 3."))
          (setq target-pt (gc-pile-e-draw-cut data target-z))
          (if target-pt (gc-pile-e-angle-draw data target-z))
          target-pt)
        nil))
    nil))


;; Для SV 4 группировка не перебирает тройки окружностей: при большом
;; количестве точек это лишняя кубическая работа до подбора эллипсов.
(defun gc-pile-e-auto ( / ss pts clusters cluster groups group clean secs pairs)
  (princ "\nВыделите точки свай (рамкой). Не-точки игнорируются: ")
  (setq ss (ssget *gc-pile-ssget-filter*) pairs nil)
  (if ss
    (progn
      (setq pts (gc-pile-ss-to-points ss)
            clusters (gc-pile-cluster-by-xy pts))
      (foreach cluster clusters
        (setq groups (gc-pile-cluster-by-z cluster) secs nil)
        (foreach group groups
          (setq clean (gc-pile-e-unique (gc-pile-strip-hm group)))
          (if (>= (length clean) 3) (setq secs (cons clean secs))))
        ;; Группы пришли по возрастанию Z, cons развернул порядок.
        (if (>= (length secs) 2)
          (setq pairs (cons (cons (last secs) (car secs)) pairs))
          (princ "\n[!] SV 4: в XY-группе меньше двух сечений по 3 точки. Проверьте выбор сечений.")))
      (if (null pairs) (princ "\n[!] SV 4: пар сечений не найдено.")))
    (princ "\nSV 4: точки не выбраны."))
  (reverse pairs))

(defun gc-pile-run-sv4 ( / pairs target-z project-centers)
  (princ "\nSV 4: эллипсы наклонной сваи + срез + проектные отклонения.")
  (princ "\nНаклон: 1 м в плане на 4,5 м высоты. Полуоси среза: 0,710000 / 0,727320 м.")
  (setq pairs (gc-pile-e-auto))
  (cond
    ((null pairs)
     (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z для среза, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq project-centers (gc-pile-read-project-centers))
        (gc-pile-run-svp-core pairs target-z project-centers "SV4"))))))


(defun c:sv ( / *error* mode-str pairs g idx total ok skipped p)
  ;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
  ;; обработчик, даже если нажали Esc посреди ввода.
  ;; Отмена это не ошибка. На локализованном AutoCAD выход по Esc приходит
  ;; сообщением «Функция прервана.», поэтому кроме английских BREAK/CANCEL/
  ;; QUIT проверяем русские слова — и БЕЗ strcase: полагаться на то, что он
  ;; верно поднимет регистр кириллицы в любой сборке, не стоит.
  (defun *error* (msg)
    (if (or (null msg)
            (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")
            (wcmatch msg "*прерван*,*Прерван*,*ПРЕРВАН*,*отмен*,*Отмен*,*ОТМЕН*"))
      (princ "\n[ОТМЕНА] SV прерван.")
      (princ (strcat "\n[ОШИБКА] SV: " msg)))
    (princ))
  (princ "\n  1 = все точки сразу (автоопределение свай)")
  (princ "\n  2 = по группам вручную (нижнее/верхнее сечение)")
  (princ "\n  3 = все сразу: SV 1 + SVP")
  (princ "\n  4 = наклонные сваи: эллипсы + срез + проектные отклонения")
  ;; Ключевое слово продублировано одной буквой: для кириллицы AutoCAD
  ;; не распознаёт заглавную букву как сокращение и требует слово целиком.
  ;; Цикл — чтобы после смены высоты снова спросить режим.
  (setq mode-str nil)
  (while (null mode-str)
    (princ (strcat "\n  Высота текста: " (gc-pile-fmt *gc-pile-text-h*)
                   " м  |  длина стрелки: " (gc-pile-fmt (gc-pile-arrow-len)) " м"))
    (initget "1 2 3 4 Текст Т")
    (setq mode-str (getkword "\nРежим [1/2/3/4/Текст] <1>: "))
    (if (null mode-str) (setq mode-str "1"))
    (if (member mode-str '("Текст" "Т"))
      (progn (gc-pile-set-text-h) (setq mode-str nil))))
  (princ (strcat "\nРежим: " mode-str))
  (cond
    ((= mode-str "4")
     (gc-pile-run-sv4))
    ((= mode-str "3")
     (gc-pile-run-sv3))
    (T
     (cond
       ((= mode-str "1")
        (setq pairs (gc-pile-mode1)))
       (T
        (setq g (gc-pile-mode2))
        (if g
          (setq pairs (list (cons (car g) (cadr g))))
          (setq pairs nil))))
     (cond
       ((null pairs)
        (princ "\nКоманда отменена."))
       (T
        (setq total (length pairs) idx 1 ok 0 skipped 0)
        (foreach p pairs
          (princ (strcat "\n=== Свая " (itoa idx) " / " (itoa total) " ==="))
          (if (gc-pile-process (car p) (cdr p))
            (setq ok (1+ ok))
            (setq skipped (1+ skipped)))
          (setq idx (1+ idx)))
        (princ (strcat "\n[Итог] обработано: " (itoa ok)
                       "  пропущено: " (itoa skipped)
                       "  всего: " (itoa total)))))))
  (princ))

(defun c:svp ( / *error* pairs target-z project-centers)
  ;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
  ;; обработчик, даже если нажали Esc посреди ввода.
  ;; Отмена это не ошибка. На локализованном AutoCAD выход по Esc приходит
  ;; сообщением «Функция прервана.», поэтому кроме английских BREAK/CANCEL/
  ;; QUIT проверяем русские слова — и БЕЗ strcase: полагаться на то, что он
  ;; верно поднимет регистр кириллицы в любой сборке, не стоит.
  (defun *error* (msg)
    (if (or (null msg)
            (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")
            (wcmatch msg "*прерван*,*Прерван*,*ПРЕРВАН*,*отмен*,*Отмен*,*ОТМЕН*"))
      (princ "\n[ОТМЕНА] SVP прерван.")
      (princ (strcat "\n[ОШИБКА] SVP: " msg)))
    (princ))
  (princ "\nSVP: сечение сваи на заданной отметке + проектное отклонение.")
  (setq pairs (gc-pile-mode1))
  (cond
    ((null pairs)
     (princ "\nКоманда отменена."))
    (T
     (setq target-z (getreal "\nВведите целевую отметку Z, м: "))
     (cond
       ((null target-z)
        (princ "\nКоманда отменена: отметка не введена."))
       (T
        (setq project-centers (gc-pile-read-project-centers))
        (gc-pile-run-svp-core pairs target-z project-centers "SVP")))))
  (princ))

;;; ====================================================================
;;; ИМЕНА КОМАНД В РУССКОЙ РАСКЛАДКЕ
;;; ====================================================================

;; Шамиль часто набирает команду, забыв переключить раскладку: вместо
;; OL получается ЩД. Регистрируем те же команды под кириллическими
;; именами — это буквы на ТЕХ ЖЕ клавишах в ЙЦУКЕН, поэтому руки
;; набирают одно движение, а команда запускается при любой раскладке.
;; ПОЧЕМУ и строчные, и прописные: AutoCAD приводит ввод к верхнему
;; регистру не всегда предсказуемо для кириллицы — регистрируем оба.

;; SV -> ЫМ
(defun c:ым ( / ) (c:sv))
(defun c:ЫМ ( / ) (c:sv))

;; SVP -> ЫМЗ
(defun c:ымз ( / ) (c:svp))
(defun c:ЫМЗ ( / ) (c:svp))
(princ "\n[gc] sv.lsp v29 загружен. Команды: SV, SVP | рус. раскладка: ЫМ, ЫМЗ")
(princ)
