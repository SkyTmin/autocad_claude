;;; gc-update.lsp -- obnovlenie komand pryamo iz Civil 3D (v7)
;;;
;;; v7: SECURELOAD. Zapret na zagruzku ispolnyaemogo koda otkuda popalo
;;;     ne snimaetsya dobavleniem papki v doverennye. Snimaem ego
;;;     NA ODIN VYZOV i srazu vozvrashchaem: ostavit snyatym -- znachit
;;;     molcha oslabit zashchitu chuzhoy mashiny.
;;;
;;; v6: command zavernuta v lyambdu. Eto ne obychnaya funkciya, a osobaya
;;;     forma yazyka, i peredat ee v vl-catch-all-apply napryamuyu nelzya:
;;;     AutoCAD otvechaet "nevernaya poryadkovaya funkciya: COMMAND".
;;;
;;; v5: NETLOAD vyzyvaetsya pri FILEDIA=0. Pri vklyuchennom dialoge on
;;;     otkryvaet okno vybora fayla i PEREDANNYY PUT IGNORIRUET: komanda
;;;     otrabatyvaet bez oshibki, a modul ne gruzitsya. Prichina otkaza
;;;     teper pechataetsya.
;;;
;;; v4: komanda GCAUTO propisyvaet avtozagruzku IZNUTRI CAD, bez .bat.
;;;     Papka podderzhki beretsya u samogo CAD cherez ROAMABLEROOTPREFIX,
;;;     a ne sobiraetsya iz imeni versii i yazyka: ugadyvat ih -- vernyy
;;;     sposob promahnutsya na chuzhoy mashine.
;;;     Chuzhoy acaddoc.lsp ne zatiraetsya: nash blok dopisyvaetsya v konec.
;;;
;;; v3: modul .NET gruzitsya sam, cherez NETLOAD iz LISP. Perezapuskat CAD
;;;     radi etogo ne nuzhno. Put zaranee dobavlyaetsya v doverennye, inache
;;;     AutoCAD libo sprosit razreshenie, libo otkazhet molcha.
;;;     Novaya komanda GCLOAD -- zagruzit vse s diska, nichego ne kachaya.
;;;
;;; v2: zakachka cherez curl. WinHttp v etom CAD ne sozdaetsya vovse -
;;;     komanda padala na kazhdom fayle s "set: WinHttp.WinHttpRequest".
;;;     curl vhodit v sostav Windows, ne keshiruet i sam hodit cherez
;;;     sistemnyy proksi. WinHttp ostavlen zapasnym putem.
;;;
;;; Komandy:
;;;   GCU   -- skachat svezhie .lsp s GitHub i perezagruzit ih.
;;;   GCV   -- pokazat, kakie versii sejchas lezhat na diske.
;;;   GCDIR -- pokazat ili smenit papku, kuda vse eto kladetsya.
;;;
;;; ZACHEM.
;;; Kazhdaya proverka pravki stoila: otkryt GitHub v brauzere, skachat fayl,
;;; polozhit kuda-to, APPLOAD, vspomnit put. Umnozhit na chislo pravok
;;; za sessiyu -- i vremya uhodit ne na rabotu, a na perenos faylov.
;;; Teper eto odna komanda: GCU.
;;;
;;; POCHEMU PEREZAPUSK CAD NE NUZHEN.
;;; .lsp perechityvaetsya na letu: (load) prosto zamenyaet opredeleniya
;;; funkciy. Poetomu vsya logika zhivet v .lsp, a modul .NET ostaetsya
;;; tonkim i menyaetsya pochti nikogda -- ego bez perezapuska ne vygruzit
;;; (ADR-0008).
;;;
;;; Kodirovka fayla: CP1251 bez BOM (ADR-0004). Ne UTF-8!

(vl-load-com)

;;; ====================================================================
;;; ОТКУДА БЕРЁМ
;;; ====================================================================

(setq *gc-upd-repo*   "SkyTmin/autocad_claude")
(setq *gc-upd-branch* "claude/project-status-check-h0n2w")

;; Что обновляем. Список растёт вместе с числом команд.
(setq *gc-upd-files*
  '("kg.lsp" "ol.lsp" "vo.lsp" "sv.lsp" "vid.lsp" "rs.lsp" "gc-update.lsp"))

;; Файлы модуля .NET. Лежат в соседней папке и обновляются вместе
;; с командами: иначе за свежим исходником пришлось бы каждый раз лезть
;; на сайт руками, а это ровно то, от чего мы уходили.
(setq *gc-upd-net-files* '("GcSurface.cs" "build.bat"))

;; Где запомнить папку: чтобы не спрашивать её при каждом запуске CAD.
(setq *gc-upd-reg* "HKEY_CURRENT_USER\\Software\\GeoClaude\\Home")

;;; ====================================================================
;;; ПАПКА С КОМАНДАМИ
;;; ====================================================================

;; Папка по умолчанию: та, куда ставит установщик (ADR-0008).
(defun gc-upd-default-dir ( / p)
  (setq p (strcat (getenv "APPDATA")
                  "\\Autodesk\\ApplicationPlugins\\GeoClaude.bundle\\Contents\\lisp\\"))
  (if (vl-file-directory-p p) p nil))

(defun gc-upd-reg-get ( / r)
  (setq r (vl-catch-all-apply 'vl-registry-read (list *gc-upd-reg* "")))
  (if (or (vl-catch-all-error-p r) (null r) (= r "")) nil r))

(defun gc-upd-reg-set (p)
  (vl-catch-all-apply 'vl-registry-write (list *gc-upd-reg* "" p))
  p)

;; Папка с командами. Сначала запомненная раньше, потом установленная
;; по умолчанию, и только если ни того ни другого нет - спрашиваем.
(defun gc-upd-dir ( / p f)
  (setq p (gc-upd-reg-get))
  (if (and p (vl-file-directory-p p))
    p
    (progn
      (setq p (gc-upd-default-dir))
      (if p
        (gc-upd-reg-set p)
        (progn
          (princ "\nНе знаю, где лежат команды.")
          (princ "\nУкажите любой файл из этой папки.")
          (setq f (getfiled "Папка с командами GeoClaude" "" "lsp" 0))
          (if f
            (gc-upd-reg-set (vl-filename-directory f))
            nil))))))

;;; ====================================================================
;;; ЗАГРУЗКА ФАЙЛА
;;;
;;; Два объекта: WinHttp тянет байты, ADODB.Stream кладёт их на диск
;;; как есть. Именно КАК ЕСТЬ и важно: файлы в CP1251, и текстовая
;;; запись превратила бы русские комментарии в кашу (docs/pitfalls.md -> П10).
;;; ====================================================================

;; Адрес сырого файла. Добавляем меняющийся хвост: иначе отдаётся копия
;; из кэша GitHub, и правка, сделанная минуту назад, не приедет.
(defun gc-upd-url (name)
  (strcat "https://raw.githubusercontent.com/" *gc-upd-repo* "/"
          *gc-upd-branch* "/src/lisp/commands/" name
          "?nocache=" (rtos (getvar "CDATE") 2 8)))

(defun gc-upd-net-url (name)
  (strcat "https://raw.githubusercontent.com/" *gc-upd-repo* "/"
          *gc-upd-branch* "/src/dotnet/GcSurface/" name
          "?nocache=" (rtos (getvar "CDATE") 2 8)))

;; Папка модуля - соседняя с папкой команд.
(defun gc-upd-net-dir ( / d)
  (setq d (gc-upd-dir))
  (if d
    (strcat (vl-filename-directory (substr d 1 (1- (strlen d)))) "\\net\\")
    nil))

;; Путь к curl. Входит в состав Windows с 2018 года.
(defun gc-upd-curl ( / p)
  (setq p (strcat (getenv "SystemRoot") "\\System32\\curl.exe"))
  (if (findfile p) p nil))

;; Скачать через curl. Он не кэширует и ходит через системный прокси -
;; ровно то, чего не хватало WinHttp, который в этом CAD вообще
;; не создаётся.
;;
;; Окно скрыто (0), ждём завершения (:vlax-true): без ожидания команда
;; пошла бы дальше и грузила ещё не скачанный файл.
(defun gc-upd-get-curl (url path / exe sh cmd r)
  (setq exe (gc-upd-curl))
  (if (null exe)
    (cons nil "curl не найден в Windows")
    (progn
      (setq r (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
      (if (vl-catch-all-error-p r)
        (cons nil "нет WScript.Shell")
        (progn
          (setq sh r)
          (setq cmd (strcat "\"" exe "\" -s -f -L --retry 2 -o \"" path "\" \"" url "\""))
          (setq r (vl-catch-all-apply 'vlax-invoke (list sh 'Run cmd 0 :vlax-true)))
          (vlax-release-object sh)
          (cond
            ((vl-catch-all-error-p r) (cons nil (vl-catch-all-error-message r)))
            ((and (numberp r) (/= r 0))
             (cons nil (strcat "curl вернул " (itoa r)
                               (if (= r 22) " (нет такого файла на сервере)" ""))))
            ((null (findfile path)) (cons nil "файл не появился"))
            (T (cons T "ok"))))))))

;; Скачать один файл. Возвращает (T . "ok") либо (nil . причина).
;; Сначала curl, потом WinHttp: первый надёжнее, но есть не везде.
(defun gc-upd-get (url path / r)
  (setq r (gc-upd-get-curl url path))
  (if (car r) r (gc-upd-get-http url path)))

;; Запасной путь через WinHttp.
(defun gc-upd-get-http (url path / http st r body)
  (setq r (vl-catch-all-apply 'vlax-create-object (list "WinHttp.WinHttpRequest.5.1")))
  (if (vl-catch-all-error-p r)
    (cons nil "нет WinHttp: закачка из Windows недоступна")
    (progn
      (setq http r)
      (setq r (vl-catch-all-apply
                '(lambda ()
                   (vlax-invoke http 'Open "GET" url :vlax-false)
                   ;; Заголовки против кэша. Меняющегося хвоста в адресе
                   ;; мало: кэшировать умеет и сам Windows, и тогда сервер
                   ;; отдаёт свежее, а на диск ложится вчерашнее.
                   (vlax-invoke http 'SetRequestHeader "Cache-Control" "no-cache")
                   (vlax-invoke http 'SetRequestHeader "Pragma" "no-cache")
                   (vlax-invoke http 'Send)
                   (vlax-get http 'Status))
                nil))
      (cond
        ((vl-catch-all-error-p r)
         (vlax-release-object http)
         (cons nil (strcat "сеть: " (vl-catch-all-error-message r))))
        ((/= r 200)
         (vlax-release-object http)
         (cons nil (strcat "сервер ответил " (itoa r)
                           ;; 404 у GitHub означает и "нет файла", и "нет
                           ;; доступа": закрытому репозиторию он отвечает
                           ;; так же, как несуществующему. Пишем оба случая,
                           ;; иначе поиск причины уходит не туда.
                           (cond
                             ((= r 404) " - репозиторий закрыт либо ветка/файл переименованы")
                             ((= r 403) " - доступ запрещён сетью или прокси")
                             (T ""))))) 
        (T
         (setq body (vl-catch-all-apply 'vlax-get (list http 'ResponseBody)))
         (vlax-release-object http)
         (if (vl-catch-all-error-p body)
           (cons nil "не удалось прочитать ответ")
           (progn
             (setq st (vl-catch-all-apply 'vlax-create-object (list "ADODB.Stream")))
             (if (vl-catch-all-error-p st)
               (cons nil "нет ADODB.Stream: нечем записать файл")
               (progn
                 (setq r (vl-catch-all-apply
                           '(lambda ()
                              (vlax-put st 'Type 1)        ; 1 = двоичный
                              (vlax-invoke st 'Open)
                              (vlax-invoke st 'Write body)
                              (vlax-invoke st 'SaveToFile path 2)  ; 2 = перезаписать
                              (vlax-invoke st 'Close))
                           nil))
                 (vlax-release-object st)
                 (if (vl-catch-all-error-p r)
                   (cons nil (strcat "не записался файл: "
                                     (vl-catch-all-error-message r)))
                   (cons T "ok")))))))))))

;; Первая строка файла - в ней у нас стоит имя и версия.
(defun gc-upd-head (path / f s)
  (setq s nil)
  (if (findfile path)
    (progn
      (setq f (open path "r"))
      (if f (progn (setq s (read-line f)) (close f)))))
  (if (or (null s) (= s "")) "?" s))

;;; ====================================================================
;;; ЗАГРУЗКА МОДУЛЯ .NET
;;;
;;; NETLOAD можно вызвать из LISP - значит перезапускать CAD не нужно.
;;; Путь сначала добавляется в доверенные, иначе AutoCAD либо спросит
;;; разрешение, либо откажет молча.
;;; ====================================================================

(defun gc-upd-net-loaded ( / )
  (if (member "gc_surface_border" (atoms-family 1)) T nil))

(defun gc-upd-netload ( / d p r fd)
  (setq *gc-upd-net-why* nil)
  (cond
    ((gc-upd-net-loaded) T)
    ((null (setq d (gc-upd-net-dir)))
     (setq *gc-upd-net-why* "не знаю папку модуля") nil)
    ((null (findfile (setq p (strcat d "GcSurface.dll"))))
     (setq *gc-upd-net-why* (strcat "нет файла " p)) nil)
    (T
     ;; Папку - в доверенные, иначе AutoCAD либо спросит разрешение
     ;; при каждом чертеже, либо откажет молча.
     (vl-catch-all-apply
       '(lambda ( / tp dd)
          (setq dd (substr d 1 (1- (strlen d))))
          (setq tp (getvar "TRUSTEDPATHS"))
          (if (not (wcmatch (strcase tp) (strcase (strcat "*" dd "*"))))
            (setvar "TRUSTEDPATHS" (if (= tp "") dd (strcat tp ";" dd)))))
       nil)
     ;; FILEDIA=0 ОБЯЗАТЕЛЕН. При включённом диалоге NETLOAD открывает
     ;; окно выбора файла и ПЕРЕДАННЫЙ ПУТЬ ПРОСТО ИГНОРИРУЕТ: команда
     ;; отрабатывает без ошибки, а модуль не грузится.
     (setq fd (getvar "FILEDIA"))
     (setvar "FILEDIA" 0)
     ;; command заворачиваем в лямбду. Это НЕ обычная функция, а особая
     ;; форма языка, и передать её в vl-catch-all-apply напрямую нельзя:
     ;; AutoCAD отвечает "неверная порядковая функция: COMMAND".
     (setq r (vl-catch-all-apply '(lambda () (command "_.NETLOAD" p)) nil))
     ;; SECURELOAD=1 запрещает загружать исполняемый код откуда попало,
     ;; и одного добавления папки в доверенные ему мало. Тогда снимаем
     ;; запрет НА ОДИН ВЫЗОВ и сразу возвращаем: оставить его снятым -
     ;; значит молча ослабить защиту чужой машины.
     (if (not (gc-upd-net-loaded))
       (vl-catch-all-apply
         '(lambda ( / sl)
            (setq sl (getvar "SECURELOAD"))
            (if (/= sl 0)
              (progn
                (setvar "SECURELOAD" 0)
                (vl-catch-all-apply '(lambda () (command "_.NETLOAD" p)) nil)
                (setvar "SECURELOAD" sl)
                (if (gc-upd-net-loaded)
                  (princ "\n[i] Модуль загружен со снятой на один раз проверкой SECURELOAD.")))))
         nil))
     ;; FILEDIA возвращаем ДО любых проверок и выходов: если оставить её
     ;; выключенной, у пользователя пропадут диалоги открытия файлов
     ;; во всех остальных командах, и связать это с нами он не сможет.
     (setvar "FILEDIA" fd)
     (if (vl-catch-all-error-p r)
       (setq *gc-upd-net-why* (vl-catch-all-error-message r)))
     (if (gc-upd-net-loaded)
       T
       (progn
         (if (null *gc-upd-net-why*)
           (setq *gc-upd-net-why*
             (strcat "NETLOAD прошёл, но функции нет. SECURELOAD="
                     (vl-princ-to-string (getvar "SECURELOAD")))))
         nil)))))

;;; ====================================================================
;;; КОМАНДЫ
;;; ====================================================================

;; Загрузить всё с диска, молча. Этим же пользуется автозагрузка.
(defun gc-upd-boot ( / dir n path)
  (setq dir (gc-upd-dir))
  (if dir
    (foreach n *gc-upd-files*
      (setq path (strcat dir n))
      (if (findfile path) (vl-catch-all-apply 'load (list path)))))
  (gc-upd-netload)
  (princ))

;;; ====================================================================
;;; АВТОЗАГРУЗКА
;;;
;;; Пишем в acaddoc.lsp - файл, который AutoCAD читает САМ при открытии
;;; каждого чертежа. Пакеты в ApplicationPlugins подхватываются не всегда
;;; и молча, а этот способ работает везде.
;;;
;;; Папку берём у самого CAD через ROAMABLEROOTPREFIX, а не собираем
;;; из имени версии и языка: угадывать их - верный способ промахнуться
;;; на чужой машине.
;;; ====================================================================

;; Удвоить обратные слэши: путь пишется В ТЕКСТ ПРОГРАММЫ, а там одиночный
;; слэш означает экранирование, и путь развалится при следующей загрузке.
(defun gc-upd-esc (s / i c out)
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (setq out (strcat out (if (= c "\\") "\\\\" c)))
    (setq i (1+ i)))
  out)

(defun gc-upd-support ( / p)
  (setq p (vl-catch-all-apply 'getvar (list "ROAMABLEROOTPREFIX")))
  (if (or (vl-catch-all-error-p p) (null p))
    nil
    (strcat p "Support\\")))

(defun c:gcauto ( / sup path dir f old)
  (setq sup (gc-upd-support)
        dir (gc-upd-dir))
  (cond
    ((null dir) (princ "\n[!] Папка с командами не задана. Сначала GCDIR."))
    ((null sup) (princ "\n[!] Не удалось узнать папку поддержки CAD."))
    (T
     (setq path (strcat sup "acaddoc.lsp"))
     (setq dir (gc-upd-esc dir))
     (setq old (if (findfile path) T nil))
     ;; Чужой acaddoc.lsp не трогаем, а дописываем свой блок в конец:
     ;; затереть чужую настройку - худшее, что можно сделать.
     (setq f (open path (if old "a" "w")))
     (if (null f)
       (princ (strcat "\n[!] Не удалось открыть на запись: " path))
       (progn
         (write-line "" f)
         (write-line ";;; --- GeoClaude: автозагрузка, добавлено командой GCAUTO ---" f)
         (write-line (strcat "(if (findfile \"" dir "gc-update.lsp\")") f)
         (write-line (strcat "  (progn (load \"" dir "gc-update.lsp\")") f)
         (write-line "         (if gc-upd-boot (gc-upd-boot))))" f)
         (write-line ";;; --- конец блока GeoClaude ---" f)
         (close f)
         (princ (strcat "\n[i] Автозагрузка прописана"
                        (if old " (дописано в конец существующего файла)" "")
                        ":"))
         (princ (strcat "\n    " path))
         (princ "\n[i] При следующем открытии чертежа команды загрузятся сами.")))))
  (princ))

;; Загрузить всё: команды с диска и модуль .NET. Ничего не качает.
;; Нужна, когда CAD почему-то не подхватил автозагрузку.
(defun c:gcload ( / dir n path r)
  ;; Страховка: если прошлый запуск оборвался на NETLOAD, FILEDIA могла
  ;; остаться выключенной. Возвращаем молча - лучше починить, чем
  ;; рассказывать про чужую поломку.
  (if (= 0 (getvar "FILEDIA")) (setvar "FILEDIA" 1))
  (setq dir (gc-upd-dir))
  (if (null dir)
    (princ "\n[!] Папка не задана.")
    (progn
      (princ "\n\n=== GCLOAD - загрузка с диска ===")
      (foreach n *gc-upd-files*
        (setq path (strcat dir n))
        (if (findfile path)
          (progn
            (setq r (vl-catch-all-apply 'load (list path)))
            (if (vl-catch-all-error-p r)
              (princ (strcat "\n  [!!] " n " - " (vl-catch-all-error-message r)))))
          (princ (strcat "\n  [!!] " n " - нет на диске"))))
      (if (gc-upd-netload)
        (princ "\n[i] Модуль .NET загружен.")
        (progn
          (princ "\n[i] Модуль .NET не загружен - край области будет приближённым.")
          (if *gc-upd-net-why*
            (princ (strcat "\n    Причина: " *gc-upd-net-why*)))))))
  (princ))

(defun c:gcu ( / dir nd n ok bad r path)
  (if (= 0 (getvar "FILEDIA")) (setvar "FILEDIA" 1))
  (setq dir (gc-upd-dir))
  (if (null dir)
    (princ "\n[!] Папка не задана - обновлять некуда.")
    (progn
      (princ "\n\n=== GCU - обновление команд ===")
      (princ (strcat "\nпапка : " dir))
      (princ (strcat "\nветка : " *gc-upd-branch*))
      (setq ok 0 bad 0)
      (foreach n *gc-upd-files*
        (setq path (strcat dir n))
        (setq r (gc-upd-get (gc-upd-url n) path))
        (if (car r)
          (progn (setq ok (1+ ok))
                 (princ (strcat "\n  [ok] " n)))
          (progn (setq bad (1+ bad))
                 (princ (strcat "\n  [!!] " n " - " (cdr r))))))
      ;; Заодно тянем исходник модуля .NET. Сам модуль пересобирать
      ;; приходится редко, но когда приходится - файл должен быть свежим,
      ;; иначе сборка чинит вчерашнюю ошибку.
      (setq nd (gc-upd-net-dir))
      (if (and nd (vl-file-directory-p nd))
        (foreach n *gc-upd-net-files*
          (setq r (gc-upd-get (gc-upd-net-url n) (strcat nd n)))
          (if (car r)
            (progn (setq ok (1+ ok)) (princ (strcat "\n  [ok] net/" n)))
            (progn (setq bad (1+ bad))
                   (princ (strcat "\n  [!!] net/" n " - " (cdr r)))))))
      (princ (strcat "\n\nскачано: " (itoa ok) ", не вышло: " (itoa bad)))
      (if (> ok 0)
        (progn
          ;; Загружаем ВСЕ, а не только скачанные: если один файл не приехал,
          ;; остальные всё равно должны быть свежими и рабочими.
          (princ "\n\n--- загружаю ---")
          (foreach n *gc-upd-files*
            (setq path (strcat dir n))
            (if (findfile path)
              (progn
                (setq r (vl-catch-all-apply 'load (list path)))
                (if (vl-catch-all-error-p r)
                  (princ (strcat "\n  [!!] " n " - "
                                 (vl-catch-all-error-message r)))))))
          ;; Модуль грузим сами: перезапуск CAD ради этого не нужен.
          (if (gc-upd-netload)
            (princ "\n\n[i] Готово. Модуль .NET загружен, край будет точным.")
            (progn
              (princ "\n\n[i] Готово, но модуль .NET не загружен -")
              (princ "\n    край области посчитается приближённо.")
              (if *gc-upd-net-why*
                (princ (strcat "\n    Причина: " *gc-upd-net-why*))
                (princ "\n    Собрать: build.bat в папке Contents\\net"))))))
      (if (> bad 0)
        (progn
          (princ "\n[i] Если файл не скачался, причины по частоте:")
          (princ "\n    нет интернета; закрыт доступ к сети;")
          (princ "\n    ветка или имя файла переименованы.")))))
  ;; Завершаем (princ) без аргументов: иначе команда вернёт строку,
  ;; и AutoCAD напечатает её ещё раз, уже как значение - с кавычками
  ;; и видимым \n. Выглядит как испорченный файл, хотя это просто
  ;; забытая точка в конце.
  (princ))

(defun c:gcv ( / dir n path r)
  (setq dir (gc-upd-dir))
  ;; Состояние модуля .NET печатаем первым: он необязателен, и когда
  ;; команда вдруг работает грубее обычного, причина чаще всего тут.
  (princ "\n\n=== Модуль .NET ===")
  (if (member "gc_surface_border" (atoms-family 1))
    (progn
      (setq r (vl-catch-all-apply 'gc_net_version nil))
      (princ (strcat "\n  загружен, версия "
                     (if (vl-catch-all-error-p r) "?" (vl-princ-to-string r))))
      (princ "\n  край области берётся у поверхности - точно"))
    (progn
      (princ "\n  НЕ загружен")
      (princ "\n  край области считается опросом - приближённо")
      (princ "\n  собрать: build.bat в папке Contents\\net, затем NETLOAD")))
  (princ "\n\n=== Что лежит на диске ===")
  (if (null dir)
    (princ "\n[!] Папка не задана.")
    (progn
      (princ (strcat "\nпапка : " dir))
      (foreach n *gc-upd-files*
        (setq path (strcat dir n))
        (princ (strcat "\n  " n
                       (if (findfile path)
                         (strcat "  ->  " (gc-upd-head path))
                         "  ->  нет"))))))
  (princ))

(defun c:gcdir ( / f p)
  (setq p (gc-upd-dir))
  (princ (strcat "\nТекущая папка: " (if p p "не задана")))
  (princ "\nУкажите любой файл из нужной папки.")
  (setq f (getfiled "Папка GeoClaude" (if p p "") "lsp" 0))
  (if f
    (progn
      (gc-upd-reg-set (vl-filename-directory f))
      (princ (strcat "\n[i] Папка учтена: " (vl-filename-directory f))))
    (princ "\n[i] Папка не изменена."))
  (princ))

;;; ====================================================================
;;; ТЕ ЖЕ КОМАНДЫ В РУССКОЙ РАСКЛАДКЕ
;;; ====================================================================

;; G -> П, C -> С, U -> Г, V -> М. См. docs/pitfalls.md -> П15.
(defun c:пег ( / ) (c:gcu))
(defun c:пем ( / ) (c:gcv))
;; L -> Д
(defun c:псдщфв ( / ) (c:gcload))
;; A -> Ф, T -> Е, O -> Щ
(defun c:псфгещ ( / ) (c:gcauto))

(princ "\n[gc] gc-update.lsp v7 загружен.")
(princ "\n     GCU обновить | GCV версии | GCLOAD загрузить | GCAUTO автозагрузка | GCDIR папка")
(princ)
