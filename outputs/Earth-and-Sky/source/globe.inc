// Included after Sky and GlobeView declarations in main.cpp.
GlobeView::V GlobeView::view(V v) const {
    const double forward=mSy*v.x+mCy*v.z;
    return {mCy*v.x-mSy*v.z,mCp*v.y-mSp*forward,mSp*v.y+mCp*forward};
}
QVariantMap GlobeView::pick(double x,double y) const {
    if(radius()<=0)return {{"valid",false}};
    double u=(x-width()/2)/radius(),v=(height()/2-y)/radius(),r2=u*u+v*v;
    if(r2>1)return {{"valid",false}};
    const double z=std::sqrt(std::max(0.0,1-r2)),a=rad(mYaw),b=rad(mPitch);
    const double forward=-std::sin(b)*v+std::cos(b)*z;
    const double wx=std::cos(a)*u+std::sin(a)*forward;
    const double wy=std::cos(b)*v+std::sin(b)*z;
    const double wz=-std::sin(a)*u+std::cos(a)*forward;
    return {{"valid",true},{"longitude",wrap(std::atan2(wx,wz)*180/pi-(mSky?mSky->earthOffset()*360:0))},
            {"latitude",std::asin(std::clamp(wy,-1.0,1.0))*180/pi}};
}
void GlobeView::mousePressEvent(QMouseEvent* e) {
    mPress=e->position();mPressYaw=mYaw;mPressPitch=mPitch;mDragging=true;mMoved=false;
    setCursor(Qt::ClosedHandCursor);e->accept();
}
void GlobeView::mouseMoveEvent(QMouseEvent* e) {
    if(!mDragging)return;
    auto delta=e->position()-mPress;
    if(std::hypot(delta.x(),delta.y())>4)mMoved=true;
    if(mMoved){setYaw(mPressYaw-delta.x()*.35/mZoom);setPitch(mPressPitch+delta.y()*.35/mZoom);}
    e->accept();
}
void GlobeView::mouseReleaseEvent(QMouseEvent* e) {
    if(mDragging && !mMoved) {
        auto point=pick(e->position().x(),e->position().y());
        if(point["valid"].toBool())emit locationSelected(point["longitude"].toDouble(),point["latitude"].toDouble());
    }
    mDragging=false;setCursor(Qt::OpenHandCursor);invalidate();e->accept();
}
void GlobeView::wheelEvent(QWheelEvent* e) {
    double amount=e->angleDelta().y()!=0?e->angleDelta().y()/120.0:e->pixelDelta().y()/40.0;
    if(amount!=0){setZoom(mZoom*std::pow(1.2,amount));mSettle.start();}
    e->accept();
}
void GlobeView::paintSky(QPainter* p,bool front) {
    if(!mSky)return;
    const auto& catalog=zodiacCatalog(layer("allConstellations"));
    const double skyTurn=mSky->skyOffset()*360;
    auto vectorAt=[&](Position point,double distance){auto v=view(direction(point.lon+skyTurn,point.lat));return V{v.x*distance,v.y*distance,v.z*distance};};
    const auto observer=direction(mObserver.x()+skyTurn,mObserver.y());
    auto worldLine=[&](V a,V b,QColor color,double distance=shell) {
        if(mHorizon) {
            double da=a.x*observer.x+a.y*observer.y+a.z*observer.z;
            double db=b.x*observer.x+b.y*observer.y+b.z*observer.z;
            if(da<0 && db<0)return;
            if(da<0 || db<0) {
                const double t=da/(da-db);
                V edge{a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t};
                const double norm=std::sqrt(edge.x*edge.x+edge.y*edge.y+edge.z*edge.z);
                edge.x/=norm;edge.y/=norm;edge.z/=norm;
                if(da<0)a=edge;else b=edge;
            }
        }
        auto start=view(a),end=view(b);
        if((start.z+end.z>=0)!=front)return;
        color.setAlphaF(color.alphaF()*(front?1.0:.28));p->setPen(QPen(color,.8));
        start.x*=distance;start.y*=distance;end.x*=distance;end.y*=distance;p->drawLine(pixel(start),pixel(end));
    };
    auto line=[&](Position a,Position b,QColor color) { worldLine(direction(a.lon+skyTurn,a.lat),direction(b.lon+skyTurn,b.lat),color); };
    if(layer("zodiac") || layer("allConstellations")) {
        for(size_t i=1;i<mSky->e.zodiac.ecliptic.size();++i)
            line(mSky->e.zodiac.ecliptic[i-1],mSky->e.zodiac.ecliptic[i],QColor(166,166,200,65));
        p->setFont(QFont("Segoe UI",8));
        for(size_t i=0;i<catalog.size();++i) {
            const auto& f=catalog[i];const auto& points=mSky->e.zodiac.figures[i];
            for(auto [a,b]:f.lines) {
                auto start=direction(points[a].lon+skyTurn,points[a].lat),end=direction(points[b].lon+skyTurn,points[b].lat);
                const double angle=std::acos(std::clamp(start.x*end.x+start.y*end.y+start.z*end.z,-1.0,1.0));
                // About 20 screen pixels per chord: smooth arcs without oversampling.
                const int segments=std::clamp(int(std::ceil(angle*shell*radius()/20)),1,96);
                auto prev=start;
                for(int step=1;step<=segments;++step){double t=double(step)/segments;V next{start.x*(1-t)+end.x*t,start.y*(1-t)+end.y*t,start.z*(1-t)+end.z*t};double norm=std::sqrt(next.x*next.x+next.y*next.y+next.z*next.z);next.x/=norm;next.y/=norm;next.z/=norm;worldLine(prev,next,QColor(163,169,177,140));prev=next;}
            }
            V mean{0,0,0};
            for(size_t j=0;j<points.size();++j) {
                auto v=vectorAt(points[j],shell);mean.x+=v.x;mean.y+=v.y;mean.z+=v.z;
                if((v.z>=0)!=front || skyFade(points[j])==0)continue;
                p->setOpacity(skyFade(points[j])*(front?1.0:.28));p->setPen(Qt::NoPen);p->setBrush(QColor(187,192,198,195));
                double size=std::clamp(1.35-.14*f.stars[j].magnitude,.65,1.3);p->drawEllipse(pixel(v),size,size);p->setOpacity(1);
            }
            auto observerView=view(observer);
            const bool labelVisible=!mHorizon || mean.x*observerView.x+mean.y*observerView.y+mean.z*observerView.z>=0;
            if(layer("labels") && labelVisible && (mean.z>=0)==front) {
                double count=points.size();mean.x/=count;mean.y/=count;mean.z/=count;
                auto pos=pixel(mean);p->setOpacity(front?1.0:.22);p->setPen(QColor(184,194,203));
                QRectF text(pos.x()-60,pos.y()+5,120,18);p->drawText(text,Qt::AlignHCenter|Qt::AlignTop,f.name);p->setOpacity(1);
            }
        }
    }
    // The shell carries all bodies at the SAME radius, independently of distance.
    const int sizes[]={28,29,12,15,14,20,25};
    static const std::array<QImage,7> planetTextures={QImage(),QImage(),planetImage(2),planetImage(3),planetImage(4),planetImage(5),planetImage(6)};
    std::array<int,7> order={0,1,2,3,4,5,6};
    std::sort(order.begin(),order.end(),[&](int a,int b){return mSky->e.bodies[a].distance>mSky->e.bodies[b].distance;});
    for(int i:order) {
        if(!(i==0?layer("sun"):i==1?layer("moon"):layer("planets")))continue;
        auto point=mSky->e.bodies[i].point;auto v=vectorAt(point,shell);if((v.z>=0)!=front || skyFade(point)==0)continue;
        auto pos=pixel(v);double size=sizes[i];p->setOpacity(skyFade(point)*(front?1.0:.65));
        const QImage image=i==0?mSky->sun:i==1?mSky->moon:planetTextures[i];
        p->drawImage(QRectF(pos.x()-size/2,pos.y()-size/2,size,size),image);
        if(layer("labels")){p->setFont(QFont("Segoe UI",8));p->setPen(QColor(198,211,221));p->drawText(QRectF(pos.x()-45,pos.y()+size/2+2,90,17),Qt::AlignHCenter,QString::fromLatin1(bodyNames[i]));}
        p->setOpacity(1);
    }
}
void GlobeView::paint(QPainter* p) {
    if(!mSky || width()<2 || height()<2)return;
    p->setRenderHint(QPainter::Antialiasing);p->setRenderHint(QPainter::SmoothPixmapTransform);
    const double r=radius();const QPointF center(width()/2,height()/2);
    p->setPen(QPen(QColor(67,91,112,75),.7));p->setBrush(Qt::NoBrush);if(!mHorizon)p->drawEllipse(center,r*shell,r*shell);
    paintSky(p,false);
    if(mDirty || mGround.isNull()) {
        mGroundRect=QRectF(center.x()-r,center.y()-r,2*r,2*r).intersected(QRectF(0,0,width(),height()));
        const double limit=1000; // Keep the same map detail during motion and at rest.
        double scale=std::min(window()?window()->devicePixelRatio():1.0,limit/std::max(mGroundRect.width(),mGroundRect.height()));
        int w=std::max(1,int(std::ceil(mGroundRect.width()*scale))),h=std::max(1,int(std::ceil(mGroundRect.height()*scale)));
        mGround=QImage(w,h,QImage::Format_ARGB32_Premultiplied);mGround.fill(Qt::transparent);
        const double turn=mSky->earthOffset()*2*pi,ct=std::cos(turn),st=std::sin(turn);
        const auto& day=mSky->day;const auto& night=mSky->night;
        std::vector<const QRgb*> dayRows(day.height()),nightRows(night.height());
        for(int i=0;i<day.height();++i)dayRows[i]=reinterpret_cast<const QRgb*>(day.constScanLine(i));
        for(int i=0;i<night.height();++i)nightRows[i]=reinterpret_cast<const QRgb*>(night.constScanLine(i));
        const auto observer=direction(mObserver.x(),mObserver.y());
        for(int y=0;y<h;++y) {
            auto row=reinterpret_cast<QRgb*>(mGround.scanLine(y));
            double v=(height()/2-(mGroundRect.top()+(y+.5)*mGroundRect.height()/h))/r;
            for(int x=0;x<w;++x) {
                double u=(mGroundRect.left()+(x+.5)*mGroundRect.width()/w-width()/2)/r;
                double rr=u*u+v*v;if(rr>1)continue;double z=std::sqrt(std::max(0.0,1-rr));
                double forward=-mSp*v+mCp*z;
                double wx=mCy*u+mSy*forward,wy=mCp*v+mSp*z,wz=-mSy*u+mCy*forward;
                double lon=std::atan2(wx,wz)-turn,lat=std::asin(std::clamp(wy,-1.0,1.0));
                double tx=(lon/(2*pi)+.5);tx-=std::floor(tx);double ty=.5-lat/pi;
                QRgb color=dayRows[std::clamp(int(ty*day.height()),0,day.height()-1)][std::clamp(int(tx*day.width()),0,day.width()-1)];
                double brightness=1-qAlpha(nightRows[std::clamp(int(ty*night.height()),0,night.height()-1)][std::clamp(int(tx*night.width()),0,night.width()-1)])/255.0;
                double fade=1;
                if(mHorizon && (wx*ct-wz*st)*observer.x+wy*observer.y+(wx*st+wz*ct)*observer.z<0)fade=.08;
                row[x]=qRgb(int(qRed(color)*brightness*fade+8*(1-fade)),int(qGreen(color)*brightness*fade+15*(1-fade)),int(qBlue(color)*brightness*fade+24*(1-fade)));
            }
        }
        mDirty=false;
    }
    p->drawImage(mGroundRect,mGround);
    p->setPen(QPen(QColor(113,157,183,100),1));p->setBrush(Qt::NoBrush);p->drawEllipse(center,r,r);
    const double earthTurn=mSky->earthOffset()*360;
    if(layer("latitudeLines")) {
        for(double latitude:{0.0,23.44,-23.44,66.56,-66.56}) {
            p->setPen(QPen(QColor(123,189,112,100),latitude==0?1.1:.7));
            for(int lon=-180;lon<180;++lon){auto a=view(direction(lon+earthTurn,latitude)),b=view(direction(lon+1+earthTurn,latitude));if(a.z>0 && b.z>0)p->drawLine(pixel(a),pixel(b));}
        }
    }
    if(mHorizon) {
        auto observer=direction(mObserver.x()+earthTurn,mObserver.y());
        V east{std::cos(rad(mObserver.x()+earthTurn)),0,-std::sin(rad(mObserver.x()+earthTurn))};
        V north{ -std::sin(rad(mObserver.y()))*std::sin(rad(mObserver.x()+earthTurn)),std::cos(rad(mObserver.y())),-std::sin(rad(mObserver.y()))*std::cos(rad(mObserver.x()+earthTurn))};
        p->setPen(QPen(QColor(146,191,204,165),1));
        for(int step=0;step<360;++step){auto at=[&](int n){double t=rad(n);return view({east.x*std::cos(t)+north.x*std::sin(t),east.y*std::cos(t)+north.y*std::sin(t),east.z*std::cos(t)+north.z*std::sin(t)});};auto a=at(step),b=at(step+1);if(a.z>=0 && b.z>=0)p->drawLine(pixel(a),pixel(b));}
        auto pos=view(observer);if(pos.z>0){auto point=pixel(pos);p->setPen(QPen(QColor(210,229,236),1.3));p->drawEllipse(point,4,4);p->drawLine(point+QPointF(-9,0),point+QPointF(9,0));p->drawLine(point+QPointF(0,-9),point+QPointF(0,9));}
    }
    paintSky(p,true);
}
