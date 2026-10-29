from html.parser import HTMLParser
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tags = []
        self.ids = set()
        self.fragments = []
        self.image_without_alt = []
        self.external_assets = []
        self.headings = {1: 0}
        self.in_title = False
        self.title = ""

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        self.tags.append((tag, values))
        if values.get("id"):
            self.ids.add(values["id"])
        if tag == "a" and values.get("href", "").startswith("#"):
            self.fragments.append(values["href"][1:])
        if tag == "img" and "alt" not in values:
            self.image_without_alt.append(values.get("src", "unknown"))
        if tag == "script" and values.get("src", "").startswith(("http://", "https://")):
            self.external_assets.append(values["src"])
        if tag == "link" and values.get("href", "").startswith(("http://", "https://")) and values.get("rel") in ("stylesheet", "preconnect"):
            self.external_assets.append(values["href"])
        if tag == "title":
            self.in_title = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data.strip()


class PortalHtmlTests(unittest.TestCase):
    def test_each_page_has_semantic_landmarks_and_one_main_heading(self):
        for filename in ("index.html", "architecture.html", "404.html"):
            with self.subTest(page=filename):
                parser = Page()
                parser.feed((ROOT / "web" / filename).read_text())
                tags = [tag for tag, _ in parser.tags]
                self.assertIn("main", tags)
                self.assertEqual(tags.count("h1"), 1)
                self.assertIn("en", dict(next(attrs for tag, attrs in parser.tags if tag == "html")).get("lang", ""))
                self.assertTrue(parser.title)
                self.assertFalse(parser.image_without_alt)
                self.assertFalse(parser.external_assets)

    def test_internal_fragment_links_resolve_and_assets_are_local(self):
        parser = Page()
        parser.feed((ROOT / "web/index.html").read_text())
        self.assertEqual(parser.fragments, [fragment for fragment in parser.fragments if fragment in parser.ids])
        self.assertFalse(parser.external_assets)

    def test_homepage_has_unique_metadata_and_project_identity(self):
        text = (ROOT / "web/index.html").read_text()
        project = __import__("json").loads((ROOT / "project.json").read_text())
        self.assertIn(project["id"].upper(), text)
        self.assertIn(f"https://{project['hostname']}/", text)
        self.assertIn('name="description"', text)
        self.assertIn('property="og:title"', text)


if __name__ == "__main__":
    unittest.main()
