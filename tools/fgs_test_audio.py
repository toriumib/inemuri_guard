"""Feed a synthetic, varying test tone to an emulator microphone (no host mic).

Uses the SDK emulator_controller.proto injectAudio RPC with local credentials
held only in memory. This tests audio delivery, NOT sleep recognition accuracy.
"""
import math, os, struct, sys, time
from pathlib import Path
import grpc

settings = None
for ini in (Path(os.environ['LOCALAPPDATA'])/'Temp/avd/running').glob('pid_*.ini'):
    candidate = dict(line.split('=', 1) for line in ini.read_text().splitlines() if '=' in line)
    if candidate.get('port.serial') == '5554':
        settings = candidate
if not settings: raise RuntimeError('Dedicated emulator not found')
channel = grpc.insecure_channel('localhost:' + settings['grpc.port'])
metadata = [('authorization', 'Bearer ' + settings['grpc.token'])]

def varint(value):
    result = bytearray()
    while value > 127:
        result.append((value & 127) | 128); value >>= 7
    result.append(value)
    return bytes(result)

def packets():
    start = time.monotonic()
    index = 0
    rate = 16000
    while time.monotonic() - start < int(sys.argv[1]):
        # Alternate two levels every three seconds; deliberately not breath.
        amplitude = 200 if int((time.monotonic()-start)/3) % 2 else 6000
        samples = [int(amplitude * math.sin(2*math.pi*440*(index+i)/rate)) for i in range(320)]
        index += 320
        pcm = struct.pack('<320h', *samples)
        fmt = b'\x08' + varint(rate) + b'\x18\x01\x20\x01'
        yield b'\x0a'+varint(len(fmt))+fmt+b'\x1a'+varint(len(pcm))+pcm
        time.sleep(.02)

channel.stream_unary('/android.emulation.control.EmulatorController/injectAudio')(
    packets(), metadata=metadata, timeout=int(sys.argv[1])+10)
print('Synthetic audio delivery finished; no host microphone was used.')
