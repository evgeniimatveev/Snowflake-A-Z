"""Regenerate the 'What's covered' table in README.md from practices.json.

practices.json is the single source of truth for the practice list. Running
this script keeps README.md in sync with it -- no more hand-editing the
markdown table (and no risk of the encoding mistakes that come with it).
"""
import json
import re
import sys

START_MARKER = "<!-- PRACTICES_TABLE:START -->"
END_MARKER = "<!-- PRACTICES_TABLE:END -->"


def build_table(practices):
    header = "| # | File | Topic | Verified result |\n|---|------|-------|------------------|"
    rows = [
        f"| {p['num']} | [`{p['file']}`]({p['file']}) | {p['topic']} | {p['result']} |"
        for p in practices
    ]
    return "\n".join([header, *rows])


def main():
    with open("practices.json", encoding="utf-8") as f:
        practices = json.load(f)

    with open("README.md", encoding="utf-8") as f:
        readme = f.read()

    if START_MARKER not in readme or END_MARKER not in readme:
        print(f"ERROR: markers {START_MARKER!r} / {END_MARKER!r} not found in README.md")
        sys.exit(1)

    table = build_table(practices)
    pattern = re.compile(
        re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER), re.DOTALL
    )
    new_readme = pattern.sub(f"{START_MARKER}\n{table}\n{END_MARKER}", readme)

    if new_readme == readme:
        print("README.md already up to date.")
        return

    with open("README.md", "w", encoding="utf-8") as f:
        f.write(new_readme)
    print("README.md updated from practices.json.")


if __name__ == "__main__":
    main()
