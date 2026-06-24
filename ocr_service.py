import io
import re
from typing import Optional
from PIL import Image
import easyocr

# Lazy singleton reader instance
_reader: Optional[easyocr.Reader] = None


def get_reader() -> easyocr.Reader:
    global _reader
    if _reader is None:
        # English by default; add 'es' or others as needed
        _reader = easyocr.Reader(["en"])
    return _reader


def extract_text_from_image(image_bytes: bytes) -> list[str]:
    """Run OCR on raw image bytes and return list of detected text lines."""
    image = Image.open(io.BytesIO(image_bytes))
    # Convert to RGB if needed (handles RGBA, P, etc.)
    if image.mode != "RGB":
        image = image.convert("RGB")

    reader = get_reader()
    results = reader.readtext(image, detail=0)
    # Normalize and deduplicate while preserving order
    seen = set()
    lines = []
    for line in results:
        stripped = line.strip()
        if stripped and stripped.lower() not in seen:
            seen.add(stripped.lower())
            lines.append(stripped)
    return lines


def find_allergens_in_text(text_lines: list[str], known_allergens: list[str]) -> list[str]:
    """Return known allergen names found in the extracted text lines."""
    found = []
    full_text = " ".join(text_lines).lower()
    for allergen in known_allergens:
        # Simple whole-word-ish matching; adjust as needed
        pattern = re.compile(r"\b" + re.escape(allergen.lower()) + r"\b")
        if pattern.search(full_text):
            found.append(allergen)
    return found
