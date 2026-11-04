#include "vision_pipeline.h"
#include "four_fair.h"
#include "live_npu_policy.h"
#include "input_scale.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QMutex>
#include <QMutexLocker>
#include <cassert>
#include <functional>
#include <vector>
#include <cstdio>
#include <time.h>
static qint64 nowMs(){timespec t{};clock_gettime(CLOCK_MONOTONIC,&t);return qint64(t.tv_sec)*1000+t.tv_nsec/1000000;}
static bool until(const std::function<bool()>& p){QElapsedTimer t;t.start();while(!p()){if(t.elapsed()>2000)return false;QThread::msleep(2);}return true;}
int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);
    for(int height:{480,640}) {
        const auto black=live_npu::blackInput(640,height);
        assert(black.width()==640&&black.height()==height&&black.format()==QImage::Format_RGB888);
        for(int y=0;y<height;++y)for(int x=0;x<640*3;++x)assert(black.constScanLine(y)[x]==0);
    }
    assert(!live_npu::decodeOutput(true)&&live_npu::decodeOutput(false));
    for(unsigned displayMask:{1u,4u,8u,0x30u,0x3fu,0x0du}) {
        assert((live_npu::captureMask(displayMask,true)&0x1du)==0x1du);
        assert(live_npu::captureMask(displayMask,false)==displayMask);
    }
    for(int c=0;c<6;++c)assert(live_npu::backgroundCamera(c,true)==bool(0x1du&(1u<<c)));
    for(const auto& page:{"home","six","single","space","hdmi"})assert(!live_npu::renderView(page,true,false,false));
    assert(live_npu::renderView("four",true,false,false));
    assert(!live_npu::renderView("four",true,false,true)&&!live_npu::renderView("four",true,true,false));
    assert(live_npu::completedFps(0,0)==0&&live_npu::completedFps(7.5,100)==7.5);
    assert(live_npu::completedFps(99,1500)==0&&live_npu::completedFps(99,-1)==0);
    assert(live_npu::completedFps(std::nan(""),0)==0);
    VisionOptions options;options.tracking=false;options.motionEnabled=false;options.minimumDetectionIntervalMs=1;
    VisionPipeline pipeline(options);QMutex mutex;std::vector<VisionFrame> requests;std::atomic<int> evidence{0};
    QObject::connect(&pipeline,&VisionPipeline::inferenceRequested,&pipeline,[&](VisionFrame f,quint64 epoch){
        assert(epoch==VisionPipeline::FourRequest);QMutexLocker lock(&mutex);requests.push_back(f);
    },Qt::DirectConnection);
    QObject::connect(&pipeline,&VisionPipeline::acceptedDetectorResult,&pipeline,[&]{++evidence;},Qt::DirectConnection);
    QObject::connect(&pipeline,&VisionPipeline::tracksReady,&pipeline,[&]{++evidence;},Qt::DirectConnection);
    const auto count=[&]{QMutexLocker lock(&mutex);return requests.size();};
    const auto last=[&]{QMutexLocker lock(&mutex);return requests.back();};
    quint64 seq=0;QImage image(640,480,QImage::Format_RGB888);image.fill(Qt::white);
    // Exercise the actual RAW normalization, including compressed C3/C4.
    // A pre-normalized 640x480 fixture hid Qt smooth scaling's RGB32 output.
    std::array<QImage,6> cameraImages;
    for(int c:FourFair::cameras) {
        QImage raw(c==2||c==3?320:640,c==2||c==3?240:480,QImage::Format_RGB888);
        raw.fill(Qt::white);
        cameraImages[c]=input480::normalize(raw,input480::Mode::Stretch);
        assert(cameraImages[c].size()==QSize(640,480));
        assert(cameraImages[c].format()==QImage::Format_RGB888);
    }
    std::array<quint64,6> latest{};
    const auto feed=[&](int generation,unsigned mask=15){for(int i=0;i<4;++i)if(mask&(1u<<i)){
        VisionFrame f;f.camera=FourFair::cameras[i];f.sourceGeneration=generation;f.frameId=++seq;
        f.image=cameraImages[f.camera];f.capturedMs=nowMs();f.tag=unsigned(seq);f.acquisition=acquisition::registry().snapshot(1u<<f.camera);
        latest[f.camera]=f.frameId;pipeline.submitFrame(f);
    }};
    const auto complete=[&](const VisionFrame& f,int model=0){pipeline.submitDetections(model?"lane":"det",f.sourceGeneration,f.frameId,{},1,0,model);};
    pipeline.configure(1,0,false,{},{},true);pipeline.start();QThread::msleep(50);assert(count()==0);
    pipeline.configure(1,0,false,{"det","lane"},{},true);assert(until([&]{return count()==1;}));
    unsigned blackCameras[6]{};
    for(int n=0;n<4;++n) {
        const auto f=last();assert(f.syntheticBlack&&f.capturedMs==-1&&f.tag==0&&!f.cameraAcquisition&&f.acquisition.mask==0);
        assert(f.frameId&(quint64(1)<<63));++blackCameras[f.camera];
        for(int y=0;y<480;++y)for(int x=0;x<640*3;++x)assert(f.image.constScanLine(y)[x]==0);
        const auto before=count();complete(f,n%2);assert(until([&]{return count()==before+1;}));
    }
    for(int c:FourFair::cameras)assert(blackCameras[c]==1);assert(evidence==0);
    const auto padding=last();assert(padding.syntheticBlack);
    for(int n=0;n<100;++n)feed(1);
    const auto held=count();QThread::msleep(2100);assert(count()==held);
    pipeline.submitDetections("det",99,padding.frameId,{},1);QThread::msleep(30);assert(count()==held);
    pipeline.submitDetections("det",1,padding.frameId+9999,{},1);QThread::msleep(30);assert(count()==held);
    feed(1);complete(padding);assert(until([&]{return count()==held+1;}));
    assert(!last().syntheticBlack&&last().frameId==latest[last().camera]);
    unsigned realCameras[6]{},models[6][2]{};
    for(int n=0;n<64;++n) {
        const auto f=last();assert(!f.syntheticBlack);++realCameras[f.camera];++models[f.camera][n%2];
        const auto before=count();feed(1);complete(f,n%2);assert(until([&]{return count()==before+1;}));
    }
    for(int c:FourFair::cameras){
        assert(realCameras[c]>=15&&realCameras[c]<=17);assert(models[c][0]&&models[c][1]);
        printf("four-normalized-real camera=%d requests=%u det=%u lane=%u\n",c+1,realCameras[c],models[c][0],models[c][1]);
    }
    // A page switch is presentation policy only: keep the identical configured
    // pipeline/generation, even for frozen replay and single/space/HDMI pages.
    for(int page=0;page<6;++page)for(bool frozen:{false,true}) {
        assert(live_npu::render(page==2,frozen)==(page==2&&!frozen));
        assert(!live_npu::render(page==2,frozen,true));
        const auto f=last();const auto before=count();feed(1);complete(f);assert(until([&]{return count()==before+1;}));
        assert(last().sourceGeneration==1&&!last().syntheticBlack);
    }
    const auto retiring=last();const auto beforeSource=count();
    pipeline.configure(2,0,false,{"det","lane"},{},true);feed(2);QThread::msleep(40);assert(count()==beforeSource);
    complete(retiring);assert(until([&]{return count()==beforeSource+1;}));assert(last().sourceGeneration==2);
    complete(retiring);QThread::msleep(40);assert(count()==beforeSource+1);
    auto current=last();acquisition::registry().fence(1u<<current.camera);feed(2);
    const auto fenced=count();QThread::msleep(40);assert(count()==fenced);
    complete(current);assert(until([&]{return count()==fenced+1;}));
    acquisition::registry().activate(1u<<current.camera);
    current=last();pipeline.configure(3,0,false,{},{},true);const auto disabled=count();complete(current);
    feed(3);QThread::msleep(80);assert(count()==disabled);
    pipeline.stop();pipeline.wait();assert(evidence==0);
    std::puts("four-pipeline PASS: initialized model-size black, fair per-camera padding, real recovery/latest priority, single inflight >2s/across source changes, wrong identity/acquisition fence, all-page continuity, only-four real rendering policy, frozen replay isolation, completed-FPS freshness, explicit disable, no padding business evidence (simulated RKNN completions)");
}
