using System.Drawing;
namespace MenuOCR.Core;
public static class SelectionMath
{
    public static Rectangle Normalize(Point start, Point end, Size bounds)
    {
        int x1 = Math.Clamp(start.X, 0, bounds.Width), x2 = Math.Clamp(end.X, 0, bounds.Width);
        int y1 = Math.Clamp(start.Y, 0, bounds.Height), y2 = Math.Clamp(end.Y, 0, bounds.Height);
        return Rectangle.FromLTRB(Math.Min(x1, x2), Math.Min(y1, y2), Math.Max(x1, x2), Math.Max(y1, y2));
    }
}
