#!/usr/bin/env python3
"""Exercise wiki wrappers without calling real services or changing the real wiki."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BIN = Path(os.environ.get("WIKI_TEST_BIN", Path(__file__).resolve().parents[2] / "bin"))


class WikiWrappers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="wiki-wrapper-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.wiki = self.root / "LLM-WIKI"
        self.wiki.mkdir()
        fake = self.root / "bin"
        fake.mkdir()
        self.calls = self.root / "calls.json"
        self.env = dict(os.environ, PATH=str(fake) + os.pathsep + os.environ["PATH"],
                        LLM_WIKI_DIR=str(self.wiki), CALLS=str(self.calls),
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        self.env.pop("LLM_WIKI_INSTANCE_ID", None)
        (fake / "llm-instance").write_text(
            '#!/bin/sh\n[ "${IDENTITY_FAIL:-}" != 1 ] || exit 4\nprintf "test-machine\\n"\n')
        (fake / "llm-wiki-git").write_text(
            '#!/usr/bin/env python3\nimport json,os,sys\n'
            'with open(os.environ["CALLS"], "w") as f: json.dump(sys.argv[1:], f)\n')
        for p in fake.iterdir():
            p.chmod(0o755)
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.write("index.md", "# Index\n[Note](note.md)\n[Instances](instances/index.md)\n")
        self.write("note.md", "---\ntype: Note\n---\nBaseline\n")
        self.write("instances/index.md", "# Instances\n[test-machine](test-machine.md)\n")
        self.write("instances/test-machine.md", "---\ntype: Instance\ninstance_id: test-machine\n---\n")
        self.git("add", ".")
        self.git("commit", "-qm", "test-machine: baseline")

    def write(self, name, text):
        p = self.wiki / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.wiki), *args], env=self.env,
                              check=True, capture_output=True, text=True)

    def run_wrapper(self, name, *args):
        return subprocess.run(["/bin/bash", str(BIN / name), *args], env=self.env,
                              capture_output=True, text=True)

    def test_plain_summary_uses_validated_identity(self):
        r = self.run_wrapper("llm-wiki-commit", "record notes", "--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(self.calls.read_text()),
                         ["commit", "-m", "test-machine: record notes", "--dry-run"])

    def test_colon_is_not_an_identity(self):
        self.run_wrapper("llm-wiki-commit", "repair: metadata")
        self.assertEqual(json.loads(self.calls.read_text())[2], "test-machine: repair: metadata")

    def test_current_prefix_is_not_duplicated(self):
        self.run_wrapper("llm-wiki-commit", "test-machine: repair")
        self.assertEqual(json.loads(self.calls.read_text())[2], "test-machine: repair")

    def test_identity_failure_never_calls_git(self):
        self.env["IDENTITY_FAIL"] = "1"
        self.assertNotEqual(self.run_wrapper("llm-wiki-commit", "repair").returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_override_cannot_replace_validated_identity(self):
        self.env["LLM_WIKI_INSTANCE_ID"] = "other-machine"
        self.assertNotEqual(self.run_wrapper("llm-wiki-commit", "repair").returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_no_summary_does_not_commit(self):
        self.assertNotEqual(self.run_wrapper("llm-wiki-commit").returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_tracked_default_and_working_tree_scope(self):
        self.write("new.md", "No frontmatter\n")
        self.assertEqual(self.run_wrapper("llm-wiki-lint").returncode, 0)
        r = self.run_wrapper("llm-wiki-lint", "--working-tree")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("frontmatter missing: new.md", r.stdout)
        self.git("add", "new.md")
        self.assertEqual(self.run_wrapper("llm-wiki-lint").returncode, 1)

    def test_redirect_coverage_does_not_restore_retired_index(self):
        self.write("retired/index.md", "---\ntype: Redirect\nredirect_to: ../note.md\n---\nMoved\n")
        self.write("retired/old.md", "---\ntype: Redirect\nredirect_to: ../note.md\n---\nMoved\n")
        self.git("add", ".")
        r = self.run_wrapper("llm-wiki-lint")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("not in", r.stdout)
        self.write("retired/index.md", "---\ntype: Redirect\n---\nUnstructured destination\n")
        r = self.run_wrapper("llm-wiki-lint")
        self.assertIn("redirect target needs manual review", r.stdout)

    def test_redirect_missing_explicit_target_is_failure(self):
        self.write("retired.md", "---\ntype: Redirect\nredirect_to: absent.md\n---\n")
        self.git("add", ".")
        r = self.run_wrapper("llm-wiki-lint")
        self.assertEqual(r.returncode, 1)
        self.assertIn("missing redirect target", r.stdout)

    def test_vault_link_reports_portability_not_missing_file(self):
        self.write("note.md", "---\ntype: Note\n---\n[Note](LLM-WIKI/note.md)\n")
        r = self.run_wrapper("llm-wiki-lint")
        self.assertIn("vault-root link needs Git-only translation", r.stdout)
        self.assertNotIn("broken link", r.stdout)
        self.write("note.md", "---\ntype: Note\n---\n[Missing](LLM-WIKI/absent.md)\n")
        self.assertIn("broken link", self.run_wrapper("llm-wiki-lint").stdout)

    def test_directory_link_remains_failure(self):
        self.write("note.md", "---\ntype: Note\n---\n[Instances](instances/)\n")
        self.assertEqual(self.run_wrapper("llm-wiki-lint").returncode, 1)

    def test_unknown_option_fails(self):
        self.assertEqual(self.run_wrapper("llm-wiki-lint", "--unknown").returncode, 64)


if __name__ == "__main__":
    unittest.main()
