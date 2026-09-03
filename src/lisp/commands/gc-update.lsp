;;; gc-update.lsp -- obnovlenie komand pryamo iz Civil 3D (v1)
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

;; Скачать один файл. Возвращает (T . "ok") либо (nil . причина).
(defun gc-upd-get (url path / http st r body)
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
;;; КОМАНДЫ
;;; ====================================================================

(defun c:gcu ( / dir nd n ok bad r path)
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
          (princ "\n\n[i] Готово. Перезапускать CAD не нужно.")
          (if (not (member "gc_surface_border" (atoms-family 1)))
            (progn
              (princ "\n[i] Модуль .NET не загружен. Если нужен точный край -")
              (princ "\n    запустите build.bat в папке Contents\\net и")
              (princ "\n    перезапустите CAD.")))))
      (if (> bad 0)
        (progn
          (princ "\n[i] Если файл не скачался, причины по частоте:")
          (princ "\n    нет интернета; закрыт доступ к сети;")
          (princ "\n    ветка или имя файла переименованы."))))))

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

(princ "\n[gc] gc-update.lsp v1 загружен. Команды: GCU обновить | GCV версии | GCDIR папка")
(princ)
