#pragma once
#include <QByteArray>
#include <QRectF>
#include <algorithm>
namespace cam34 {
inline int displayHeight(int camera,bool shared){return shared&&(camera==2||camera==3)?240:480;}
inline int displayWidth(int camera,bool shared){return shared&&(camera==2||camera==3)?320:640;}
inline void average2x2(const unsigned char*top,const unsigned char*bottom,unsigned char*out){
 unsigned r=0,g=0,b=0;
 for(int i=0;i<4;++i){const auto p=(i<2?top:bottom)+(i&1)*2;unsigned v=p[0]|(unsigned(p[1])<<8);
  unsigned a=(v>>11)&31,c=(v>>5)&63,d=v&31;r+=(a<<3)|(a>>2);g+=(c<<2)|(c>>4);b+=(d<<3)|(d>>2);}
 out[0]=(r+2)/4;out[1]=(g+2)/4;out[2]=(b+2)/4;
}
inline QByteArray halfDisplay(const QByteArray&raw){
 if(raw.size()!=640*480*2)return {};
 QByteArray result(320*240*2,Qt::Uninitialized);
 const auto in=reinterpret_cast<const unsigned char*>(raw.constData());auto out=reinterpret_cast<unsigned char*>(result.data());
 for(int y=0;y<240;++y)for(int x=0;x<320;++x){
  unsigned char rgb[3];const auto top=in+y*2*1280+x*4;
  average2x2(top,top+1280,rgb);
  unsigned packed=((unsigned(rgb[0])>>3)<<11)|((unsigned(rgb[1])>>2)<<5)|(unsigned(rgb[2])>>3);
  int i=(y*320+x)*2;out[i]=packed&255;out[i+1]=packed>>8;
 }
 return result;
}
struct Placement{int camera;QRectF tile,box;};
inline QRectF tileFor(int camera,const QRectF&content){
 const qreal w=content.width()/3,h=content.height()/2;
 return QRectF(content.left()+(camera%3)*w,content.top()+(camera/3)*h,w,h);
}
inline Placement mapBox(float x1,float y1,float x2,float y2,const QRectF&content){
 const bool right=(x1+x2)*0.5f>=320;const int camera=right?3:2;
 const float origin=right?320:0;
 const qreal a=std::clamp((x1-origin)*2.0f,0.0f,640.0f),b=std::clamp((x2-origin)*2.0f,0.0f,640.0f);
 const qreal c=std::clamp((y1-200.0f)*2.0f,0.0f,480.0f),d=std::clamp((y2-200.0f)*2.0f,0.0f,480.0f);
 const QRectF tile=tileFor(camera,content);
 return {camera,tile,QRectF(tile.left()+a*tile.width()/640,tile.top()+c*tile.height()/480,
                          std::max(qreal(0),b-a)*tile.width()/640,std::max(qreal(0),d-c)*tile.height()/480)};
}
int runSixDisplaySelfTest();
}
