"""Generate a Sparkle 2 EdDSA (Ed25519) key pair without a Mac.

Same format as Sparkle's `generate_keys` / `generate_keys -x`:
  - SUPublicEDKey: base64 of the 32-byte raw public key  -> App Info.plist
  - private key:   base64 of the 32-byte private seed    -> GitHub secret SPARKLE_ED_PRIVATE_KEY
                   (CI pipes it to `generate_appcast --ed-key-file -`)

Prints both to the terminal and writes nothing to disk. Keep an offline copy of the private
key: if it is lost, existing installs can never verify another update.

    pip install cryptography
    python tools/sparkle_keys.py
"""
import base64

from cryptography.hazmat.primitives import serialization as s
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

key = Ed25519PrivateKey.generate()
seed = key.private_bytes(s.Encoding.Raw, s.PrivateFormat.Raw, s.NoEncryption())
public = key.public_key().public_bytes(s.Encoding.Raw, s.PublicFormat.Raw)
assert len(seed) == 32 and len(public) == 32

# No indent: whitespace copied along with a key breaks signing (see docs/RELEASING.md step 4).
print("SUPublicEDKey (Info.plist, public):")
print(base64.b64encode(public).decode())
print("SPARKLE_ED_PRIVATE_KEY (GitHub secret, never commit):")
print(base64.b64encode(seed).decode())
