// Origin: immutable main.cpp lines 408..500; see origin_receipt.json.
    // Optional metadata never enters the camera failure/restart accounting.
    motion::Evidence motionHint(int camera, int generation) {
        if (camera < 0 || camera >= int(motion::SupportedCameras)) return {};
        // Join the existing FIFO: opportunistic acquisition can starve metadata
        // indefinitely under six continuously queued image streams. Cooldown
        // below reuses the generation-checked cache without additional IO.
        dmaMutex_->lock();
        struct Unlock { tdm::FairDmaMutex& mutex; ~Unlock() { mutex.unlock(); } } lock{*dmaMutex_};
        auto& observer = motionObservers_[camera];
        auto& hintObserver = observer.legacy;
        if (hintObserver.evidence.sourceGeneration != generation) hintObserver.reset(generation);
        if (observer.bound && observer.geometryGeneration!=runtimeGeometries_[camera].generation) {
            hintObserver.reset(generation); observer.bound=false;
            motionNextMs_[camera]=0; // Don't return a cached old-geometry hint during poll cooldown.
        }
        const qint64 now = monotonicMs();
        if (motionLogMs_ < 0) motionLogMs_ = now;
        if (now - motionLogMs_ >= 5000) {
            quint64 gaps=0, resets=0;
            for (const auto& o : motionObservers_) { gaps+=o.legacy.gaps; resets+=o.legacy.resets; }
            fprintf(stderr, "[motion-traffic] polls=%llu attempted_io_ops=%llu completed_dma_bytes=%llu errors=%llu sequence_gaps=%llu sequence_resets=%llu sequence_changed=%llu last_generation=%u captureduration_last_us=%lld captureduration_max_us=%lld max_ioctl_us=%lld disabled=%d\n",
                (unsigned long long)motionPolls_, (unsigned long long)motionOps_,
                (unsigned long long)motionBytes_, (unsigned long long)motionErrors_,
                (unsigned long long)gaps, (unsigned long long)resets,
                (unsigned long long)motionSequenceChanged_, motionLastGeneration_,
                (long long)motionCaptureLastUs_, (long long)motionCaptureMaxUs_,
                (long long)motionMaxIoctlUs_, motionDisabled_);
            motionLogMs_=now;
        }
        if (motionDisabled_) { hintObserver.failure(); return hintObserver.evidence; }
        if (motionNextMs_[camera] > now) return hintObserver.evidence;
        ++motionPolls_;
        const qint64 started = monotonicNs();
        const qint64 deadline = started + 250000000; // 250ms for probe + entire capture
        auto io = [&](unsigned long command, uint32_t address, uint32_t& word) {
            const qint64 remaining = deadline-monotonicNs();
            if (remaining<=0 || !tx_ || !rx_) return false;
            // Scheme2 allocates only 4KiB of TX. RX metadata retains the baseline
            // disjoint scratch; serialized TX commands use its first 16 bytes.
            DmaOp op{}; op.offset_addr=command==H2F_CMD ? 0 : motion::Scratch;
            op.ddr3_addr=address; op.total_length=16;
            if (command==H2F_CMD) { memset(tx_,0,16); memcpy(tx_,&word,4); }
            // Like the inherited ioctl watchdog this is process-wide. All DMA is
            // mutex serialized; a driver ignoring signals can exceed the budget.
            timeoutHit_=false;
            struct itimerval timer{};
            const qint64 remainingUs=std::max<qint64>(1,remaining/1000);
            timer.it_value.tv_sec=long(remainingUs/1000000);
            timer.it_value.tv_usec=long(remainingUs%1000000);
            setitimer(ITIMER_REAL,&timer,nullptr);
            ++motionOps_;
            const qint64 ioctlStarted=monotonicNs();
            const int result=::ioctl(fd_,command,&op);
            const qint64 ioctlCompleted=monotonicNs();
            motionMaxIoctlUs_=std::max(motionMaxIoctlUs_,(ioctlCompleted-ioctlStarted)/1000);
            struct itimerval cancel{}; setitimer(ITIMER_REAL,&cancel,nullptr);
            if (result>=0) motionBytes_+=16;
            if (result<0 || timeoutHit_ || monotonicNs()>deadline) return false;
            if (command==F2H_CMD) memcpy(&word,rx_+motion::Scratch,4);
            return true;
        };
        auto read = [&](uint32_t address, uint32_t& word) { return io(F2H_CMD,address,word); };
        auto write = [&](uint32_t address, uint32_t word) { return io(H2F_CMD,address,word); };
        bool good=true;
        if (!motionProbed_) {
            bool mismatch=false;
            good=integrated_motion::probe([&](uint32_t address,uint32_t& value) {
                if (!read(address,value)) return false;
                const uint32_t expected=address==CAM134_MOTION_MAGIC_ADDR?CAM134_MOTION_MAGIC:
                    address==CAM134_MOTION_GEOMETRY_ADDR?CAM134_MOTION_GEOMETRY:
                    address==CAM134_MOTION_CONFIG_ADDR?CAM134_MOTION_CONFIG:CAM134_MOTION_EXTENSION;
                mismatch |= value!=expected;
                return true;
            });
            motionDisabled_=mismatch;
            motionProbed_=good;
            fprintf(stderr,"[motion-probe] available=%d abi_base=20000b00 extension=00010010 strict_config=1 same_raw_frame=0 advisory_source_hint=1 budget_us=250000 disabled=%d\n",
                good,motionDisabled_);
            if (motionDisabled_) fprintf(stderr,
                "[motion-capability] unavailable: ABI identity/config/version mismatch; motion option ON, regular full-frame inference fallback; no selector writes\n");
        }
        integrated_motion::Record record;
        if (good) good=integrated_motion::capture(unsigned(camera),record,write,read);
        const qint64 completedNs=monotonicNs();
        const qint64 completed=completedNs/1000000;
        motionCaptureLastUs_=(completedNs-started)/1000;
        motionCaptureMaxUs_=std::max(motionCaptureMaxUs_,motionCaptureLastUs_);
        motionNextMs_[camera]=completed+(good ? 100 : 1000);
        if (good) {
            if (hintObserver.evidence.have && hintObserver.evidence.record.seq!=record.hint.seq) ++motionSequenceChanged_;
            motionLastGeneration_=record.hint.generation;
            observer.observe(record,runtimeGeometries_[camera],completed,generation);
            if (motionCapabilityEpoch_[camera]!=record.epoch || motionCapability_[camera]!=record.capabilities) {
                motionCapabilityEpoch_[camera]=record.epoch; motionCapability_[camera]=record.capabilities;
                fprintf(stderr,"[motion-capability] camera=%d flags=%x epoch=%u transport=%08x bytes=%u same_raw_frame=0 advisory_source_hint=1 usable=%d fallback=%d\n",
                    camera+1,record.capabilities,record.epoch,record.transportGeometry,record.pixelBytes,
                    integrated_motion::usable(record,runtimeGeometries_[camera]),
                    !integrated_motion::usable(record,runtimeGeometries_[camera]));
            }
        }
        else {
            ++motionErrors_; hintObserver.failure(); motionProbed_=false;
            fprintf(stderr,"[motion-error] camera=%d disabled=%d retry_ms=%d captureduration_us=%lld; full-frame inference fallback\n",
                camera+1,motionDisabled_,motionDisabled_ ? 0 : 1000,(long long)motionCaptureLastUs_);
        }
        return hintObserver.evidence;
    }

private:
    std::array<integrated_motion::Observer,4> motionObservers_;
    std::array<uint32_t,4> motionCapabilityEpoch_{{~0u,~0u,~0u,~0u}};
    std::array<uint32_t,4> motionCapability_{{~0u,~0u,~0u,~0u}};
    std::array<qint64,4> motionNextMs_{};
    bool motionProbed_=false, motionDisabled_=false;
    quint64 motionPolls_=0, motionOps_=0, motionBytes_=0, motionErrors_=0;
    quint64 motionSequenceChanged_=0;
    uint32_t motionLastGeneration_=0;
    qint64 motionCaptureLastUs_=0, motionCaptureMaxUs_=0, motionMaxIoctlUs_=0;
    qint64 motionLogMs_=-1;
