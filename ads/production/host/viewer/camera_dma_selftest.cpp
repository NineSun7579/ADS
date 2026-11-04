#include "camera_dma.h"
#include "runtime_camera_geometry.h"
#include <algorithm>
#include <chrono>
#include <future>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace tdm {
int runCameraDmaSelfTest() {
    try {
        auto check = [](bool ok, const char* reason) { if (!ok) throw std::runtime_error(reason); };
        check(newestCameraBank(0, 0, false, 0) == -1, "uninitialized counters");
        check(newestCameraBank(101, 100, false, 0) == 0, "newest ping");
        check(newestCameraBank(101, 102, true, 101) == 1, "newest pong");
        check(newestCameraBank(101, 102, true, 102) == -1, "no duplicate frames");
        check(newestCameraBank(UINT32_MAX, 0, true, UINT32_MAX) == 1, "counter wrap to zero");
        check(newestCameraBank(0, 1, true, 0) == 1, "counter after wrap");
        check(newestCameraBank(8, 9, true, 100) == -1, "counter reset requires reprime");
        std::vector<uint8_t> rx(cameraAllocationBytes, 0xaa);
        for (int camera = 0; camera < 6; ++camera) {
            auto* pixels = rx.data() + cameraSlotOffset(camera);
            for (size_t i = 0; i < cameraFrameBytes; ++i) pixels[i] = uint8_t(i * 7 + camera);
            const uint32_t tag = 100 + camera;
            std::memcpy(pixels + cameraFrameBytes, &tag, sizeof(tag));
        }
        std::fill_n(rx.data() + cameraScratchOffset, 16, 0xff);
        for (int camera = 0; camera < 6; ++camera) {
            std::vector<uint8_t> output(cameraFrameBytes + 8, 0xab);
            const auto* pixels = rx.data() + cameraSlotOffset(camera);
            copyCameraPixels(output.data(), pixels, cameraFrameBytes);
            check(std::equal(output.begin(), output.begin() + cameraFrameBytes, pixels), "pixel copy mismatch");
            check(std::all_of(output.begin() + cameraFrameBytes, output.end(), [](uint8_t v) { return v == 0xab; }),
                  "tag bytes escaped into pixel output");
            uint32_t tag = 0;
            std::memcpy(&tag, pixels + cameraFrameBytes, sizeof(tag));
            check(tag == uint32_t(100 + camera), "disjoint slots lost their commit tags");
        }
        for (size_t bytes : {size_t(0), size_t(1), size_t(63), size_t(64), size_t(65), size_t(129)}) {
            std::vector<uint8_t> output(bytes + 4, 0xcc);
            copyCameraPixels(output.data() + 1, rx.data() + 3, bytes);
            check(std::equal(output.begin() + 1, output.begin() + 1 + bytes, rx.data() + 3), "unaligned tail copy");
            check(output.front() == 0xcc && output[bytes + 1] == 0xcc, "copy wrote outside requested bytes");
        }
        // Every mixed-resolution combination: C1/C3/C4/C5 change, and each
        // payload/tag stays inside its documented 2MiB ping/pong bank.
        for (unsigned mask = 0; mask < 16; ++mask) {
            for (int camera = 0; camera < 6; ++camera) {
                const int bit = camera == 0 ? 0 : camera == 2 ? 1 : camera == 3 ? 2 : camera == 4 ? 3 : -1;
                const bool hd = bit >= 0 && (mask & (1u << bit));
                const auto g = runtime_camera::geometry(camera, hd ? runtime_camera::Mode::Hd720 :
                    runtime_camera::Mode::Default, 37);
                check(g.valid(), "mixed geometry invalid");
                check(g.pixelBytes == (hd ? 1843200u : camera == 2 || camera == 3 ? 153600u : 614400u),
                      "mode-dependent transport bytes");
                for (int bank = 0; bank < 2; ++bank) {
                    check(g.tagAddress(bank) == g.bank(bank) + g.pixelBytes, "metadata offset");
                    check(uint64_t(g.tagAddress(bank)) + 16 <= uint64_t(g.bank(bank)) + runtime_camera::bankBytes,
                          "frame escapes bank");
                }
                check(g.acceptsPublication(37, g.pixelBytes), "current publication rejected");
                check(!g.acceptsPublication(36, g.pixelBytes), "stale generation accepted");
                check(!g.acceptsPublication(37, g.pixelBytes + 16), "tag included in publication");
                auto bad = g; bad.tagOffset += 16;
                check(!bad.valid(), "corrupt metadata offset accepted");
                bad = g; bad.pong += 16;
                check(!bad.valid(), "bank geometry mismatch accepted");
            }
        }
        for (int camera : {-1, 1, 5, 6})
            check(!runtime_camera::geometry(camera, runtime_camera::Mode::Hd720).valid(), "unsupported HD camera");
        check(!runtime_camera::geometry(0, runtime_camera::Mode::Default, 0).valid(), "zero generation accepted");
        const auto old = runtime_camera::geometry(2);
        const auto next = runtime_camera::geometry(2, runtime_camera::Mode::Hd720, old.generation + 1);
        check(!next.acceptsPublication(old.generation, old.pixelBytes), "old compressed frame accepted as HD");

        const auto c5Vga=runtime_camera::geometry(4,runtime_camera::Mode::Default,41);
        const auto c5Hd=runtime_camera::geometry(4,runtime_camera::Mode::Hd720,42);
        check(c5Vga.valid() && c5Vga.width==640 && c5Vga.height==480 && c5Vga.pixelBytes==614400,
              "C5 native VGA descriptor");
        check(c5Hd.valid() && c5Hd.width==1280 && c5Hd.height==720 && c5Hd.stride==2560 &&
              c5Hd.pixelBytes==1843200 && c5Hd.ping==0x01800000u && c5Hd.pong==0x01a00000u,
              "C5 native HD descriptor");
        check(!c5Hd.acceptsPublication(41,c5Vga.pixelBytes) &&
              !c5Hd.acceptsPublication(41,c5Hd.pixelBytes), "C5 stale descriptor/generation accepted");
        check(!c5Hd.acceptsPublication(42,c5Vga.pixelBytes) &&
              !c5Hd.acceptsPublication(42,c5Hd.transferBytes()), "C5 wrong bytes or tag accepted");
        uint32_t landing=123;
        check(cameraLandingOffset(c5Hd,landing) && landing==0, "C5 HD must land at offset zero");
        check(c5Hd.transferBytes()<=cameraScratchOffset &&
              uint64_t(cameraSlotOffset(4))+c5Hd.transferBytes()>cameraAllocationBytes,
              "C5 HD slot collision premise");
        check(cameraLandingOffset(c5Vga,landing) && landing==cameraSlotOffset(4), "C5 VGA slot changed");
        auto wrong=c5Hd;wrong.stride=1280;landing=123;
        check(!cameraLandingOffset(wrong,landing) && landing==123, "C5 wrong stride admitted to RX");
        wrong=c5Hd;wrong.camera=5;
        check(!wrong.valid() && !cameraLandingOffset(wrong,landing), "C6 HD descriptor admitted");
        wrong=c5Hd;wrong.mode=runtime_camera::Mode::Default;
        check(!wrong.valid(), "C5 HD bytes with VGA mode accepted");
        wrong=c5Hd;wrong.ping+=16;
        check(!wrong.valid(), "C5 wrong bank accepted");
        check(!runtime_camera::admitsLargeTransfer(c5Hd,c5Hd.ping,c5Hd.transferBytes(),0),
              "C5 bypassed C3/C4-only wire guard");
        const auto c6=runtime_camera::geometry(5);
        check(c6.valid() && c6.width==640 && c6.height==480 && c6.pixelBytes==614400 &&
              cameraLandingOffset(c6,landing) && landing==cameraSlotOffset(5), "C6 VGA changed");
        for(int camera:{2,3}) {
            const auto full=runtime_camera::geometry(camera,runtime_camera::Mode::FullVga);
            check(cameraLandingOffset(full,landing) && landing==0 &&
                  runtime_camera::admitsLargeTransfer(full,full.ping,full.transferBytes(),0),
                  "C3/C4 full VGA landing/admission changed");
            check(!runtime_camera::admitsLargeTransfer(full,full.ping,full.transferBytes(),cameraSlotOffset(camera)) &&
                  !runtime_camera::admitsLargeTransfer(full,full.ping,full.transferBytes()+16,0),
                  "C3/C4 guard relaxed offset or length");
        }

        // An HD DMA at offset zero overwrites legacy VGA slots. Queue another
        // camera after transfer and before copy, then prove it cannot enter until
        // output detaches. This is the same ownership scope as cameraRead.
        for (int camera : {0, 2, 3, 4}) {
            FairDmaMutex mutex;
            const auto g = runtime_camera::geometry(camera, runtime_camera::Mode::Hd720);
            uint32_t offset=UINT32_MAX;
            check(cameraLandingOffset(g,offset) && offset==0, "HD ownership test landing differs from cameraRead");
            std::vector<uint8_t> output(g.pixelBytes + 8, 0xcd);
            std::future<void> overwrite;
            bool blocked = false, copied = false;
            withCameraRxOwnership(&mutex, [&] {
                std::fill_n(rx.data(), g.pixelBytes, uint8_t(0x40 + camera));
                const uint32_t tag = 1000 + camera;
                std::memcpy(rx.data() + g.tagOffset, &tag, 4);
                auto attempted = std::make_shared<std::promise<void>>();
                auto ready = attempted->get_future();
                overwrite = std::async(std::launch::async, [&mutex, &rx, attempted, g] {
                    attempted->set_value();
                    withCameraRxOwnership(&mutex, [&] { std::fill_n(rx.data(), g.transferBytes(), 0xee); });
                });
                ready.wait();
                blocked = overwrite.wait_for(std::chrono::milliseconds(20)) == std::future_status::timeout;
                copied = copyCommittedCameraPixels(output.data(), rx.data(), g.pixelBytes, tag);
            });
            overwrite.get();
            check(blocked && copied, "cross-camera DMA entered before validated copy");
            check(std::all_of(output.begin(), output.begin() + g.pixelBytes,
                  [camera](uint8_t value) { return value == uint8_t(0x40 + camera); }), "shared RX output corrupted");
            check(output[g.pixelBytes] == 0xcd, "shared RX tag escaped output");
            check(rx.front() == 0xee && output.front() != rx.front(), "output retained RX reference");
            const auto unchanged = output;
            withCameraRxOwnership(&mutex, [&] {
                check(!copyCommittedCameraPixels(output.data(), rx.data(), g.pixelBytes, 1000 + camera),
                      "unstable commit accepted");
            });
            check(output == unchanged, "unstable commit modified output");
        }
        // cameraReadFpga must detach VGA RAW before releasing ownership for
        // conversion polling: an intervening HD read covers its old RX slot.
        {
            FairDmaMutex mutex;
            std::vector<uint8_t> output(cameraFrameBytes);
            const auto offset = cameraSlotOffset(1);
            const uint32_t tag = 77;
            withCameraRxOwnership(&mutex, [&] {
                std::fill_n(rx.data() + offset, cameraFrameBytes, 0x23);
                std::memcpy(rx.data() + offset + cameraFrameBytes, &tag, 4);
                check(copyCommittedCameraPixels(output.data(), rx.data() + offset, cameraFrameBytes, tag),
                      "converter RAW detach failed");
            });
            withCameraRxOwnership(&mutex, [&] {
                std::fill_n(rx.data(), runtime_camera::geometry(2, runtime_camera::Mode::Hd720).transferBytes(), 0xfe);
            });
            check(rx[offset] == 0xfe && std::all_of(output.begin(), output.end(),
                  [](uint8_t v) { return v == 0x23; }), "converter RAW retained overwritten RX slot");
        }
        std::cout << "CAMERA_DMA_SELFTEST_PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "CAMERA_DMA_SELFTEST_FAIL: " << error.what() << '\n';
        return 1;
    }
}
} // namespace tdm
