#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QDateTime>
#include <QElapsedTimer>
#include <QTimer>
#include <QPainter>
#include <QPainterPath>
#include <QFile>
#include <QDebug>
#include <QIcon>
#include <cmath>
#include <algorithm>
#include "vendor/astronomy.h"

constexpr double pi = 3.14159265358979323846;
double rad(double d) { return d * pi / 180.0; }
double wrap(double d) { return d - 360.0 * std::floor((d + 180.0) / 360.0); }
double smooth(double a, double b, double x)
{
    double t = std::clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
struct Position
{
    double lat, lon;
};
struct Ephemeris
{
    Position sun, moon;
    double fraction, phase;
};
Ephemeris calculate(QDateTime date)
{
    auto utc = date.toUTC();
    auto d = utc.date();
    auto c = utc.time();
    auto t = Astronomy_MakeTime(d.year(), d.month(), d.day(), c.hour(), c.minute(), c.second() + c.msec() / 1000.0);
    auto rotation = Astronomy_Rotation_EQJ_EQD(&t);
    auto position = [&](astro_body_t body)
    {
        auto vec = Astronomy_GeoVector(body, t, ABERRATION);
        auto eq = Astronomy_EquatorFromVector(Astronomy_RotateVector(rotation, vec));
        if (eq.status != ASTRO_SUCCESS)
            qFatal("Astronomical calculation failed");
        return Position{eq.dec, wrap(15 * (eq.ra - Astronomy_SiderealTime(&t)))};
    };
    auto illum = Astronomy_Illumination(BODY_MOON, t);
    auto phase = Astronomy_MoonPhase(t);
    if (illum.status != ASTRO_SUCCESS || phase.status != ASTRO_SUCCESS)
        qFatal("Moon calculation failed");
    return {position(BODY_SUN), position(BODY_MOON), illum.phase_fraction, phase.angle};
}
double altitudeSine(double lat, double lon, Position sun)
{
    return std::sin(rad(lat)) * std::sin(rad(sun.lat)) +
           std::cos(rad(lat)) * std::cos(rad(sun.lat)) * std::cos(rad(lon - sun.lon));
}
constexpr double visibleSunAltitude = -0.833; // Upper limb plus standard horizon refraction.
Position horizonPosition(Position sun, double angle)
{
    double lat = rad(sun.lat), lon = rad(sun.lon), h = rad(visibleSunAltitude);
    double cx = std::cos(lat) * std::cos(lon), cy = std::cos(lat) * std::sin(lon), cz = std::sin(lat);
    double ex = -std::sin(lon), ey = std::cos(lon);
    double fx = -std::sin(lat) * std::cos(lon), fy = -std::sin(lat) * std::sin(lon), fz = std::cos(lat);
    double x = std::sin(h) * cx + std::cos(h) * (ex * std::cos(angle) + fx * std::sin(angle));
    double y = std::sin(h) * cy + std::cos(h) * (ey * std::cos(angle) + fy * std::sin(angle));
    double z = std::sin(h) * cz + std::cos(h) * fz * std::sin(angle);
    return {std::asin(std::clamp(z, -1.0, 1.0)) * 180 / pi, std::atan2(y, x) * 180 / pi};
}
QImage nightImage(Position sun)
{
    QImage image(1800, 900, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < image.height(); ++y)
    {
        auto row = reinterpret_cast<QRgb *>(image.scanLine(y));
        double lat = 90.0 - (y + 0.5) * 180 / image.height();
        for (int x = 0; x < image.width(); ++x)
        {
            double lon = (x + 0.5) * 360 / image.width() - 180;
            double altitude = std::asin(std::clamp(altitudeSine(lat, lon, sun), -1.0, 1.0)) * 180 / pi;
            // Darkening starts at the visible-Sun horizon, with a rapid initial
            // decline through civil twilight and a gentler fade into full night.
            double depth = visibleSunAltitude - altitude;
            double darkness = depth > 0
                                  ? .33 +
                                    (.30 * smooth(0, 5.167, depth)) + 
                                    (.37 * smooth(0, 17.167, depth))
                                  : 0;
            int alpha = qRound(200 * darkness);
            row[x] = qPremultiply(qRgba(0, 0, 0, alpha));
        }
    }
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(QPen(QColor(200, 200, 204, 40), 1.0));
    QPainterPath boundary;
    QPointF previous;
    for (int i = 0; i <= 2400; ++i)
    {
        auto p = horizonPosition(sun, i * 2 * pi / 2400);
        QPointF point((p.lon + 180) / 360 * image.width(), (90 - p.lat) / 180 * image.height());
        if (i == 0)
            boundary.moveTo(point);
        else if (std::abs(point.x() - previous.x()) > image.width() / 2.0)
        {
            // Split at the date line without a chord across the map.
            bool right = previous.x() > image.width() / 2.0;
            double unwrapped = point.x() + (right ? image.width() : -image.width());
            double edge = right ? image.width() : 0;
            double f = (edge - previous.x()) / (unwrapped - previous.x());
            double y = previous.y() + f * (point.y() - previous.y());
            boundary.lineTo(edge, y);
            boundary.moveTo(right ? 0 : image.width(), y);
            boundary.lineTo(point);
        }
        else
            boundary.lineTo(point);
        previous = point;
    }
    painter.drawPath(boundary);
    return image;
}
const QImage &fullMoonTexture()
{
    static const QImage texture = []
    {
        QImage photo(":/qt/qml/Daylight/assets/moon-full.jpg");
        if (photo.isNull())
            qFatal("Full Moon photograph is missing");
        photo = photo.convertToFormat(QImage::Format_RGB32);
        int left = photo.width(), right = 0, top = photo.height(), bottom = 0;
        for (int y = 0; y < photo.height(); ++y)
        {
            auto row = reinterpret_cast<const QRgb *>(photo.constScanLine(y));
            for (int x = 0; x < photo.width(); ++x)
                if (qGray(row[x]) > 40)
                {
                    left = std::min(left, x);
                    right = std::max(right, x);
                    top = std::min(top, y);
                    bottom = std::max(bottom, y);
                }
        }
        // Remove the photograph's black margins, preserving its original orientation.
        return photo.copy(QRect(QPoint(left, top), QPoint(right, bottom))).scaled(320, 320, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    }();
    return texture;
}
QImage moonImage(double fraction, double phase)
{
    const int size = 160;
    QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    double lightZ = 2 * fraction - 1;
    double lightX = std::sqrt(std::max(0.0, 1 - lightZ * lightZ)) * (phase < 180 ? 1 : -1);
    const auto &photo = fullMoonTexture();
    for (int y = 0; y < size; ++y)
    {
        auto row = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < size; ++x)
        {
            double nx = (x + .5 - size / 2.0) / (size / 2.0 - 3), ny = (y + .5 - size / 2.0) / (size / 2.0 - 3);
            double r2 = nx * nx + ny * ny;
            if (r2 >= 1)
                continue;
            double z = std::sqrt(1 - r2), incidence = nx * lightX + z * lightZ;
            double lit = smooth(-.012, .012, incidence);
            int px = std::clamp(qRound((nx + 1) * .5 * (photo.width() - 1)), 0, photo.width() - 1);
            int py = std::clamp(qRound((ny + 1) * .5 * (photo.height() - 1)), 0, photo.height() - 1);
            QRgb pixel = photo.pixel(px, py);
            double brightness = .07 + .93 * lit;
            int alpha = qRound(255 * std::clamp((1 - std::sqrt(r2)) * size / 2, 0.0, 1.0));
            row[x] = qPremultiply(qRgba(qRound(qRed(pixel) * brightness), qRound(qGreen(pixel) * brightness), qRound(qBlue(pixel) * brightness), alpha));
        }
    }
    return image;
}
QImage sunImage()
{
    QImage image(64, 64, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter p(&image);
    p.setRenderHint(QPainter::Antialiasing);
    QRadialGradient disk(27, 25, 38);
    disk.setColorAt(0, QColor("#fff5d6"));
    disk.setColorAt(1, QColor("#e9c474"));
    p.setPen(QPen(QColor("#fff1c9"), 1));
    p.setBrush(disk);
    p.drawEllipse(QPointF(32, 32), 26, 26);
    return image;
}
QImage dayImage()
{
    QImage image(":/qt/qml/Daylight/assets/world_changed.jpg");
    image = image.convertToFormat(QImage::Format_RGB32);
    int lift[256];
    for (int i = 0; i < 256; ++i)
        lift[i] = qRound(255 * std::min(1.0, 1.10 * std::pow(i / 255.0, .55)));
    for (int y = 0; y < image.height(); ++y)
    {
        auto row = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
        {
            auto p = row[x];
            row[x] = qRgb(lift[qRed(p)], lift[qGreen(p)], lift[qBlue(p)]);
        }
    }
    return image;
}
class Sky : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double sunX READ sunX NOTIFY changed)
    Q_PROPERTY(double sunY READ sunY NOTIFY changed)
    Q_PROPERTY(double moonX READ moonX NOTIFY changed)
    Q_PROPERTY(double moonY READ moonY NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    Ephemeris e;
    QImage day = dayImage(), night, moon, sun = sunImage();
    int version = 0;
    void refresh()
    {
        e = calculate(QDateTime::currentDateTimeUtc());
        night = nightImage(e.sun);
        moon = moonImage(e.fraction, e.phase);
        ++version;
        emit changed();
    }
    double sunX() const { return (e.sun.lon + 180) / 360; }
    double sunY() const { return (90 - e.sun.lat) / 180; }
    double moonX() const { return (e.moon.lon + 180) / 360; }
    double moonY() const { return (90 - e.moon.lat) / 180; }
    int revision() const { return version; }
signals:
    void changed();
};
class Images : public QQuickImageProvider
{
    Sky *sky;

public:
    Images(Sky *s) : QQuickImageProvider(QQuickImageProvider::Image), sky(s) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &) override
    {
        QImage image = id.startsWith("day") ? sky->day : id.startsWith("night") ? sky->night
                                                     : id.startsWith("moon")    ? sky->moon
                                                                                : sky->sun;
        if (size)
            *size = image.size();
        return image;
    }
};
bool selfTest()
{
    auto date = [](const char *s)
    { return QDateTime::fromString(QString::fromLatin1(s), Qt::ISODate); };
    auto equinox = calculate(date("2026-03-20T14:46:00Z"));
    auto june = calculate(date("2026-06-21T08:24:00Z"));
    auto december = calculate(date("2026-12-21T20:50:00Z"));
    auto newMoon = calculate(date("2024-04-08T18:21:00Z"));
    auto fullMoon = calculate(date("2024-03-25T07:00:00Z"));
    bool ok = std::abs(equinox.sun.lat) < .1 && june.sun.lat > 23.3 && june.sun.lat < 23.5 && december.sun.lat < -23.3;
    ok = ok && newMoon.fraction < .001 && fullMoon.fraction > .999;
    auto night = nightImage({0, 0});
    ok = ok && qAlpha(night.pixel(900, 450)) < 2 && qAlpha(night.pixel(0, 450)) > 200;
    ok = ok && std::abs(altitudeSine(0, 90, {0, 0})) < 1e-10;
    auto dark = moonImage(0, 0), full = moonImage(1, 180), wax = moonImage(.5, 90), wane = moonImage(.5, 270);
    ok = ok && qRed(full.pixel(80, 80)) > 50 && qRed(dark.pixel(80, 80)) < 30;
    ok = ok && qRed(wax.pixel(120, 80)) > qRed(wane.pixel(120, 80)) * 5 && qRed(wane.pixel(40, 80)) > qRed(wax.pixel(40, 80)) * 5;
    for (auto sun : {Position{0, 0}, Position{23.44, 179}, Position{-23.44, -179}})
    {
        for (int i = 0; i < 360; ++i)
        {
            auto p = horizonPosition(sun, rad(i));
            ok = ok && std::abs(altitudeSine(p.lat, p.lon, sun) - std::sin(rad(visibleSunAltitude))) < 1e-10;
        }
    }
    qInfo() << "Astronomy, twilight and lunar phase tests:" << (ok ? "PASS" : "FAIL");
    return ok;
}
int main(int argc, char **argv)
{
    QElapsedTimer startup;
    startup.start();
    QGuiApplication app(argc, argv);
    app.setApplicationName("Daylight");
    app.setWindowIcon(QIcon(":/qt/qml/Daylight/assets/daylight.ico"));
    if (app.arguments().contains("--self-test"))
        return selfTest() ? 0 : 1;
    Sky sky;
    sky.refresh();
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("sky", &sky);
    engine.addImageProvider("earth", new Images(&sky));
    engine.loadFromModule("Daylight", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    bool first = true;
    QObject::connect(window, &QQuickWindow::frameSwapped, &app, [&]
                     {
        if(first) { qInfo()<<"First frame:"<<startup.elapsed()<<"ms"; first=false; } }, Qt::QueuedConnection);
    QTimer timer;
    QObject::connect(&timer, &QTimer::timeout, &sky, &Sky::refresh);
    timer.start(10000);
    int capture = app.arguments().indexOf("--capture");
    if (capture >= 0 && capture + 1 < app.arguments().size())
    {
        QString path = app.arguments().at(capture + 1);
        QTimer::singleShot(0, &app, [window, path, &app, &startup]
                           {
            bool ok=window->grabWindow().save(path);
            qInfo()<<"Launch to captured render (including PNG save):"<<startup.elapsed()<<"ms";
            qInfo()<<"Capture:"<<ok; app.exit(ok?0:2); });
    }
    return app.exec();
}
#include "main.moc"
