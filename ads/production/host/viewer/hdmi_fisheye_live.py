"""Private live-only transport adapter; the board remap/stitch algorithm is unmodified."""
import argparse
import contextlib
import hashlib
import importlib.util
import os
import struct
import sys
import threading
import time
from collections import defaultdict
from dataclasses import dataclass

PATH = "/dev/shm/ads-hdmi-fisheye-v2"
HEADER = struct.Struct("<IIIIQQQQQQ")
PIXEL_BYTES = 1280 * 960 * 3
BOARD_SCRIPT = "/userdata/surround-view/run_board_view.py"
BOARD_SHA256 = "85975776f0a8bf53b8f61ad9065970dbc37043bd4192c11b27da41afa3175a39"
REGIONS = ((0, 0), (640, 0), (0, 480), (640, 480))
OUTPUT_MAGIC = 0x33465348


def install_single_pass_balance(module):
    """Keep native geometry, but leave all gain application to BirdView.

    run_board_view shares this native_remap module with its read workers.
    Patching it here is process-local: the pinned board files are untouched.
    """
    original_transform = module.native_remap.transform

    def unbalanced_transform(image, model, output, gains=None):
        # Previous BirdView gains must not feed back into the next remap.
        # This also bypasses the native gain LUT's strided channel pointers.
        return original_transform(image, model, output, gains=None)

    module.native_remap.transform = unbalanced_transform


class BalanceDiagnostics:
    """Observe the first three frames and every 300th; never alter pixels/gains."""
    def __init__(self, module, birdview):
        self.np = module.np
        self.birdview = birdview
        self.balance_calls = self.render_frames = 0
        self.input_means = {}
        update_frames = birdview.update_frames
        balance = birdview.make_luminance_balance

        def observed_update(frames):
            if self.due(self.balance_calls + 1):
                self.input_means = {name: self.pixel_summary(image)
                                    for name, image in frames.items()}
            return update_frames(frames)

        def observed_balance(*args, **kwargs):
            self.balance_calls += 1
            result = balance(*args, **kwargs)
            if self.due(self.balance_calls):
                gains = birdview._balance_gains
                finite = gains is None or bool(self.np.isfinite(self.np.asarray(gains)).all())
                print("ADS_BALANCE calls={} input={} gains={} gains_finite={}".format(
                    self.balance_calls, self.input_means, gains, finite),
                    file=sys.stderr, flush=True)
            return result

        birdview.update_frames = observed_update
        birdview.make_luminance_balance = observed_balance

    @staticmethod
    def due(count):
        return count <= 3 or count % 300 == 0

    def pixel_summary(self, image):
        pixels = self.np.asarray(image)
        return {"mean": float(pixels.mean()),
                "zero_fraction": float((pixels == 0).mean()),
                "finite": bool(self.np.isfinite(pixels).all())}

    def rendered(self, image):
        self.render_frames += 1
        if self.due(self.render_frames):
            print("ADS_RENDER frames={} balance_calls={} output={} top200={}".format(
                self.render_frames, self.balance_calls, self.pixel_summary(image),
                self.pixel_summary(image[:200])), file=sys.stderr, flush=True)


class StageStats:
    def __init__(self):
        self.lock = threading.Lock()
        self.stages = defaultdict(lambda: [0, 0.0, 0.0])

    def record(self, name, started):
        elapsed = (time.perf_counter() - started) * 1000
        with self.lock:
            value = self.stages[name]
            value[0] += 1
            value[1] += elapsed
            value[2] = max(value[2], elapsed)

    def wrap(self, name, function):
        def measured(*args, **kwargs):
            started = time.perf_counter()
            try:
                return function(*args, **kwargs)
            finally:
                self.record(name, started)
        return measured

    def summary(self):
        with self.lock:
            return " ".join("{}={:.2f}/{:.2f}ms(n={})".format(name, total / count, maximum, count)
                            for name, (count, total, maximum) in sorted(self.stages.items()) if count)


def output_packet(snapshot, payload):
    if len(payload) != 600 * 800 * 3:
        raise RuntimeError("Unexpected board BGR output geometry")
    return HEADER.pack(OUTPUT_MAGIC, 3, 600, 800, snapshot.sequence, snapshot.captured_ms,
                       *snapshot.identity, 888) + payload


class LatestOutput:
    """One immutable in-flight packet and one replaceable pending packet.

    Never replace part of a packet already on the pipe. Only this thread writes
    stdout; a stalled consumer cannot stall remapping or grow a frame queue.
    """
    def __init__(self, stream, stats):
        self.stream = stream
        self.stats = stats
        self.condition = threading.Condition()
        self.pending = None
        self.closed = False
        self.error = None
        self.offered = self.written = self.replaced = 0
        self.thread = threading.Thread(target=self._run, name="ads-frame-output", daemon=True)
        self.thread.start()

    def offer(self, packet):
        with self.condition:
            if self.error is not None:
                raise RuntimeError("Frame output failed") from self.error
            if self.closed:
                raise RuntimeError("Frame output closed")
            self.offered += 1
            self.replaced += self.pending is not None
            self.pending = packet
            self.condition.notify()

    def counters(self):
        with self.condition:
            return self.offered, self.written, self.replaced, int(self.pending is not None)

    def close(self):
        # Do not wait for a blocked pipe during teardown. The process owns the
        # daemon writer and the GUI terminates the child on source transitions.
        with self.condition:
            self.closed = True
            self.pending = None
            self.condition.notify()

    def _run(self):
        try:
            while True:
                with self.condition:
                    self.condition.wait_for(lambda: self.closed or self.pending is not None)
                    if self.closed:
                        return
                    packet, self.pending = self.pending, None
                started = time.perf_counter()
                remaining = memoryview(packet)
                while remaining:
                    count = self.stream.write(remaining)
                    if count is None or count <= 0:
                        raise BrokenPipeError("Incomplete output packet")
                    remaining = remaining[count:]
                self.stream.flush()
                self.stats.record("pipe_write", started)
                with self.condition:
                    self.written += 1
        except Exception as error:
            with self.condition:
                self.error = error
                self.pending = None


class SharedOutput:
    """Single latest complete output; never wait for the GUI reader's lock."""
    def __init__(self, path, stats):
        self.stream = open(path, "r+b", buffering=0)
        self.stats = stats
        self.offered = self.written = self.dropped = 0

    def offer(self, packet):
        import fcntl
        self.offered += 1
        started = time.perf_counter()
        try:
            fcntl.flock(self.stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            self.dropped += 1
            return
        try:
            self.stream.seek(0)
            # Invalidate first and commit the header last. If the worker dies
            # mid-write, the unlocked file cannot advertise a torn frame.
            self._write_all(bytes(HEADER.size))
            self._write_all(memoryview(packet)[HEADER.size:])
            self.stream.seek(0)
            self._write_all(memoryview(packet)[:HEADER.size])
            self.written += 1
        finally:
            fcntl.flock(self.stream.fileno(), fcntl.LOCK_UN)
            self.stats.record("output_write", started)

    def counters(self):
        return self.offered, self.written, self.dropped, 0

    def _write_all(self, remaining):
        remaining = memoryview(remaining)
        while remaining:
            count = self.stream.write(remaining)
            if count is None or count <= 0:
                raise OSError("Incomplete shared output frame")
            remaining = remaining[count:]

    def close(self):
        self.stream.close()


@dataclass(frozen=True)
class Snapshot:
    sequence: int
    captured_ms: int
    identity: tuple
    pixels: bytes


def decode(header, pixels, now_ms):
    if len(header) != HEADER.size or len(pixels) != PIXEL_BYTES:
        return None
    magic, version, width, height, sequence, captured, generation, left, right, fmt = HEADER.unpack(header)
    if ((magic, version, width, height, fmt) != (0x32465348, 2, 1280, 960, 888)
            or not sequence or not captured or not left or not right or left & 1 or right & 1
            or now_ms < captured):
        return None
    return Snapshot(sequence, captured, (generation, left, right), pixels)


def output_current(original, latest, now_ms):
    # Processing latency is not source failure. Never re-date the input capture.
    return (latest is not None and latest.identity == original.identity
            and latest.sequence >= original.sequence
            and now_ms >= latest.captured_ms and now_ms >= original.captured_ms)


def read_snapshot(stream, now_ms=None):
    import fcntl
    try:
        fcntl.flock(stream.fileno(), fcntl.LOCK_SH | fcntl.LOCK_NB)
    except BlockingIOError:
        return None
    try:
        stream.seek(0)
        header = stream.read(HEADER.size)
        pixels = stream.read(PIXEL_BYTES)
        return decode(header, pixels, int(time.monotonic() * 1000) if now_ms is None else now_ms)
    finally:
        fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def crops(snapshot):
    """Unwarped RGB originals, useful for transport/geometry regression tests."""
    result = []
    for x, y in REGIONS:
        result.append(b"".join(snapshot.pixels[((y + row) * 1280 + x) * 3:
                                             ((y + row) * 1280 + x + 640) * 3]
                               for row in range(480)))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-dir", required=True)
    parser.add_argument("--source-fps", type=float, default=30)
    parser.add_argument("--output-shm", help="GUI-owned private latest BGR output mailbox")
    for flag in ("hardware", "native", "native-hdmi-shm", "stream-frames", "headless"):
        parser.add_argument("--" + flag, action="store_true", required=True)
    args = parser.parse_args()
    args.no_balance = False
    # No video-dir option and no opening a video device or file, including on failure.
    with open(BOARD_SCRIPT, "rb") as source:
        if hashlib.sha256(source.read()).hexdigest() != BOARD_SHA256:
            raise RuntimeError("Board algorithm fingerprint differs; live adapter refuses to run")
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    sys.path.insert(0, os.path.dirname(BOARD_SCRIPT))
    spec = importlib.util.spec_from_file_location("ads_board_algorithm", BOARD_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    install_single_pass_balance(module)
    # __init__ creates the same native transport handles, redirected only at the
    # boundary. Override its reader before constructing the original BoardView.
    # Its 36-byte mmap is never read by this adapter; private reads use locked I/O.
    builtin_open = open

    def native_open(path, *values, **options):
        if path == "/dev/shm/surround-native-hdmi-960":
            path = PATH
        return builtin_open(path, *values, **options)

    module.open = native_open
    expected_identity = None

    def read_native(view):
        nonlocal expected_identity
        snapshot = read_snapshot(view.native_shm)
        if snapshot is None:
            return None
        if expected_identity is None:
            expected_identity = snapshot.identity
        if snapshot.identity != expected_identity:
            raise RuntimeError("Acquisition epoch changed; restart live worker")
        if snapshot.sequence <= view.native_shm_sequence:
            return None
        view.native_shm_sequence = snapshot.sequence
        view.native_shm_captured_ms = snapshot.captured_ms
        view._ads_snapshot = snapshot
        return module.np.frombuffer(snapshot.pixels, module.np.uint8).reshape(960, 1280, 3)

    module.BoardView.read_native_snapshot = read_native
    app = module.QApplication(sys.argv)
    # Suppress only the original stream writer. Everything from read(name)
    # through BirdView stitching/balance/car remains the original algorithm,
    # except remap is explicitly unbalanced before BirdView's single gain pass.
    args.stream_frames = False
    view = module.BoardView(args)
    diagnostics = BalanceDiagnostics(module, view.birdview)
    stats = StageStats()
    view.read_native_snapshot = stats.wrap("snapshot", view.read_native_snapshot)
    view.read = stats.wrap("convert_remap", view.read)
    for method in ("update_frames", "make_luminance_balance", "stitch_all_parts", "copy_car_image"):
        setattr(view.birdview, method, stats.wrap(method, getattr(view.birdview, method)))
    output = SharedOutput(args.output_shm, stats) if args.output_shm else LatestOutput(sys.stdout.buffer, stats)
    report_at = time.monotonic()
    reported_frames = reported_written = misses = rejected = 0
    try:
        while True:
            previous = view.frames
            started = time.perf_counter()
            with contextlib.redirect_stdout(sys.stderr):
                view.render()
            if view.frames != previous:
                diagnostics.rendered(view.last_frame)
                stats.record("render", started)
                original = view._ads_snapshot
                started = time.perf_counter()
                latest = read_snapshot(view.native_shm)
                now = int(time.monotonic() * 1000)
                if output_current(original, latest, now):
                    payload = view.last_frame.tobytes()
                    if len(payload) != 600 * 800 * 3:
                        raise RuntimeError("Unexpected board BGR output geometry")
                    packet = output_packet(original, payload) if args.output_shm else struct.pack("<I", len(payload)) + payload
                    output.offer(packet)
                else:
                    rejected += 1
                stats.record("validate_pack_offer", started)
            else:
                misses += 1
            now = time.monotonic()
            if now - report_at >= 2:
                offered, written, replaced, pending = output.counters()
                print("ADS_PERF fusion_fps={:.2f} output_fps={:.2f} frames={} offered={} written={} "
                      "dropped_or_replaced={} pending={} misses={} rejected={} stages_avg/max {}".format(
                          (view.frames - reported_frames) / (now - report_at),
                          (written - reported_written) / (now - report_at), view.frames,
                          offered, written, replaced, pending, misses, rejected, stats.summary()),
                      file=sys.stderr, flush=True)
                report_at, reported_frames, reported_written = now, view.frames, written
            time.sleep(0.001)
    finally:
        output.close()
        view.close()


if __name__ == "__main__":
    main()
