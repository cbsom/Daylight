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
#include <QVariantList>
#include <QSettings>
#include <array>
#include <cmath>
#include <algorithm>
#include "vendor/astronomy.h"

constexpr double pi = 3.14159265358979323846;
double rad(double d) { return d*pi/180.0; }
double wrap(double d) { return d - 360.0*std::floor((d+180.0)/360.0); }
double smooth(double a, double b, double x) {
    double t = std::clamp((x-a)/(b-a),0.0,1.0);
    return t*t*(3.0-2.0*t);
}
struct Position { double lat, lon; };
#include "zodiac.h"
struct BodyPosition { Position point; double distance; };
constexpr std::array<astro_body_t,7> bodies={BODY_SUN,BODY_MOON,BODY_MERCURY,BODY_VENUS,BODY_MARS,BODY_JUPITER,BODY_SATURN};
const std::array<const char*,7> bodyNames={"Sun","Moon","Mercury","Venus","Mars","Jupiter","Saturn"};
struct Ephemeris {
    ZodiacFrame zodiac;
    std::array<BodyPosition,7> bodies;
    Position sun, moon;
    double fraction, phase;
};
Ephemeris calculate(QDateTime date) {
    auto utc = date.toUTC(); auto d = utc.date(); auto c = utc.time();
    auto t = Astronomy_MakeTime(d.year(), d.month(), d.day(), c.hour(), c.minute(), c.second()+c.msec()/1000.0);
    auto rotation = Astronomy_Rotation_EQJ_EQD(&t);
    auto position = [&](astro_body_t body) {
        auto vec = Astronomy_GeoVector(body,t,ABERRATION);
        auto eq = Astronomy_EquatorFromVector(Astronomy_RotateVector(rotation,vec));
        if (eq.status != ASTRO_SUCCESS) qFatal("Astronomical calculation failed");
        return BodyPosition{{eq.dec, wrap(15*(eq.ra-Astronomy_SiderealTime(&t)))},eq.dist};
    };
    auto illum = Astronomy_Illumination(BODY_MOON,t);
    auto phase = Astronomy_MoonPhase(t);
    if (illum.status != ASTRO_SUCCESS || phase.status != ASTRO_SUCCESS) qFatal("Moon calculation failed");
    Ephemeris result{};
    result.zodiac=calculateZodiac(t);
    for(size_t i=0;i<bodies.size();++i) result.bodies[i]=position(bodies[i]);
    result.sun=result.bodies[0].point; result.moon=result.bodies[1].point;
    result.fraction=illum.phase_fraction; result.phase=phase.angle;
    return result;
}
double altitudeSine(double lat,double lon,Position sun) {
    return std::sin(rad(lat))*std::sin(rad(sun.lat)) +
        std::cos(rad(lat))*std::cos(rad(sun.lat))*std::cos(rad(lon-sun.lon));
}
constexpr double visibleSunAltitude=-0.833; // Upper limb plus standard horizon refraction.
Position horizonPosition(Position sun, double angle) {
    double lat=rad(sun.lat),lon=rad(sun.lon),h=rad(visibleSunAltitude);
    double cx=std::cos(lat)*std::cos(lon),cy=std::cos(lat)*std::sin(lon),cz=std::sin(lat);
    double ex=-std::sin(lon),ey=std::cos(lon);
    double fx=-std::sin(lat)*std::cos(lon),fy=-std::sin(lat)*std::sin(lon),fz=std::cos(lat);
    double x=std::sin(h)*cx+std::cos(h)*(ex*std::cos(angle)+fx*std::sin(angle));
    double y=std::sin(h)*cy+std::cos(h)*(ey*std::cos(angle)+fy*std::sin(angle));
    double z=std::sin(h)*cz+std::cos(h)*fz*std::sin(angle);
    return {std::asin(std::clamp(z,-1.0,1.0))*180/pi,std::atan2(y,x)*180/pi};
}
QImage nightImage(Position sun) {
    QImage image(1800,900,QImage::Format_ARGB32_Premultiplied);
    for (int y=0;y<image.height();++y) {
        auto row = reinterpret_cast<QRgb*>(image.scanLine(y));
        double lat=90.0-(y+0.5)*180/image.height();
        for (int x=0;x<image.width();++x) {
            double lon=(x+0.5)*360/image.width()-180;
            double altitude=std::asin(std::clamp(altitudeSine(lat,lon,sun),-1.0,1.0))*180/pi;
            // Darkening starts at the visible-Sun horizon, with a rapid initial
            // decline through civil twilight and a gentler fade into full night.
            double depth=visibleSunAltitude-altitude;
            double darkness=.55*smooth(0,5.167,depth)+.45*smooth(0,17.167,depth);
            int alpha = qRound(190*darkness);
            row[x]=qPremultiply(qRgba(1,3,9,alpha));
        }
    }
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(QPen(QColor(200,200,204,40),1.0));
    QPainterPath boundary;
    QPointF previous;
    for(int i=0;i<=2400;++i) {
        auto p=horizonPosition(sun,i*2*pi/2400);
        QPointF point((p.lon+180)/360*image.width(),(90-p.lat)/180*image.height());
        if(i==0) boundary.moveTo(point);
        else if(std::abs(point.x()-previous.x())>image.width()/2.0) {
            // Split at the date line without a chord across the map.
            bool right=previous.x()>image.width()/2.0;
            double unwrapped=point.x()+(right?image.width():-image.width());
            double edge=right?image.width():0;
            double f=(edge-previous.x())/(unwrapped-previous.x());
            double y=previous.y()+f*(point.y()-previous.y());
            boundary.lineTo(edge,y);
            boundary.moveTo(right?0:image.width(),y);
            boundary.lineTo(point);
        } else boundary.lineTo(point);
        previous=point;
    }
    painter.drawPath(boundary);
    return image;
}
const QImage& fullMoonTexture() {
    static const QImage texture=[] {
        QImage photo(":/qt/qml/Daylight/assets/moon-full.jpg");
        if(photo.isNull()) qFatal("Full Moon photograph is missing");
        photo=photo.convertToFormat(QImage::Format_RGB32);
        int left=photo.width(),right=0,top=photo.height(),bottom=0;
        for(int y=0;y<photo.height();++y) {
            auto row=reinterpret_cast<const QRgb*>(photo.constScanLine(y));
            for(int x=0;x<photo.width();++x) if(qGray(row[x])>40) {
                left=std::min(left,x); right=std::max(right,x);
                top=std::min(top,y); bottom=std::max(bottom,y);
            }
        }
        // Remove the photograph's black margins, preserving its original orientation.
        return photo.copy(QRect(QPoint(left,top),QPoint(right,bottom))).scaled(320,320,Qt::IgnoreAspectRatio,Qt::SmoothTransformation);
    }();
    return texture;
}
QImage moonImage(double fraction,double phase) {
    const int size=160;
    QImage image(size,size,QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    double lightZ=2*fraction-1;
    double lightX=std::sqrt(std::max(0.0,1-lightZ*lightZ))*(phase<180?1:-1);
    const auto& photo=fullMoonTexture();
    for(int y=0;y<size;++y) {
        auto row=reinterpret_cast<QRgb*>(image.scanLine(y));
        for(int x=0;x<size;++x) {
            double nx=(x+.5-size/2.0)/(size/2.0-3),ny=(y+.5-size/2.0)/(size/2.0-3);
            double r2=nx*nx+ny*ny;
            if(r2>=1) continue;
            double z=std::sqrt(1-r2), incidence=nx*lightX+z*lightZ;
            double lit=smooth(-.012,.012,incidence);
            int px=std::clamp(qRound((nx+1)*.5*(photo.width()-1)),0,photo.width()-1);
            int py=std::clamp(qRound((ny+1)*.5*(photo.height()-1)),0,photo.height()-1);
            QRgb pixel=photo.pixel(px,py);
            double brightness=.07+.93*lit;
            int alpha=qRound(255*std::clamp((1-std::sqrt(r2))*size/2,0.0,1.0));
            row[x]=qPremultiply(qRgba(qRound(qRed(pixel)*brightness),qRound(qGreen(pixel)*brightness),qRound(qBlue(pixel)*brightness),alpha));
        }
    }
    return image;
}
QImage sunImage() {
    QImage image(64,64,QImage::Format_ARGB32_Premultiplied); image.fill(Qt::transparent);
    QPainter p(&image); p.setRenderHint(QPainter::Antialiasing);
    QRadialGradient disk(27,25,38); disk.setColorAt(0,QColor("#fff5d6")); disk.setColorAt(1,QColor("#e9c474"));
    p.setPen(QPen(QColor("#fff1c9"),1)); p.setBrush(disk); p.drawEllipse(QPointF(32,32),26,26);
    return image;
}
// Stylized disks remain recognizable at map-marker sizes.
QImage planetImage(int index) {
    QImage image(96,96,QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter p(&image); p.setRenderHint(QPainter::Antialiasing);
    const QColor colors[]={QColor("#aaa39b"),QColor("#edcf91"),QColor("#ce7752"),QColor("#d7b895"),QColor("#dccb93")};
    QColor color=colors[index-2];
    if(index==6) {
        p.setPen(QPen(QColor("#b7a77f"),7));
        p.drawEllipse(QPointF(48,48),43,14);
    }
    QRadialGradient disk(37,34,48);
    disk.setColorAt(0,color.lighter(125)); disk.setColorAt(1,color.darker(175));
    p.setPen(QPen(color.lighter(115),1)); p.setBrush(disk);
    QPainterPath outline; outline.addEllipse(QPointF(48,48),29,29);
    p.drawPath(outline);
    p.save(); p.setClipPath(outline);
    if(index==5 || index==6) {
        p.setPen(QPen(color.darker(125),5));
        for(int y : {35,47,61}) p.drawLine(18,y,78,y+3);
    }
    p.restore();
    if(index==6) {
        p.setBrush(Qt::NoBrush); p.setPen(QPen(QColor("#d9c99d"),6));
        p.drawArc(QRectF(5,34,86,28),180*16,180*16);
    }
    return image;
}
QImage dayImage() {
    QImage image(":/qt/qml/Daylight/assets/world_changed.jpg");
    image=image.convertToFormat(QImage::Format_RGB32);
    int lift[256];
    for(int i=0;i<256;++i) lift[i]=qRound(255*std::min(1.0,1.10*std::pow(i/255.0,.55)));
    for(int y=0;y<image.height();++y) {
        auto row=reinterpret_cast<QRgb*>(image.scanLine(y));
        for(int x=0;x<image.width();++x) {
            auto p=row[x]; row[x]=qRgb(lift[qRed(p)],lift[qGreen(p)],lift[qBlue(p)]);
        }
    }
    return image;
}
class Sky : public QObject {
    Q_OBJECT
    Q_PROPERTY(double sunX READ sunX NOTIFY changed)
    Q_PROPERTY(double sunY READ sunY NOTIFY changed)
    Q_PROPERTY(double moonX READ moonX NOTIFY changed)
    Q_PROPERTY(double moonY READ moonY NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QVariantList markers READ markers NOTIFY changed)
    Q_PROPERTY(QString displayedTime READ displayedTime NOTIFY changed)
    Q_PROPERTY(QDateTime displayedUtc READ displayedUtc NOTIFY changed)
    Q_PROPERTY(bool live READ live NOTIFY changed)
    QSettings settings{"Daylight","Daylight"};
    QDateTime displayedInstant;
    bool liveMode=true;
    void renderTime(const QDateTime& instant) {
        displayedInstant=instant;
        e=calculate(instant); night=nightImage(e.sun); moon=moonImage(e.fraction,e.phase);
        ++version; emit changed();
    }
public:
    Q_INVOKABLE bool layerVisible(const QString& key) const {
        return settings.value("visibility/"+key,true).toBool();
    }
    Q_INVOKABLE void setLayerVisible(const QString& key,bool visible) {
        settings.setValue("visibility/"+key,visible);
        settings.sync();
        if(settings.status()!=QSettings::NoError) qWarning()<<"Could not save visibility settings";
    }
    Ephemeris e; QImage day=dayImage(),night,moon,sun=sunImage(); int version=0;
    void refresh() { if(liveMode) renderTime(QDateTime::currentDateTimeUtc()); }
    Q_INVOKABLE void stepDay(int direction) {
        if(direction!= -1 && direction!=1) return;
        // Step from the displayed instant by elapsed seconds, including across DST.
        auto target=displayedInstant.addSecs(qint64(direction)*86400);
        if(!target.isValid()) return;
        liveMode=false; renderTime(target);
    }
    Q_INVOKABLE void goToNow() {
        liveMode=true; renderTime(QDateTime::currentDateTimeUtc());
    }
    bool live() const { return liveMode; }
    QDateTime displayedUtc() const { return displayedInstant; }
    QString displayedTime() const {
        auto local=displayedInstant.toLocalTime();
        int offset=local.offsetFromUtc()/60;
        QString zone=QString("UTC%1%2:%3").arg(offset<0?"-":"+")
            .arg(std::abs(offset)/60,2,10,QLatin1Char('0'))
            .arg(std::abs(offset)%60,2,10,QLatin1Char('0'));
        return local.toString("dd MMM yyyy  HH:mm:ss")+"  ("+zone+")";
    }
    double sunX() const { return (e.sun.lon+180)/360; }
    double sunY() const { return (90-e.sun.lat)/180; }
    double moonX() const { return (e.moon.lon+180)/360; }
    double moonY() const { return (90-e.moon.lat)/180; }
    QVariantList markers() const {
        QVariantList result;
        std::array<int,7> order={0,1,2,3,4,5,6};
        std::sort(order.begin(),order.end(),[&](int a,int b){return e.bodies[a].distance>e.bodies[b].distance;});
        const int sizes[]={28,29,12,15,14,20,25};
        for(int i : order) {
            const auto& body=e.bodies[i];
            result.append(QVariantMap{{"name",QString::fromLatin1(bodyNames[i])},
                {"x",(body.point.lon+180)/360},{"y",(90-body.point.lat)/180},
                {"size",sizes[i]},{"image",i==0?QString("sun"):i==1?QString("moon/")+QString::number(version):QString("planet/")+QString::number(i)}});
        }
        return result;
    }
    int revision() const { return version; }
signals: void changed();
};
class Images : public QQuickImageProvider {
    Sky* sky;
public:
    Images(Sky* s):QQuickImageProvider(QQuickImageProvider::Image),sky(s) {}
    QImage requestImage(const QString &id,QSize *size,const QSize& requestedSize) override {
        if(id.startsWith("zodiac")) {
            auto image=zodiacImage(sky->e.zodiac,requestedSize.isValid()?requestedSize:QSize(1280,640),!id.contains("/no-labels/"));
            if(size) *size=image.size();
            return image;
        }
        QImage image=id.startsWith("planet/")?planetImage(id.section('/',1,1).toInt()):id.startsWith("day")?sky->day:id.startsWith("night")?sky->night:id.startsWith("moon")?sky->moon:sky->sun;
        if(size) *size=image.size(); return image;
    }
};
bool selfTest() {
    auto date=[](const char* s){return QDateTime::fromString(QString::fromLatin1(s),Qt::ISODate);};
    auto equinox=calculate(date("2026-03-20T14:46:00Z"));
    auto june=calculate(date("2026-06-21T08:24:00Z"));
    auto december=calculate(date("2026-12-21T20:50:00Z"));
    auto newMoon=calculate(date("2024-04-08T18:21:00Z"));
    auto fullMoon=calculate(date("2024-03-25T07:00:00Z"));
    bool ok=std::abs(equinox.sun.lat)<.1 && june.sun.lat>23.3 && june.sun.lat<23.5 && december.sun.lat< -23.3;
    ok=ok && newMoon.fraction<.001 && fullMoon.fraction>.999;
    for(const auto& sample : {equinox,june,december,newMoon,fullMoon}) {
        for(const auto& body : sample.bodies)
            ok=ok && std::isfinite(body.point.lat) && std::isfinite(body.point.lon) &&
                std::abs(body.point.lat)<=90 && body.point.lon>=-180 && body.point.lon<180 && body.distance>0;
        ok=ok && sample.bodies[1].distance<sample.bodies[0].distance &&
            sample.bodies[5].distance>sample.bodies[0].distance && sample.bodies[6].distance>sample.bodies[5].distance;
    }
    // Catalog integrity, Earth rotation, true ecliptic, and date-line geometry.
    for(const auto& figure : zodiacCatalog())
        for(const auto& star : figure.stars)
            ok=ok && std::isfinite(star.ra) && std::isfinite(star.dec) &&
                std::abs(star.ra)<=180 && std::abs(star.dec)<=90 && std::isfinite(star.magnitude);
    auto sixHoursLater=calculate(date("2026-03-20T20:46:00Z"));
    for(size_t i=0;i<equinox.zodiac.figures.size();++i) {
        const auto& before=equinox.zodiac.figures[i];
        const auto& after=sixHoursLater.zodiac.figures[i];
        for(size_t j=0;j<before.size();++j)
            ok=ok && std::abs(wrap(after[j].lon-before[j].lon)+90.2464)<.02 &&
                std::abs(after[j].lat-before[j].lat)<.001;
    }
    for(const auto& sample : {equinox,june,december}) {
        double maxDeclination=0,nearestSun=-1;
        for(const auto& point : sample.zodiac.ecliptic) {
            maxDeclination=std::max(maxDeclination,std::abs(point.lat));
            nearestSun=std::max(nearestSun,altitudeSine(point.lat,point.lon,sample.sun));
        }
        ok=ok && maxDeclination>23.3 && maxDeclination<23.5 && nearestSun>std::cos(rad(.3));
        const auto& start=sample.zodiac.ecliptic.front(); const auto& end=sample.zodiac.ecliptic.back();
        ok=ok && std::abs(start.lat-end.lat)<1e-10 && std::abs(wrap(start.lon-end.lon))<1e-10;
    }
    QImage seam(360,180,QImage::Format_ARGB32_Premultiplied); seam.fill(Qt::transparent);
    {
        QPainter painter(&seam); painter.setPen(QPen(Qt::white,1));
        drawWrappedSegment(painter,seam.size(),{0,179},{0,-179});
    }
    ok=ok && qAlpha(seam.pixel(0,90))>0 && qAlpha(seam.pixel(359,90))>0 && qAlpha(seam.pixel(180,90))==0;
    auto midpoint=interpolateSky({0,179},{0,-179},.5);
    ok=ok && std::abs(std::abs(midpoint.lon)-180)<1e-10 && std::abs(midpoint.lat)<1e-10;
    auto night=nightImage({0,0});
    ok=ok && qAlpha(night.pixel(900,450))<2 && qAlpha(night.pixel(0,450))>=190;
    ok=ok && std::abs(altitudeSine(0,90,{0,0}))<1e-10;
    auto dark=moonImage(0,0),full=moonImage(1,180),wax=moonImage(.5,90),wane=moonImage(.5,270);
    ok=ok && qRed(full.pixel(80,80))>50 && qRed(dark.pixel(80,80))<30;
    ok=ok && qRed(wax.pixel(120,80))>qRed(wane.pixel(120,80))*5 && qRed(wane.pixel(40,80))>qRed(wax.pixel(40,80))*5;
    for(auto sun : {Position{0,0},Position{23.44,179},Position{-23.44,-179}}) {
        for(int i=0;i<360;++i) {
            auto p=horizonPosition(sun,rad(i));
            ok=ok && std::abs(altitudeSine(p.lat,p.lon,sun)-std::sin(rad(visibleSunAltitude)))<1e-10;
        }
    }
    qInfo()<<"Astronomy, twilight, lunar phase and zodiac tests:"<<(ok?"PASS":"FAIL");
    return ok;
}
int main(int argc,char**argv) {
    QElapsedTimer startup; startup.start();
    QGuiApplication app(argc,argv); app.setApplicationName("Daylight");
    app.setWindowIcon(QIcon(":/qt/qml/Daylight/assets/daylight.ico"));
    if(app.arguments().contains("--self-test")) return selfTest()?0:1;
    Sky sky; sky.refresh();
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("sky",&sky);
    engine.addImageProvider("earth",new Images(&sky));
    engine.loadFromModule("Daylight","Main");
    if(engine.rootObjects().isEmpty()) return 1;
    auto window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    bool first=true;
    QObject::connect(window,&QQuickWindow::frameSwapped,&app,[&] {
        if(first) { qInfo()<<"First frame:"<<startup.elapsed()<<"ms"; first=false; }
    },Qt::QueuedConnection);
    QTimer timer; QObject::connect(&timer,&QTimer::timeout,&sky,&Sky::refresh); timer.start(10000);
    int capture=app.arguments().indexOf("--capture");
    if(capture>=0 && capture+1<app.arguments().size()) {
        QString path=app.arguments().at(capture+1);
        // Allow the first layout and scene-graph frame before grabbing the window.
        QTimer::singleShot(250,&app,[window,path,&app,&startup]{
            bool ok=window->grabWindow().save(path);
            qInfo()<<"Launch to captured render (including PNG save):"<<startup.elapsed()<<"ms";
            qInfo()<<"Capture:"<<ok; app.exit(ok?0:2);
        });
    }
    return app.exec();
}
#include "main.moc"
