// GcSurface.cs -- наш модуль .NET для Civil 3D.
//
// ЗАЧЕМ ОН НУЖЕН.
// Область картограммы кончается там, где кончается поверхность. Из чистого
// AutoLISP эту границу видно только косвенно: опрашиваем отметки в узлах
// и по смене ответа ищем край. Получается ломаная по СВОИМ точкам, а не
// настоящее ребро триангуляции, и на чертеже она с границей не совпадает.
//
// В .NET-интерфейсе Civil 3D есть прямой ответ: поверхность умеет отдать
// свою границу набором кривых. Одна функция -- и приближение больше
// не нужно, сетка режется точно.
//
// ПОЧЕМУ ЭТО НЕ ЛОМАЕТ ADR-0003 (один файл на команду).
// Модуль НЕОБЯЗАТЕЛЕН. Нет его -- команда работает как раньше, приближённо,
// и говорит об этом вслух. Есть -- переходит на точную границу.
// Проверка одна: есть ли функция среди загруженных.
//
// СОБИРАЕТСЯ БЕЗ Visual Studio и без SDK от Autodesk: компилятор C# входит
// в состав Windows, а библиотеки берутся из папки установленного Civil 3D.
// Всё это делает build.bat рядом.

using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Civil.ApplicationServices;
using Autodesk.Civil.DatabaseServices;

[assembly: CommandClass(typeof(GeoClaude.GcSurface))]

namespace GeoClaude
{
    public class GcSurface
    {
        // Версия печатается при загрузке: чтобы не гадать, тот ли файл
        // подгрузился, когда поведение вдруг стало другим.
        private const string Version = "1.0";

        [LispFunction("GC_NET_VERSION")]
        public object GcNetVersion(ResultBuffer args)
        {
            return Version;
        }

        // (GC_SURFACE_BORDER "имя поверхности")
        //
        // Возвращает список замкнутых контуров границы поверхности:
        //     ( ((x y) (x y) ...) ((x y) ...) ... )
        // Первый контур -- наружный, остальные (если есть) -- внутренние
        // вырезы. Возвращает nil, если поверхность не найдена.
        //
        // Точки отдаются двумерными: картограмма считается в плане, а лишняя
        // координата в LISP только мешает -- её пришлось бы отбрасывать
        // на каждом шаге.
        [LispFunction("GC_SURFACE_BORDER")]
        public object GcSurfaceBorder(ResultBuffer args)
        {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            if (doc == null) return null;

            string name = FirstString(args);
            if (string.IsNullOrEmpty(name))
            {
                doc.Editor.WriteMessage("\nGC_SURFACE_BORDER: нужно имя поверхности.");
                return null;
            }

            ObjectId surfId = FindSurface(doc, name);
            if (surfId.IsNull)
            {
                doc.Editor.WriteMessage("\nGC_SURFACE_BORDER: поверхность \"" + name + "\" не найдена.");
                return null;
            }

            List<List<Point2d>> loops = new List<List<Point2d>>();
            try
            {
                using (Transaction tr = doc.Database.TransactionManager.StartTransaction())
                {
                    // Model -- граница такая, какой поверхность является,
                    // а не такая, какой её рисует стиль. Именно она нам нужна:
                    // отметки поверхность даёт ровно внутри неё.
                    Surface surf = (Surface)tr.GetObject(surfId, OpenMode.ForRead);
                    using (DBObjectCollection curves =
                               surf.ExtractBorder(SurfaceExtractionSettingsType.Model))
                    {
                        foreach (DBObject o in curves)
                        {
                            List<Point2d> pts = CurveToPoints(o);
                            if (pts != null && pts.Count > 2) loops.Add(pts);
                            o.Dispose();
                        }
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
            // с вырезами их несколько, и порядок Civil 3D не обещает.
            loops.Sort(delegate(List<Point2d> a, List<Point2d> b)
            {
                return Math.Abs(Area(b)).CompareTo(Math.Abs(Area(a)));
            });

            ResultBuffer rb = new ResultBuffer();
            foreach (List<Point2d> loop in loops)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (Point2d p in loop)
                    rb.Add(new TypedValue((int)LispDataType.Point2d, p));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            return rb;
        }

        // ---------- вспомогательное ----------

        private static string FirstString(ResultBuffer args)
        {
            if (args == null) return null;
            foreach (TypedValue tv in args.AsArray())
                if (tv.TypeCode == (int)LispDataType.Text) return (string)tv.Value;
            return null;
        }

        private static ObjectId FindSurface(Document doc, string name)
        {
            CivilDocument civil = CivilApplication.ActiveDocument;
            ObjectIdCollection ids = civil.GetSurfaceIds();
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction())
            {
                foreach (ObjectId id in ids)
                {
                    Surface s = tr.GetObject(id, OpenMode.ForRead) as Surface;
                    if (s != null && string.Equals(s.Name, name, StringComparison.Ordinal))
                    {
                        tr.Commit();
                        return id;
                    }
                }
                tr.Commit();
            }
            return ObjectId.Null;
        }

        // Границу Civil 3D отдаёт трёхмерной полилинией. Дуг в ней не бывает
        // (это рёбра треугольников), поэтому хватает вершин.
        private static List<Point2d> CurveToPoints(DBObject o)
        {
            List<Point2d> pts = new List<Point2d>();

            Polyline3d p3 = o as Polyline3d;
            if (p3 != null)
            {
                using (Transaction tr = p3.Database.TransactionManager.StartTransaction())
                {
                    foreach (ObjectId vid in p3)
                    {
                        PolylineVertex3d v = tr.GetObject(vid, OpenMode.ForRead) as PolylineVertex3d;
                        if (v != null) pts.Add(new Point2d(v.Position.X, v.Position.Y));
                    }
                    tr.Commit();
                }
                return pts;
            }

            Polyline pl = o as Polyline;
            if (pl != null)
            {
                for (int i = 0; i < pl.NumberOfVertices; i++)
                {
                    Point3d q = pl.GetPoint3dAt(i);
                    pts.Add(new Point2d(q.X, q.Y));
                }
                return pts;
            }

            // Прочие кривые -- снимаем точками по длине. Запасной путь:
            // граница приходит полилинией, но падать на неожиданном типе
            // нельзя, лучше отдать приближение и сказать об этом числом точек.
            Curve c = o as Curve;
            if (c != null)
            {
                double s = c.StartParam, e = c.EndParam;
                int n = 128;
                for (int i = 0; i <= n; i++)
                {
                    Point3d q = c.GetPointAtParameter(s + (e - s) * i / n);
                    pts.Add(new Point2d(q.X, q.Y));
                }
                return pts;
            }
            return null;
        }

        private static double Area(List<Point2d> p)
        {
            double s = 0.0;
            for (int i = 0; i < p.Count; i++)
            {
                Point2d a = p[i], b = p[(i + 1) % p.Count];
                s += a.X * b.Y - b.X * a.Y;
            }
            return s / 2.0;
        }
    }
}
