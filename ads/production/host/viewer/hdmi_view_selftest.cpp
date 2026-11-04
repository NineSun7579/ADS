#include "hdmi_view.h"
#include <cstdio>
int tdm::runHdmiViewSelfTest(){
 int failures=0;auto expect=[&](bool ok,const char*n){fprintf(stderr,"%s %s\n",ok?"[ok]":"[FAIL]",n);failures+=!ok;};
 QImage left(320,240,QImage::Format_RGB16),right(320,240,QImage::Format_RGB16);left.fill(Qt::red);right.fill(Qt::blue);
 auto bytes=[](const QImage&i){return QByteArray(reinterpret_cast<const char*>(i.constBits()),i.sizeInBytes());};
 auto image=hdmiAnalyticsImage(bytes(left),bytes(right));
 expect(image.size()==QSize(640,480)&&image.format()==QImage::Format_RGB888,"network input stays 640x480 RGB888");
 expect(image.pixelColor(0,119)==QColor(114,114,114)&&image.pixelColor(639,360)==QColor(114,114,114),"exact 120 gray rows above and below");
 expect(image.pixelColor(0,120).red()>240&&image.pixelColor(319,359).red()>240&&image.pixelColor(320,120).blue()>240&&image.pixelColor(639,359).blue()>240,"compressed C3/C4 bytes placed once without a second resize");
 left.fill(Qt::black);reinterpret_cast<quint16*>(left.scanLine(239))[319]=0xffff;
 auto edge=hdmiAnalyticsImage(bytes(left),bytes(right));
 expect(edge.pixelColor(319,359)==QColor(255,255,255)&&edge.pixelColor(318,359)==QColor(0,0,0),"wire bottom-right pixel survives");
 expect(hdmiAnalyticsImage(bytes(left),{}).isNull(),"missing frame rejected");
  QImage fullLeft(640,480,QImage::Format_RGB16),fullRight(640,480,QImage::Format_RGB16);fullLeft.fill(Qt::red);fullRight.fill(Qt::blue);
  auto full=hdmiAnalyticsImage(bytes(fullLeft),bytes(fullRight));
  expect(full.size()==QSize(640,480)&&full.pixelColor(0,120).red()>240&&full.pixelColor(639,359).blue()>240,"640x480 C5/C6 frames are reduced into the HDMI analytics input");
  expect(hdmiLeftCamera==4&&hdmiRightCamera==5,"HDMI input is mapped to C5/C6");
  for(int rows:{480,960}) {
   QImage nativeLeft(640,rows,QImage::Format_RGB16),nativeRight(640,rows,QImage::Format_RGB16);
   nativeLeft.fill(Qt::red);nativeRight.fill(Qt::blue);
   reinterpret_cast<quint16*>(nativeLeft.scanLine(rows-1))[639]=0xffff;
   const auto native=nativeHdmiImage(bytes(nativeLeft),bytes(nativeRight),1280,rows);
   expect(native.size()==QSize(1280,rows),"native dimensions retained");
   expect(native.pixelColor(639,rows-1)==QColor(255,255,255)&&native.pixelColor(640,rows-1).blue()>240,
          "native bottom row and half seam preserved");
   expect(nativeHdmiImage(bytes(nativeLeft),{},1280,rows).isNull(),"missing native half rejected");
  }
 expect(hdmiPairReady(1000,980,990,3,3,3),"fresh pair accepted");
 expect(!hdmiPairReady(1000,800,990,3,3,3),"stale frame rejected");
 expect(!hdmiPairReady(1000,940,990,3,3,3),"excessive skew rejected");
 expect(!hdmiPairReady(1000,980,990,3,2,3),"generation mismatch rejected");
 fprintf(stderr,failures?"CAM34_WIRE_SELFTEST_FAIL\n":"CAM34_WIRE_SELFTEST_PASS\n");return failures?2:0;
}
