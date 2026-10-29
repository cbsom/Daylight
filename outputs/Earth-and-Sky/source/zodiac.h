#pragma once

#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFont>
#include <vector>

struct ZodiacStar { double ra, dec, magnitude; };
struct ZodiacFigure {
    QString name;
    std::vector<ZodiacStar> stars;
    std::vector<std::pair<int,int>> lines;
};
std::vector<ZodiacFigure> loadConstellationCatalog(const QString& path,int expected) {
        QFile file(path);
        if(!file.open(QIODevice::ReadOnly)) qFatal("Constellation catalog is missing");
        QJsonParseError error;
        auto document=QJsonDocument::fromJson(file.readAll(),&error);
        if(error.error!=QJsonParseError::NoError) qFatal("Invalid constellation catalog JSON");
        std::vector<ZodiacFigure> result;
        for(const auto& value : document.object()["constellations"].toArray()) {
            auto entry=value.toObject();
            ZodiacFigure figure; figure.name=entry["name"].toString();
            for(const auto& starValue : entry["stars"].toArray()) {
                auto star=starValue.toObject();
                figure.stars.push_back({star["ra"].toDouble(),star["dec"].toDouble(),star["magnitude"].toDouble()});
            }
            for(const auto& lineValue : entry["lines"].toArray()) {
                auto line=lineValue.toArray();
                if(line.size()!=2) qFatal("Invalid constellation connection");
                int a=line[0].toInt(-1),b=line[1].toInt(-1);
                if(a<0 || b<0 || a>=int(figure.stars.size()) || b>=int(figure.stars.size()))
                    qFatal("Zodiac connection references an invalid star");
                figure.lines.emplace_back(a,b);
            }
            if(figure.name.isEmpty() || figure.stars.empty() || figure.lines.empty()) qFatal("Empty constellation figure");
            result.push_back(std::move(figure));
        }
        if(int(result.size())!=expected) qFatal("Unexpected constellation count");
        return result;
}
const std::vector<ZodiacFigure>& zodiacCatalog(bool all=false) {
    static const auto zodiac=loadConstellationCatalog(":/qt/qml/EarthSky/data/zodiac.json",12);
    if(!all) return zodiac;
    // The zodiac stays first, preserving its existing frame indexes and rendering.
    static const auto complete=[] {
        auto result=zodiac;
        auto others=loadConstellationCatalog(":/qt/qml/EarthSky/data/constellations.json",76);
        result.insert(result.end(),others.begin(),others.end());
        return result;
    }();
    return complete;
}
struct ZodiacFrame {
    std::vector<std::vector<Position>> figures;
    std::vector<Position> ecliptic;
};
Position vectorSubpoint(astro_vector_t vector,double sidereal) {
    auto eq=Astronomy_EquatorFromVector(vector);
    if(eq.status!=ASTRO_SUCCESS) qFatal("Star coordinate calculation failed");
    return {eq.dec,wrap(15*(eq.ra-sidereal))};
}
ZodiacFrame calculateZodiac(astro_time_t time) {
    ZodiacFrame frame;
    auto rotation=Astronomy_Rotation_EQJ_EQD(&time);
    double sidereal=Astronomy_SiderealTime(&time);
    for(const auto& figure : zodiacCatalog(true)) {
        std::vector<Position> points;
        for(const auto& star : figure.stars) {
            // Reuse one library slot sequentially; there is no eight-star catalog limit.
            // A distant fixed star includes annual aberration without invented parallax.
            auto status=Astronomy_DefineStar(BODY_STAR1,(star.ra<0?star.ra+360:star.ra)/15,star.dec,1000000);
            if(status!=ASTRO_SUCCESS) qFatal("Invalid zodiac star coordinates");
            auto vector=Astronomy_GeoVector(BODY_STAR1,time,ABERRATION);
            points.push_back(vectorSubpoint(Astronomy_RotateVector(rotation,vector),sidereal));
        }
        frame.figures.push_back(std::move(points));
    }
    // True ecliptic of date, transformed into the same equatorial frame as the bodies.
    auto eclipticRotation=Astronomy_Rotation_ECT_EQD(&time);
    for(int i=0;i<=720;++i) {
        double angle=i*pi/360;
        astro_vector_t vector{ASTRO_SUCCESS,std::cos(angle),std::sin(angle),0,time};
        frame.ecliptic.push_back(vectorSubpoint(Astronomy_RotateVector(eclipticRotation,vector),sidereal));
    }
    return frame;
}
QPointF mapPoint(Position point,QSize size) {
    return {(point.lon+180)/360*size.width(),(90-point.lat)/180*size.height()};
}
void drawWrappedSegment(QPainter& painter,QSize size,Position a,Position b) {
    auto start=mapPoint(a,size),end=mapPoint(b,size);
    double width=size.width();
    if(end.x()-start.x()>width/2) end.rx()-=width;
    if(end.x()-start.x()< -width/2) end.rx()+=width;
    for(int copy=-1;copy<=1;++copy) {
        QPointF offset(copy*width,0);
        painter.drawLine(start+offset,end+offset);
    }
}
Position interpolateSky(Position a,Position b,double fraction) {
    // Normalize an interpolated 3D chord to follow the short great-circle arc.
    double x=(1-fraction)*std::cos(rad(a.lat))*std::cos(rad(a.lon))+fraction*std::cos(rad(b.lat))*std::cos(rad(b.lon));
    double y=(1-fraction)*std::cos(rad(a.lat))*std::sin(rad(a.lon))+fraction*std::cos(rad(b.lat))*std::sin(rad(b.lon));
    double z=(1-fraction)*std::sin(rad(a.lat))+fraction*std::sin(rad(b.lat));
    return {std::atan2(z,std::hypot(x,y))*180/pi,std::atan2(y,x)*180/pi};
}
QImage zodiacImage(const ZodiacFrame& frame,QSize size,bool showLabels=true,bool showAll=false) {
    QImage image(size,QImage::Format_ARGB32_Premultiplied); image.fill(Qt::transparent);
    QPainter painter(&image); painter.setRenderHint(QPainter::Antialiasing);
    // Widths and dots are in display pixels, so enlarging the map stays restrained.
    painter.setPen(QPen(QColor(166,166,200,65),.65));
    for(size_t i=1;i<frame.ecliptic.size();++i)
        drawWrappedSegment(painter,size,frame.ecliptic[i-1],frame.ecliptic[i]);
    const auto& catalog=zodiacCatalog(showAll);
    QFont font("Segoe UI"); font.setPixelSize(9); font.setWeight(QFont::Medium);
    painter.setFont(font);
    for(size_t i=0;i<catalog.size();++i) {
        const auto& figure=catalog[i]; const auto& points=frame.figures[i];
        painter.setPen(QPen(QColor(163,169,177,110),.8));
        for(auto [a,b] : figure.lines) {
            auto previous=points[a];
            const double cosine=std::sin(rad(points[a].lat))*std::sin(rad(points[b].lat))+std::cos(rad(points[a].lat))*std::cos(rad(points[b].lat))*std::cos(rad(points[b].lon-points[a].lon));
            const double angle=std::acos(std::clamp(cosine,-1.0,1.0))*180/pi;
            const int segments=std::clamp(int(std::ceil(std::max(angle/2.0,std::abs(wrap(points[b].lon-points[a].lon))/5.0))),1,32);
            for(int step=1;step<=segments;++step) {
                auto next=interpolateSky(points[a],points[b],double(step)/segments);
                drawWrappedSegment(painter,size,previous,next); previous=next;
            }
        }
        painter.setPen(Qt::NoPen); painter.setBrush(QColor(187,192,198,165));
        double sx=0,sy=0,bottom=0;
        for(size_t j=0;j<points.size();++j) {
            auto point=mapPoint(points[j],size);
            double radius=std::clamp(1.35-.14*figure.stars[j].magnitude,.65,1.3);
            for(int copy=-1;copy<=1;++copy) painter.drawEllipse(point+QPointF(copy*size.width(),0),radius,radius);
            sx+=std::cos(rad(points[j].lon)); sy+=std::sin(rad(points[j].lon));
            bottom=std::max(bottom,point.y());
        }
        if(!showLabels) continue;
        double center=(std::atan2(sy,sx)*180/pi+180)/360*size.width();
        // A restrained dark outline preserves grey text over bright terrain.
        double advance=painter.fontMetrics().horizontalAdvance(figure.name);
        for(int copy=-1;copy<=1;++copy) {
            const double labelX=center+copy*size.width()-advance/2;
            if(labelX+advance< -3 || labelX>size.width()+3) continue;
            QPainterPath label;
            label.addText(QPointF(labelX,
                                 std::min(double(size.height()-3),bottom+3+painter.fontMetrics().ascent())),font,figure.name);
            painter.strokePath(label,QPen(QColor(8,15,24,220),2.5,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
            painter.fillPath(label,QColor(180,186,194));
        }
    }
    return image;
}
