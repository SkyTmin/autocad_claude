;;; kg.lsp -- kartogramma zemlyanyh mass (SPEC-009 v29)
;;; Komandy:
;;;   KG          -- osnovnaya komanda.
;;;   GC-CARTOGRAM -- polnoe imya toy zhe komandy.
;;;   ЛП          -- to zhe v russkoy raskladke.
;;;
;;; v29: PODPISI PRIVEDENY K OBRAZCU.
;;;      Shamil prislal zoom obrazca, i po nemu vsyo soshlos:
;;;        +5,23  13,23     sleva rabochaya, sprava sverhu SUSHCHESTVUYUSHCHAYA
;;;                8,00     sprava snizu PROEKTNAYA
;;;      13,23 - 8,00 = +5,23: plyus oznachaet VYEMKU.
;;;      Cveta: sushchestvuyushchaya sinyaya, proektnaya zelenaya,
;;;      rabochaya purpurnaya. Vse tri odnoy vysoty.
;;;      U menya bylo naoborot i po raspolozheniyu, i po znaku.
;;;
;;; v28: PODPISI V KRAEVYH KUSOCHKAH, RASPOLOZHENIE I ZNAK.
;;;      1. Podpisyvalis tolko uzly setki, popavshie vnutr oblasti.
;;;         U kraevogo kvadrata ugly lezhat SNARUZHI granicy, i "malenkie
;;;         kusochki" ostavalis pustymi -- a v nih tozhe schitaetsya obem.
;;;         Teper beryom eshche i vershiny obrezannogo kontura: eto tochki,
;;;         gde granica peresekaet linii setki.
;;;      2. Raspolozhenie: rabochaya SLEVA i krupnee, krasnaya sprava sverhu,
;;;         chernaya sprava snizu. Rabochuyu chitayut pervoy.
;;;      3. Znak rabochey stal tumblerom: plyus = nasyp libo plyus = vyemka.
;;;         Zerkalnyy znak vyglyadit pravdopodobno i molcha portit vedomost,
;;;         poetomu vybor yavnyy i napechatan v otchete.
;;;
;;; v27: ETAP 3 -- PODPISI OTMETOK V UZLAH.
;;;      V kazhdom uzle setki tri chisla: krasnaya sverhu, chernaya snizu,
;;;      rabochaya sprava CVETOM PO ZNAKU. Znak cvetom -- ne ukrashenie:
;;;      uzlov na ploshchadke sotni, i razbirat znak chteniem kazhdogo
;;;      chisla nevozmozhno.
;;;      Uzly berutsya u POSTROENNOY setki, a ne schitayutsya zanovo:
;;;      podpisyvaetsya rovno to, chto narisovano.
;;;      Sosednie kvadraty delyat uzly, poetomu sobiraem bez povtorov --
;;;      inache kazhdaya podpis legla by dvazhdy.
;;;
;;; v26: TOCHNOE PERESECHENIE OBLASTEY CHEREZ TREUGOLNIKI.
;;;      Kontury ot modulya okazalis PRAVILNYE -- Shamil podtverdil, chto
;;;      obe narisovannye linii legli po granicam. Znachit vinovat byl
;;;      raschet: v kvadratah, gde shodyatsya DVA kontura, on uhodil
;;;      v droblenie na podyacheyki, i kray tam prevrashchalsya v gruboy
;;;      hordu -- eto i vidno kak srezannye ugly.
;;;
;;;      Teper kazhdyy kontur odin raz rezhetsya na TREUGOLNIKI. Treugolnik
;;;      vypuklyy vsegda, otsechenie im tochnoe, a peresechenie dvuh
;;;      oblastey -- summa peresecheniy vseh par treugolnikov.
;;;      Droblenie na podyacheyki bolshe ne nuzhno vovse.
;;;
;;;      Provereno chislenno: summa po yacheykam sovpadaet s tochnym
;;;      peresecheniem DO NULYA, a ono s etalonom Monte-Karlo po 3 mln
;;;      tochek -- do 0,0008 %.
;;;
;;; v25: PECHATAEM PLOSHCHAD KONTURA I VERSIYU MODULYA.
;;;      "model" i "plan" dali odinakovye 35 i 19 tochek -- znachit libo
;;;      modul v pamyati eshche 1.0 i vtoroy argument ignoriruet, libo
;;;      ExtractBorder otdaet odno i to zhe. Chislo tochek o sovpadenii
;;;      s chertezhom ne govorit, a ploshchad -- sravnima s ploshchadyu setki.
;;;      Teper pechataetsya i to, i drugoe, i versiya modulya.
;;;
;;; v24: GRANICA BERETSYA REZHIMOM "plan", A NE "model".
;;;      Komanda KGB narisovala oba varianta na chertezhe, i vidno srazu:
;;;      "plan" lozhitsya na nastoyashchuyu granicu s izlomami, "model"
;;;      otdaet grubyy kontur v poltora desyatka tochek -- po nemu setka
;;;      i srezala ugly.
;;;      "model" stoyal po umolchaniyu prosto potomu, chto ya tak reshil,
;;;      i eto ni razu ne bylo provereno. Teper snachala "plan",
;;;      "model" -- zapasnoy.
;;;
;;; v23: KOMANDA KGB -- POKAZAT GRANICY, POLUCHENNYE OT MODULYA.
;;;      Kontur ot modulya okazalsya grubee nastoyashchey granicy: 35 i 19
;;;      tochek, i na chertezhe setka srezaet ugly. Spor "modul dal ne to"
;;;      ili "my poschitali ne to" reshaetsya tolko glazami: risuem rovno
;;;      to, chto vernul modul, oboimi sposobami (model i plan), raznymi
;;;      cvetami -- i sravnivaem s granicey na chertezhe.
;;;
;;; v22: OTVET MODULYA RAZBIRAETSYA PO SODERZHIMOMU, A NE PO OZHIDANIYAM.
;;;      "neverny tip argumenta: consp 1.44907e+06" -- v tekste oshibki
;;;      koordinata: modul otdal ODIN kontur ploskim spiskom tochek,
;;;      a razbor lez na uroven glubzhe, kak esli by konturov bylo neskolko.
;;;      Teper forma opredelyaetsya po soderzhimomu, i pechataetsya, skolko
;;;      konturov i tochek prishlo -- chtoby ne gadat, chto vernul modul.
;;;
;;; v21: UBRAN eval V ZASHCHITE POLEY OKNA.
;;;      "nevernaya funkciya: #<SUBR ... -lambda->" -- eval prevrashchaet
;;;      lyambdu v skompilirovannyy obekt, a vl-catch-all-apply takoy
;;;      ne prinimaet. Peredaem IMYA funkcii i spisok argumentov.
;;;
;;; v20: OKNO PADALO IZ-ZA PROTUHSHEGO NABORA VYBORA.
;;;      "fixnump: nil" -- eto (itoa (sslength ss)), gde nabor uzhe
;;;      nedeystvitelen. Nabory vybora zhivut ne vechno: sterli obekt,
;;;      pereotkryli chertezh -- i sslength vozvrashchaet nil. A nastroyki
;;;      hranyatsya do zakrytiya chertezha, poetomu protuhshiy nabor dozhivaet
;;;      do sleduyushchego otkrytiya okna.
;;;      Teper dlina nabora chitaetsya bezopasno, a v okne pishetsya
;;;      "vybor ustarel, ukazhite zanovo".
;;;      Zaodno kazhdyy shag zapolneniya okna zashchishchen po otdelnosti:
;;;      okno otkryvaetsya v lyubom sluchae i nazyvaet slomannye polya.
;;;
;;; v19: OKNO BOLSHE NE PADAET NA ODNOM ISPORCHENNOM POLE.
;;;      "neverny tip argumenta: fixnump: nil" ronyal vse okno, hotya
;;;      vinovato bylo odno pole iz dvadcati: dimx_tile vozvrashchaet nil
;;;      dlya nesushchestvuyushchego polya, a cvet mozhet byt nil pri starom
;;;      nabore nastroek. Nastroyki zhivut do zakrytiya chertezha i
;;;      perezhivayut obnovlenie komandy, poetomu staryy nabor ne znaet
;;;      pro novye klyuchi -- teper nedostayushchee beretsya iz umolchaniy.
;;;
;;; v18: PROVERKA MODULYA .NET BYLA SLOMANA REGISTROM.
;;;      (atoms-family 1) otdaet imena ZAGLAVNYMI, a sravnivalis oni
;;;      so strochnoy strokoy: proverka ne mogla vernut istinu nikogda.
;;;      Modul, veroyatno, gruzilsya s samogo nachala, a komanda schitala
;;;      ego otsutstvuyushchim i shla priblizhennym putem.
;;;
;;; v17: NARUZHNYH GRANIC MOZHNO VYBRAT NESKOLKO.
;;;      Odna polilinya opisyvaet kray odnoy poverhnosti i nichego ne govorit
;;;      pro vtoruyu, poetomu k ney prihodilos dobavlyat opros otmetok --
;;;      a on otkazyvaet u samogo kraya poverhnosti, i po krayam teryalis
;;;      kusochki (ploshchad 1104 vmesto 1110).
;;;      Teper mozhno ukazat OBA kontura -- chernoy i krasnoy. Togda oblast
;;;      opisana polnostyu, opros ne nuzhen, i schet snova tochnyy.
;;;      Tak i zapisano v specs/009 §5B.5: naruzhnyh granic mozhno neskolko,
;;;      beretsya obshchaya oblast.
;;;
;;; v16: VYBRANNAYA POLILINIYA NE OTMENYAET PROVERKU POVERHNOSTEY.
;;;      Bez modulya .NET granic poverhnostey net, i v peresechenii ostavalas
;;;      odna polilinya. Ona mozhet vyhodit za poverhnosti -- i setka vstavala
;;;      tam, gde vtoroy poverhnosti uzhe net.
;;;      Teper: net granic OBEIH poverhnostey -- ih kray dopolnitelno
;;;      ishchetsya oprosom otmetok, i eto skazano v otchete vsluh.
;;;
;;; v15: OBLAST -- PERESECHENIE VSEH KONTUROV, A NE ODIN IZ NIH.
;;;      v14 vernula staruyu oshibku: vybrannaya polilinya ZAMENYALA
;;;      poverhnosti, i setka uhodila tuda, gde vtoroy poverhnosti net.
;;;      Eto P33 drugim putem.
;;;
;;;      Do etogo iz konturov vybiralsya odin -- tot, chto lezhit vnutri
;;;      ostalnyh. Eto neverno, kogda kontury peresekayutsya krayami:
;;;      u Shamilya krasnaya poverhnost mestami vyhodit za zelenuyu,
;;;      i "vlozhennogo" kontura ne sushchestvuet vovse.
;;;
;;;      Teper oblast -- PERESECHENIE vseh: granicy oboih poverhnostey
;;;      i vybrannaya polilinya. Ni odin iz nih ne glavnee drugih.
;;;
;;;      Kak eto schitaetsya. Otsechenie Sazerlenda-Hodgmana tochno rezhet
;;;      odin kontur kvadratom, no peresech dva proizvolnyh kontura mezhdu
;;;      soboy ne umeet. Poetomu rabotaem ot kvadrata: kontur pokryvaet ego
;;;      celikom -- ne rezhet; ne zadevaet -- kvadrat pust; rezhet rovno
;;;      odin -- beryom ego otsechenie, eto tochno; rezhut neskolko --
;;;      drobim na podyacheyki. Drobit prihoditsya lish tam, gde shodyatsya
;;;      dva kraya, a takih kvadratov edinicy.
;;;
;;; v14: VYBRANNAYA POLILINIYA TOZHE SCHITAETSYA TOCHNOY GRANICEY.
;;;      Ranshe ona rabotala filtrom poverh priblizhennogo oprosa, i kontur
;;;      vse ravno srezal ugly. No u polilinii vershiny IZVESTNY -- rezat
;;;      po ney tochno luchshe, chem nashchupyvat kray oprosom.
;;;      Eto ne povtorenie P33: tam granica molcha ZAMENYALA poverhnosti,
;;;      zdes ona beretsya osoznanno, o ney skazano v otchete otdelnoy
;;;      strokoy, i sbrosit ee mozhno knopkoy v okne.
;;;      V otchete teper vidno, OTKUDA vzyata granica.
;;;
;;; v13: TOCHNAYA GRANICA IZ MODULYA .NET.
;;;      Modul zagruzhen -- granica poverhnosti beretsya u nee samoy,
;;;      i setka rezhetsya TOCHNO: kontur sovpadaet s liniey poverhnosti
;;;      odin v odin. Opros otmetok pri etom ne nuzhen vovse -- proverka
;;;      "tochka vnutri" stanovitsya chisto vychislitelnoy, bez obrashcheniy
;;;      k CAD, i schet uskoryaetsya na poryadok.
;;;
;;;      Oblast -- tot iz konturov, kotoryy lezhit VNUTRI vseh ostalnyh:
;;;      granica chernoy, granica krasnoy, vybrannaya naruzhnaya granica.
;;;      Takogo net -- znachit oni peresekayutsya krayami, odnim
;;;      mnogougolnikom oblast ne opisat: uhodim na priblizhennyy put
;;;      i govorim pochemu.
;;;
;;;      Modul neobyazatelen (ADR-0008): bez nego vse rabotaet kak v v12.
;;;
;;; v12: KRAEVOY KVADRAT TEPER POVTORYAET GRANICU.
;;;      Bylo: ploshchad schitalas drobleniem 4 x 4, a LINIYA risovalas odnoy
;;;      pryamoy mezhdu dvumya tochkami kraya na storonah kvadrata. U nastoyashchey
;;;      granicy vnutri kvadrata est izlomy, i pryamaya ih srezala: chislo
;;;      tochnoe, kartinka net.
;;;      Stalo: liniya stroitsya po tomu zhe drobleniyu. Kuski podyacheek
;;;      sshivayutsya v odin kontur -- vnutrennie rebra vstrechayutsya dvazhdy
;;;      v protivopolozhnyh napravleniyah i vzaimno unichtozhayutsya.
;;;      Provereno chislenno: ploshchad sshitogo kontura sovpala s summoy
;;;      ploshchadey podyacheek na vseh formah, sboev net.
;;;
;;; v11: NAYDENA NASTOYASHCHAYA PRICHINA "LISHNEGO UCHASTKA".
;;;      V otchete stoyalo "granica naruzhnaya: vybrana". Granica, vybrannaya
;;;      v odnom iz proshlyh zapuskov, hranilas do zakrytiya chertezha, i
;;;      komanda shla PO NEY, voobshche ne sprashivaya poverhnosti. Setka
;;;      lozhilas na polyliniyu, a ne na obshchuyu oblast dvuh poverhnostey.
;;;      Snyat granicu bylo nechem: knopki sbrosa ne bylo.
;;;
;;;      Prichina v arhitekture: granica ZAMENYALA poverhnosti, a dolzhna
;;;      byla DOBAVLYATSYA k nim. Teper oblast -- peresechenie: obe
;;;      poverhnosti otvetili I tochka vnutri granicy, esli ta vybrana.
;;;      V okne poyavilas knopka "Sbros granic".
;;;
;;;      Zaodno ubran put cherez poverhnost obemov (v9-v10). On dobavlyalsya
;;;      pod oshibochnyy diagnoz, ni razu ne srabotal na chertezhe i menyal
;;;      chertezh polzovatelya. Proverka Shamilya pokazala: opros dvuh
;;;      poverhnostey daet pravilnuyu oblast sam.
;;;
;;; v10: SETKA VYLEZALA ZA MENSHUYU POVERHNOST.
;;;      Tam, gde krasnaya poverhnost vyhodit za zelenuyu, kvadraty vse ravno
;;;      stroilis, hotya vtoroy poverhnosti tam net.
;;;      Prichina: poverhnost obemov Civil 3D stroitsya na BAZOVOY poverhnosti,
;;;      a otmetki beret u sravnivaemoy. Gde bazovaya est, a vtoroy net, ona
;;;      vse ravno mozhet otvetit -- i oblast poluchaetsya po bazovoy.
;;;      Teper tochka schitaetsya vnutri, tolko esli otvetili VSE TROE:
;;;      poverhnost obemov i obe ishodnye. Peresechenie trekh otvetov
;;;      uzhe ne shire ni odnogo iz nih.
;;;      Rezhim "Proverka" teper pokazyvaet otvet KAZHDOY poverhnosti
;;;      i vyvod "vnutri / vne oblasti" -- chtoby ne gadat, kto vinovat.
;;;
;;; v9: DVE OSHIBKI, VIDNYE NA CHERTEZHE.
;;;
;;;     1. FIGURY NE 5 x 5 POSREDI NORMALNOY SETKI. Prichina: odinochnyy
;;;        proval oprosa -- uzel, gde poverhnost ne otvetila, hotya vse
;;;        chetyre soseda otvetili. Odin takoy uzel prevrashchaet CHETYRE
;;;        sosednih kvadrata v obrezki. Dyrki razmerom v odin uzel ne byvaet:
;;;        ona byla by menshe shaga setki. Teper lechim -- tolko pri vseh
;;;        chetyreh zanyatyh sosedyah, s pechatyu chisla zalechennyh.
;;;
;;;     2. LISHNIY UCHASTOK SPRAVA. Prichina: FindElevationAtXY otvechaet
;;;        po TRIANGULYACII, a ne po tomu, chto pokazano. Kraevye tonkie
;;;        treugolniki i uchastki za granicey, naveshennoy na poverhnost,
;;;        v nee popadali.
;;;        Reshenie -- to zhe, na chem stoit etalonnyy instrument: vremenno
;;;        sozdaetsya POVERHNOST OBEMOV Civil 3D. Ona sushchestvuet rovno
;;;        tam, gde oblast kartogrammy, i granicy uchityvaet. Posle
;;;        postroeniya udalyaetsya -- v tom chisle pri oshibke i po Esc.
;;;        Ne poluchilos sozdat -- staryy put, no s gromkim preduprezhdeniem.
;;;
;;; v8: OBLAST KARTOGRAMMY BERETSYA U SAMIH POVERHNOSTEY.
;;;     Vybirat granicu rukami bolshe ne nuzhno. Rabochaya otmetka
;;;     sushchestvuet tolko tam, gde OBE poverhnosti dayut otmetku, znachit
;;;     oblast -- ih peresechenie, i ono uzhe zadano poverhnostyami.
;;;     Tak zhe sami soboy rabotayut granicy, dobavlennye v poverhnost:
;;;     za granicey otmetki net, tuda setka i ne poydet.
;;;     Eto sovpadaet s tem, chto zapisano v specs/009 §5B.5: beretsya
;;;     OBSHCHAYA OBLAST poverhnostey i granic.
;;;
;;;     Kray ishchetsya opросом uzlov i deleniem popolam. Ploshchad kraevogo
;;;     kvadrata utochnyaetsya drobleniem 4 x 4 -- bez etogo ugol granicy,
;;;     popavshiy vnutr kvadrata, srezalsya by pryamoy (docs/pitfalls.md P29).
;;;
;;;     Setka stroitsya srazu posle OK, bez lishnego voprosa.
;;;     Cvet setki -- po sloyu (belyy).
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
    ;; Цвета по образцу, к которому Шамиль привык: существующая синяя,
    ;; проектная зелёная, рабочая пурпурная. Развести цвета рабочей
    ;; по знаку можно в окне - настройки для этого есть.
    (cons "c-black"  5)           ; существующая (чёрная поверхность), синий
    (cons "c-red"    3)           ; проектная (красная поверхность), зелёный
    (cons "c-work"   3)           ; цвет рабочей отметки (общий, запасной)
    ;; У рабочей отметки ТРИ цвета по знаку: знак виден цветом, без чтения
    ;; самого числа (specs/009 §5Б.5). Это не украшение - на картограмме
    ;; узлов сотни, и глазами их не перебрать.
    (cons "c-wminus" 6)           ; рабочая: один знак
    (cons "c-wzero"  6)           ; рабочая: ноль
    (cons "c-wplus"  6)           ; рабочая: другой знак
    (cons "sep"      "0")         ; разделитель: 0 запятая, 1 точка
    ;; Знак рабочей отметки. 0: плюс = насыпь (проект выше земли),
    ;; как в docs/formulas.md. 1: плюс = выемка, обратная конвенция.
    ;; Тумблер, а не жёстко: контора конторе рознь, а зеркальный знак
    ;; выглядит правдоподобно и молча портит всю ведомость.
    ;; По умолчанию ПЛЮС = ВЫЕМКА: так в образце, по которому Шамиль
    ;; сверяется. Рабочая считается как существующая минус проектная:
    ;; земля 13,23, проект 8,00 -> +5,23, срезать пять с лишним метров.
    ;; В docs/formulas.md записана обратная конвенция - обе встречаются,
    ;; поэтому это тумблер, а не жёстко зашитое правило.
    (cons "wsign"    "1")
    (cons "style"    "Standard")  ; стиль текста подписей
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

(defun gc-kg-get (k / v)
  (setq v (assoc k *gc-kg-cfg*))
  ;; Ключа нет в настройках - берём из значений по умолчанию, а не nil.
  ;; Настройки живут до закрытия чертежа и переживают обновление команды,
  ;; поэтому старый набор может не знать про новый ключ.
  (if v (cdr v) (cdr (assoc k *gc-kg-def*))))

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
        *gc-kg-surf-why* nil
        *gc-kg-surf-coll* nil)
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
           ;; Коллекция нужна дальше: через неё создаётся поверхность объёмов.
           (setq *gc-kg-surf-coll* surfs)
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
"      : text { key = \"lines_txt\"; }"
"      : button { key = \"clr_bnd\"; label = \"Сброс границ\"; }"
"      : text { label = \"без границ область = общая\"; }"
"      : text { label = \"часть двух поверхностей\"; } } }"
"  : boxed_column { label = \" Подписи отметок в узлах \";"
"    : row {"
"      : popup_list { key = \"t_style\"; label = \"Стиль текста \"; width = 22; fixed_width = true; }"
"      : edit_box   { key = \"h_mark\";  label = \" Высота, м \"; edit_width = 6; }"
"      : popup_list { key = \"p_mark\";  label = \" Точность \"; width = 7; fixed_width = true; } }"
"    : row {"
"      : text { label = \"Цвет:\"; }"
"      : text { label = \" существ.\"; }"
"      : image_button { key = \"c_black\"; width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" проектной\"; }"
"      : image_button { key = \"c_red\";   width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" рабочей\"; }"
"      : image_button { key = \"c_work\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; } }"
"    : row {"
"      : text { label = \"Рабочая по знаку:\"; }"
"      : text { label = \" выемка\"; }"
"      : image_button { key = \"c_wminus\"; width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" ноль\"; }"
"      : image_button { key = \"c_wzero\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; }"
"      : text { label = \" насыпь\"; }"
"      : image_button { key = \"c_wplus\";  width = 5; height = 1.4; fixed_width = true; fixed_height = true; } }"
"    : row {"
"      : text   { label = \"Разделитель дробной части:\"; }"
"      : toggle { key = \"sep\"; label = \"точка вместо запятой\"; } }"
"    : row {"
"      : text   { label = \"Знак рабочей отметки:\"; }"
"      : toggle { key = \"wsign\"; label = \"плюс = выемка (иначе плюс = насыпь)\"; } } }"
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
  ;; dimx_tile возвращает nil, если такого поля в окне нет, а цвет может
  ;; оказаться nil при испорченных настройках. Оба случая роняли всё окно
  ;; сообщением "неверный тип аргумента: fixnump: nil" - а виновато при
  ;; этом одно поле из двадцати (docs/pitfalls.md -> П48).
  (setq w (dimx_tile tile) h (dimy_tile tile))
  (if (and w h (numberp col))
    (progn
      (start_image tile)
      (fill_image 0 0 w h col)
      (end_image))))

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

;; Длина набора. nil, если набор ПРОТУХ.
;;
;; Наборы выбора живут не вечно: стёрли объект, переоткрыли чертёж,
;; набралось слишком много наборов - и sslength возвращает nil.
;; Настройки же хранятся до закрытия чертежа, поэтому протухший набор
;; вполне может дожить до следующего открытия окна.
;;
;; Именно на этом падало всё окно: (itoa nil) -> "fixnump: nil"
;; (docs/pitfalls.md -> П49).
(defun gc-kg-ss-len (ss / n)
  (if (null ss)
    nil
    (progn
      (setq n (vl-catch-all-apply 'sslength (list ss)))
      (if (or (vl-catch-all-error-p n) (null n) (not (numberp n))) nil n))))

;; Строка-описание выбранного набора для показа в окне.
(defun gc-kg-ss-txt (ss zero / n)
  (setq n (gc-kg-ss-len ss))
  (cond
    ((null ss) zero)
    ((null n)  "  выбор устарел, укажите заново")
    (T (strcat "  выбрано: " (itoa n)))))

;; Шаг заполнения окна. Ошибка в одном поле не должна закрывать окно:
;; пользователю нужно окно, а нам - имя сломанного поля.
;;
;; Передаём ИМЯ функции и список аргументов, а не лямбду через eval:
;; eval превращает лямбду в скомпилированный объект, а vl-catch-all-apply
;; такой не принимает и отвечает "неверная функция: #<SUBR ... -lambda->"
;; (docs/pitfalls.md -> П51).
(defun gc-kg-try (what fn args / r)
  (setq r (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p r)
    (progn
      (setq *gc-kg-dlg-err*
        (cons (strcat what ": " (vl-catch-all-error-message r)) *gc-kg-dlg-err*))
      nil)
    r))

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
  (gc-kg-set "sep"     (get_tile "sep"))
  (gc-kg-set "wsign"   (get_tile "wsign"))
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
        ((or (null id) (not (numberp id)) (< id 0))
         (princ "\n[ОШИБКА] Не удалось загрузить диалог.")
         nil)
        ((not (new_dialog *gc-kg-dlg* id))
         (princ "\n[ОШИБКА] Диалог не открылся.")
         (unload_dialog id)
         nil)
        (T
         (setq *gc-kg-dlg-err* nil)
         ;; --- поверхности
         (gc-kg-try "поверхности" '(lambda ( / )
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
                 "  [!] Поверхности не найдены — расчёт будет недоступен"))))) nil)
         ;; --- сетка и подписи. Каждое поле отдельно: одно испорченное
         ;; значение не уносит с собой остальные девятнадцать.
         (foreach k '("step_x" "step_y" "angle" "h_mark" "h_vol" "min_vol"
                      "trim" "use_min" "sep" "wsign")
           (gc-kg-try k 'set_tile (list k (gc-kg-get (gc-kg-key k)))))
         (gc-kg-try "p_mark" 'gc-kg-fill-list
           (list "p_mark" *gc-kg-prec* (gc-kg-get "p-mark")))
         (gc-kg-try "p_vol" 'gc-kg-fill-list
           (list "p_vol" *gc-kg-prec* (gc-kg-get "p-vol")))
         (gc-kg-try "t_style" 'gc-kg-fill-list
           (list "t_style" *gc-kg-styles*
                 (gc-kg-index-of (gc-kg-get "style") *gc-kg-styles*)))
         ;; --- цвета
         (foreach k '("c_black" "c_red" "c_work"
                      "c_wminus" "c_wzero" "c_wplus"
                      "c_plus" "c_minus" "c_zero")
           (gc-kg-try k 'gc-kg-show-color (list k (gc-kg-get (gc-kg-key k)))))
         ;; --- выбранные объекты
         (gc-kg-try "выбранные объекты" '(lambda ( / )
           (set_tile "base_txt"  (if (gc-kg-get "base") "  задана" "  не задана"))
           (set_tile "outer_txt" (gc-kg-ss-txt (gc-kg-get "outer") "  не выбрана"))
           (set_tile "inner_txt" (gc-kg-ss-txt (gc-kg-get "inner") "  нет"))
           (set_tile "lines_txt" (gc-kg-ss-txt (gc-kg-get "lines") "  нет")))
           nil)
         ;; --- действия
         (foreach k '("c_black" "c_red" "c_work"
                      "c_wminus" "c_wzero" "c_wplus"
                      "c_plus" "c_minus" "c_zero")
           (action_tile k (strcat "(gc-kg-pick-color \"" k "\")")))
         ;; ПОЧЕМУ перед закрытием читаем поля: тыкать по чертежу при открытом
         ;; окне DCL нельзя, окно приходится закрывать. Без этой строки всё
         ;; набранное в полях пропадало бы при каждом «Указать».
         (action_tile "pick_base"  "(progn (gc-kg-read-tiles) (done_dialog 10))")
         (action_tile "pick_angle" "(progn (gc-kg-read-tiles) (done_dialog 11))")
         (action_tile "pick_outer" "(progn (gc-kg-read-tiles) (done_dialog 12))")
         (action_tile "pick_inner" "(progn (gc-kg-read-tiles) (done_dialog 13))")
         (action_tile "pick_lines" "(progn (gc-kg-read-tiles) (done_dialog 14))")
         (action_tile "clr_bnd"    "(progn (gc-kg-read-tiles) (done_dialog 15))")
         ;; ОК: сначала проверяем, при ошибке окно не закрываем.
         (action_tile "accept" "(if (gc-kg-validate) (progn (gc-kg-read-tiles) (done_dialog 1)))")
         (action_tile "cancel" "(done_dialog 0)")
         ;; Что не заполнилось - говорим вслух, но окно показываем.
         (if *gc-kg-dlg-err*
           (progn
             (princ "\n[!] Часть полей окна не заполнилась:")
             (foreach e (reverse *gc-kg-dlg-err*) (princ (strcat "\n    " e)))
             (princ "\n    Окно открыто, остальные поля работают.")))
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
      ((= res 12) (gc-kg-set "outer" (gc-kg-pick-curves "Наружные границы, можно НЕСКОЛЬКО: " nil)))
      ((= res 13) (gc-kg-set "inner" (gc-kg-pick-curves "Внутренние границы (исключения): " nil)))
      ((= res 14) (gc-kg-set "lines" (gc-kg-pick-curves "Характерные линии рельефа: " nil)))
      ;; Сброс границ отдельной кнопкой. Без неё выбранная однажды граница
      ;; жила до закрытия чертежа, и снять её было нечем (docs/pitfalls.md -> П33).
      ((= res 15)
       (gc-kg-set "outer" nil) (gc-kg-set "inner" nil) (gc-kg-set "lines" nil)
       (princ "\n[i] Границы сброшены. Область теперь задают только поверхности."))
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
                 (cond
                   ((gc-kg-ss-len (gc-kg-get "outer"))
                    (strcat "ВЫБРАНО контуров: "
                            (itoa (gc-kg-ss-len (gc-kg-get "outer")))
                            " - каждый сужает область"))
                   ((gc-kg-get "outer") "выбор устарел - укажите заново")
                   (T "не выбрана - область по поверхностям"))))
  (princ (strcat "\n  границы внутренние  : "
                 (if (gc-kg-ss-len (gc-kg-get "inner"))
                   (itoa (gc-kg-ss-len (gc-kg-get "inner"))) "нет")))
  (princ (strcat "\n  характерные линии   : "
                 (if (gc-kg-ss-len (gc-kg-get "lines"))
                   (itoa (gc-kg-ss-len (gc-kg-get "lines"))) "нет")))
  (princ (strcat "\n  отметки             : стиль " (gc-kg-get "style")
                 ", высота " (gc-kg-get "h-mark") " м"
                 ", точность " (nth (gc-kg-get "p-mark") *gc-kg-prec*)
                 ", разделитель "
                 (if (= "1" (gc-kg-get "sep")) "точка" "запятая")
                 (if (= "1" (gc-kg-get "wsign"))
                   ", плюс = ВЫЕМКА" ", плюс = насыпь")))
  (princ (strcat "\n  объёмы              : высота " (gc-kg-get "h-vol") " м"
                 ", точность " (nth (gc-kg-get "p-vol") *gc-kg-prec*)))
  (if (= "1" (gc-kg-get "use-min"))
    (princ (strcat "\n  порог объёма        : " (gc-kg-get "min-vol") " м3")))
  (princ))

;;; --------------------------------------------------------------------
;;; ЭТАП 3. ПОДПИСИ ОТМЕТОК В УЗЛАХ
;;;
;;; В каждом узле сетки три числа:
;;;   красная  - проектная отметка, сверху;
;;;   чёрная   - существующая, снизу;
;;;   рабочая  - справа, ЦВЕТОМ ПО ЗНАКУ.
;;;
;;; Знак рабочей цветом - требование спеки, и оно по делу: узлов на
;;; площадке сотни, и разбирать знак чтением каждого числа невозможно.
;;;
;;; Узлы берутся у ПОСТРОЕННОЙ сетки, а не считаются заново: подписывается
;;; ровно то, что нарисовано, и расхождению взяться неоткуда.
;;; --------------------------------------------------------------------

;; Число с нужной точностью и нужным разделителем.
(defun gc-kg-fmt-p (x prec sep / s i out ch)
  (setq s (rtos x 2 prec) out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq out (strcat out (if (= ch ".") (if (= sep "1") "." ",") ch)))
    (setq i (1+ i)))
  out)

;; Текст в точке. Выравнивание: 0 влево, 1 по центру, 2 вправо.
;; Группа 72/73 и точка 11 - выравнивание идёт по ней, а не по 10
;; (docs/pitfalls.md -> П2: со стилем фиксированной высоты и аннотативным
;; текст ведёт себя иначе, поэтому высоту задаём явно).
(defun gc-kg-text (p txt h col lay stl just / d)
  (setq d (list '(0 . "TEXT") '(100 . "AcDbEntity")
                (cons 8 lay) (cons 62 col)
                '(100 . "AcDbText")
                (cons 10 p) (cons 11 p)
                (cons 40 h) (cons 1 txt)
                (cons 7 (if stl stl "Standard"))
                (cons 72 (cond ((= just 1) 1) ((= just 2) 2) (T 0)))
                '(73 . 0)))
  (entmake d))

;; Точки подписи: узлы сетки И вершины краевых контуров.
;;
;; Одних узлов сетки мало. У краевого квадрата углы лежат СНАРУЖИ границы,
;; отметок там нет, и "маленькие кусочки" оставались неподписанными -
;; а в них тоже считается объём. Поэтому берём ещё и вершины обрезанного
;; контура: это те самые точки, где граница пересекает линии сетки.
;;
;; Возвращает список точек в системе сетки, без повторов.
(defun gc-kg-label-pts (cells sx sy / out key seen c i j ar full p k)
  (setq out nil seen nil)
  (foreach c cells
    (setq i (car c) j (cadr c) ar (nth 2 c))
    (setq full (> ar (- (* sx sy) (* 1.0e-6 sx sy))))
    ;; углы квадрата - для целых квадратов их достаточно
    (foreach nd (list (cons i j) (cons (1+ i) j)
                      (cons (1+ i) (1+ j)) (cons i (1+ j)))
      (setq p (list (* (car nd) sx) (* (cdr nd) sy)))
      (setq key (strcat (rtos (car p) 2 4) "|" (rtos (cadr p) 2 4)))
      (if (not (member key seen))
        (progn (setq seen (cons key seen)) (setq out (cons p out)))))
    ;; у краевого квадрата - ещё и вершины его обрезанного контура
    (if (not full)
      (foreach lp (cons (nth 4 c) (nth 5 c))
        (if (listp lp)
          (foreach p lp
            (if (and (listp p) (numberp (car p)))
              (progn
                (setq key (strcat (rtos (car p) 2 4) "|" (rtos (cadr p) 2 4)))
                (if (not (member key seen))
                  (progn (setq seen (cons key seen))
                         (setq out (cons p out)))))))))))
  (reverse out))

;; Уникальные узлы построенной сетки: список пар (i . j).
;; Ячейка (i j) владеет четырьмя узлами, соседние ячейки их делят -
;; поэтому собираем без повторов, иначе каждая подпись легла бы дважды
;; и на печати вышла бы жирной кашей.
(defun gc-kg-nodes (cells / seen key out i j)
  (setq seen nil out nil)
  (foreach c cells
    (setq i (car c) j (cadr c))
    (foreach nd (list (cons i j) (cons (1+ i) j)
                      (cons (1+ i) (1+ j)) (cons i (1+ j)))
      (setq key (strcat (itoa (car nd)) "," (itoa (cdr nd))))
      (if (not (member key seen))
        (progn (setq seen (cons key seen))
               (setq out (cons nd out))))))
  (reverse out))

;; Подписать отметки в узлах построенной сетки.
;;
;; РАСПОЛОЖЕНИЕ по образцу:
;;
;;     +5,23  13,23      <- слева рабочая, справа сверху СУЩЕСТВУЮЩАЯ
;;             8,00      <- справа снизу ПРОЕКТНАЯ
;;
;; 13,23 - 8,00 = +5,23: плюс означает выемку, землю срезают.
;; Все три числа одной высоты - так в образце.
(defun gc-kg-label ( / cells par base ang sx sy pts lay stl h prec sep
                       wsg p w zb zr hw col cnt skip cls hx)
  (setq cells *gc-kg-cells* par *gc-kg-grid-par*)
  (cond
    ((or (null cells) (null par))
     (princ "\n[!] Сетки нет - сначала постройте её.")
     nil)
    ((or (null *gc-kg-sb*) (null *gc-kg-sr*))
     (princ "\n[!] Поверхности не выбраны - отметки взять неоткуда.")
     nil)
    (T
     (setq base (car par) ang (cadr par) sx (caddr par) sy (cadddr par))
     (gc-kg-set-frame base ang)
     (setq pts (gc-kg-label-pts cells sx sy))
     (setq lay  (gc-kg-layer "GC-Картограмма-Отметки" 7)
           stl  (gc-kg-get "style")
           h    (gc-kg-num (gc-kg-get "h-mark"))
           prec (gc-kg-get "p-mark")
           sep  (gc-kg-get "sep")
           wsg  (gc-kg-get "wsign"))
     (if (or (null h) (<= h 0.0)) (setq h 0.5))
     (if (not (numberp prec)) (setq prec 2))
     (setq hx h)                   ; все три числа одной высоты
     (princ (strcat "\n[i] Точек для подписи: " (itoa (length pts))
                    ". Считаю отметки..."))
     (setq cnt 0 skip 0)
     (setvar "CMDECHO" 0)
     (command "_.UNDO" "_BEGIN")
     (foreach w pts
       (setq p (gc-kg-to-wcs w))
       (setq zb (gc-kg-elev *gc-kg-sb* (car p) (cadr p)))
       (setq zr (gc-kg-elev *gc-kg-sr* (car p) (cadr p)))
       (if (and zb zr)
         (progn
           ;; Знак по выбранной конвенции.
           (setq hw (if (= wsg "1") (- zb zr) (- zr zb)))
           (setq cls (gc-kg-work-class hw))
           (setq col (cond
                       ((= cls "ZERO") (gc-kg-get "c-wzero"))
                       ((= cls "CUT")  (gc-kg-get "c-wminus"))
                       (T              (gc-kg-get "c-wplus"))))
           ;; рабочая - слева от точки, прижата к ней правым краем
           (gc-kg-text (list (- (car p) (* 0.15 h)) (+ (cadr p) (* 0.15 h)))
                       (strcat (if (= cls "FILL") "+" "") (gc-kg-fmt-p hw prec sep))
                       h col lay stl 2)
           ;; справа сверху СУЩЕСТВУЮЩАЯ, справа снизу ПРОЕКТНАЯ
           (gc-kg-text (list (+ (car p) (* 0.15 h)) (+ (cadr p) (* 0.15 h)))
                       (gc-kg-fmt-p zb prec sep) hx
                       (gc-kg-get "c-black") lay stl 0)
           (gc-kg-text (list (+ (car p) (* 0.15 h)) (- (cadr p) (* 1.05 h)))
                       (gc-kg-fmt-p zr prec sep) hx
                       (gc-kg-get "c-red") lay stl 0)
           (setq cnt (1+ cnt)))
         (setq skip (1+ skip))))
     (command "_.UNDO" "_END")
     (princ "\n\n--- ОТМЕТКИ ПОДПИСАНЫ ---")
     (princ (strcat "\n  точек подписано  : " (itoa cnt)))
     (if (> skip 0)
       (princ (strcat "\n  пропущено        : " (itoa skip)
                      "  (одна из поверхностей не дала отметку)")))
     (princ (strcat "\n  слой             : " lay))
     (princ (strcat "\n  высота текста    : " (gc-kg-fmt h) " м"
                    ", точность " (itoa prec) " знака"))
     (princ (strcat "\n  разделитель      : "
                    (if (= sep "1") "точка" "запятая")))
     (princ (strcat "\n  знак рабочей     : "
                    (if (= wsg "1")
                      "плюс = ВЫЕМКА (существующая минус проектная)"
                      "плюс = насыпь (проектная минус существующая)")))
     (princ "\n  расположение     : слева рабочая, справа сверху существующая,")
     (princ "\n                     справа снизу проектная")
     (princ "\n[i] Один Ctrl+Z убирает все подписи.")
     T)))

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
(defun gc-kg-probe-one (p s-blk s-red / zb zr h ins)
  (setq zb (gc-kg-elev s-blk (car p) (cadr p)))
  (setq zr (gc-kg-elev s-red (car p) (cadr p)))
  (setq ins (and zb zr))
  (if ins
    (foreach c *gc-kg-outer*
      (if (and ins (not (gc-kg-in-poly p c))) (setq ins nil))))
  (if ins
    (foreach hh *gc-kg-holes*
      (if (and ins (gc-kg-in-poly p hh)) (setq ins nil))))
  (princ (strcat "\n  чёрная  " (gc-kg-z zb)
                 "   красная " (gc-kg-z zr)))
  ;; Границу печатаем отдельной строкой: когда область выходит не той,
  ;; виновата чаще всего забытая с прошлого запуска граница, а не поверхности.
  (if *gc-kg-outer*
    (princ (strcat "\n  наружные границы (" (itoa (length *gc-kg-outer*)) "): точка "
                   (if (vl-every '(lambda (c) (gc-kg-in-poly p c)) *gc-kg-outer*)
                     "внутри всех" "СНАРУЖИ хотя бы одной"))))
  (princ (strcat "\n  -> " (if ins "ВНУТРИ области" "ВНЕ области")))
  (cond
    ((and zb zr)
     (setq h (- zr zb))
     (princ (strcat "   рабочая " (gc-kg-work-str h)))
     T)
    (T
     (princ "\n  [!] Точка вне одной из поверхностей - рабочая не считается.")
     nil)))

;; Цикл проверки. Возвращает T, если хоть одна точка прочиталась.
(defun gc-kg-probe ( / s-blk s-red p ok any why)
  (setq s-blk (gc-kg-surf-obj (gc-kg-get "s-black"))
        s-red (gc-kg-surf-obj (gc-kg-get "s-red")))
  (gc-kg-load-bounds)
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

;; Внутри ли точка замкнутого контура. Метод луча: считаем, сколько раз
;; горизонтальный луч из точки пересёк стороны. Нечётное число - внутри.
;;
;; Годится для любого контура, включая вогнутый, и не требует ни COM,
;; ни разбора направления обхода.
(defun gc-kg-in-poly (p pts / n i a b c ia ib res)
  (setq n (length pts) res nil i 0)
  (setq a (nth (1- n) pts))
  (while (< i n)
    (setq b (nth i pts))
    ;; Сторона пересекает горизонталь точки, если её концы по разные
    ;; стороны от неё. Сравниваем через eq, а не через /= : в AutoLISP
    ;; /= сравнивает ЧИСЛА, и на T/nil он падает.
    (setq ia (> (cadr a) (cadr p))
          ib (> (cadr b) (cadr p)))
    (if (and (not (eq (not ia) (not ib)))
             (/= (cadr b) (cadr a)))
      (progn
        (setq c (+ (car a) (/ (* (- (car b) (car a)) (- (cadr p) (cadr a)))
                              (- (cadr b) (cadr a)))))
        (if (< (car p) c) (setq res (not res)))))
    (setq a b)
    (setq i (1+ i)))
  res)

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

;; Контур площадки, если он выбран в окне вручную. nil, если не выбран —
;; тогда область берётся по поверхностям, спрашивать нечего.
(defun gc-kg-outer-pts ( / ss n i out pts)
  (setq ss (gc-kg-get "outer") out nil n (gc-kg-ss-len ss))
  (if (and ss (null n))
    (princ "\n[!] Выбор наружных границ устарел - укажите заново."))
  (if n
    (progn
      (setq i 0)
      (while (< i n)
        (setq pts (gc-kg-ent-pts (ssname ss i)))
        (if (and pts (> (length pts) 2))
          (setq out (cons pts out))
          (princ "\n[!] Одна из выбранных границ не читается как замкнутый контур."))
        (setq i (1+ i)))))
  (reverse out))

;; Внутренние границы-исключения списком контуров.
(defun gc-kg-load-bounds ( / )
  (setq *gc-kg-outer* (gc-kg-outer-pts)
        *gc-kg-holes* (gc-kg-holes-pts))
  (princ))

(defun gc-kg-holes-pts ( / ss n i out pts)
  (setq ss (gc-kg-get "inner") out nil n (gc-kg-ss-len ss))
  (if n
    (progn
      (setq i 0)
      (while (< i n)
        (setq pts (gc-kg-ent-pts (ssname ss i)))
        (if (and pts (> (length pts) 2)) (setq out (cons pts out)))
        (setq i (1+ i)))))
  (reverse out))

;;; --------------------------------------------------------------------
;;; Точная граница из модуля .NET
;;;
;;; Опрос отметок даёт КРАЙ ПРИБЛИЖЁННО: ломаную по своим точкам, а не
;;; настоящее ребро триангуляции. Модуль .NET отдаёт границу поверхности
;;; как есть, и тогда сетка режется точно (ADR-0008).
;;;
;;; Модуль необязателен. Нет его - идём прежним путём и говорим об этом.
;;; --------------------------------------------------------------------

(defun gc-kg-net-p ( / )
  ;; Ищем имя в таблице символов, и обязательно ЗАГЛАВНЫМИ: atoms-family
  ;; отдаёт имена в верхнем регистре, а сравнение со строчной строкой
  ;; не срабатывало никогда (docs/pitfalls.md -> П46).
  ;;
  ;; ВЫЗЫВАТЬ функцию для проверки НЕЛЬЗЯ. Если её нет, AutoLISP отвечает
  ;; "неверная функция", и это НЕ перехватывается vl-catch-all-apply:
  ;; ошибка происходит до входа в функцию, перехватывать нечего.
  ;; Попытка проверить вызовом уронила команду целиком (П50).
  (if (or (member "GC_SURFACE_BORDER" (atoms-family 1))
          (member "GC_NET_VERSION"    (atoms-family 1)))
    T
    nil))

;; Привести ответ модуля к одному виду: СПИСОК КОНТУРОВ.
;;
;; Модуль отдаёт контуры вложенными списками, но когда контур ОДИН,
;; лишнего уровня не возникает, и на выходе оказывается просто список
;; точек. Разбирать это "как ожидалось" нельзя: попытка зайти на уровень
;; глубже даёт "неверный тип аргумента: consp" с координатой в тексте
;; (docs/pitfalls.md -> П52).
;;
;; Поэтому смотрим на СОДЕРЖИМОЕ, а не на предполагаемую форму.
(defun gc-kg-norm-loops (r)
  (cond
    ((or (null r) (not (listp r))) nil)
    ;; список контуров: первый элемент - список, и внутри него тоже список
    ((and (listp (car r)) (listp (car (car r))))
     (mapcar '(lambda (lp) (mapcar 'gc-kg-2d lp)) r))
    ;; один контур: список точек, у точки первый элемент - число
    ((and (listp (car r)) (numberp (car (car r))))
     (list (mapcar 'gc-kg-2d r)))
    (T nil)))

;; Контуры границы поверхности: список списков 2D-точек, либо nil.
;; Первый контур наружный, остальные - внутренние вырезы.
(defun gc-kg-net-border (name / out)
  ;; СНАЧАЛА "plan", потом "model".
  ;;
  ;; Проверка на чертеже (команда KGB) показала: "plan" даёт границу такой,
  ;; какой её видно - с изломами, по настоящему краю. "model" отдаёт грубый
  ;; контур в полтора десятка точек, и сетка по нему срезает углы.
  ;;
  ;; Раньше "model" стоял по умолчанию просто потому, что я так решил,
  ;; и это ни разу не было проверено (docs/pitfalls.md -> П53).
  (setq out (gc-kg-net-border-m name "plan"))
  (if (null out) (setq out (gc-kg-net-border-m name "model")))
  out)

;; То же, но с указанием режима извлечения: nil - как настроено,
;; "plan" - по показанному в плане, "model" - по модели поверхности.
(defun gc-kg-net-border-m (name mode / r out)
  (if (and (gc-kg-net-p) name)
    (progn
      (setq r (if mode
                (vl-catch-all-apply 'gc_surface_border (list name mode))
                (vl-catch-all-apply 'gc_surface_border (list name))))
      (cond
        ((vl-catch-all-error-p r)
         (princ (strcat "\n[!] Модуль не отдал границу \"" name "\": "
                        (vl-catch-all-error-message r)))
         nil)
        ((null r)
         (princ (strcat "\n[!] Модуль вернул пусто для \"" name "\"."))
         nil)
        (T
         (setq out (gc-kg-norm-loops r))
         (if out
           ;; Печатаем и ПЛОЩАДЬ контура: по ней сразу видно, тот ли это
           ;; контур. Число точек о совпадении с чертежом не говорит,
           ;; а площадь сравнима с площадью сетки.
           (princ (strcat "\n[i] Граница \"" name "\" ["
                          (if mode mode "по умолчанию") "]: контуров "
                          (itoa (length out)) ", точек в наружном "
                          (itoa (length (car out)))
                          ", площадь " (gc-kg-fmt (gc-kg-area (car out))) " м2"))
           (princ (strcat "\n[!] Ответ модуля для \"" name
                          "\" не разобран.")))
         out)))
    nil))

;; Собрать ВСЕ точные контуры области и все вырезы.
;;
;; ГЛАВНОЕ ЗДЕСЬ. Раньше из контуров выбирался один - тот, что лежит внутри
;; остальных, - и он объявлялся областью. Это неверно, когда контуры
;; пересекаются краями: у Шамиля красная поверхность местами выходит
;; за зелёную, и "вложенного" контура не существует вовсе.
;;
;; Хуже того, выбранная полилиния так ЗАМЕНЯЛА поверхности, и сетка уходила
;; туда, где второй поверхности нет. Ровно П33, только другим путём.
;;
;; Область - ПЕРЕСЕЧЕНИЕ всех контуров, и ни один из них не главнее других.
;; Возвращает T, если хоть один точный контур есть.
(defun gc-kg-load-clips (sbn srn / bl rl)
  (setq *gc-kg-clips* nil *gc-kg-hcuts* nil
        *gc-kg-clip-src* nil *gc-kg-exact-why* nil
        ;; Пока границ поверхностей нет, их край придётся нащупывать
        ;; опросом отметок. Выбранная полилиния поверхности НЕ заменяет:
        ;; она может выходить за них, и тогда сетка встанет там, где
        ;; второй поверхности нет (docs/pitfalls.md -> П43).
        *gc-kg-need-surf* T)
  ;; Границы поверхностей - если модуль .NET их отдал.
  (if (gc-kg-net-p)
    (progn
      (setq bl (gc-kg-net-border sbn)
            rl (gc-kg-net-border srn))
      (if (car bl)
        (setq *gc-kg-clips* (cons (car bl) *gc-kg-clips*)
              *gc-kg-hcuts* (append (cdr bl) *gc-kg-hcuts*)))
      (if (car rl)
        (setq *gc-kg-clips* (cons (car rl) *gc-kg-clips*)
              *gc-kg-hcuts* (append (cdr rl) *gc-kg-hcuts*)))
      (if (and (car bl) (car rl))
        (setq *gc-kg-clip-src* "границы поверхностей"
              *gc-kg-need-surf* nil)
        (setq *gc-kg-exact-why* "модуль не отдал границы обеих поверхностей")))
    (setq *gc-kg-exact-why* "модуль .NET не загружен"))
  ;; Выбранные полилинии - ещё условия, а не замена предыдущих.
  (if *gc-kg-outer*
    (progn
      (foreach c *gc-kg-outer* (setq *gc-kg-clips* (cons c *gc-kg-clips*)))
      (setq *gc-kg-clip-src*
        (strcat (if *gc-kg-clip-src* (strcat *gc-kg-clip-src* " + ") "")
                "выбранные полилинии (" (itoa (length *gc-kg-outer*)) ")"))
      ;; Границы ОБЕИХ поверхностей заменить может только НЕСКОЛЬКО контуров:
      ;; одна полилиния описывает край одной поверхности и ничего не говорит
      ;; про вторую (docs/pitfalls.md -> П45). Две и больше - пользователь
      ;; описал область сам, и опрос отметок только портит края: он
      ;; отказывает у самой границы поверхности.
      (if (> (length *gc-kg-outer*) 1)
        (setq *gc-kg-need-surf* nil))))
  (setq *gc-kg-hcuts* (append *gc-kg-hcuts* *gc-kg-holes*))
  (if *gc-kg-clips* T nil))

;;; --------------------------------------------------------------------
;;; Рисование;;; --------------------------------------------------------------------
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
;;; Область картограммы
;;;
;;; ГЛАВНОЕ РЕШЕНИЕ ЭТАПА 2: границу выбирать руками не нужно.
;;;
;;; Рабочая отметка существует только там, где ОБЕ поверхности дают отметку.
;;; Значит область картограммы — это их пересечение, и оно уже задано самими
;;; поверхностями. Спрашивать про неё нечего.
;;;
;;; Отсюда же само собой работают границы, добавленные в поверхность: за
;;; границей поверхность отметку не даёт, туда сетка и не пойдёт. Отдельного
;;; выбора границ для этого не требуется.
;;;
;;; КАК ИЩЕТСЯ КРАЙ. Узлы сетки опрашиваются: есть отметка или нет. На
;;; стороне квадрата, где ответ меняется, край ищется делением пополам
;;; с допуском 5 см. Площадь краевого квадрата дополнительно уточняется
;;; дроблением на 4 x 4 — без этого угол границы, попавший внутрь квадрата,
;;; срезался бы прямой (до 3 % площадки на крупном шаге).
;;;
;;; Если наружная граница ВСЁ ЖЕ выбрана в окне, работает второй путь:
;;; обрезка по выбранной полилинии. Пути не смешиваются, и команда вслух
;;; говорит, каким пошла.
;;; --------------------------------------------------------------------

;; Точка из варианта COM. Отдельно, чтобы не городить перехват в перехвате.
(defun gc-kg-pt-of-var (v / r)
  (setq r (vl-catch-all-apply
            '(lambda (x) (vlax-safearray->list (vlax-variant-value x)))
            (list v)))
  (if (vl-catch-all-error-p r) nil r))

;; Габариты COM-объекта: (x0 y0 x1 y1) в МСК либо nil.
(defun gc-kg-bb-of-vla (o / r p1 p2 a b)
  (setq p1 nil p2 nil)
  (setq r (vl-catch-all-apply 'vla-getboundingbox (list o 'p1 'p2)))
  (if (vl-catch-all-error-p r)
    nil
    (progn
      (setq a (gc-kg-pt-of-var p1) b (gc-kg-pt-of-var p2))
      (if (and a b (cadr a) (cadr b))
        (list (min (car a) (car b)) (min (cadr a) (cadr b))
              (max (car a) (car b)) (max (cadr a) (cadr b)))
        nil))))

;; Габариты поверхности по её объекту на чертеже. Запасной путь: не всякая
;; версия Civil 3D отдаёт габариты у объекта из коллекции поверхностей.
(defun gc-kg-bb-of-ent (name / ss i e o nm res)
  (setq res nil)
  (setq ss (ssget "_X" '((0 . "AECC*SURFACE*"))))
  (if ss
    (progn
      (setq i 0)
      (while (and (null res) (< i (sslength ss)))
        (setq o (vl-catch-all-apply 'vlax-ename->vla-object (list (ssname ss i))))
        (if (not (vl-catch-all-error-p o))
          (progn
            (setq nm (gc-kg-com-get o "Name"))
            (if (and (car nm) (= (cdr nm) name))
              (setq res (gc-kg-bb-of-vla o)))))
        (setq i (1+ i)))))
  res)

(defun gc-kg-surf-bb (name obj / bb)
  (setq bb (if obj (gc-kg-bb-of-vla obj) nil))
  (if bb
    (gc-kg-log "габариты" name "у объекта поверхности")
    (progn
      (gc-kg-log "габариты" name "объект поверхности не отдал")
      (setq bb (gc-kg-bb-of-ent name))
      (if bb
        (gc-kg-log "габариты" name "по объекту на чертеже")
        (gc-kg-log "габариты" name "и по чертежу не вышло"))))
  bb)

;; Пересечение габаритов. nil, если поверхности вообще не пересекаются.
(defun gc-kg-bb-and (a b / x0 y0 x1 y1)
  (cond
    ((null a) b)
    ((null b) a)
    (T
     (setq x0 (max (car a)   (car b))   y0 (max (cadr a)   (cadr b))
           x1 (min (caddr a) (caddr b)) y1 (min (cadddr a) (cadddr b)))
     (if (and (> x1 x0) (> y1 y0)) (list x0 y0 x1 y1) nil))))

;; Углы габаритов списком точек.
(defun gc-kg-bb-pts (bb)
  (list (list (car bb)   (cadr bb))   (list (caddr bb) (cadr bb))
        (list (caddr bb) (cadddr bb)) (list (car bb)   (cadddr bb))))

;;; --------------------------------------------------------------------
;;; Опрос поверхностей
;;; --------------------------------------------------------------------

;; Внутри ли точка области картограммы.
;;
;; Область - это ПЕРЕСЕЧЕНИЕ условий, а не выбор одного из них:
;;   1. чёрная поверхность отвечает;
;;   2. красная поверхность отвечает;
;;   3. точка внутри выбранной наружной границы, если она выбрана;
;;   4. точка вне внутренних границ-исключений.
;;
;; Пункт 3 РАНЬШЕ ЗАМЕНЯЛ первые два, а не добавлялся к ним. Забытая
;; с прошлого запуска граница молча отключала поверхности, и сетка уходила
;; туда, где второй поверхности нет (docs/pitfalls.md -> П33).
;;
;; Порядок не случаен: сначала поверхности - они отсекают больше всего,
;; и каждый их ответ стоит обращения к CAD. Проверка контура своя, дешёвая.
(defun gc-kg-node-ok (p / w x y ok)
  (setq w (gc-kg-to-wcs p) x (car w) y (cadr w))
  ;; Есть точные контуры - проверка чисто вычислительная, к CAD не ходим.
  ;; Точка годна, только если она внутри КАЖДОГО контура: область - это
  ;; их пересечение, а не любой из них.
  (if *gc-kg-clips*
    (progn
      (setq ok T)
      (foreach c *gc-kg-clips*
        (if (and ok (not (gc-kg-in-poly w c))) (setq ok nil)))
      (if ok
        (foreach h *gc-kg-hcuts*
          (if (and ok (gc-kg-in-poly w h)) (setq ok nil))))
      ;; Границ поверхностей среди контуров нет - спрашиваем сами
      ;; поверхности. Иначе точка за краем поверхности сойдёт за годную.
      (if (and ok *gc-kg-need-surf*)
        (setq ok (and (gc-kg-elev *gc-kg-sb* x y)
                      (gc-kg-elev *gc-kg-sr* x y))))
      (setq w nil))
    (setq ok (and (gc-kg-elev *gc-kg-sb* x y)
                  (gc-kg-elev *gc-kg-sr* x y))))
  (if (null w) (if ok T nil) (progn
  (if ok
    (foreach c *gc-kg-outer*
      (if (and ok (not (gc-kg-in-poly w c))) (setq ok nil))))
  (if ok
    (foreach h *gc-kg-holes*
      (if (and ok (gc-kg-in-poly w h)) (setq ok nil))))
  (if ok T nil))))

;; Допуск на поиск края, м. Мельче не нужно: сама съёмка грубее.
(setq *gc-kg-edge-tol* 0.05)

;; На сколько частей дробится сторона КРАЕВОГО квадрата при счёте площади.
;;
;; ЗАЧЕМ ЭТО НУЖНО. Прямая, проведённая между двумя точками края на сторонах
;; квадрата, СРЕЗАЕТ угол границы, если он попал внутрь квадрата. Численная
;; проверка: на шаге 20 м это давало до 3 % по всей площадке - для ведомости
;; объёмов недопустимо. Дробление 4 x 4 убирает ошибку до сотых долей
;; процента (docs/pitfalls.md -> П29).
;;
;; Цена - опрос поверхностей в узлах дробления, но только у краевых
;; квадратов, а их порядка периметра, а не площади.
(setq *gc-kg-sub* 4)

;; Сколько делений пополам нужно, чтобы уложиться в допуск.
(defun gc-kg-cross-n (l / n)
  (setq n 1)
  (while (and (> (/ l (expt 2.0 n)) *gc-kg-edge-tol*) (< n 12))
    (setq n (1+ n)))
  n)

;; Край области на отрезке: pin — где данные есть, pout — где их нет.
(defun gc-kg-cross (pin pout / a b m i n)
  (setq a pin b pout n (gc-kg-cross-n (distance pin pout)) i 0)
  (while (< i n)
    (setq m (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))
    (if (gc-kg-node-ok m) (setq a m) (setq b m))
    (setq i (1+ i)))
  ;; Середина последней вилки, а не её внутренний конец: иначе край
  ;; систематически уезжает внутрь и вся площадка выходит меньше.
  (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))

;; Часть фигуры, где есть данные. cs — вершины, vs — признаки.
;; Обход тот же, что в отсечении: вершина берётся, если данные есть, и на
;; каждой смене признака добавляется найденная точка края.
(defun gc-kg-part (cs vs / n k out a b ia ib)
  (setq n (length cs) out nil k 0)
  (while (< k n)
    (setq a  (nth k cs)                 ia (nth k vs)
          b  (nth (rem (1+ k) n) cs)    ib (nth (rem (1+ k) n) vs))
    (if ia (setq out (cons a out)))
    (cond
      ((and ia (not ib)) (setq out (cons (gc-kg-cross a b) out)))
      ((and (not ia) ib) (setq out (cons (gc-kg-cross b a) out))))
    (setq k (1+ k)))
  (reverse out))

;; Строка признаков по узлам от i0 до i1 включительно.
;; Каждый узел опрашивается ОДИН раз, а не по разу на каждый из четырёх
;; квадратов, которым он принадлежит.
(defun gc-kg-row (j i0 i1 sx sy / k out)
  (setq out nil k i0)
  (while (<= k i1)
    (setq out (cons (gc-kg-node-ok (list (* k sx) (* j sy))) out))
    (setq k (1+ k)))
  (reverse out))

;; Все строки узлов сразу. Нужны целиком, чтобы залечить одиночные провалы:
;; по одной строке за раз соседа сверху не видно.
(defun gc-kg-rows (i0 j0 i1 j1 sx sy / j out)
  (setq out nil j j0)
  (while (<= j j1)
    (setq out (cons (gc-kg-row j i0 i1 sx sy) out))
    (princ ".")
    (setq j (1+ j)))
  (reverse out))

;; Залечить одиночные провалы опроса.
;;
;; ЗАЧЕМ. Узел без данных, у которого ВСЕ ЧЕТЫРЕ соседа с данными, — это
;; не дырка в площадке. Дырки размером в один узел не бывает: она была бы
;; меньше шага сетки. Это осечка опроса на ребре триангуляции.
;; Цена осечки несоразмерна: один такой узел превращает ЧЕТЫРЕ соседних
;; квадрата в обрезки, и на чертеже появляются фигуры, которые не 5 x 5
;; посреди нормальной сетки.
;;
;; ОХРАННОЕ УСЛОВИЕ (docs/pitfalls.md -> П17). Лечим только когда заняты
;; все четыре соседа. Настоящая выемка или дырка всегда шире одного узла,
;; значит хотя бы один сосед у неё тоже пустой, и её мы не тронем.
;; Число залеченных узлов печатается — молча данные не досочиняем.
(defun gc-kg-fix-holes (rows / n m j i out row prev cur nxt cnt)
  (setq n (length rows) cnt 0 out nil j 0)
  (while (< j n)
    (setq cur  (nth j rows)
          prev (if (> j 0) (nth (1- j) rows) nil)
          nxt  (if (< j (1- n)) (nth (1+ j) rows) nil))
    (setq m (length cur) row nil i 0)
    (while (< i m)
      (setq row
        (cons
          (cond
            ((nth i cur) T)
            ((and prev nxt (> i 0) (< i (1- m))
                  (nth i prev) (nth i nxt)
                  (nth (1- i) cur) (nth (1+ i) cur))
             (setq cnt (1+ cnt))
             T)
            (T nil))
          row))
      (setq i (1+ i)))
    (setq out (cons (reverse row) out))
    (setq j (1+ j)))
  (setq *gc-kg-holes-fixed* cnt)
  (reverse out))

;; Рамка вокруг площадки двумя углами. Запасной путь, когда габариты
;; поверхностей прочитать не удалось.
;;
;; Углы строятся в ПСК и переводятся в МСК поштучно: если ПСК повёрнута,
;; смешивать координаты до перевода нельзя (docs/pitfalls.md -> П1).
(defun gc-kg-ask-bb ( / p1 p2 pts)
  (setq p1 (getpoint "\nПервый угол рамки: "))
  (if (null p1)
    nil
    (progn
      (setq p2 (getcorner p1 "\nПротивоположный угол: "))
      (if (null p2)
        nil
        (progn
          (setq pts (mapcar '(lambda (q) (gc-kg-2d (trans q 1 0)))
                            (list p1
                                  (list (car p2) (cadr p1))
                                  p2
                                  (list (car p1) (cadr p2)))))
          (gc-kg-bbox pts))))))

;;; --------------------------------------------------------------------
;;; Построение
;;; --------------------------------------------------------------------

;; Предел на число квадратов. Не вкусовщина: при шаге, задетом случайно
;; (0,2 вместо 20), счёт уходит на сотни тысяч объектов и CAD встаёт.
(setq *gc-kg-max-cells* 20000)

;; Части четырёхугольника, где есть данные. Список многоугольников.
(defun gc-kg-quad (cs vs / nv v0 v1 v2 v3)
  (setq v0 (nth 0 vs) v1 (nth 1 vs) v2 (nth 2 vs) v3 (nth 3 vs))
  (setq nv (+ (if v0 1 0) (if v1 1 0) (if v2 1 0) (if v3 1 0)))
  (cond
    ((= nv 0) nil)
    ((= nv 4) (list cs))
    ;; Край прошёл по диагонали: данные в двух противоположных углах.
    ;; Обычный обход дал бы самопересекающийся контур и неверную площадь,
    ;; поэтому квадрат делится диагональю на два треугольника.
    ((or (and v0 v2 (not v1) (not v3))
         (and v1 v3 (not v0) (not v2)))
     (list (gc-kg-part (list (nth 0 cs) (nth 1 cs) (nth 2 cs)) (list v0 v1 v2))
           (gc-kg-part (list (nth 2 cs) (nth 3 cs) (nth 0 cs)) (list v2 v3 v0))))
    (T (list (gc-kg-part cs vs)))))

;; Части краевого квадрата: дробим на K x K и собираем куски с данными.
;; Углы берутся из уже опрошенных узлов сетки, заново не спрашиваются.
(defun gc-kg-cell-parts (x0 y0 sx sy vs / k hx hy a b g row out cs sv)
  (setq k *gc-kg-sub* hx (/ sx k) hy (/ sy k))
  (setq g nil b 0)
  (while (<= b k)
    (setq row nil a 0)
    (while (<= a k)
      (setq row
        (cons
          (cond
            ((and (= a 0) (= b 0)) (nth 0 vs))
            ((and (= a k) (= b 0)) (nth 1 vs))
            ((and (= a k) (= b k)) (nth 2 vs))
            ((and (= a 0) (= b k)) (nth 3 vs))
            (T (gc-kg-node-ok (list (+ x0 (* a hx)) (+ y0 (* b hy))))))
          row))
      (setq a (1+ a)))
    (setq g (cons (reverse row) g))
    (setq b (1+ b)))
  (setq g (reverse g))
  (setq out nil b 0)
  (while (< b k)
    (setq a 0)
    (while (< a k)
      (setq cs (list (list (+ x0 (* a hx))      (+ y0 (* b hy)))
                     (list (+ x0 (* (1+ a) hx)) (+ y0 (* b hy)))
                     (list (+ x0 (* (1+ a) hx)) (+ y0 (* (1+ b) hy)))
                     (list (+ x0 (* a hx))      (+ y0 (* (1+ b) hy)))))
      (setq sv (list (nth a      (nth b      g))
                     (nth (1+ a) (nth b      g))
                     (nth (1+ a) (nth (1+ b) g))
                     (nth a      (nth (1+ b) g))))
      (foreach pp (gc-kg-quad cs sv) (if (> (length pp) 2) (setq out (cons pp out))))
      (setq a (1+ a)))
    (setq b (1+ b)))
  (reverse out))

;;; --------------------------------------------------------------------
;;; Контур краевого квадрата
;;;
;;; ЗАЧЕМ ОТДЕЛЬНАЯ РАБОТА. Площадь краевого квадрата считается дроблением
;;; 4 x 4 (П29), а рисовался он до сих пор ОДНОЙ ПРЯМОЙ между двумя точками
;;; края на сторонах. Из-за этого линия на чертеже не повторяла границу
;;; поверхности: у настоящей границы внутри квадрата есть изломы, а прямая
;;; их срезала. Число было точное, картинка — нет.
;;;
;;; Теперь линия строится по тому же дроблению: берём куски подъячеек
;;; и сшиваем из них ОДИН контур. Внутренние рёбра встречаются дважды
;;; в противоположных направлениях и взаимно уничтожаются, остаётся
;;; внешняя граница.
;;;
;;; ПОЧЕМУ СШИВКА СХОДИТСЯ. Соседние подъячейки делят ребро, и точку края
;;; на нём каждая ищет от ОДНОГО И ТОГО ЖЕ внутреннего конца — деление
;;; пополам детерминировано, значит обе получают одно и то же число.
;;; Поэтому сравнение точек с допуском в микрон надёжно.
;;;
;;; Проверено численно: площадь сшитого контура совпала с суммой площадей
;;; подъячеек на всех проверочных формах.
;;; --------------------------------------------------------------------

;; Рёбра многоугольника парами (начало конец). Нулевые пропускаем.
(defun gc-kg-edges (pts / n i out a b)
  (setq n (length pts) i 0 out nil)
  (while (< i n)
    (setq a (nth i pts) b (nth (rem (1+ i) n) pts))
    (if (> (distance a b) 1.0e-9) (setq out (cons (list a b) out)))
    (setq i (1+ i)))
  out)

;; Есть ли в списке это же ребро, пройденное в обратную сторону.
(defun gc-kg-has-rev (e lst / r)
  (setq r nil)
  (foreach o lst
    (if (and (null r)
             (equal (car e)  (cadr o) 1.0e-7)
             (equal (cadr e) (car o)  1.0e-7))
      (setq r T)))
  r)

;; Сшить рёбра в замкнутые контуры. guard от зацикливания на случай,
;; если сшивка всё же разорвётся: лучше вернуть меньше, чем повиснуть.
(defun gc-kg-stitch (edges / loops cur pt nxt rest guard outer)
  (setq loops nil outer 0)
  (while (and edges (< outer 20))
    (setq outer (1+ outer))
    (setq cur (list (car (car edges))) pt (cadr (car edges)) edges (cdr edges))
    (setq guard 0)
    (while (and (not (equal pt (car cur) 1.0e-7)) (< guard 2000))
      (setq guard (1+ guard) nxt nil rest nil)
      (foreach e edges
        (if (and (null nxt) (equal (car e) pt 1.0e-7))
          (setq nxt e)
          (setq rest (cons e rest))))
      (if (null nxt)
        (setq guard 2000)
        (progn
          (setq cur (cons pt cur))
          (setq pt (cadr nxt))
          (setq edges (reverse rest)))))
    (if (> (length cur) 2) (setq loops (cons (reverse cur) loops))))
  (reverse loops))

;; Внешний контур объединения кусков.
(defun gc-kg-outline (parts / all keep)
  (setq all nil)
  (foreach pp parts (setq all (append all (gc-kg-edges pp))))
  (setq keep nil)
  (foreach e all (if (not (gc-kg-has-rev e all)) (setq keep (cons e keep))))
  (gc-kg-stitch (reverse keep)))

;; Квадраты по поверхностям.
;;
;; ПЛОЩАДЬ и ЛИНИЯ считаются по-разному, и это осознанно:
;;   площадь — дроблением 4 x 4, потому что она идёт в объёмы;
;;   линия   — одним контуром по узлам сетки, потому что на чертеже нужен
;;             один чистый квадрат, а не сетка из шестнадцати кусочков.
;; Расхождение между ними — сотые доли процента площади квадрата.
(defun gc-kg-cells-auto (rows i0 j0 i1 j1 sx sy / j i r0 r1 v0 v1 v2 v3
                           c0 c1 c2 c3 cs vs parts sub ar cells nv eps)
  (setq cells nil eps (* 1.0e-6 sx sy))
  (setq j j0)
  (while (< j j1)
    (setq r0 (nth (- j j0) rows)
          r1 (nth (- (1+ j) j0) rows))
    (setq i i0)
    (while (< i i1)
      (setq v0 (nth (- i i0) r0)
            v1 (nth (- (1+ i) i0) r0)
            v2 (nth (- (1+ i) i0) r1)
            v3 (nth (- i i0) r1))
      (setq nv (+ (if v0 1 0) (if v1 1 0) (if v2 1 0) (if v3 1 0)))
      (if (> nv 0)
        (progn
          (setq c0 (list (* i sx)      (* j sy))
                c1 (list (* (1+ i) sx) (* j sy))
                c2 (list (* (1+ i) sx) (* (1+ j) sy))
                c3 (list (* i sx)      (* (1+ j) sy)))
          (setq cs (list c0 c1 c2 c3) vs (list v0 v1 v2 v3))
          (if (= nv 4)
            (setq parts (list cs) ar (* sx sy))
            (progn
              (setq sub (gc-kg-cell-parts (* i sx) (* j sy) sx sy vs))
              (setq ar 0.0)
              (foreach pp sub (setq ar (+ ar (gc-kg-area pp))))
              (setq parts (gc-kg-outline sub))
              ;; Сшивка разорвалась - рисуем грубым контуром и считаем это
              ;; вслух. Молча подсунуть другую фигуру вместо посчитанной
              ;; нельзя: площадь и линия разойдутся, а заметить будет нечем.
              (if (null parts)
                (progn
                  (setq parts (gc-kg-quad cs vs))
                  (setq *gc-kg-outline-fail* (1+ *gc-kg-outline-fail*))))))
          (if (> ar eps)
            (setq cells (cons (list i j ar cs (car parts) (cdr parts)) cells)))))
      (setq i (1+ i)))
    (setq j (1+ j)))
  (reverse cells))

;;; --------------------------------------------------------------------
;;; ТОЧНОЕ ПЕРЕСЕЧЕНИЕ ОБЛАСТЕЙ
;;;
;;; ЗАЧЕМ. Отсечение Сазерленда-Ходгмана точно режет контур квадратом,
;;; но пересечь два произвольных контура между собой не умеет. Раньше
;;; такие квадраты уходили в дробление на подъячейки, и там край
;;; превращался в грубую хорду - на чертеже это видно как срезанные углы
;;; ровно там, где сходятся две границы.
;;;
;;; КАК СДЕЛАНО. Каждый контур один раз режется на ТРЕУГОЛЬНИКИ. Треугольник
;;; выпуклый всегда, а значит отсечение им точное. Пересечение двух областей
;;; внутри квадрата - это сумма пересечений всех пар треугольников.
;;;
;;; ПОЧЕМУ РЕЖЕМ ИСХОДНЫЕ КОНТУРЫ, А НЕ ИХ ОБРЕЗКИ. Обрезка невыпуклого
;;; контура квадратом даёт многоугольник с вырожденными перемычками:
;;; площадь по ней считается верно, а вот треугольники из неё захватывают
;;; лишнее. Проверено численно: так сумма по сетке превышала точное
;;; значение на 0,36 %.
;;;
;;; ПРОВЕРЕНО ЧИСЛЕННО: сумма по ячейкам совпадает с точным пересечением
;;; до нуля, а оно с эталоном Монте-Карло по 3 млн точек - до 0,0008 %.
;;; --------------------------------------------------------------------

;; Площадь СО ЗНАКОМ: по ней определяется направление обхода.
(defun gc-kg-area-s (pts / s a b)
  (setq s 0.0)
  (if (and pts (cddr pts))
    (progn
      (setq a (last pts))
      (foreach b pts
        (setq s (+ s (- (* (car a) (cadr b)) (* (car b) (cadr a)))))
        (setq a b))))
  (/ s 2.0))

;; Обход против часовой стрелки. Отсечение требует известного направления.
(defun gc-kg-ccw (pts)
  (if (< (gc-kg-area-s pts) 0.0) (reverse pts) pts))

;; С какой стороны от прямой a-b лежит точка p.
(defun gc-kg-side (p a b)
  (- (* (- (car b) (car a)) (- (cadr p) (cadr a)))
     (* (- (cadr b) (cadr a)) (- (car p) (car a)))))

;; Точка пересечения отрезка p-q с прямой a-b.
(defun gc-kg-cut (p q a b / d1 d2 kk)
  (setq d1 (gc-kg-side p a b) d2 (gc-kg-side q a b))
  (if (< (abs (- d1 d2)) 1.0e-15)
    q
    (progn
      (setq kk (/ d1 (- d1 d2)))
      (list (+ (car p)  (* kk (- (car q)  (car p))))
            (+ (cadr p) (* kk (- (cadr q) (cadr p))))))))

;; Отсечение произвольного многоугольника ВЫПУКЛЫМ.
(defun gc-kg-clip-cx (subj clip / out cl n i a b inp s sa e se)
  (setq out subj cl (gc-kg-ccw clip) n (length cl) i 0)
  (while (and (< i n) out)
    (setq a (nth i cl) b (nth (rem (1+ i) n) cl))
    (setq inp out out nil s (last inp) sa (gc-kg-side (last inp) a b))
    (foreach e inp
      (setq se (gc-kg-side e a b))
      (cond
        ((>= se -1.0e-9)
         (if (< sa -1.0e-9) (setq out (cons (gc-kg-cut s e a b) out)))
         (setq out (cons e out)))
        ((>= sa -1.0e-9)
         (setq out (cons (gc-kg-cut s e a b) out))))
      (setq s e sa se))
    (setq out (reverse out))
    (setq i (1+ i)))
  out)

;; Векторное произведение: знак говорит о повороте.
(defun gc-kg-cross3 (a b c)
  (- (* (- (car b) (car a)) (- (cadr c) (cadr a)))
     (* (- (cadr b) (cadr a)) (- (car c) (car a)))))

;; Строго ли внутри треугольника.
(defun gc-kg-in-tri (q a b c)
  (and (> (gc-kg-cross3 a b q) 1.0e-9)
       (> (gc-kg-cross3 b c q) 1.0e-9)
       (> (gc-kg-cross3 c a q) 1.0e-9)))

;; Список без элемента с номером k.
(defun gc-kg-drop-nth (k lst / i out)
  (setq i 0 out nil)
  (foreach e lst
    (if (/= i k) (setq out (cons e out)))
    (setq i (1+ i)))
  (reverse out))

;; Разрезать многоугольник на треугольники, отрезая "уши".
;; Ухо - выпуклая вершина, в чей треугольник не попадает ни одна другая.
(defun gc-kg-ear (poly / p tris guard n kk a b c ok)
  (setq p (gc-kg-ccw (gc-kg-dedup poly)) tris nil guard 0)
  (while (and (> (length p) 3) (< guard 2000))
    (setq guard (1+ guard) n (length p) kk 0 ok nil)
    (while (and (< kk n) (null ok))
      (setq a (nth (rem (+ kk (1- n)) n) p)
            b (nth kk p)
            c (nth (rem (1+ kk) n) p))
      (if (> (gc-kg-cross3 a b c) 1.0e-9)
        (progn
          (setq ok T)
          (foreach m p
            (if (and ok
                     (not (equal m a 1.0e-9))
                     (not (equal m b 1.0e-9))
                     (not (equal m c 1.0e-9))
                     (gc-kg-in-tri m a b c))
              (setq ok nil)))
          (if ok
            (progn
              (setq tris (cons (list a b c) tris))
              (setq p (gc-kg-drop-nth kk p))))))
      (if (null ok) (setq kk (1+ kk))))
    ;; Ухо не нашлось - дальше резать нечем, выходим с тем, что есть.
    (if (null ok) (setq guard 2000)))
  (if (= (length p) 3) (setq tris (cons p tris)))
  (reverse tris))

;; Треугольники контура вместе с габаритами: габариты нужны, чтобы
;; не гонять отсечение для каждой пары, а сперва отсеять заведомо далёкие.
(defun gc-kg-tris (poly / out)
  (setq out nil)
  (foreach tr (gc-kg-ear poly)
    (setq out (cons (cons tr (gc-kg-bbox tr)) out)))
  (reverse out))

;; Пересекаются ли габариты с квадратом.
(defun gc-kg-bb-hit (bb x0 y0 x1 y1)
  (not (or (< (caddr bb) x0) (> (car bb) x1)
           (< (cadddr bb) y0) (> (cadr bb) y1))))

;; Квадраты по НЕСКОЛЬКИМ точным контурам.
;;
;; Область квадрата - пересечение всех контуров с ним. Считается точно,
;; через треугольники: дробление на подъячейки больше не нужно.
(defun gc-kg-cells-clip (gc gh i0 j0 i1 j1 sx sy
                         / tris hset i j cx cy cx1 cy1 rect ca eps cells
                           cur parts ar hp hs lo)
  (setq ca (* sx sy) eps (* 1.0e-9 ca) cells nil)
  ;; Треугольники считаем ОДИН раз на всю сетку.
  (setq tris (mapcar 'gc-kg-tris gc))
  (setq hset (mapcar 'gc-kg-tris gh))
  (setq j j0)
  (while (< j j1)
    (setq i i0)
    (while (< i i1)
      (setq cx (* i sx) cy (* j sy) cx1 (+ cx sx) cy1 (+ cy sy))
      (setq rect (list (list cx cy) (list cx1 cy) (list cx1 cy1) (list cx cy1)))
      ;; Начинаем с квадрата и последовательно пересекаем с каждым контуром.
      (setq cur (list rect))
      (foreach tl tris
        (if cur
          (progn
            (setq parts nil)
            (foreach pc cur
              (foreach tb tl
                (if (gc-kg-bb-hit (cdr tb) cx cy cx1 cy1)
                  (progn
                    (setq hp (gc-kg-clip-cx pc (car tb)))
                    (if (> (abs (gc-kg-area-s hp)) eps)
                      (setq parts (cons hp parts)))))))
            (setq cur (reverse parts)))))
      ;; Вырезы: вычитаем их площадь и рисуем отдельно.
      (setq ar 0.0)
      (foreach pc cur (setq ar (+ ar (gc-kg-area pc))))
      (setq hs nil)
      (foreach tl hset
        (foreach tb tl
          (if (gc-kg-bb-hit (cdr tb) cx cy cx1 cy1)
            (foreach pc cur
              (setq hp (gc-kg-clip-cx pc (car tb)))
              (if (> (gc-kg-area hp) eps)
                (progn (setq ar (- ar (gc-kg-area hp)))
                       (setq hs (cons hp hs))))))))
      (if (> ar eps)
        (progn
          ;; Куски сшиваем в один контур: рисовать десяток треугольников
          ;; вместо квадрата нельзя. Сшиваем ОДИН раз - повторный вызов
          ;; и считал бы вдвое, и счётчик отказов задваивал.
          (setq lo (gc-kg-outline-or cur))
          (setq cells (cons (list i j ar rect (car lo) (cdr lo)) cells))))
      (setq i (1+ i)))
    (setq j (1+ j)))
  (reverse cells))

;; Сшить куски в контур, а если не сошлось - вернуть куски как есть
;; и посчитать это вслух.
(defun gc-kg-outline-or (parts / lo)
  (setq lo (gc-kg-outline parts))
  (if lo
    lo
    (progn
      (setq *gc-kg-outline-fail* (1+ *gc-kg-outline-fail*))
      parts)))

;; Отрисовка построенных квадратов.;; Отрисовка построенных квадратов.
(defun gc-kg-draw-cells (cells trim sx sy / lay eps)
  (setq lay (gc-kg-layer "GC-Картограмма-Сетка" 7))
  (setq eps (* 1.0e-6 sx sy))
  (setvar "CMDECHO" 0)
  (command "_.UNDO" "_BEGIN")
  (foreach c cells
    (if (and trim (< (nth 2 c) (- (* sx sy) eps)))
      (progn
        (gc-kg-draw-poly (nth 4 c) lay)
        (foreach h (nth 5 c) (gc-kg-draw-poly h lay)))
      (gc-kg-draw-poly (nth 3 c) lay)))
  (command "_.UNDO" "_END")
  lay)

(defun gc-kg-build ( / sbn srn ang sx sy base trim bb)
  (setq sbn (gc-kg-get "s-black") srn (gc-kg-get "s-red"))
  (setq *gc-kg-sb* (gc-kg-surf-obj sbn)
        *gc-kg-sr* (gc-kg-surf-obj srn))
  (setq ang (gc-kg-num (gc-kg-get "angle")))
  (if (null ang) (setq ang 0.0))
  (setq ang (/ (* pi ang) 180.0))
  (setq sx (gc-kg-num (gc-kg-get "step-x"))
        sy (gc-kg-num (gc-kg-get "step-y")))
  (setq trim (= "1" (gc-kg-get "trim")))
  (gc-kg-load-bounds)
  (setq *gc-kg-holes-fixed* 0 *gc-kg-outline-fail* 0)
  ;; Точная граница, если модуль .NET её отдал. Тогда весь дальнейший
  ;; счёт идёт по многоугольнику, а не по опросу отметок.
  (gc-kg-load-clips sbn srn)
  (cond
    ((or (null *gc-kg-sb*) (null *gc-kg-sr*))
     (princ "\n[!] Выбраны не обе поверхности - область строить не из чего.")
     (princ "\n    Область картограммы задают сами поверхности: она там,")
     (princ "\n    где отметку дают обе. Выберите чёрную и красную в окне.")
     nil)
    (T
     ;; --- габариты области
     ;; Лог чистим: иначе в отчёт попадут записи от подключения к Civil 3D,
     ;; сделанные при открытии окна, и причина утонет среди них.
     (setq *gc-kg-try-log* nil)
     (if *gc-kg-clips*
       ;; Габариты - пересечение габаритов всех контуров: за пределами
       ;; любого из них области нет по определению.
       (foreach c *gc-kg-clips*
         (setq bb (gc-kg-bb-and bb (gc-kg-bbox c))))
       (progn
         (setq bb (gc-kg-bb-and (gc-kg-surf-bb sbn *gc-kg-sb*)
                                (gc-kg-surf-bb srn *gc-kg-sr*)))
         (foreach c *gc-kg-outer*
           (setq bb (gc-kg-bb-and bb (gc-kg-bbox c))))))
     (cond
       ((null bb)
        ;; Габариты нужны только чтобы очертить рамку перебора: внутри неё
        ;; всё решает проверка "точка внутри области". Поэтому отказ здесь
        ;; не повод останавливаться - достаточно, чтобы рамку задал человек.
        (princ "\n[!] Габариты поверхностей не читаются. Что отвечал CAD:")
        (foreach ln (reverse *gc-kg-try-log*) (princ (strcat "\n" ln)))
        (princ "\n[i] Это не мешает счёту: габариты задают только рамку")
        (princ "\n    перебора, а что попадёт в сетку - решают поверхности.")
        (princ "\n    Укажите рамку вокруг площадки двумя углами.")
        (setq bb (gc-kg-ask-bb))
        (if (null bb)
          (progn (princ "\n[i] Рамка не задана - сетка не построена.") nil)
          (gc-kg-build-in bb sbn srn ang sx sy base trim)))
       (T (gc-kg-build-in bb sbn srn ang sx sy base trim))))))

;; Построение в заданных габаритах. Вынесено отдельно, потому что попасть
;; сюда можно двумя путями: габариты прочитались сами либо их задал человек.
(defun gc-kg-build-in (bb sbn srn ang sx sy base trim
                       / ext gbb gp gh i0 j0 i1 j1 nc cells total lay
                         rows nnodes aout)
  (progn
        (setq ext (gc-kg-bb-pts bb))
        ;; --- система координат сетки
        (setq base (gc-kg-get "base"))
        (if (null base)
          (progn
            (gc-kg-set-frame '(0.0 0.0) ang)
            (setq gbb (gc-kg-bbox (mapcar 'gc-kg-to-grid ext)))
            (setq base (gc-kg-to-wcs (list (car gbb) (cadr gbb))))))
        (gc-kg-set-frame base ang)
        (setq gbb (gc-kg-bbox (mapcar 'gc-kg-to-grid ext)))
        (setq i0 (gc-kg-floor (/ (car    gbb) sx))
              j0 (gc-kg-floor (/ (cadr   gbb) sy))
              i1 (gc-kg-ceil  (/ (caddr  gbb) sx))
              j1 (gc-kg-ceil  (/ (cadddr gbb) sy)))
        (setq nc (* (- i1 i0) (- j1 j0)))
        (if (> nc *gc-kg-max-cells*)
          (progn
            (princ (strcat "\n[!] При шаге " (gc-kg-get "step-x") " x "
                           (gc-kg-get "step-y") " м на эту площадку ложится "
                           (itoa nc) " квадратов."))
            (princ (strcat "\n    Предел " (itoa *gc-kg-max-cells*)
                           ". Увеличьте шаг."))
            nil)
          (progn
            (cond
              ;; --- точный путь: область задана многоугольником
              (*gc-kg-clips*
               (if (member "GC_NET_VERSION" (atoms-family 1))
                 (princ (strcat "\n[i] Модуль .NET версии "
                                (vl-princ-to-string (gc_net_version)))))
               (princ (strcat "\n[i] Граница: ТОЧНАЯ, источник - "
                              (if *gc-kg-clip-src* *gc-kg-clip-src* "?")
                              " (контуров: " (itoa (length *gc-kg-clips*)) ")"))
               (if *gc-kg-need-surf*
                 (progn
                   (princ "\n[!] Границ поверхностей нет - их край ищется опросом.")
                   (if *gc-kg-exact-why*
                     (princ (strcat "\n    " *gc-kg-exact-why*)))
                   (princ "\n    Опрос отказывает у самого края поверхности, и по краям")
                   (princ "\n    теряются кусочки. Чтобы считать точно, укажите наружными")
                   (princ "\n    границами ОБА контура - и чёрной, и красной поверхности.")))
               (setq gp (mapcar '(lambda (c) (mapcar 'gc-kg-to-grid c))
                                *gc-kg-clips*))
               (setq gh (mapcar '(lambda (h) (mapcar 'gc-kg-to-grid h))
                                *gc-kg-hcuts*))
               (setq cells (gc-kg-cells-clip gp gh i0 j0 i1 j1 sx sy)))
              ;; --- приближённый: край ищем опросом отметок
              (T
               (princ "\n[i] Граница: приближённая, опросом отметок.")
               (if *gc-kg-exact-why*
                 (princ (strcat "\n    Точную взять не вышло: " *gc-kg-exact-why*)))
               (princ (strcat "\n[i] Область: обе поверхности"
                              (if *gc-kg-outer* " + выбранная наружная граница" "")
                              (if *gc-kg-holes*
                                (strcat " минус внутренние границы ("
                                        (itoa (length *gc-kg-holes*)) ")")
                                "")))
               (setq nnodes (* (1+ (- i1 i0)) (1+ (- j1 j0))))
               (princ (strcat "\n[i] Опрашиваю: " (itoa nnodes) " узлов. "))
               (setq rows (gc-kg-rows i0 j0 i1 j1 sx sy))
               (setq rows (gc-kg-fix-holes rows))
               (setq cells (gc-kg-cells-auto rows i0 j0 i1 j1 sx sy))))
            (if (null cells)
              (progn
                (princ "\n[!] Ни один квадрат не попал в область.")
                (princ "\n    Поверхности не пересекаются по площади, либо")
                (princ "\n    выбранная граница лежит вне их общей области.")
                nil)
              (progn
                (setq total 0.0)
                (foreach c cells (setq total (+ total (nth 2 c))))
                (setq lay (gc-kg-draw-cells cells trim sx sy))
                (setq *gc-kg-cells* cells
                      *gc-kg-grid-par* (list (gc-kg-2d base) ang sx sy))
                (princ "\n\n--- СЕТКА ПОСТРОЕНА ---")
                (princ (strcat "\n  квадратов        : " (itoa (length cells))
                               (if trim "  (краевые обрезаны)"
                                        "  (краевые целые)")))
                (princ (strcat "\n  слой             : " lay
                               "  (цвет по слою, белый)"))
                (princ (strcat "\n  шаг              : " (gc-kg-fmt sx)
                               " x " (gc-kg-fmt sy) " м"))
                (if (> *gc-kg-outline-fail* 0)
                  (princ (strcat "\n  [!] контур не сшился: " (itoa *gc-kg-outline-fail*)
                                 " кв. нарисованы упрощённо")))
                (if (> *gc-kg-holes-fixed* 0)
                  (princ (strcat "\n  залечено узлов   : "
                                 (itoa *gc-kg-holes-fixed*)
                                 "  (одиночные осечки опроса, П31)")))
                (princ (strcat "\n  граница          : "
                               (if *gc-kg-clips*
                                 (strcat "ТОЧНАЯ, " *gc-kg-clip-src*
                                         (if *gc-kg-need-surf*
                                           " + край поверхностей опросом" ""))
                                 "приближённая, опросом")))
                (princ (strcat "\n  площадь по сетке : " (gc-kg-fmt total) " м2"))
                ;; Контроль площади имеет смысл, только когда контур ОДИН:
                ;; площадь пересечения нескольких контуров заранее неизвестна,
                ;; и сравнивать сетку было бы не с чем.
                (if (and *gc-kg-clips* (= 1 (length *gc-kg-clips*)))
                  (progn
                    (setq aout (gc-kg-area (car *gc-kg-clips*)))
                    (foreach h *gc-kg-hcuts* (setq aout (- aout (gc-kg-area h))))
                    (princ (strcat "\n  площадь границы  : " (gc-kg-fmt aout) " м2"))
                    (if (and trim (> aout 1.0e-9))
                      (princ (strcat "\n  расхождение      : "
                                     (gc-kg-fmt (* 100.0 (/ (abs (- total aout)) aout)))
                                     " %  (должно быть около нуля)")))))
                (princ "\n[i] Один Ctrl+Z убирает всю сетку целиком.")
                (princ "\n[i] Дальше — «Отметки»: подпишет чёрную, красную")
                (princ "\n    и рабочую в каждом узле.")
                T))))))

;;; --------------------------------------------------------------------
;;; Меню действий
;;;
;;; Один вопрос, три ответа, Enter всегда что-то делает и говорит что.
;;; Слепых переключателей нет (docs/pitfalls.md -> П23).
;;; --------------------------------------------------------------------

(defun gc-kg-menu ( / k dflt done)
  (setq done nil dflt "Выход")
  (while (not done)
    (initget "Сетка Отметки Проверка Выход")
    (setq k (getkword
              (strcat "\nЧто делаем? [Сетка/Отметки/Проверка/Выход] <" dflt ">: ")))
    (if (null k) (setq k dflt))
    (cond
      ((= k "Сетка")    (gc-kg-build) (setq dflt "Отметки"))
      ((= k "Отметки")  (gc-kg-label) (setq dflt "Выход"))
      ((= k "Проверка") (gc-kg-probe) (setq dflt "Выход"))
      (T (setq done T))))
  (princ))

;;; --------------------------------------------------------------------
;;; Показать границы, полученные от модуля
;;;
;;; Отдельная команда, потому что спор "модуль дал не то" или "мы посчитали
;;; не то" решается только глазами: рисуем ровно то, что вернул модуль,
;;; и сравниваем с настоящей границей поверхности на чертеже.
;;; Гадать по числу точек бесполезно.
;;; --------------------------------------------------------------------

(defun gc-kg-draw-loops (loops lay col / d)
  (gc-kg-layer lay col)
  (foreach lp loops
    (if (> (length lp) 2)
      (progn
        (setq d (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
                      (cons 8 lay) '(100 . "AcDbPolyline")
                      (cons 90 (length lp)) '(70 . 1)))
        (foreach p lp (setq d (append d (list (cons 10 (gc-kg-2d p))))))
        (entmake d)))))

(defun c:kgb ( / sbn srn n)
  (princ "\n\n=== KGB - показать границы поверхностей от модуля ===")
  (if (member "GC_NET_VERSION" (atoms-family 1))
    (princ (strcat "\n[i] Модуль .NET версии "
                   (vl-princ-to-string (gc_net_version))
                   " (для выбора режима нужна 1.1)")))
  (if (not (gc-kg-net-p))
    (princ "\n[!] Модуль .NET не загружен - показывать нечего.")
    (progn
      (gc-kg-defaults)
      (setq *gc-kg-surf-list* (gc-kg-surfaces))
      (setq sbn (gc-kg-get "s-black") srn (gc-kg-get "s-red"))
      (if (or (null sbn) (null srn))
        (princ "\n[!] Сначала выберите поверхности в окне KG.")
        (progn
          (setvar "CMDECHO" 0)
          (command "_.UNDO" "_BEGIN")
          (foreach pair (list (cons sbn "чёрная") (cons srn "красная"))
            (foreach m '("model" "plan")
              (setq n (gc-kg-net-border-m (car pair) m))
              (if n
                (progn
                  (gc-kg-draw-loops n
                    (strcat "GC-Проверка-Граница-" m)
                    (if (= m "model") 4 6))
                  (princ (strcat "\n  " (cdr pair) " [" m "]: контуров "
                                 (itoa (length n)) ", точек "
                                 (itoa (length (car n)))
                                 ", площадь "
                                 (gc-kg-fmt (gc-kg-area (car n))) " м2")))
                (princ (strcat "\n  " (cdr pair) " [" m "]: пусто")))))
          (command "_.UNDO" "_END")
          (princ "\n\n[i] Нарисовано на слоях:")
          (princ "\n    GC-Проверка-Граница-model  (голубой)")
          (princ "\n    GC-Проверка-Граница-plan   (сиреневый)")
          (princ "\n[i] Сравните с настоящей границей поверхности.")
          (princ "\n    Какой из двух совпадает - тот режим и нужен.")
          (princ "\n[i] Один Ctrl+Z убирает всё нарисованное."))))) 
  (princ))

;; K -> Л, G -> П, B -> И
(defun c:лпи ( / ) (c:kgb))

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
  (princ "\n[i] ЭТАП 3 ИЗ 5: сетка квадратов и подписи отметок в узлах.")
  (princ "\n    Выберите в окне две поверхности и нажмите ОК — сетка ляжет")
  (princ "\n    на их общую область сама. Границу выбирать не нужно: рабочая")
  (princ "\n    отметка есть только там, где отметку дают обе поверхности.")
  (princ "\n    Границы, добавленные в саму поверхность, тоже учтутся.")
  (princ "\n    После сетки — «Отметки»: в каждом узле три числа,")
  (princ "\n    красная сверху, чёрная снизу, рабочая справа цветом по знаку.")
  (princ "\n    Объёмы и ведомость — этапы 4–5."))

(defun gc-kg-run ( / )
  (gc-kg-defaults)
  (gc-kg-intro)
  (if (gc-kg-dialog-loop)
    (progn
      (gc-kg-report)
      (princ "\n\n[i] Настройки сохранены до закрытия чертежа.")
      ;; Сетка строится сразу: окно и есть подтверждение. Лишний вопрос
      ;; между «ОК» и результатом ничего не добавляет.
      (gc-kg-build)
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
(princ "\n[gc] kg.lsp v29 загружен. Команды: KG | KGB показать границы | рус. ЛП, ЛПИ")
(princ "\n     Этап 3 из 5: сетка по области поверхностей и подписи отметок.")
(princ)
