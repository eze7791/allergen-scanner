import re


def find_allergens_in_text(text_lines: list[str], known_allergens: list[str]) -> list[str]:
    """Return known allergen names found in the extracted text lines."""
    found = []
    full_text = " ".join(text_lines).lower()
    for allergen in known_allergens:
        pattern = re.compile(r"\b" + re.escape(allergen.lower()) + r"\b")
        if pattern.search(full_text):
            found.append(allergen)
    return found
