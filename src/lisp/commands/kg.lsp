;;; kg.lsp -- kartogramma zemlyanyh mass (SPEC-009 v1)
;;; Komandy:
;;;   KG          -- osnovnaya komanda.
;;;   GC-CARTOGRAM -- polnoe imya toy zhe komandy.
;;;   ЛП          -- to zhe v russkoy raskladke.
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
(defun gc-kg-surfaces ( / app doc surfs n i out)
  (setq out nil)
  (if (gc-kg-com-ok)
    (foreach pid '("AeccXUiLand.AeccApplication.13.6"
                   "AeccXUiLand.AeccApplication.13.5"
                   "AeccXUiLand.AeccApplication.13.4"
                   "AeccXUiLand.AeccApplication.13.3"
                   "AeccXUiLand.AeccApplication.13.2"
                   "AeccXUiLand.AeccApplication.13.1"
                   "AeccXUiLand.AeccApplication.13.0"
                   "AeccXUiLand.AeccApplication.12.0"
                   "AeccXUiLand.AeccApplication.11.0"
                   "AeccXUiLand.AeccApplication.10.5")
      (if (null out)
        (progn
          (setq app (vl-catch-all-apply 'vlax-get-or-create-object (list pid)))
          (if (not (vl-catch-all-error-p app))
            (progn
              (setq doc (vl-catch-all-apply 'vlax-get (list app "ActiveDocument")))
              (if (not (vl-catch-all-error-p doc))
                (progn
                  (setq surfs (vl-catch-all-apply 'vlax-get (list doc "Surfaces")))
                  (if (not (vl-catch-all-error-p surfs))
                    (progn
                      (setq n (vl-catch-all-apply 'vlax-get (list surfs "Count")))
                      (if (not (vl-catch-all-error-p n))
                        (progn
                          (setq out '() i 0)
                          (while (< i n)
                            (setq out (cons (vlax-get (vlax-invoke surfs 'Item i) 'Name) out))
                            (setq i (1+ i)))
                          (setq out (reverse out))))))))))))))
  out)

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
               "  [!] Поверхности Civil 3D не найдены — расчёт будет недоступен")))
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
;;; ЯДРО КОМАНДЫ
;;; ====================================================================

(defun gc-kg-defaults ( / )
  (if (null *gc-kg-cfg*) (setq *gc-kg-cfg* *gc-kg-def*)))

(defun gc-kg-intro ( / )
  (princ "\n\n=== KG — картограмма земляных масс ===")
  (princ "\nСетка квадратов, отметки в узлах, объёмы выемки и насыпи,")
  (princ "\nлиния нулевых работ и ведомость.")
  (princ "\n")
  (princ "\n[i] ЭТАП 1 ИЗ 5: сейчас работает только окно настроек.")
  (princ "\n    Оно собирает и запоминает все параметры и показывает,")
  (princ "\n    что принято. Построение сетки, расчёт объёмов и ведомость")
  (princ "\n    добавляются следующими этапами.")
  (princ "\n    Посмотрите окно и скажите, что переставить или переименовать —")
  (princ "\n    его правка стоит дёшево, а переделывать после расчётов дорого."))

(defun gc-kg-run ( / )
  (gc-kg-defaults)
  (gc-kg-intro)
  (if (gc-kg-dialog-loop)
    (progn
      (gc-kg-report)
      (princ "\n\n[i] Настройки сохранены до закрытия чертежа.")
      (princ "\n[i] Расчёт на этом этапе не выполняется — см. сообщение выше.")))
  (princ "\n[i] KG завершена.")
  (princ))

;;; ====================================================================
;;; КОМАНДА
;;; ====================================================================

;; *error* объявлен локальным: на выходе AutoLISP сам вернёт прежний
;; обработчик, даже если нажали Esc посреди ввода.
(defun c:kg ( / *error*)
  (defun *error* (msg)
    (if (and msg
             (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*")))
      (princ (strcat "\n[ОШИБКА] KG: " msg))
      (princ "\n[ОТМЕНА] KG прерван."))
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
(princ "\n[gc] kg.lsp v1 загружен. Команда: KG | рус. раскладка: ЛП")
(princ "\n     Этап 1 из 5: окно настроек. Расчёт добавляется следующими этапами.")
(princ)
