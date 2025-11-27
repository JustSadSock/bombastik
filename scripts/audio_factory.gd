extends Resource
class_name AudioFactory

const SAMPLE_RATE := 44100
const TAU := PI * 2.0

static var _cache := {}

static func _clamp_pcm(sample: float) -> int:
    return int(clamp(sample, -1.0, 1.0) * 32767.0)

static func _noise_for_index(idx: int) -> float:
    # Deterministic pseudo-random noise without relying on RNG state.
    var raw := sin(float(idx) * 12.9898) * 43758.5453
    return fmod(raw, 1.0) * 2.0 - 1.0

static func _triangle_wave(t: float, freq: float) -> float:
    var phase := fmod(t * freq, 1.0)
    return 1.0 - 4.0 * abs(phase - 0.5)

static func _saw_wave(t: float, freq: float) -> float:
    var phase := fmod(t * freq, 1.0)
    return 2.0 * phase - 1.0

static func _make_stream(length_sec: float, generator: Callable, loop := true, stereo := false) -> AudioStreamWAV:
    var frames := int(SAMPLE_RATE * length_sec)
    var buffer := PackedByteArray()
    var stride := 4 if stereo else 2
    buffer.resize(frames * stride)
    var write_index := 0
    for i in range(frames):
        var t := float(i) / SAMPLE_RATE
        var sample: float = generator.call(t)
        var l_sample := _clamp_pcm(sample)
        var r_sample := l_sample if not stereo else _clamp_pcm(sample * 0.92 + _noise_for_index(i) * 0.02)
        buffer[write_index] = l_sample & 0xFF
        buffer[write_index + 1] = (l_sample >> 8) & 0xFF
        if stereo:
            buffer[write_index + 2] = r_sample & 0xFF
            buffer[write_index + 3] = (r_sample >> 8) & 0xFF
        write_index += stride
    var stream := AudioStreamWAV.new()
    stream.mix_rate = SAMPLE_RATE
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.stereo = stereo
    stream.data = buffer
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
    return stream

static func _cached(key: String, builder: Callable) -> AudioStreamWAV:
    if _cache.has(key):
        return _cache[key]
    var built: AudioStreamWAV = builder.call()
    _cache[key] = built
    return built

static func factory_hum() -> AudioStreamWAV:
    return _cached("factory_hum", func():
        return _make_stream(5.5, func(t):
            var bass := sin(TAU * 43.0 * t) * 0.46
            var mid := sin(TAU * 91.0 * t) * 0.28
            var shimmer := _triangle_wave(t, 7.3) * 0.1
            var grit := _noise_for_index(int(t * SAMPLE_RATE)) * 0.07
            return bass + mid + shimmer + grit
        )
    )

static func factory_alarm() -> AudioStreamWAV:
    return _cached("factory_alarm", func():
        return _make_stream(3.0, func(t):
            var progress := fmod(t, 0.9)
            var envelope: float = clamp(1.0 - (progress / 0.9), 0.0, 1.0)
            var tone := _saw_wave(t, 220.0) * 0.35 + _triangle_wave(t, 440.0) * 0.12
            return tone * envelope + _noise_for_index(int(t * SAMPLE_RATE)) * 0.05
        )
    )

static func factory_arc() -> AudioStreamWAV:
    return _cached("factory_arc", func():
        return _make_stream(2.2, func(t):
            var crackle_rate := 18.0
            var phase := fmod(t * crackle_rate, 1.0)
            var burst := phase < 0.16
            var envelope := exp(-12.0 * fmod(t, 0.22)) if burst else 0.12
            var hiss := _noise_for_index(int(t * SAMPLE_RATE)) * 0.34
            var spark := _saw_wave(t, 880.0) * (0.08 + envelope)
            return (hiss + spark) * (0.45 + envelope)
        )
    )

static func player_fire() -> AudioStreamWAV:
    return _cached("player_fire", func():
        var generator := func(t):
            var kick := exp(-12.0 * t)
            var click := _triangle_wave(t, 1900.0) * 0.18 * kick
            var thump := sin(TAU * (120.0 + 48.0 * (1.0 - t))) * 0.55 * kick
            var hiss := _noise_for_index(int(t * SAMPLE_RATE)) * 0.25 * kick
            return thump + click + hiss
        return _make_stream(0.35, generator, false)
    )

static func player_hurt() -> AudioStreamWAV:
    return _cached("player_hurt", func():
        var generator := func(t):
            var wobble := sin(TAU * (180.0 - t * 40.0) * t) * 0.45
            var rasp := _noise_for_index(int(t * SAMPLE_RATE)) * 0.18
            var envelope := exp(-6.5 * t)
            return (wobble + rasp) * envelope
        return _make_stream(0.42, generator, false)
    )

static func player_step() -> AudioStreamWAV:
    return _cached("player_step", func():
        var generator := func(t):
            var heel := sin(TAU * 70.0 * t) * 0.65
            var squeak := _triangle_wave(t, 480.0) * 0.06
            var envelope := exp(-10.5 * t)
            return (heel + squeak) * envelope
        return _make_stream(0.22, generator, false)
    )

static func player_jump() -> AudioStreamWAV:
    return _cached("player_jump", func():
        var generator := func(t):
            var lift := sin(TAU * (160.0 + t * 120.0) * t) * 0.48
            var air := _noise_for_index(int(t * SAMPLE_RATE)) * 0.12
            var envelope := exp(-7.0 * t)
            return (lift + air) * envelope
        return _make_stream(0.35, generator, false)
    )

static func player_land() -> AudioStreamWAV:
    return _cached("player_land", func():
        var generator := func(t):
            var slam := _saw_wave(t, 120.0) * 0.55
            var grit := _noise_for_index(int(t * SAMPLE_RATE)) * 0.2
            var envelope := exp(-12.0 * t)
            return (slam + grit) * envelope
        return _make_stream(0.28, generator, false)
    )

static func player_slide() -> AudioStreamWAV:
    return _cached("player_slide", func():
        var generator := func(t):
            var glide := _triangle_wave(t, 130.0) * 0.22
            var rasp := _noise_for_index(int(t * SAMPLE_RATE)) * 0.12
            var envelope: float = clamp(1.0 - t * 1.6, 0.0, 1.0)
            return (glide + rasp) * envelope
        return _make_stream(0.55, generator, false, true)
    )

static func player_swap() -> AudioStreamWAV:
    return _cached("player_swap", func():
        var generator := func(t):
            var click := _triangle_wave(t, 1050.0) * 0.3
            var mech := sin(TAU * 240.0 * t) * 0.22
            var envelope := exp(-18.0 * t)
            return (click + mech) * envelope
        return _make_stream(0.18, generator, false)
    )
