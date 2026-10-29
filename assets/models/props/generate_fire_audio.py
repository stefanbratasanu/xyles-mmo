"""Generate original seamless, low-volume crackling loops for world fires."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050
DURATION = 12
COUNT = RATE * DURATION

def generate(name, seed, pops, bed, strength):
    rng = random.Random(seed)
    samples = [0.0] * COUNT
    low = 0.0
    for i in range(COUNT):
        low += 0.13 * (rng.uniform(-1, 1) - low)
        samples[i] = low * bed * (0.7 + 0.3 * math.sin(2*math.pi*i/COUNT*3))
    for _ in range(pops):
        start = rng.randrange(COUNT)
        length = rng.randrange(150, 1500)
        amplitude = rng.uniform(0.2, 1.0) * strength
        tone = rng.uniform(180, 1800)
        for j in range(length):
            env = math.exp(-j / (length * 0.22))
            value = (rng.uniform(-1, 1)*0.7 + math.sin(2*math.pi*tone*j/RATE)*0.3) * env * amplitude
            samples[(start+j) % COUNT] += value
    # Blend the seam so repeating the stream does not create a click.
    for i in range(300):
        weight = 0.5 * (1.0 - i / 300)
        a, b = samples[i], samples[COUNT-1-i]
        samples[i] = a * (1-weight) + b * weight
        samples[COUNT-1-i] = b * (1-weight) + a * weight
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s))*32767)) for s in samples))

generate("campfire_crackle.wav", 1343, 90, 0.07, 0.20)
generate("torch_crackle.wav", 637, 30, 0.025, 0.10)
