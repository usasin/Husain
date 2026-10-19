import copy
import unittest
from APPLE_REVIEW_99 import BUILD_ID, VERSION_ID, validate_plan


class ReviewGuardsTest(unittest.TestCase):
    def setUp(self):
        self.version = {"id": VERSION_ID, "attributes": {"versionString": "2.8.14"}}
        self.build = {"id": BUILD_ID, "attributes": {"version": "99", "processingState": "VALID", "expired": False}}
        self.locales = [{"id": "fr", "attributes": {"locale": "fr-FR", "description": "PRONO4", "supportUrl": "https://example.com"}}]

    def test_accepts_exact_valid_build(self):
        validate_plan(self.version, self.build, self.locales)

    def test_refuses_another_version_before_withdrawal(self):
        self.version["id"] = "another-version"
        with self.assertRaises(RuntimeError):
            validate_plan(self.version, self.build, self.locales)

    def test_refuses_another_build(self):
        self.build["id"] = "another-build"
        with self.assertRaises(RuntimeError):
            validate_plan(self.version, self.build, self.locales)

    def test_refuses_processing_or_expired_build(self):
        for change in ({"processingState": "PROCESSING"}, {"expired": True}):
            build = copy.deepcopy(self.build)
            build["attributes"].update(change)
            with self.assertRaises(RuntimeError):
                validate_plan(self.version, build, self.locales)

    def test_refuses_incomplete_metadata_before_withdrawal(self):
        self.locales[0]["attributes"]["supportUrl"] = None
        with self.assertRaises(RuntimeError):
            validate_plan(self.version, self.build, self.locales)

    def test_refuses_missing_translation_before_withdrawal(self):
        self.locales.append({"attributes": {"locale": "de-DE", "description": "PRONO4", "supportUrl": "https://example.com"}})
        with self.assertRaises(RuntimeError):
            validate_plan(self.version, self.build, self.locales)


if __name__ == "__main__":
    unittest.main()
