#!/usr/bin/env python3
"""puzzle/check.py: check an answer to the puzzle at the foot of README.md.

  python3 puzzle/check.py                 checks puzzle/answer.txt
  python3 puzzle/check.py "your answer"   checks the text you give it

The puzzle is optional. Nothing else in this repo uses it, and it's safe to
ignore.

HOW IT CHECKS (in order; it stops at the first test that fails)
  1. There is an answer: one line of text.
  2. It's the right length: one letter for each number.
  3. Each letter, encoded by the rule in the README footer, gives the number
     in the same place. It tells you the first place that doesn't match.
  4. A fingerprint (the first 16 hex digits of the SHA-256 of the whole
     answer) matches, as a final cross-check.

TO PROVE YOU SOLVED IT
  Put your answer in puzzle/answer.txt and open a pull request. Reviewers
  (and, once it's switched on, an automatic "puzzle" check) run this file.

This file doesn't contain the answer, only the numbers and the rule, both
of which are already public in the README.

Written by: Claude (2026-11-21)
"""
import hashlib
import sys
from pathlib import Path

# The rule from the README footer: n = (7*c + F) mod 257, where c is the
# letter's ASCII code and F is the Fibonacci number in that place (1, 1, 2, 3, 5, ...).
MULTIPLIER = 7
MODULUS = 257  # a prime, so every letter has exactly one number, and back
NUMBERS = [
    255, 201, 226, 79, 11, 56, 237, 193, 227, 22, 81, 220, 200, 154, 137, 124, 82,
    65, 36, 80, 168, 220, 115, 75, 153, 25, 37, 235, 235, 179, 130, 201, 114, 35,
    213, 2, 139, 76, 52, 93, 148, 12, 165, 255, 199, 96, 113, 172, 251, 79, 41,
    232, 164, 140, 41, 2, 93, 180, 211, 110, 238, 147, 44, 96, 253, 79, 146, 60,
    109, 0, 89, 40, 220, 228, 178, 115, 215, 67, 247, 60, 1, 227, 229, 172, 124,
    92, 27, 187, 218, 111, 112, 30, 241, 43, 49, 46, 110, 157, 39, 158, 15, 171,
    106, 123, 192, 24, 213, 105, 77, 187, 191, 189, 72, 171, 162, 94, 67, 124, 157,
    194, 71, 214, 204, 144, 248, 189, 15, 170, 224, 60, 247, 16, 236, 144, 191, 214,
    254, 194, 206, 85, 67, 94, 44, 5, 71, 115, 74, 138, 122, 179, 62, 17, 28,
    240, 85, 73, 233, 127, 216, 192, 145, 229, 113, 88, 201, 100, 115, 223, 33, 236,
    116, 166, 29, 109, 157, 178, 138, 43, 55, 64, 36, 143, 24, 48, 70, 38, 211,
    212, 132, 60, 84, 79, 203, 194, 211, 37, 242, 135, 110,
]
FINGERPRINT = "3ee8ea4549bd1554"


def fibonacci(count):
    """The first `count` Fibonacci numbers: 1, 1, 2, 3, 5, 8, ..."""
    values = [1, 1]
    while len(values) < count:
        values.append(values[-1] + values[-2])
    return values[:count]


def encode(text):
    """Apply the README's rule to every letter of `text`."""
    return [(MULTIPLIER * ord(letter) + f) % MODULUS
            for letter, f in zip(text, fibonacci(len(text)))]


def main():
    if len(sys.argv) > 1:
        answer = " ".join(sys.argv[1:])
    else:
        path = Path(__file__).resolve().parent / "answer.txt"
        answer = path.read_text(encoding="utf-8") if path.exists() else ""
    answer = answer.rstrip("\r\n")

    if not answer or "\n" in answer:
        sys.exit("test 1 failed: put your answer, on one line, in puzzle/answer.txt")
    print("test 1 passed: there is an answer")

    if len(answer) != len(NUMBERS):
        sys.exit(f"test 2 failed: the answer has {len(answer)} letters, "
                 f"but there are {len(NUMBERS)} numbers")
    print("test 2 passed: the length is right")

    for place, (got, want) in enumerate(zip(encode(answer), NUMBERS), start=1):
        if got != want:
            sys.exit(f"test 3 failed: letter {place} encodes to {got}, not {want}")
    print("test 3 passed: every letter encodes to its number")

    if hashlib.sha256(answer.encode("utf-8")).hexdigest()[:16] != FINGERPRINT:
        sys.exit("test 4 failed: the fingerprint doesn't match")
    print("test 4 passed: the fingerprint matches")
    print("\nSolved.")


if __name__ == "__main__":
    main()
