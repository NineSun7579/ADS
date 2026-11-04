#pragma once
// Real RKNN parity regression. Environment changes occur only between stopped
// workers; every callback and assertion shares the same mutex.
static int asyncPipelineSelfTest(const QString& detectorPath, const QString& lanePath,
                                 const QString& imagePath) {
    QImage image(imagePath);
    if (image.isNull() || !QFile::exists(detectorPath) || !QFile::exists(lanePath)) return 2;
    struct Output { QVector<Detection> boxes; QImage mask; bool failed=false; quint64 epoch=0; };
    std::array<Output,2> reference;
    const char* variables[] = {"ADS_TRUE_ASYNC","ADS_ASYNC_PREPROCESS"};
    const std::array<QByteArray,2> saved = {qgetenv(variables[0]),qgetenv(variables[1])};
    auto restore = qScopeGuard([&] {
        for(int i=0;i<2;++i) {
            if(saved[i].isNull()) qunsetenv(variables[i]); else qputenv(variables[i],saved[i]);
        }
    });
    for(int mode=0;mode<3;++mode) {
        if(mode==0) qunsetenv("ADS_TRUE_ASYNC"); else qputenv("ADS_TRUE_ASYNC","1");
        if(mode==2) qputenv("ADS_ASYNC_PREPROCESS","1"); else qunsetenv("ADS_ASYNC_PREPROCESS");
        for(int model=0;model<2;++model) {
            ModelInfo info;
            info.path=model?lanePath:detectorPath;
            info.det640S4=!model; info.lane6D3a=model; info.lane=model;
            InferenceThread worker;
            std::mutex mutex; std::condition_variable ready;
            std::map<quint64,Output> outputs;
            QObject::connect(&worker,&InferenceThread::detectionsReady,&worker,
                [&](QString,int,quint64 id,QVector<Detection> boxes,double,double) {
                    std::lock_guard<std::mutex> lock(mutex);
                    outputs[id].boxes=std::move(boxes); ready.notify_all();
                },Qt::DirectConnection);
            QObject::connect(&worker,&InferenceThread::laneMaskReady,&worker,
                [&](QImage mask,int,quint64 id,double,double) {
                    std::lock_guard<std::mutex> lock(mutex);
                    outputs[id].mask=std::move(mask); ready.notify_all();
                },Qt::DirectConnection);
            QObject::connect(&worker,&InferenceThread::inferenceFailed,&worker,
                [&](int,quint64 id,quint64 epoch) {
                    std::lock_guard<std::mutex> lock(mutex);
                    outputs[id].failed=true; outputs[id].epoch=epoch; ready.notify_all();
                },Qt::DirectConnection);
            QObject::connect(&worker,&InferenceThread::observationReady,&worker,
                [&](QString,int,quint64 id,QVector<Detection>,double,bool,quint64 epoch) {
                    std::lock_guard<std::mutex> lock(mutex);
                    outputs[id].epoch=epoch;
                },Qt::DirectConnection);
            worker.setModel(info); worker.start();
            auto stopped = qScopeGuard([&]{worker.stop();});
            // Second request follows an explicit model revision change. This
            // verifies successful reloading after work has completed as well.
            for(quint64 id=1;id<=2;++id) {
                if(id==2) worker.setModel(info);
                const quint64 epoch=mode?100+id:0;
                const tdm::InferAge age{id,7,0,quint32(id),monotonicMs()};
                worker.submit(image,epoch,7,id,{},age);
                std::unique_lock<std::mutex> lock(mutex);
                const bool arrived=ready.wait_for(lock,std::chrono::seconds(20),[&] {
                    auto it=outputs.find(id);
                    return it!=outputs.end() && (it->second.failed ||
                        (model?!it->second.mask.isNull():!it->second.boxes.isEmpty()));
                });
                if(!arrived || outputs[id].failed || outputs[id].epoch!=epoch) {
                    fprintf(stderr,"ASYNC_PARITY_FAIL mode=%d model=%d frame=%llu arrived=%d\n",
                            mode,model,(unsigned long long)id,int(arrived)); return 1;
                }
                const auto& output=outputs[id];
                if(mode==0 && id==1) reference[model]=output;
                const auto& expected=reference[model];
                if(output.boxes.size()!=expected.boxes.size() || output.mask!=expected.mask) return 1;
                for(int i=0;i<output.boxes.size();++i) {
                    const auto& a=output.boxes[i]; const auto& b=expected.boxes[i];
                    if(a.cls!=b.cls || a.score!=b.score || a.x1!=b.x1 || a.y1!=b.y1 ||
                       a.x2!=b.x2 || a.y2!=b.y2) return 1;
                }
                fprintf(stderr,"ASYNC_PARITY_PASS mode=%d model=%d frame=%llu boxes=%d mask=%dx%d\n",
                        mode,model,(unsigned long long)id,output.boxes.size(),output.mask.width(),output.mask.height());
            }
        }
    }
    fprintf(stderr,"ASYNC_PIPELINE_SELFTEST_PASS sync_post_preprocess_same_outputs\n");
    return 0;
}
