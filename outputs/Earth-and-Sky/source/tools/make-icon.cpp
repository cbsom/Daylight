// Generate a geographic Earth icon from the bundled NASA map.
#include <QCoreApplication>
#include <QImage>
#include <QBuffer>
#include <QDataStream>
#include <QFile>
#include <QPainter>
#include <cmath>
#include <algorithm>

int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);
    if(argc!=3) return 1;
    QImage map(argv[1]);
    if(map.isNull()) return 2;
    constexpr int size=512;
    constexpr double pi=3.14159265358979323846;
    QImage earth(size,size,QImage::Format_ARGB32_Premultiplied);
    earth.fill(Qt::transparent);
    double lat=15*pi/180,lon=10*pi/180;
    int lift[256];
    for(int i=0;i<256;++i) lift[i]=qRound(255*std::min(1.0,1.12*std::pow(i/255.0,.65)));
    for(int y=0;y<size;++y) {
        auto row=reinterpret_cast<QRgb*>(earth.scanLine(y));
        for(int x=0;x<size;++x) {
            double nx=(x+.5-size/2.)/242,ny=(y+.5-size/2.)/242;
            double r2=nx*nx+ny*ny;
            if(r2>=1) continue;
            double z=std::sqrt(1-r2);
            double vx=z*std::cos(lat)*std::cos(lon)-nx*std::sin(lon)+ny*std::sin(lat)*std::cos(lon);
            double vy=z*std::cos(lat)*std::sin(lon)+nx*std::cos(lon)+ny*std::sin(lat)*std::sin(lon);
            double vz=z*std::sin(lat)-ny*std::cos(lat);
            double latitude=std::asin(std::clamp(vz,-1.,1.));
            double longitude=std::atan2(vy,vx);
            int px=std::clamp(int((longitude+pi)/(2*pi)*map.width()),0,map.width()-1);
            int py=std::clamp(int((pi/2-latitude)/pi*map.height()),0,map.height()-1);
            QRgb p=map.pixel(px,py);
            double t=std::clamp((nx+.055)/.11,0.,1.); t=t*t*(3-2*t);
            double light=(1-.88*t)*(.78+.22*z);
            double rim=std::pow(1-z,5)*.32;
            int red=qRound(std::clamp(lift[qRed(p)]*light+rim*20,0.,255.));
            int green=qRound(std::clamp(lift[qGreen(p)]*light+rim*110,0.,255.));
            int blue=qRound(std::clamp(lift[qBlue(p)]*light+rim*235,0.,255.));
            int alpha=qRound(255*std::clamp((1-std::sqrt(r2))*242,0.,1.));
            row[x]=qPremultiply(qRgba(red,green,blue,alpha));
        }
    }
    QString base=QString::fromLocal8Bit(argv[2]);
    if(!earth.save(base+".png")) return 3;
    QList<QByteArray> frames;
    QList<int> sizes={16,24,32,48,64,128,256};
    for(int n:sizes) {
        QByteArray bytes; QBuffer buffer(&bytes); buffer.open(QIODevice::WriteOnly);
        earth.scaled(n,n,Qt::IgnoreAspectRatio,Qt::SmoothTransformation).save(&buffer,"PNG");
        frames.append(bytes);
    }
    QFile ico(base+".ico"); if(!ico.open(QIODevice::WriteOnly)) return 4;
    QDataStream out(&ico); out.setByteOrder(QDataStream::LittleEndian);
    out<<quint16(0)<<quint16(1)<<quint16(sizes.size());
    quint32 offset=6+16*sizes.size();
    for(int i=0;i<sizes.size();++i) {
        int n=sizes[i];
        out<<quint8(n==256?0:n)<<quint8(n==256?0:n)<<quint8(0)<<quint8(0)
           <<quint16(1)<<quint16(32)<<quint32(frames[i].size())<<offset;
        offset+=frames[i].size();
    }
    for(auto frame:frames) out.writeRawData(frame.constData(),frame.size());
    return out.status()==QDataStream::Ok?0:5;
}
