// GcSurface.cs -- наш модуль .NET для Civil 3D.
//
// ЗАЧЕМ ОН НУЖЕН.
// Область картограммы кончается там, где кончается поверхность. Из чистого
// AutoLISP эту границу видно только косвенно: опрашиваем отметки в узлах
// и по смене ответа ищем край. Получается ломаная по СВОИМ точкам, а не
// настоящее ребро триангуляции, и на чертеже она с границей не совпадает.
//
// В .NET-интерфейсе Civil 3D есть прямой ответ: поверхность умеет отдать
// свою границу. Одна функция -- и приближение больше не нужно.
//
// ПОЧЕМУ ЭТО НЕ ЛОМАЕТ ADR-0003 (один файл на команду).
// Модуль НЕОБЯЗАТЕЛЕН. Нет его -- команда работает как раньше, приближённо,
// и говорит об этом вслух. Есть -- переходит на точную границу.
//
// ПОЧЕМУ ВЕЗДЕ ПОЛНЫЕ ИМЕНА ТИПОВ, А НЕ using.
// У AutoCAD и Civil 3D совпадают имена в разных пространствах: DBObject,
// Surface, Polyline и другие есть и там, и там. С обычными using компилятор
// не может выбрать и останавливается на первой же строке. Псевдонимы
// AcDb/CivDb снимают это раз и навсегда, а не по одному типу за проход.
//
// Собирается без Visual Studio и без SDK от Autodesk: это делает build.bat
// рядом, компилятор входит в состав Windows.

using System;
using System.Collections.Generic;
using AcApp = Autodesk.AutoCAD.ApplicationServices;
using AcDb = Autodesk.AutoCAD.DatabaseServices;
using AcGe = Autodesk.AutoCAD.Geometry;
using AcRx = Autodesk.AutoCAD.Runtime;
using CivApp = Autodesk.Civil.ApplicationServices;
using CivDb = Autodesk.Civil.DatabaseServices;

// CommandClass намеренно НЕ объявлен. Этот атрибут ограничивает список
// типов, которые AutoCAD сканирует при загрузке, а команд ([CommandMethod])
// у нас нет вовсе - только функции для LISP. В заведомо рабочем образце
// для Civil 3D 2021 его тоже нет.

namespace GeoClaude
{
    public class GcSurface
    {
        // Версия печатается по запросу: чтобы не гадать, тот ли файл
        // подгрузился, когда поведение вдруг стало другим.
        private const string Version = "1.1";

        [AcRx.LispFunction("GC_NET_VERSION")]
        public object GcNetVersion(AcDb.ResultBuffer args)
        {
            return Version;
        }

        // (GC_SURFACE_BORDER "имя поверхности" ["plan"|"model"])
        //
        // Возвращает список замкнутых контуров границы поверхности:
        //     ( ((x y) (x y) ...) ((x y) ...) ... )
        // Первый -- наружный, остальные (если есть) -- внутренние вырезы.
        // nil, если поверхность не найдена или граница не читается.
        //
        // Точки отдаются двумерными: картограмма считается в плане, и лишняя
        // координата в LISP только мешала бы -- её пришлось бы отбрасывать
        // на каждом шаге.
        [AcRx.LispFunction("GC_SURFACE_BORDER")]
        public object GcSurfaceBorder(AcDb.ResultBuffer args)
        {
            AcApp.Document doc = AcApp.Application.DocumentManager.MdiActiveDocument;
            if (doc == null) return null;

            string name = FirstString(args);
            if (string.IsNullOrEmpty(name))
            {
                doc.Editor.WriteMessage("\nGC_SURFACE_BORDER: нужно имя поверхности.");
                return null;
            }

            // Режим извлечения. Model - граница по самой модели поверхности,
            // Plan - по тому, что показано в плане. Они РАЗНЫЕ, и какой
            // совпадает с видимой границей, проверяется на чертеже,
            // а не угадывается.
            string mode = SecondString(args);
            Autodesk.Civil.SurfaceExtractionSettingsType kind =
                (mode != null && mode.ToLower().StartsWith("plan"))
                    ? Autodesk.Civil.SurfaceExtractionSettingsType.Plan
                    : Autodesk.Civil.SurfaceExtractionSettingsType.Model;

            AcDb.ObjectId surfId = FindSurface(doc, name);
            if (surfId.IsNull)
            {
                doc.Editor.WriteMessage("\nGC_SURFACE_BORDER: поверхность \"" + name + "\" не найдена.");
                return null;
            }

            List<List<AcGe.Point2d>> loops = new List<List<AcGe.Point2d>>();
            try
            {
                using (doc.LockDocument())
                using (AcDb.Transaction tr = doc.Database.TransactionManager.StartTransaction())
                {
                    // Именно TinSurface, а не базовый Surface: границу
                    // умеет отдавать поверхность по триангуляции, а у нас
                    // как раз такие. Если поверхность другого рода -
                    // говорим об этом прямо, а не падаем.
                    CivDb.TinSurface surf =
                        tr.GetObject(surfId, AcDb.OpenMode.ForRead) as CivDb.TinSurface;
                    if (surf == null)
                    {
                        doc.Editor.WriteMessage(
                            "\nGC_SURFACE_BORDER: \"" + name + "\" - не TIN-поверхность.");
                        tr.Commit();
                        return null;
                    }

                    // Model -- граница такая, какой поверхность ЯВЛЯЕТСЯ,
                    // а не такая, какой её рисует стиль. Нужна именно она:
                    // отметки поверхность даёт ровно внутри неё.
                    AcDb.ObjectIdCollection ids =
                        surf.ExtractBorder(kind);

                    foreach (AcDb.ObjectId id in ids)
                    {
                        AcDb.DBObject o = tr.GetObject(id, AcDb.OpenMode.ForWrite);
                        List<AcGe.Point2d> pts = CurveToPoints(tr, o);
                        if (pts != null && pts.Count > 2) loops.Add(pts);

                        // ExtractBorder кладёт созданные объекты В ЧЕРТЁЖ.
                        // Точки мы уже забрали, поэтому убираем за собой:
                        // иначе каждый запуск оставлял бы пользователю
                        // лишнюю полилинию поверх его работы.
                        o.Erase();
                    }
                    tr.Commit();
                }
            }
            catch (System.Exception ex)
            {
                doc.Editor.WriteMessage("\nGC_SURFACE_BORDER: " + ex.Message);
                return null;
            }

            if (loops.Count == 0) return null;

            // Наружный контур -- самый большой по площади. У поверхности
            // с вырезами контуров несколько, и порядок Civil 3D не обещает.
            loops.Sort(delegate(List<AcGe.Point2d> a, List<AcGe.Point2d> b)
            {
                return Math.Abs(Area(b)).CompareTo(Math.Abs(Area(a)));
            });

            AcDb.ResultBuffer rb = new AcDb.ResultBuffer();
            foreach (List<AcGe.Point2d> loop in loops)
            {
                rb.Add(new AcDb.TypedValue((int)AcRx.LispDataType.ListBegin));
                foreach (AcGe.Point2d p in loop)
                    rb.Add(new AcDb.TypedValue((int)AcRx.LispDataType.Point2d, p));
                rb.Add(new AcDb.TypedValue((int)AcRx.LispDataType.ListEnd));
            }
            return rb;
        }

        // ---------- вспомогательное ----------

        private static string FirstString(AcDb.ResultBuffer args)
        {
            if (args == null) return null;
            foreach (AcDb.TypedValue tv in args.AsArray())
                if (tv.TypeCode == (int)AcRx.LispDataType.Text) return (string)tv.Value;
            return null;
        }

        // Второй текстовый аргумент, если он есть.
        private static string SecondString(AcDb.ResultBuffer args)
        {
            if (args == null) return null;
            int seen = 0;
            foreach (AcDb.TypedValue tv in args.AsArray())
                if (tv.TypeCode == (int)AcRx.LispDataType.Text)
                {
                    seen++;
                    if (seen == 2) return (string)tv.Value;
                }
            return null;
        }

        private static AcDb.ObjectId FindSurface(AcApp.Document doc, string name)
        {
            CivApp.CivilDocument civil = CivApp.CivilApplication.ActiveDocument;
            AcDb.ObjectIdCollection ids = civil.GetSurfaceIds();
            using (AcDb.Transaction tr = doc.Database.TransactionManager.StartTransaction())
            {
                foreach (AcDb.ObjectId id in ids)
                {
                    CivDb.Surface s = tr.GetObject(id, AcDb.OpenMode.ForRead) as CivDb.Surface;
                    if (s != null && string.Equals(s.Name, name, StringComparison.Ordinal))
                    {
                        tr.Commit();
                        return id;
                    }
                }
                tr.Commit();
            }
            return AcDb.ObjectId.Null;
        }

        // Границу Civil 3D отдаёт трёхмерной полилинией. Дуг в ней не бывает
        // (это рёбра треугольников), поэтому хватает вершин.
        private static List<AcGe.Point2d> CurveToPoints(AcDb.Transaction tr, AcDb.DBObject o)
        {
            List<AcGe.Point2d> pts = new List<AcGe.Point2d>();

            AcDb.Polyline3d p3 = o as AcDb.Polyline3d;
            if (p3 != null)
            {
                foreach (AcDb.ObjectId vid in p3)
                {
                    AcDb.PolylineVertex3d v =
                        tr.GetObject(vid, AcDb.OpenMode.ForRead) as AcDb.PolylineVertex3d;
                    if (v != null) pts.Add(new AcGe.Point2d(v.Position.X, v.Position.Y));
                }
                return pts;
            }

            AcDb.Polyline pl = o as AcDb.Polyline;
            if (pl != null)
            {
                for (int i = 0; i < pl.NumberOfVertices; i++)
                {
                    AcGe.Point3d q = pl.GetPoint3dAt(i);
                    pts.Add(new AcGe.Point2d(q.X, q.Y));
                }
                return pts;
            }

            AcDb.Polyline2d p2 = o as AcDb.Polyline2d;
            if (p2 != null)
            {
                foreach (AcDb.ObjectId vid in p2)
                {
                    AcDb.Vertex2d v = tr.GetObject(vid, AcDb.OpenMode.ForRead) as AcDb.Vertex2d;
                    if (v != null) pts.Add(new AcGe.Point2d(v.Position.X, v.Position.Y));
                }
                return pts;
            }

            // Прочие кривые -- снимаем точками по параметру. Запасной путь:
            // граница приходит полилинией, но падать на неожиданном типе
            // нельзя, лучше отдать приближение.
            AcDb.Curve c = o as AcDb.Curve;
            if (c != null)
            {
                double s = c.StartParam, e = c.EndParam;
                int n = 128;
                for (int i = 0; i <= n; i++)
                {
                    AcGe.Point3d q = c.GetPointAtParameter(s + (e - s) * i / n);
                    pts.Add(new AcGe.Point2d(q.X, q.Y));
                }
                return pts;
            }
            return null;
        }

        private static double Area(List<AcGe.Point2d> p)
        {
            double s = 0.0;
            for (int i = 0; i < p.Count; i++)
            {
                AcGe.Point2d a = p[i], b = p[(i + 1) % p.Count];
                s += a.X * b.Y - b.X * a.Y;
            }
            return s / 2.0;
        }
    }
}
