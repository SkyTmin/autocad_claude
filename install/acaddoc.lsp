;;; acaddoc.lsp -- avtozagruzka GeoClaude
;;;
;;; Etot fayl AutoCAD chitaet SAM pri otkrytii KAZHDOGO chertezha.
;;; Nichego nazhimat ne nuzhno: ni APPLOAD, ni NETLOAD.
;;;
;;; POCHEMU NE PAKET .bundle. Pakety v ApplicationPlugins podhvatyvayutsya
;;; ne vsegda i molcha: ni soobshcheniya, ni sposoba uznat pochemu.
;;; acaddoc.lsp rabotaet vezde i vsegda, i esli chto-to ne zagruzilos --
;;; on ob etom pishet.
;;;
;;; Put ne propisan zhestko, a schitaetsya ot APPDATA: znachit fayl odin
;;; i tot zhe u lyubogo polzovatelya, i ego mozhno obnovlyat kak vse ostalnoe.
;;;
;;; Kodirovka fayla: CP1251 bez BOM (ADR-0004). Ne UTF-8!

(vl-load-com)

(setq *gc-home*
  (strcat (getenv "APPDATA")
          "\\Autodesk\\ApplicationPlugins\\GeoClaude.bundle\\Contents\\"))

;; Команды. gc-update первым: если остальные окажутся битыми, команда GCU
;; всё равно будет под рукой и позволит их перекачать.
(foreach gc-f '("gc-update.lsp" "kg.lsp" "ol.lsp" "vo.lsp"
                "sv.lsp" "vid.lsp" "rs.lsp")
  (if (findfile (strcat *gc-home* "lisp\\" gc-f))
    (if (vl-catch-all-error-p
          (vl-catch-all-apply 'load (list (strcat *gc-home* "lisp\\" gc-f))))
      (princ (strcat "\n[gc] не загрузился: " gc-f)))))

;; Модуль .NET. Грузится тем же NETLOAD, только не руками.
;;
;; Путь сначала добавляется в доверенные: иначе AutoCAD либо спросит
;; разрешение при каждом открытии чертежа, либо откажет молча.
(if (and (findfile (strcat *gc-home* "net\\GcSurface.dll"))
         (not (member "gc_surface_border" (atoms-family 1))))
  (progn
    (vl-catch-all-apply
      '(lambda ( / tp d)
         (setq d (strcat *gc-home* "net"))
         (setq tp (getvar "TRUSTEDPATHS"))
         (if (not (wcmatch (strcase tp) (strcase (strcat "*" d "*"))))
           (setvar "TRUSTEDPATHS"
                   (if (= tp "") d (strcat tp ";" d)))))
      nil)
    (if (vl-catch-all-error-p
          (vl-catch-all-apply
            'command (list "_.NETLOAD" (strcat *gc-home* "net\\GcSurface.dll"))))
      (princ "\n[gc] модуль .NET не загрузился — край области будет приближённым."))))

(princ)
