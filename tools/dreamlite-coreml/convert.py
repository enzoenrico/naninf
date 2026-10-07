"""Convert carlofkl/DreamLite-mobile into the Core ML models the app runs on device.

Output directory layout (consumed by ``DreamLiteModelStore`` in the app):

    DreamLiteManifest.json          shapes, scheduler config, file list with sizes + SHA-256
    DreamLiteTextEncoder{0..N-1}.mlpackage
    DreamLiteUNet.mlpackage
    DreamLiteDecoder.mlpackage

Either drop the output folder's contents into ``magoSanduiche/Resources/DreamLiteModels/`` to
bundle them (Xcode compiles the packages), or upload the folder to any static host (for example
a Hugging Face model repo) and set the ``DREAMLITE_MODEL_BASE_URL`` build setting so the app
downloads it once into Application Support.

    pip install -r requirements.txt
    python convert.py --out ./DreamLiteCoreML
    python inspect_models.py ./DreamLiteCoreML     # hashes + the I/O contract the app relies on
    python verify.py --model-dir .cache/DreamLite-mobile --space-dir .cache/DreamLite-space --out ./verify-out
"""

from __future__ import annotations

import argparse
import gc
import hashlib
import json
import shutil
from pathlib import Path

import coremltools as ct
import coremltools.optimize as cto
import numpy as np
import torch

import modules as m

MODEL_REPO = "carlofkl/DreamLite-mobile"
SPACE_REPO = "carlofkl/DreamLite"
MANIFEST_NAME = "DreamLiteManifest.json"
DEPLOYMENT_TARGET = ct.target.iOS18


def fetch_sources(model_dir: Path | None, space_dir: Path | None, cache: Path) -> tuple[Path, Path]:
    from huggingface_hub import snapshot_download  # noqa: PLC0415

    if model_dir is None:
        model_dir = Path(snapshot_download(MODEL_REPO, local_dir=cache / "DreamLite-mobile"))
    if space_dir is None:
        space_dir = Path(snapshot_download(SPACE_REPO, repo_type="space", allow_patterns=["dreamlite/**"], local_dir=cache / "DreamLite-space"))
    return model_dir, space_dir


WEIGHT_OP_TYPES = {"linear", "conv", "matmul", "gather"}


def quantize(model: ct.models.MLModel, bits: int | None) -> ct.models.MLModel:
    """Quantize layer weights only; rotary tables, masks, and other folded constants stay float16."""
    if not bits:
        return model
    if bits == 8:
        op_config = cto.coreml.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8", granularity="per_channel", weight_threshold=2048)
    elif bits == 4:
        op_config = cto.coreml.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int4", granularity="per_block", block_size=32, weight_threshold=2048)
    else:
        raise ValueError(f"unsupported weight bits: {bits}")
    # Per-op-type configs conflict on small constants that op fusion shares between weight and
    # non-weight ops, so exclude by name every constant that feeds no weight op instead.
    keep_float = {}
    for const in model._mil_program.find_ops(op_type="const"):
        consumers = {child.op_type for output in const.outputs for child in output.child_ops}
        if consumers and not consumers & WEIGHT_OP_TYPES:
            keep_float[const.name] = None
    config = cto.coreml.OptimizationConfig(global_config=op_config, op_name_configs=keep_float)
    return cto.coreml.linear_quantize_weights(model, config=config)


def convert_module(module: torch.nn.Module, example: tuple, inputs: list, outputs: list, bits: int | None, path: Path, description: str) -> None:
    with torch.no_grad():
        traced = torch.jit.trace(module, example, check_trace=False)
    model = ct.convert(
        traced,
        inputs=inputs,
        outputs=outputs,
        convert_to="mlprogram",
        minimum_deployment_target=DEPLOYMENT_TARGET,
        compute_precision=ct.precision.FLOAT16,
    )
    del traced
    gc.collect()
    model = quantize(model, bits)
    model.short_description = description
    model.author = f"{MODEL_REPO} (CC BY-NC 4.0), converted by tools/dreamlite-coreml"
    if path.exists():
        shutil.rmtree(path)
    model.save(str(path))
    del model
    gc.collect()
    print(f"saved {path.name}", flush=True)


def file_entries(out: Path) -> list[dict]:
    entries = []
    for path in sorted(out.rglob("*")):
        if not path.is_file() or path.name == MANIFEST_NAME:
            continue
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1 << 20), b""):
                digest.update(block)
        entries.append({"path": path.relative_to(out).as_posix(), "size": path.stat().st_size, "sha256": digest.hexdigest()})
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--model-dir", type=Path, help="local snapshot of carlofkl/DreamLite-mobile")
    parser.add_argument("--space-dir", type=Path, help="local snapshot of the carlofkl/DreamLite Space (for the dreamlite package)")
    parser.add_argument("--cache", type=Path, default=Path("./.cache"))
    parser.add_argument("--text-chunks", type=int, default=4)
    parser.add_argument("--text-bits", type=int, choices=[0, 4, 8], default=8)
    parser.add_argument("--unet-bits", type=int, choices=[0, 4, 8], default=8)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument("--only", choices=["text", "unet", "decoder"], action="append")
    args = parser.parse_args()

    model_dir, space_dir = fetch_sources(args.model_dir, args.space_dir, args.cache)
    args.out.mkdir(parents=True, exist_ok=True)
    stages = set(args.only or ["text", "unet", "decoder"])
    config = m.TextConfig.load(model_dir)
    seq = m.TEXT_SEQUENCE_LENGTH
    prompt_len = seq - m.DROP_TOKEN_COUNT
    latent = m.IMAGE_SIZE // m.VAE_SCALE_FACTOR
    float32 = np.float32

    boundaries = m.chunk_boundaries(config.num_layers, args.text_chunks)
    text_names = [f"DreamLiteTextEncoder{i}" for i in range(len(boundaries))]
    if "text" in stages:
        for name, (start, end) in zip(text_names, boundaries):
            chunk = m.TextEncoderChunk.load(model_dir, config, start, end)
            if chunk.is_first:
                example = (torch.full((1, seq), m.PAD_TOKEN_ID, dtype=torch.int64),)
                inputs = [ct.TensorType(name="input_ids", shape=(1, seq), dtype=np.int32)]
            else:
                example = (torch.randn(1, seq, config.hidden_size),)
                inputs = [ct.TensorType(name="input_hidden_states", shape=(1, seq, config.hidden_size), dtype=float32)]
            convert_module(
                chunk, example, inputs,
                [ct.TensorType(name="hidden_states", dtype=float32)],
                args.text_bits, args.out / f"{name}.mlpackage",
                f"DreamLite-mobile Qwen3-VL text decoder layers {start}..<{end}",
            )
            del chunk
            gc.collect()

    if "unet" in stages:
        unet = m.UNetStep.load(model_dir, space_dir)
        example = (
            torch.randn(1, m.LATENT_CHANNELS, latent, latent),
            torch.tensor([1000.0]),
            torch.randn(1, prompt_len, config.hidden_size),
            torch.ones(1, prompt_len),
        )
        convert_module(
            unet, example,
            [
                ct.TensorType(name="latents", shape=example[0].shape, dtype=float32),
                ct.TensorType(name="timestep", shape=(1,), dtype=float32),
                ct.TensorType(name="encoder_hidden_states", shape=example[2].shape, dtype=float32),
                ct.TensorType(name="encoder_attention_mask", shape=example[3].shape, dtype=float32),
            ],
            [ct.TensorType(name="noise_pred", dtype=float32)],
            args.unet_bits, args.out / "DreamLiteUNet.mlpackage",
            "DreamLite-mobile UNet, one flow-matching velocity prediction",
        )
        del unet
        gc.collect()

    if "decoder" in stages:
        decoder = m.LatentDecoder.load(model_dir)
        example = (torch.randn(1, m.LATENT_CHANNELS, latent, latent),)
        convert_module(
            decoder, example,
            [ct.TensorType(name="latents", shape=example[0].shape, dtype=float32)],
            [ct.TensorType(name="image", dtype=float32)],
            None, args.out / "DreamLiteDecoder.mlpackage",
            "DreamLite-mobile TAESDXL decoder, RGB in [0, 1]",
        )
        del decoder
        gc.collect()

    scheduler = json.loads((model_dir / "scheduler" / "scheduler_config.json").read_text())
    manifest = {
        "format": 1,
        "model_id": MODEL_REPO,
        "license": "CC-BY-NC-4.0",
        "image_size": m.IMAGE_SIZE,
        "latent_size": latent,
        "latent_channels": m.LATENT_CHANNELS,
        "text_sequence_length": seq,
        "drop_token_count": m.DROP_TOKEN_COUNT,
        "pad_token_id": m.PAD_TOKEN_ID,
        "hidden_size": config.hidden_size,
        "default_steps": args.steps,
        "scheduler": {
            "num_train_timesteps": scheduler["num_train_timesteps"],
            "base_image_seq_len": scheduler["base_image_seq_len"],
            "max_image_seq_len": scheduler["max_image_seq_len"],
            "base_shift": scheduler["base_shift"],
            "max_shift": scheduler["max_shift"],
        },
        "text_encoder": [f"{name}.mlpackage" for name in text_names],
        "unet": "DreamLiteUNet.mlpackage",
        "decoder": "DreamLiteDecoder.mlpackage",
        "weight_bits": {"text_encoder": args.text_bits or 16, "unet": args.unet_bits or 16, "decoder": 16},
        "files": file_entries(args.out),
    }
    (args.out / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2))
    total = sum(entry["size"] for entry in manifest["files"])
    print(f"wrote {MANIFEST_NAME}: {len(manifest['files'])} files, {total / 1e9:.2f} GB")


if __name__ == "__main__":
    main()
