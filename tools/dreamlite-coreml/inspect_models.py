"""Check a ``convert.py`` output folder against the contract ``DreamLiteOnDeviceGenerator`` relies on.

Verifies every manifest file's size and SHA-256, then reads each package's Core ML spec and checks
input/output names, shapes, and dtypes, and reports how many weights are stored quantized.

    python inspect_models.py ./DreamLiteCoreML [--spec-out ./specs]

``--spec-out`` writes ``<Model>.json`` (inputs/outputs only) for each package.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import sys
from pathlib import Path

import coremltools as ct

DTYPES = {
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.FLOAT32: "float32",
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.FLOAT16: "float16",
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.INT32: "int32",
}
QUANTIZED_OPS = {"constexpr_affine_dequantize", "constexpr_blockwise_shift_scale", "constexpr_lut_to_dense"}


def tensors(features) -> list[dict]:
    return [
        {"name": f.name, "shape": list(f.type.multiArrayType.shape), "dtype": DTYPES.get(f.type.multiArrayType.dataType, "unknown")}
        for f in features
    ]


def op_counts(spec) -> collections.Counter:
    counts: collections.Counter = collections.Counter()
    for function in spec.mlProgram.functions.values():
        for block in function.block_specializations.values():
            for op in block.operations:
                counts[op.type] += 1
    return counts


def expected_contract(manifest: dict) -> dict[str, dict]:
    seq, hidden = manifest["text_sequence_length"], manifest["hidden_size"]
    prompt = seq - manifest["drop_token_count"]
    side, channels = manifest["latent_size"], manifest["latent_channels"]
    latents = {"name": "latents", "shape": [1, channels, side, side], "dtype": "float32"}
    contract = {}
    chunks = manifest["text_encoder"]
    for index, package in enumerate(chunks):
        first = {"name": "input_ids", "shape": [1, seq], "dtype": "int32"}
        middle = {"name": "input_hidden_states", "shape": [1, seq, hidden], "dtype": "float32"}
        out_len = prompt if index == len(chunks) - 1 else seq
        contract[package] = {
            "inputs": [first if index == 0 else middle],
            "outputs": [{"name": "hidden_states", "shape": [1, out_len, hidden], "dtype": "float32"}],
        }
    contract[manifest["unet"]] = {
        "inputs": [
            latents,
            {"name": "timestep", "shape": [1], "dtype": "float32"},
            {"name": "encoder_hidden_states", "shape": [1, prompt, hidden], "dtype": "float32"},
            {"name": "encoder_attention_mask", "shape": [1, prompt], "dtype": "float32"},
        ],
        "outputs": [dict(latents, name="noise_pred")],
    }
    image = manifest["image_size"]
    contract[manifest["decoder"]] = {
        "inputs": [latents],
        "outputs": [{"name": "image", "shape": [1, 3, image, image], "dtype": "float32"}],
    }
    return contract


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("models", type=Path)
    parser.add_argument("--spec-out", type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.models / "DreamLiteManifest.json").read_text())
    problems: list[str] = []

    for entry in manifest["files"]:
        path = args.models / entry["path"]
        if not path.is_file() or path.stat().st_size != entry["size"] or sha256(path) != entry["sha256"]:
            problems.append(f"file mismatch: {entry['path']}")
    print(f"files: {len(manifest['files'])} checked, {sum(e['size'] for e in manifest['files']) / 1e9:.2f} GB")

    for package, expected in expected_contract(manifest).items():
        spec = ct.models.MLModel(str(args.models / package), skip_model_load=True).get_spec()
        actual = {"inputs": tensors(spec.description.input), "outputs": tensors(spec.description.output)}
        if actual != expected:
            problems.append(f"{package}: interface {actual} != expected {expected}")
        counts = op_counts(spec)
        quantized = sum(counts[op] for op in QUANTIZED_OPS)
        print(f"{package}: ok={actual == expected} ops={sum(counts.values())} quantized_weights={quantized} "
              f"spec={spec.specificationVersion} inputs={[t['name'] for t in actual['inputs']]}")
        if args.spec_out:
            args.spec_out.mkdir(parents=True, exist_ok=True)
            (args.spec_out / f"{Path(package).stem}.json").write_text(json.dumps(actual, indent=2))

    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print("all packages match the app contract")


if __name__ == "__main__":
    main()
