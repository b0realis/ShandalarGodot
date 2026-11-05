"""The downloads' second try when Windows refuses a certificate, and the one
stop when that fails too.

A PLAY-TESTER'S WINDOWS 10 REPORT (2026-11-05): every picture failed with
"certificate verify failed: certificate has expired", while the Scryfall
lookups worked. Scryfall's certificates were valid; the picture server's
chain runs through Let's Encrypt's ISRG Root X2. Python on Windows trusts
BOTH system stores, the trusted roots and the intermediate authorities,
and Windows keeps old certificates in the second: its copy of the X2
cross-signed by ISRG Root X1, expired on 15 September 2025, was taken as
trusted and the chain through it refused. (Reproduced with OpenSSL 3.5: a
store of X1 plus that expired copy refuses cards.scryfall.io exactly so;
X1 alone, or with X2's own root, accepts it.)

NOTHING CHANGES FOR A DOWNLOAD THAT WORKS (the owner, 2026-11-05: *"make
sure the cert fix does not affect normal script users"*):
- on Linux and macOS `install()` does nothing at all;
- on Windows every request goes through Python's own default first; only a
  certificate refused is asked again, trusting the ROOT store alone, as
  Windows itself does (the chain the server sends supplies the
  intermediates; SSL_CERT_FILE and SSL_CERT_DIR still count), and the rest
  of the run keeps that trust.

A certificate that still cannot be checked (a wrong clock, a virus
scanner reading HTTPS, a missing root) ends the run at once with what to do
(`stop_if_refused`), instead of one warning per card.
"""

from __future__ import annotations

import http.client
import ssl
import sys
import urllib.error
import urllib.request

GUIDE = "https://b0realis.github.io/ShandalarGodot/#faq-title"

ADVICE = """\
Stopped: this computer could not check the download server's certificate
({reason}).
The fix is on this computer:
- check that its date and time are right;
- a virus scanner that checks HTTPS traffic can cause this: turn that
  scanning off while the pictures download;
- Windows: run  py -3 -m pip install --upgrade certifi  and then, in the same
  window,  for /f %i in ('py -3 -m certifi') do set SSL_CERT_FILE=%i
- macOS: run Install Certificates.command in Applications > Python 3.x;
- Linux: update the ca-certificates package.
Then run the same command again: finished downloads are kept.
More help: {guide}"""


class CertificateRefused(SystemExit):
    """The run's end on a certificate failure: its message is the advice,
    printed without a traceback, and the exit status is 1."""

    def __init__(self, error: BaseException):
        super().__init__(ADVICE.format(reason=_reason(error), guide=GUIDE))


def _reason(error: BaseException) -> str:
    reason = getattr(error, "reason", error)
    return str(getattr(reason, "verify_message", "") or reason)


def refused(error: BaseException) -> bool:
    """Whether [error] (a URLError or the SSL error itself) is a certificate
    that could not be checked."""
    return isinstance(getattr(error, "reason", error), ssl.SSLCertVerificationError) \
        or isinstance(error, ssl.SSLCertVerificationError)


def stop_if_refused(error: BaseException) -> None:
    """Raise CertificateRefused for a certificate failure; anything else is
    left to the caller's own handling."""
    if refused(error):
        raise CertificateRefused(error) from error


def roots_only_context() -> ssl.SSLContext:
    """A context trusting Windows' ROOT store alone (and SSL_CERT_FILE /
    SSL_CERT_DIR): the second try's (see the module doc)."""
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    for cert, encoding, trust in ssl.enum_certificates("ROOT"):
        if encoding == "x509_asn" and (trust is True or ssl.Purpose.SERVER_AUTH.oid in trust):
            try:
                ctx.load_verify_locations(cadata=cert)
            except ssl.SSLError:
                pass   # one odd root costs only itself
    ctx.set_default_verify_paths()
    return ctx


class SecondTryHandler(urllib.request.HTTPSHandler):
    """HTTPS as Python does it by default; a certificate refused is asked
    once more with roots_only_context(), which the rest of the run keeps."""

    def __init__(self):
        super().__init__()
        # Exactly what Python's own HTTPS handler would use: the default
        # context it built (3.12 on), or None, which each connection fills
        # with the default (3.10 and 3.11).
        self.context = getattr(self, "_context", None)
        self.second_try = False

    def https_open(self, req):
        try:
            return self.do_open(http.client.HTTPSConnection, req, context=self.context)
        except urllib.error.URLError as err:
            if self.second_try or not refused(err):
                raise
        self.context = roots_only_context()
        self.second_try = True
        return self.do_open(http.client.HTTPSConnection, req, context=self.context)


_installed = False


def install() -> None:
    """On Windows, every urllib.request.urlopen in this process gets the
    second try (SecondTryHandler); elsewhere nothing changes. Called by
    fetch_cards and fetch_card_art, which every download tool imports;
    calling it again changes nothing."""
    global _installed
    if _installed or sys.platform != "win32":
        return
    urllib.request.install_opener(urllib.request.build_opener(SecondTryHandler()))
    _installed = True
