#!/usr/bin/env python3
"""Ephemeral loopback TLS fixture; never imports a CA into system trust."""
import http.server
import json
import os
import pathlib
import ssl
import socketserver
import subprocess
import sys
import threading
import shutil
import time

root = pathlib.Path(sys.argv[1])
os.chdir(root)
os.umask(0o077)

openssl = os.environ.get('PRIZM_TEST_OPENSSL') or next((p for p in ['/opt/homebrew/bin/openssl', '/usr/local/bin/openssl'] if pathlib.Path(p).exists()), shutil.which('openssl'))
def run(*args):
    subprocess.run([openssl, *args], check=True, stdout=subprocess.DEVNULL)

def key(name):
    run('genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', name + '.key')

def csr(name, subject):
    key(name)
    run('req', '-new', '-key', name + '.key', '-subj', '/CN=' + subject, '-out', name + '.csr')

def sign(name, issuer, extension, expired=False, future=False):
    pathlib.Path(name + '.ext').write_text(extension + '\n')
    if expired or future:
        pathlib.Path('index').write_text('')
        pathlib.Path('serial').write_text('1000\n')
        pathlib.Path('ca.conf').write_text(f'''[ ca ]
default_ca = local
[ local ]
database = index
serial = serial
new_certs_dir = .
certificate = {issuer}.crt
private_key = {issuer}.key
default_md = sha256
policy = policy
[ policy ]
commonName = supplied
''')
        start, end = ('20200101000000Z', '20210101000000Z') if expired else ('20900101000000Z', '20910101000000Z')
        run('ca', '-batch', '-config', 'ca.conf', '-in', name + '.csr', '-out', name + '.crt', '-startdate', start, '-enddate', end, '-extfile', name + '.ext')
    else:
        run('x509', '-req', '-in', name + '.csr', '-CA', issuer + '.crt', '-CAkey', issuer + '.key', '-CAcreateserial', '-days', '2', '-extfile', name + '.ext', '-out', name + '.crt')

key('ca')
run('req', '-new', '-x509', '-key', 'ca.key', '-days', '2', '-subj', '/CN=Prizm ephemeral CA', '-addext', 'basicConstraints=critical,CA:TRUE', '-addext', 'keyUsage=critical,keyCertSign,cRLSign', '-out', 'ca.crt')
run('x509', '-in', 'ca.crt', '-outform', 'DER', '-out', 'ca.der')
csr('intermediate', 'Prizm ephemeral intermediate')
sign('intermediate', 'ca', 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign')
csr('server', 'localhost')
sign('server', 'ca', 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1')
client_extensions = 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth'
for name in ['client', 'expired', 'future', 'serverOnly', 'wrongUsage', 'unrestricted']:
    csr(name, 'Prizm test client')
    ext = client_extensions
    if name == 'serverOnly': ext = ext.replace('clientAuth', 'serverAuth')
    if name == 'wrongUsage': ext = ext.replace('digitalSignature', 'keyEncipherment')
    if name == 'unrestricted': ext = 'basicConstraints=critical,CA:FALSE'
    sign(name, 'intermediate', ext, expired=name == 'expired', future=name == 'future')
    run('pkcs12', '-export', '-legacy', '-inkey', name + '.key', '-in', name + '.crt', '-certfile', 'intermediate.crt', '-passout', 'pass:test-only', '-out', name + '.p12')
run('pkcs12', '-export', '-legacy', '-nokeys', '-in', 'client.crt', '-passout', 'pass:test-only', '-out', 'noKey.p12')
# OpenSSL's CLI exports only one key. Use its public PKCS#12 bag API to create
# a genuine two-identity negative fixture, with matching localKeyId attributes.
import ctypes
lib_path = pathlib.Path(openssl).resolve().parent.parent / 'lib/libcrypto.dylib'
lib = ctypes.CDLL(str(lib_path))
def bind(name, result, arguments):
    fn = getattr(lib, name)
    fn.restype, fn.argtypes = result, arguments
    return fn
ptr, int_, char = ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p
bio_new = bind('BIO_new_file', ptr, [char, char])
read_key = bind('PEM_read_bio_PrivateKey', ptr, [ptr, ptr, ptr, ptr])
read_cert = bind('PEM_read_bio_X509', ptr, [ptr, ptr, ptr, ptr])
add_key = bind('PKCS12_add_key', ptr, [ctypes.POINTER(ptr), ptr, int_, int_, int_, char])
add_cert = bind('PKCS12_add_cert', ptr, [ctypes.POINTER(ptr), ptr])
local_id = bind('PKCS12_add_localkeyid', int_, [ptr, char, int_])
add_safe = bind('PKCS12_add_safe', int_, [ctypes.POINTER(ptr), ptr, int_, int_, char])
add_safes = bind('PKCS12_add_safes', ptr, [ptr, int_])
set_mac = bind('PKCS12_set_mac', int_, [ptr, char, int_, ptr, int_, int_, ptr])
encode = bind('i2d_PKCS12_bio', int_, [ptr, ptr])
nid = bind('OBJ_txt2nid', int_, [char])
bags, safes = ptr(), ptr()
for index, name in enumerate(['client', 'unrestricted']):
    private = read_key(bio_new((name + '.key').encode(), b'r'), None, None, None)
    certificate = read_cert(bio_new((name + '.crt').encode(), b'r'), None, None, None)
    keybag = add_key(ctypes.byref(bags), private, 0, 2048, nid(b'pbeWithSHA1And3-KeyTripleDES-CBC'), b'test-only')
    certbag = add_cert(ctypes.byref(bags), certificate)
    assert keybag and certbag
    assert local_id(keybag, bytes([index + 1]), 1) == 1
    assert local_id(certbag, bytes([index + 1]), 1) == 1
assert add_safe(ctypes.byref(safes), bags, -1, 0, None) == 1
archive = add_safes(safes, 0)
assert archive and set_mac(archive, b'test-only', -1, None, 0, 2048, None) == 1
output_bio = bio_new(b'multiple.p12', b'wb')
assert encode(output_bio, archive) == 1
# Close output BIO before the Swift test reads it.
bind('BIO_free', int_, [ptr])(output_bio)  # Remaining objects live only in this fixture process.

lock = threading.Lock()
servers = {}
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length', '0')))
        self.do_GET()
    def do_GET(self):
        with lock:
            with open('events.jsonl', 'a') as output:
                output.write(json.dumps({'server': self.server.label, 'path': self.path, 'client': bool(self.connection.getpeercert()), 'authorization_present': 'Authorization' in self.headers}) + '\n')
        if self.path == '/redirect':
            self.send_response(302)
            self.send_header('Location', f'https://localhost:{servers["other"].server_port}/')
            self.end_headers()
        else:
            self.send_response(200)
            self.end_headers()
            if self.path.startswith('/api/accounts/prelogin'):
                response = {'kdf': 0, 'kdfIterations': 600000}
            elif self.path.startswith('/identity/connect/token'):
                response = {'access_token': 'test-only-access', 'refresh_token': 'test-only-refresh', 'token_type': 'Bearer', 'expires_in': 3600}
            elif self.path.startswith('/api/sync'):
                response = {'profile': {'id': 'test-only-user', 'email': 'test@example.org', 'key': 'test-only-encrypted-key'}, 'ciphers': []}
            else:
                self.wfile.write(b'client authenticated')
                return
            self.wfile.write(json.dumps(response).encode())
    def log_message(self, *_): pass

class LoopbackHTTPServer(http.server.ThreadingHTTPServer):
    def server_bind(self):
        # HTTPServer's default performs reverse DNS even for loopback, making a
        # completely local fixture depend on resolver availability/startup latency.
        socketserver.TCPServer.server_bind(self)
        self.server_name = 'localhost'
        self.server_port = self.server_address[1]

for name in ['server', 'other', 'reject']:
    server = LoopbackHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain('server.crt', 'server.key')
    # The reject server trusts the server leaf as an unrelated anchor.
    context.load_verify_locations(cafile='server.crt' if name == 'reject' else 'ca.crt')
    context.verify_mode = ssl.CERT_REQUIRED
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.label = name
    servers[name] = server
    threading.Thread(target=server.serve_forever, daemon=True).start()
pathlib.Path('events.jsonl').touch()
pathlib.Path('ready.json').write_text(json.dumps({name: server.server_port for name, server in servers.items()}))
while True: time.sleep(60)
