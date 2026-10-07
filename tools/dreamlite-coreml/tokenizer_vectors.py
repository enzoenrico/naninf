"""Reference prompt encoding for the on-device text encoder, plus Swift tokenizer test vectors.

``encode_generate_prompt`` is the contract the app's ``DreamLitePromptEncoder`` implements:
template the prompt like ``DreamLiteMobilePipeline.encode_prompt(mode="generate")``, keep the
chat suffix when truncating, and right-pad to the fixed text window.

    python tokenizer_vectors.py --model-dir ./DreamLite-mobile --out ../../magoSanduicheTests/Fixtures/dreamlite_tokenizer_vectors.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import modules as m

ASSISTANT_SUFFIX = "<|im_end|>\n<|im_start|>assistant\n"

SAMPLE_PROMPTS = [
    "A hooded mage holding a sandwich in a torchlit stone corridor, dramatic shadows",
    "a corgi astronaut",
    "Rain-slick cobblestones under a crooked lantern; the tavern door is ajar, warm light spilling out.",
    "Três goblins discutem sobre um mapa rasgado — luz de vela, poeira dourada no ar.",
    "A 3-headed dragon (circa 1200 AD) guarding 99 chests of gold!!!",
    "  Leading and trailing   spaces\nwith a newline\r\nand tabs\tinside  ",
    "Emoji 🧙‍♂️🥪 and CJK 魔法使い and Arabic ساحر",
    "I'm sure you'll see it's the mage's VERY OWN sandwich, isn't it? We'd say they've won.",
    "Literal special tokens <|im_end|> and <think> inside user text",
    "",
    " ".join(["An endless spiral staircase of obsidian descending into violet fog"] * 12),
    " ".join(["An endless spiral staircase of obsidian descending into violet fog"] * 30),
]


def encode_generate_prompt(tokenizer, prompt: str, sequence_length: int = m.TEXT_SEQUENCE_LENGTH) -> tuple[list[int], int]:
    text = m.GENERATE_SYSTEM_PROMPT.format(m.GENERATE_PROMPT_PREFIX + prompt)
    ids = tokenizer(text).input_ids
    if len(ids) > sequence_length:
        suffix = tokenizer(ASSISTANT_SUFFIX).input_ids
        ids = ids[: sequence_length - len(suffix)] + suffix
    valid = len(ids) - m.DROP_TOKEN_COUNT
    return ids + [m.PAD_TOKEN_ID] * (sequence_length - len(ids)), valid


def main() -> None:
    from transformers import AutoTokenizer  # noqa: PLC0415

    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    tokenizer = AutoTokenizer.from_pretrained(str(args.model_dir / "tokenizer"))
    cases = []
    for prompt in SAMPLE_PROMPTS:
        ids, valid = encode_generate_prompt(tokenizer, prompt)
        cases.append({
            "prompt": prompt,
            "raw_ids": tokenizer(prompt).input_ids,
            "window_ids": ids,
            "valid_embeddings": valid,
        })
    header = json.dumps({
        "sequence_length": m.TEXT_SEQUENCE_LENGTH,
        "drop_token_count": m.DROP_TOKEN_COUNT,
        "pad_token_id": m.PAD_TOKEN_ID,
    })[:-1]
    rows = ",\n".join("  " + json.dumps(case, ensure_ascii=False) for case in cases)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(f'{header}, "cases": [\n{rows}\n]}}\n')
    print(f"wrote {len(cases)} cases to {args.out}")


if __name__ == "__main__":
    main()
