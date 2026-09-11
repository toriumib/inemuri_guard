"""Use the emulator's authenticated local API to aim its virtual camera.
Credentials stay in memory; no tokens are logged or saved to project files.
Schema: Android SDK emulator/lib/emulator_controller.proto.
"""
import os,struct,sys
from pathlib import Path
import grpc

ini=Path(os.environ['LOCALAPPDATA'])/'Temp/avd/running/pid_7732.ini'
settings=dict(line.split('=',1) for line in ini.read_text().splitlines() if '=' in line)
if settings.get('port.serial')!='5554':raise RuntimeError('Unexpected emulator target')
channel=grpc.insecure_channel('localhost:'+settings['grpc.port'])
metadata=[('authorization','Bearer '+settings['grpc.token'])]
method='/android.emulation.control.EmulatorController/'
if sys.argv[1]=='rotate':
    data=b'\x0d'+struct.pack('<f',float(sys.argv[2]))+b'\x15'+struct.pack('<f',float(sys.argv[3]))
    channel.unary_unary(method+'rotateVirtualSceneCamera')(data,metadata=metadata,timeout=10)
    print('Virtual scene camera rotated')
elif sys.argv[1]=='position':
    # PhysicalModelValue target POSITION=0; ParameterValue packed float data.
    values=struct.pack('<fff',*map(float,sys.argv[2:5]))
    data=b'\x1a\x0e\x0a\x0c'+values
    channel.unary_unary(method+'setPhysicalModel')(data,metadata=metadata,timeout=10)
    print('Virtual position updated')
