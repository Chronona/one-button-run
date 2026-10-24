#!/usr/bin/env python3
"""Generate game sound effects from the earshot bank, in code.

The game used to ship four hand-picked WAV files in ``assets/se/`` with no
record of where they came from. This script replaces that with a manifest:
``audio/earshot-manifest.json`` maps each output file to earshot bank
sounds (Leonxlnx/earshot, MIT). earshot's bank renders are code synthesis --
no recorded audio, no models and no network are needed for ``bank.render``,
only numpy / scipy -- so the same command reproduces the same WAVs.

A manifest entry is either a single sound (``bank_id``, optional ``pitch``)
or a short phrase (``sequence``: a list of ``bank_id``/``pitch`` steps
placed ``spacing_s`` apart, overlapping tails summed). Jump and land share
one timbre at different pitches so they read as one action, and gameover is
a descending phrase rather than a single impact, for the same reason.

Usage:
    EARSHOT_PATH=/path/to/earshot python3 scripts/generate-audio.py
    python3 scripts/generate-audio.py --check   # verify, do not write

``EARSHOT_PATH`` is only needed when the ``earshot`` package is not already
importable (for example, a plain ``git clone`` without ``pip install``).
Output is mono 44.1 kHz 16-bit WAV, matching the assets this game already
ships, and every render must pass earshot's model-free audit
(``meta["checks"]["ok"]``) or the script fails without writing that file.
"""

import json
import os
import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "audio" / "earshot-manifest.json"
OUT_SR = 44100
BANK_SR = 48000


def _load_bank():
    try:
        from earshot.forge import bank

        return bank
    except ImportError:
        earshot_path = os.environ.get("EARSHOT_PATH")
        if not earshot_path:
            raise SystemExit(
                "earshot is not importable. Clone https://github.com/Leonxlnx/earshot "
                "and either pip-install it or set EARSHOT_PATH to the clone."
            )
        sys.path.insert(0, earshot_path)
        from earshot.forge import bank

        return bank


def _to_mono_44100(y: np.ndarray) -> np.ndarray:
    mono = np.asarray(y, dtype=np.float64)
    if mono.ndim == 2:
        mono = mono.mean(axis=1)
    if BANK_SR != OUT_SR:
        mono = resample_poly(mono, 147, 160)
    peak = np.max(np.abs(mono)) if mono.size else 0.0
    if peak > 0:
        # Bank renders peak at -1 dBFS; resampling can nudge that, so
        # re-peak to -1 dBFS (0.891) instead of clipping.
        mono = mono * (0.891251 / peak)
    return np.clip(mono, -1.0, 1.0)


def _render_entry(bank, entry):
    """Render one manifest entry to mono 48 kHz audio.

    Returns (audio, description). Every component render must pass
    earshot's model-free audit, or the entry fails without writing.
    """
    seed = entry.get("seed", 1)
    if "sequence" in entry:
        spacing = int(round(entry.get("spacing_s", 0.28) * BANK_SR))
        steps = entry["sequence"]
        parts = []
        for step in steps:
            y, meta = bank.render(
                step["bank_id"], seed=step.get("seed", seed),
                pitch=step.get("pitch"),
            )
            checks = meta.get("checks", {})
            print(
                f"  {step['bank_id']} pitch={step.get('pitch')} "
                f"dur={meta.get('dur_s', 0):.3f}s "
                f"{'clean' if checks.get('ok') else 'FAILED AUDIT'}"
            )
            if not checks.get("ok"):
                print(f"    warnings: {checks.get('warnings')}")
                return None, None
            mono = np.asarray(y, dtype=np.float64)
            if mono.ndim == 2:
                mono = mono.mean(axis=1)
            parts.append(mono)
        total = spacing * (len(parts) - 1) + len(parts[-1])
        out = np.zeros(total, dtype=np.float64)
        for i, part in enumerate(parts):
            out[i * spacing:i * spacing + len(part)] += part
        desc = " + ".join(
            f"{s['bank_id']}@{s.get('pitch')}" for s in steps
        )
        return out, desc
    y, meta = bank.render(
        entry["bank_id"], seed=seed, pitch=entry.get("pitch"),
    )
    checks = meta.get("checks", {})
    print(
        f"{entry['output']}: {entry['bank_id']} pitch={entry.get('pitch')} "
        f"dur={meta.get('dur_s', 0):.3f}s "
        f"{'clean' if checks.get('ok') else 'FAILED AUDIT'}"
    )
    if not checks.get("ok"):
        print(f"  warnings: {checks.get('warnings')}")
        return None, None
    mono = np.asarray(y, dtype=np.float64)
    if mono.ndim == 2:
        mono = mono.mean(axis=1)
    return mono, entry["bank_id"]


def main(argv) -> int:
    check_only = "--check" in argv
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    bank = _load_bank()
    failed = False
    for entry in manifest["sounds"]:
        out_path = ROOT / entry["output"]
        y, desc = _render_entry(bank, entry)
        if y is None:
            failed = True
            continue
        if check_only:
            continue
        data = (_to_mono_44100(y) * 32767).astype(np.int16)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        wavfile.write(out_path, OUT_SR, data)
        print(f"  wrote {out_path} ({len(data) / OUT_SR:.3f}s, mono {OUT_SR} Hz) [{desc}]")
    if failed:
        print("ERROR: one or more renders failed earshot's audit; see above.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
