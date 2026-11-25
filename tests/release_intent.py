"""Release trigger validation; no tag or network mutations."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_intent", Path(__file__).resolve().parents[1] / "scripts/release_intent.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = "a" * 40
REQUEST = {"version": "2.0.0", "commit": SHA}


class ReleaseIntentTests(unittest.TestCase):
    def call(self, event="push", ref="refs/heads/main", payload=None, request=REQUEST,
             repo=module.REPO, actor=module.OWNER, retry=module.OWNER):
        if payload is None:
            payload = {"deleted": False}
        return module.parse_intent(repo, actor, retry, event, ref, payload, request)

    def test_owner_request(self):
        self.assertEqual(self.call(), ("2.0.0", SHA, "request"))

    def test_owner_dispatch(self):
        self.assertEqual(self.call("workflow_dispatch", payload={"inputs": REQUEST}), ("2.0.0", SHA, "request"))

    def test_owner_tag(self):
        self.assertEqual(self.call(ref="refs/tags/v2.0.0"), ("2.0.0", None, "tag"))

    def test_unauthorized_actor_retry_fork(self):
        for event, ref, payload in (("push", "refs/heads/main", {"deleted": False}),
            ("workflow_dispatch", "refs/heads/main", {"inputs": REQUEST}),
            ("push", "refs/tags/v2.0.0", {"deleted": False})):
            for kwargs in ({"actor": "contributor"}, {"retry": "contributor"}, {"repo": "fork/names-in-red"}):
                with self.subTest(event=event, kwargs=kwargs), self.assertRaises(ValueError):
                    self.call(event, ref, payload, **kwargs)

    def test_wrong_event_or_ref(self):
        for event, ref, payload in (("pull_request", "refs/heads/main", {}),
            ("push", "refs/heads/feature", {"deleted": False}),
            ("workflow_dispatch", "refs/heads/feature", {"inputs": REQUEST}),
            ("push", "refs/tags/v2.0.0", {"deleted": True}),
            ("push", "refs/tags/v2.0.0-preview", {"deleted": False}),
            ("workflow_dispatch", "refs/tags/v2.0.0", {"inputs": REQUEST})):
            with self.subTest(event=event, ref=ref), self.assertRaises(ValueError):
                self.call(event, ref, payload)

    def test_bad_request(self):
        for request in (None, {}, {"version": "2.0", "commit": SHA},
            {"version": "2.0.0", "commit": "main"}, {"version": "2.0.0", "commit": "a" * 39},
            {"version": "2.0.0\nmode=tag", "commit": SHA},
            dict(REQUEST, extra=True), {"version": 2, "commit": SHA}):
            with self.subTest(request=request), self.assertRaises(ValueError):
                self.call(request=request)


if __name__ == "__main__":
    unittest.main()
