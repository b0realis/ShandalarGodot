"""The downloads' HTTPS trust (tools/tls_trust.py; a play-tester's Windows 10
report, 2026-11-05: every picture refused with "certificate has expired").

Run: python3 -m unittest discover -s tools -p 'test_tls_trust.py'
"""

import contextlib
import io
import ssl
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_card_art  # noqa: E402
import tls_trust  # noqa: E402
from test_build_card_packs import FakeScryfall, JPEG, card_json  # noqa: E402

SERVER_AUTH = ssl.Purpose.SERVER_AUTH.oid
EXPIRED = ssl.SSLCertVerificationError(1, "certificate verify failed: certificate has expired")
EXPIRED.verify_message = "certificate has expired"


class FakeContext:
    """What tls_trust.context() builds on Windows, minus OpenSSL."""

    def __init__(self, _protocol):
        self.loaded = []
        self.default_paths = False

    def load_verify_locations(self, cadata=None):
        self.loaded.append(cadata)

    def set_default_verify_paths(self):
        self.default_paths = True


class NothingChangesForADownloadThatWorksTest(unittest.TestCase):
    """The owner, 2026-11-05: the fix must not touch the players whose
    downloads work. Off Windows nothing is installed; on Windows a request
    goes through Python's own default first, and only a certificate refused
    is asked again."""

    def setUp(self):
        self.seen = []
        self.answers = []

    def _handler(self):
        handler = tls_trust.SecondTryHandler()

        def do_open(_connection, _req, context=None):
            self.seen.append(context)
            answer = self.answers.pop(0)
            if isinstance(answer, BaseException):
                raise answer
            return answer
        handler.do_open = do_open
        return handler

    def test_off_windows_nothing_is_installed(self):
        before = urllib.request._opener
        with mock.patch.object(tls_trust.sys, "platform", "linux"), \
                mock.patch.object(tls_trust, "_installed", False):
            tls_trust.install()
            self.assertFalse(tls_trust._installed)
        self.assertIs(urllib.request._opener, before)

    def test_a_download_that_works_uses_python_s_own_default(self):
        default = urllib.request.HTTPSHandler()
        handler = self._handler()
        self.answers = ["picture", "picture"]
        with mock.patch.object(tls_trust, "roots_only_context",
                               side_effect=AssertionError("no second try")):
            self.assertEqual(handler.https_open(object()), "picture")
            self.assertEqual(handler.https_open(object()), "picture")
        first = getattr(default, "_context", None)
        if first is None:
            self.assertEqual(self.seen, [None, None])
        else:   # 3.12 on: the handler's default context, the same kind
            self.assertEqual([type(c) for c in self.seen], [type(first)] * 2)
            self.assertEqual({c.verify_mode for c in self.seen}, {ssl.CERT_REQUIRED})

    def test_only_a_refused_certificate_is_asked_again_and_then_kept(self):
        roots = object()
        handler = self._handler()
        self.answers = [urllib.error.URLError(EXPIRED), "picture", "picture"]
        with mock.patch.object(tls_trust, "roots_only_context", return_value=roots):
            self.assertEqual(handler.https_open(object()), "picture")
            self.assertEqual(handler.https_open(object()), "picture")
        self.assertIs(self.seen[1], roots)
        self.assertIs(self.seen[2], roots)

    def test_another_failure_is_not_asked_again(self):
        handler = self._handler()
        self.answers = [urllib.error.URLError(TimeoutError("timed out"))]
        with mock.patch.object(tls_trust, "roots_only_context",
                               side_effect=AssertionError("no second try")), \
                self.assertRaises(urllib.error.URLError):
            handler.https_open(object())

    def test_a_second_refusal_is_the_caller_s(self):
        handler = self._handler()
        self.answers = [urllib.error.URLError(EXPIRED), urllib.error.URLError(EXPIRED)]
        with mock.patch.object(tls_trust, "roots_only_context", return_value=object()), \
                self.assertRaises(urllib.error.URLError) as caught:
            handler.https_open(object())
        self.assertTrue(tls_trust.refused(caught.exception))


class TheSecondTryTrustsTheRootsAloneTest(unittest.TestCase):
    """Python's own Windows context loads the CA store too, where the
    expired ISRG Root X2 cross-sign sat and was taken as trusted."""

    def test_only_the_root_store_is_read_and_only_for_servers(self):
        asked = []

        def stores(name):
            asked.append(name)
            return [(b"root-for-everything", "x509_asn", True),
                    (b"root-for-servers", "x509_asn", {SERVER_AUTH}),
                    (b"root-for-code-only", "x509_asn", {"1.3.6.1.5.5.7.3.3"}),
                    (b"a-pkcs7-bundle", "pkcs_7_asn", True)]

        with mock.patch.object(tls_trust.ssl, "enum_certificates", stores, create=True), \
                mock.patch.object(tls_trust.ssl, "SSLContext", FakeContext):
            ctx = tls_trust.roots_only_context()
        self.assertEqual(asked, ["ROOT"])
        self.assertEqual(ctx.loaded, [b"root-for-everything", b"root-for-servers"])
        self.assertTrue(ctx.default_paths, "SSL_CERT_FILE still counts")


class ACertificateFailureStopsTheRunTest(unittest.TestCase):
    """One certificate refused is every picture refused: the run stops with
    the fix, instead of a warning for each card."""

    def setUp(self):
        patcher = mock.patch.object(fetch_card_art.time, "sleep", lambda _s: None)
        patcher.start()
        self.addCleanup(patcher.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)

    def test_only_a_certificate_failure_counts(self):
        self.assertTrue(tls_trust.refused(urllib.error.URLError(EXPIRED)))
        self.assertTrue(tls_trust.refused(EXPIRED))
        self.assertFalse(tls_trust.refused(urllib.error.URLError(TimeoutError("timed out"))))
        self.assertFalse(tls_trust.refused(ValueError("not a whole JPEG")))

    def test_a_refused_picture_stops_with_the_fix(self):
        scryfall = FakeScryfall({"named?exact": card_json("leg"),
                                 "/art.jpg": urllib.error.URLError(EXPIRED), "/card.jpg": JPEG})
        printed = io.StringIO()
        with mock.patch.object(fetch_card_art.urllib.request, "urlopen", scryfall), \
                contextlib.redirect_stdout(printed), \
                self.assertRaises(tls_trust.CertificateRefused) as caught:
            fetch_card_art.fetch_missing_art("Arboria", "leg", fetch_card_art.targets_for("Arboria", self.dir))
        advice = str(caught.exception.code)
        self.assertIn("certificate has expired", advice)
        self.assertIn("date and time", advice)
        self.assertIn("certifi", advice)
        self.assertIn(tls_trust.GUIDE, advice)
        self.assertNotIn("WARN", printed.getvalue())
        self.assertEqual(list(self.dir.iterdir()), [], "nothing staged is left behind")
        self.assertTrue(isinstance(caught.exception, SystemExit), "no traceback, exit status 1")

    def test_a_refused_lookup_stops_too(self):
        scryfall = FakeScryfall({"named?exact": urllib.error.URLError(EXPIRED)})
        with mock.patch.object(fetch_card_art.urllib.request, "urlopen", scryfall), \
                contextlib.redirect_stdout(io.StringIO()), \
                self.assertRaises(tls_trust.CertificateRefused):
            fetch_card_art.fetch_art_url("Arboria", "leg")

    def test_another_failure_still_warns_and_goes_on(self):
        scryfall = FakeScryfall({"named?exact": card_json("leg"),
                                 "/art.jpg": urllib.error.URLError(TimeoutError("timed out")),
                                 "/card.jpg": JPEG})
        printed = io.StringIO()
        with mock.patch.object(fetch_card_art.urllib.request, "urlopen", scryfall), \
                contextlib.redirect_stdout(printed):
            done, failed = fetch_card_art.fetch_missing_art(
                "Arboria", "leg", fetch_card_art.targets_for("Arboria", self.dir))
        self.assertEqual((done, failed), (1, 1))
        self.assertIn("WARN: download failed for Arboria (art_crop)", printed.getvalue())


if __name__ == "__main__":
    unittest.main()
