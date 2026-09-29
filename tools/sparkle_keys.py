"""Sparkle 2 EdDSA (Ed25519) keys without a Mac, standard library only.

Same format as Sparkle's `generate_keys` / `generate_keys -x`:
  - SUPublicEDKey: base64 of the 32-byte raw public key  -> App Info.plist
  - private key:   base64 of the 32-byte private seed    -> GitHub secret SPARKLE_ED_PRIVATE_KEY
                   (CI pipes it to `generate_appcast --ed-key-file -`)

    python tools/sparkle_keys.py              # new pair, printed to the terminal, nothing written to disk
    python tools/sparkle_keys.py public       # SUPublicEDKey of $SPARKLE_ED_PRIVATE_KEY (release.yml preflight)
    python tools/sparkle_keys.py --self-test  # RFC 8032 test vectors only

Keep an offline copy of the private key: if it is lost, existing installs can never verify another update.
"""
import base64
import hashlib
import os
import re
import secrets
import sys

# Ed25519 public key from a seed, after RFC 8032 §5.1.5 and its reference code (§6). Only ever derives a public key,
# never signs. ponytail: not constant-time; fine for this one-shot derivation, never for signing.
P = 2**255 - 19
D = -121665 * pow(121666, P - 2, P) % P
GX = 15112221349535400772501151409588531511454012693041857206046113283949847762202
GY = 46316835694926478169428394003475163141307993866256225615783033603165251855960


def add(a, b):  # RFC 8032 §5.1.4, extended coordinates (X, Y, Z, T); Dz is the RFC's D
    A, B = (a[1] - a[0]) * (b[1] - b[0]) % P, (a[1] + a[0]) * (b[1] + b[0]) % P
    C, Dz = 2 * a[3] * b[3] * D % P, 2 * a[2] * b[2] % P
    E, F, G, H = B - A, Dz - C, Dz + C, B + A
    return E * F % P, G * H % P, F * G % P, E * H % P


def public_key(seed):
    assert len(seed) == 32
    s = int.from_bytes(hashlib.sha512(seed).digest()[:32], "little") & (2**254 - 8) | 2**254   # clamp
    q, g = (0, 1, 1, 0), (GX, GY, 1, GX * GY % P)
    while s:
        if s & 1:
            q = add(q, g)
        g, s = add(g, g), s >> 1
    zi = pow(q[2], P - 2, P)
    x, y = q[0] * zi % P, q[1] * zi % P
    return (y | (x & 1) << 255).to_bytes(32, "little")


# RFC 8032 §7.1 tests 1-3 (secret key, public key), checked on every run.
for sk, pk in [("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
                "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"),
               ("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb",
                "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"),
               ("c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7",
                "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025")]:
    assert public_key(bytes.fromhex(sk)).hex() == pk, "Ed25519 derivation fails RFC 8032"

arg = sys.argv[1] if len(sys.argv) > 1 else ""
if arg == "--self-test":
    print("sparkle_keys: RFC 8032 vectors ok")
elif arg == "public":
    # Strict, after the same whitespace strip as release.yml's publish: generate_appcast rejects anything else.
    # The key comes from the environment, never argv, and never appears in an error.
    try:
        k = base64.b64decode(re.sub(r"\s", "", os.environ.get("SPARKLE_ED_PRIVATE_KEY", "")), validate=True)
    except ValueError:
        k = b""
    # 32 bytes: seed (this tool, generate_keys -x). 96 bytes: Sparkle's older export format, the 64-byte private key
    # then the 32-byte public key (common_cli/Secret.swift, Sparkle 2.10.0).
    if len(k) not in (32, 96):
        sys.exit("SPARKLE_ED_PRIVATE_KEY must be base64 of a 32-byte seed (or Sparkle's 96-byte export)")
    print(base64.b64encode(k[64:] if len(k) == 96 else public_key(k)).decode())
elif arg == "":
    seed = secrets.token_bytes(32)   # RFC 8032 §5.1.5: the private key is 32 random bytes
    # No indent: whitespace copied along with a key breaks signing (see docs/RELEASING.md step 4).
    print("SUPublicEDKey (Info.plist, public):")
    print(base64.b64encode(public_key(seed)).decode())
    print("SPARKLE_ED_PRIVATE_KEY (GitHub secret, never commit):")
    print(base64.b64encode(seed).decode())
else:
    sys.exit(__doc__)
