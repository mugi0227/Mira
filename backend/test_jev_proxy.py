import io
import json
import unittest
from pathlib import Path

from jev_proxy import (INTENTS, MAX_REQUEST_BYTES, ClientError, IntentApplication,
                       Settings, make_payload, parse_input, validate_response)


def answer(intent="checkInvitation", confidence=0.92, probability=0.95):
    distribution = {key: (1 - probability) / (len(INTENTS) - 1) for key in INTENTS}
    distribution[intent] = probability
    return {"model": "jev-1.13.0", "answers": {"intent": {
        "type": "choice", "choice": intent, "confidence": confidence,
        "probabilities": distribution,
    }}}


class JevProxyTests(unittest.TestCase):
    def setUp(self):
        self.settings = Settings(api_key="test-provider-secret", client_token="x" * 40)
        self.calls = []

        def upstream(payload, settings):
            self.calls.append(payload)
            return answer()

        self.app = IntentApplication(self.settings, upstream=upstream)

    def request(self, data=None, app=None, **overrides):
        body = json.dumps(data or {"text": "金曜の飲み会、今週しんどいけど行けるかな", "hasContext": False}, ensure_ascii=False).encode()
        environ = {
            "PATH_INFO": "/v1/intent", "REQUEST_METHOD": "POST",
            "CONTENT_TYPE": "application/json", "CONTENT_LENGTH": str(len(body)),
            "HTTP_AUTHORIZATION": "Bearer " + self.settings.client_token,
            "wsgi.input": io.BytesIO(body),
        }
        environ.update(overrides)
        captured = {}

        def start_response(status, headers):
            captured.update(status=int(status.split()[0]), headers=dict(headers))

        result = b"".join((app or self.app)(environ, start_response))
        return captured["status"], json.loads(result), captured["headers"]

    def test_authenticated_request_forwards_only_minimal_state(self):
        status, result, headers = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(result["intent"], "checkInvitation")
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(set(self.calls[0]["state"]), {"userInput", "hasSelectedCase"})
        self.assertEqual(self.calls[0]["model"], "jev-1.13.0")
        self.assertNotIn(self.settings.api_key, json.dumps(result))

    def test_missing_and_wrong_credentials_never_call_upstream(self):
        for authorization in ("", "Bearer wrong", "Bearer 日本語"):
            with self.subTest(authorization=authorization):
                self.assertEqual(self.request(HTTP_AUTHORIZATION=authorization)[0], 401)
        self.assertEqual(self.calls, [])

    def test_invalid_request_size_type_and_length_fail_before_upstream(self):
        overrides = [
            ({"CONTENT_LENGTH": str(MAX_REQUEST_BYTES + 1)}, 413),
            ({"CONTENT_LENGTH": "-1"}, 411),
            ({"CONTENT_LENGTH": ""}, 411),
            ({"CONTENT_TYPE": "text/plain"}, 415),
            ({"HTTP_TRANSFER_ENCODING": "chunked"}, 400),
            ({"QUERY_STRING": "input=private"}, 404),
            ({"REQUEST_METHOD": "GET"}, 405),
            ({"PATH_INFO": "/v1/arbitrary-proxy"}, 404),
        ]
        for value, expected in overrides:
            with self.subTest(value=value):
                self.assertEqual(self.request(**value)[0], expected)
        self.assertEqual(self.calls, [])

    def test_rejects_arbitrary_model_calendar_and_schema_fields(self):
        invalid = [
            {"text": "hello", "hasContext": False, "model": "other"},
            {"text": "hello", "hasContext": False, "calendar": []},
            {"text": "hello", "hasContext": "false"},
            {"text": " ", "hasContext": False},
            {"text": "a" * 2001, "hasContext": False},
            {"text": "\x00", "hasContext": False},
        ]
        for value in invalid:
            with self.subTest(value=str(value)[:100]):
                self.assertEqual(self.request(data=value)[0], 400)
        self.assertEqual(self.calls, [])

    def test_invalid_unicode_json_is_rejected(self):
        for body in (b"\xff", b"{bad", b'{"text":"\\ud800","hasContext":false}'):
            with self.assertRaises(ClientError):
                parse_input(body)

    def test_malformed_model_decisions_fail_closed(self):
        invalid = [None, {}, {"answers": {"intent": []}}, answer(confidence=float("nan")),
                   answer(confidence=True), answer(confidence=1.1)]
        bad_choice = answer()
        bad_choice["answers"]["intent"]["choice"] = "deleteEverything"
        invalid.append(bad_choice)
        bad_distribution = answer()
        bad_distribution["answers"]["intent"]["probabilities"]["unknown"] = 1
        invalid.append(bad_distribution)
        for value in invalid:
            with self.subTest(value=value):
                with self.assertRaises(ClientError):
                    validate_response(value)

    def test_timeout_and_provider_failure_do_not_echo_secrets(self):
        def fail(payload, settings):
            raise TimeoutError("private input or provider credentials must never be returned")

        status, result, _ = self.request(app=IntentApplication(self.settings, upstream=fail))
        self.assertEqual(status, 503)
        self.assertEqual(result, {"error": "service_unavailable"})

    def test_changed_upstream_model_is_rejected(self):
        def changed(payload, settings):
            value = answer()
            value["model"] = "jev-1.14.0"
            return value

        self.assertEqual(self.request(app=IntentApplication(self.settings, upstream=changed))[0], 502)

    def test_rate_limit_resets_and_does_not_charge_bad_inputs(self):
        settings = Settings(api_key="test", client_token=self.settings.client_token, requests_per_minute=1)
        clock = [100.0]
        app = IntentApplication(settings, upstream=lambda *_: answer(), clock=lambda: clock[0])
        self.assertEqual(self.request(app=app, HTTP_AUTHORIZATION="wrong")[0], 401)
        self.assertEqual(self.request(app=app)[0], 200)
        self.assertEqual(self.request(app=app)[0], 429)
        clock[0] = 160
        self.assertEqual(self.request(app=app)[0], 200)

    def test_configuration_cannot_run_open_or_with_a_moving_model(self):
        for changes in ({"api_key": ""}, {"client_token": ""}, {"client_token": "short"},
                        {"model": "jev-latest"}, {"timeout": 30}):
            values = dict(api_key="test", client_token="x" * 40)
            values.update(changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                Settings(**values)

    def test_japanese_fixture_contract_with_mocked_decisions(self):
        # This verifies integration for the labeled examples, NOT the model's Japanese accuracy.
        cases = json.loads((Path(__file__).parent / "fixtures" / "intent-cases-ja.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(cases), 20)
        for case in cases:
            with self.subTest(case=case["id"]):
                value = {"text": case["text"], "hasContext": case["hasContext"]}
                self.assertEqual(parse_input(json.dumps(value).encode()), value)
                self.assertEqual(set(make_payload(value, self.settings.model)["questions"]), {"intent"})
                self.assertEqual(validate_response(answer(case["expected"]))["intent"], case["expected"])


if __name__ == "__main__":
    unittest.main()
