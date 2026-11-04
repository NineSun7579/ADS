#include "cam34_six.h"
#include <cstdio>
int cam34::runSixDisplaySelfTest(){
 int fails=0;auto check=[&](bool ok,const char*n){std::fprintf(stderr,"%s %s\n",ok?"[ok]":"[FAIL]",n);fails+=!ok;};
 for(int c=0;c<6;++c)check(displayWidth(c,true)==((c==2||c==3)?320:640)&&displayHeight(c,true)==((c==2||c==3)?240:480),"six-camera mixed display widths");
 check(displayWidth(2,false)==640&&displayWidth(3,false)==640,"full-density fallback dimensions");
 QByteArray raw(640*480*2,0);for(int i=0;i<640*480;i+=2){raw[i*2]=char(0xff);raw[i*2+1]=char(0xff);}
 auto small=halfDisplay(raw);
 check(small.size()==320*240*2,"C3/C4 display carries 320x240 pixels, no fake full-density repeat buffer");
 check(small.size()>2&&static_cast<unsigned char>(small[0])==0x10&&static_cast<unsigned char>(small[1])==0x84,"adjacent black-white RGB565 columns average before packing");
 check(halfDisplay({}).isEmpty()&&halfDisplay(raw.left(10)).isEmpty(),"invalid frame rejected");
 raw.fill(0);for(int i=raw.size()-1284;i<raw.size()-1280;++i)raw[i]=char(0xff);raw[raw.size()-4]=raw[raw.size()-3]=raw[raw.size()-2]=raw[raw.size()-1]=char(0xff);small=halfDisplay(raw);
 check(small.size()==320*240*2&&static_cast<unsigned char>(small[small.size()-1])==0xff&&static_cast<unsigned char>(small[small.size()-2])==0xff,"last column and last row preserved");
 const QRectF content(30,40,1920,960);
 auto l=mapBox(80,250,160,300,content);
 check(l.camera==2&&l.tile==QRectF(1310,40,640,480)&&l.box==QRectF(1470,140,160,100),"shared left detections map into C3 top-right tile with x doubled and y padding removed");
 auto r=mapBox(400,250,480,300,content);
 check(r.camera==3&&r.tile==QRectF(30,520,640,480)&&r.box==QRectF(190,620,160,100),"shared right detections map into C4 bottom-left tile");
 auto seam=mapBox(300,190,360,450,content);
 check(seam.camera==3&&seam.box==QRectF(30,520,80,480),"seam and out-of-frame box clipped to its own camera");
 std::fprintf(stderr,fails?"CAM34_SIX_SELFTEST_FAIL\n":"CAM34_SIX_SELFTEST_PASS\n");return fails?2:0;
}
