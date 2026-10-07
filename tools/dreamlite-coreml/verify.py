"""Numerical parity checks for the decomposed on-device DreamLite-mobile pipeline.

Runs the reference ``DreamLiteMobilePipeline`` (fp32, CPU) once with recording hooks, then
re-runs the same prompt and initial noise through the exact stages the app executes:
fixed-window text encoder chunks -> UNetStep x N with the Swift-equivalent Euler update ->
LatentDecoder. Also emulates on-device int8 weights and float16 compute to bound their effect
and to catch float16 overflow (Core ML predictions cannot run off Apple platforms).

    python verify.py --model-dir ./DreamLite-mobile --space-dir ./DreamLite-space --out ./verify-out
"""

from __future__ import annotations

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image

import modules as m
from tokenizer_vectors import encode_generate_prompt

PROMPT = "A hooded mage holding a sandwich in a torchlit stone corridor, dramatic shadows"


def psnr(a: np.ndarray, b: np.ndarray) -> float:
    mse = float(np.mean((a.astype(np.float64) - b.astype(np.float64)) ** 2))
    return float("inf") if mse == 0 else 10 * math.log10(1.0 / mse)


def reference_run(model_dir: Path, space_dir: Path, seed: int, steps: int) -> dict:
    import sys  # noqa: PLC0415

    sys.path.insert(0, str(space_dir))
    from dreamlite import DreamLiteMobilePipeline  # noqa: PLC0415

    pipe = DreamLiteMobilePipeline.from_pretrained(str(model_dir), torch_dtype=torch.float32, low_cpu_mem_usage=True)
    record: dict = {"unet_in": [], "unet_t": [], "unet_out": []}
    unet_forward = pipe.unet.forward

    def recording_unet(sample, timestep, encoder_hidden_states=None, encoder_attention_mask=None, added_cond_kwargs=None, return_dict=True, **kwargs):
        out = unet_forward(sample, timestep, encoder_hidden_states=encoder_hidden_states, encoder_attention_mask=encoder_attention_mask, added_cond_kwargs=added_cond_kwargs, return_dict=return_dict, **kwargs)
        record["unet_in"].append(sample.clone())
        record["unet_t"].append(timestep.clone())
        record["unet_out"].append(out[0].clone())
        record["encoder_hidden_states"] = encoder_hidden_states.clone()
        return out

    pipe.unet.forward = recording_unet
    tokenizer_call = type(pipe.tokenizer).__call__

    def recording_tokenizer(self, *args, **kwargs):
        out = tokenizer_call(self, *args, **kwargs)
        record["input_ids"] = out.input_ids.clone()
        return out

    type(pipe.tokenizer).__call__ = recording_tokenizer
    generator = torch.Generator(device="cpu").manual_seed(seed)
    with torch.no_grad():
        image = pipe(PROMPT, num_inference_steps=steps, generator=generator).images[0]
    type(pipe.tokenizer).__call__ = tokenizer_call
    record["image"] = np.asarray(image, dtype=np.float32) / 255.0
    record["scheduler_config"] = dict(pipe.scheduler.config)
    record["tokenizer"] = pipe.tokenizer
    del pipe
    return record


def quantize_linear_weights(module: torch.nn.Module, bits: int) -> None:
    """Per-output-channel symmetric linear quantization round trip (coremltools ``linear_symmetric``)."""
    levels = 2 ** (bits - 1) - 1
    with torch.no_grad():
        for child in module.modules():
            if isinstance(child, (torch.nn.Linear, torch.nn.Conv2d, torch.nn.Embedding)) and child.weight.numel() >= 2048:
                w = child.weight
                flat = w.reshape(w.shape[0], -1)
                scale = flat.abs().amax(dim=1, keepdim=True).clamp(min=1e-12) / levels
                child.weight.copy_((torch.round(flat / scale).clamp(-levels, levels) * scale).reshape(w.shape))


class Float16Emulation:
    """Rounds weights and every leaf module's floating inputs/outputs through float16.

    Approximates Core ML ``FLOAT16`` compute precision closely enough to expose overflow: any
    activation above 65504 becomes inf. Also records the largest activation magnitude seen.
    """

    def __init__(self, module: torch.nn.Module):
        self.peak = 0.0
        self.peak_module = ""
        self.non_finite = 0
        with torch.no_grad():
            for tensor in list(module.parameters()) + list(module.buffers()):
                if tensor.is_floating_point():
                    tensor.copy_(tensor.half().float())
        for name, child in module.named_modules():
            if next(child.children(), None) is None:
                child.register_forward_pre_hook(lambda _, args, name=name: tuple(self.round(name, a) for a in args))
                child.register_forward_hook(lambda _, __, out, name=name: self.round(name, out))

    def round(self, name: str, value):
        if not torch.is_tensor(value) or not value.is_floating_point():
            return value
        peak = float(value.abs().max())
        if peak > self.peak:
            self.peak, self.peak_module = peak, name
        rounded = value.half().float()
        self.non_finite += int((~torch.isfinite(rounded)).sum())
        return rounded

    def summary(self) -> dict:
        return {"peak_abs_activation": self.peak, "peak_module": self.peak_module, "non_finite_values": self.non_finite}


def run_decomposed(
    model_dir: Path,
    space_dir: Path,
    ids: list[int],
    valid_embeddings: int,
    initial_noise: torch.Tensor,
    sigmas: list[float],
    num_chunks: int,
    text_bits: int | None,
    unet_bits: int | None,
    float16: bool = False,
) -> dict:
    config = m.TextConfig.load(model_dir)
    hidden = torch.tensor([ids], dtype=torch.int64)
    float16_stats: dict = {}
    with torch.no_grad():
        for index, (start, end) in enumerate(m.chunk_boundaries(config.num_layers, num_chunks)):
            chunk = m.TextEncoderChunk.load(model_dir, config, start, end)
            if text_bits:
                quantize_linear_weights(chunk, text_bits)
            emulation = Float16Emulation(chunk) if float16 else None
            hidden = chunk(hidden)
            if emulation:
                float16_stats[f"text_encoder_{index}"] = emulation.summary()
            del chunk
    embeddings = hidden
    mask = torch.zeros(1, embeddings.shape[1])
    mask[:, :valid_embeddings] = 1

    unet = m.UNetStep.load(model_dir, space_dir)
    if unet_bits:
        quantize_linear_weights(unet, unet_bits)
    emulation = Float16Emulation(unet) if float16 else None
    latents = initial_noise.clone()
    outputs = []
    with torch.no_grad():
        for i in range(len(sigmas) - 1):
            timestep = torch.tensor([sigmas[i] * 1000.0], dtype=torch.float32)
            noise = unet(latents, timestep, embeddings, mask)
            outputs.append(noise)
            latents = latents + (sigmas[i + 1] - sigmas[i]) * noise
    if emulation:
        float16_stats["unet"] = emulation.summary()
    del unet
    decoder = m.LatentDecoder.load(model_dir)
    emulation = Float16Emulation(decoder) if float16 else None
    with torch.no_grad():
        image = decoder(latents)[0].permute(1, 2, 0).numpy()
    if emulation:
        float16_stats["decoder"] = emulation.summary()
    return {"embeddings": embeddings, "unet_out": outputs, "latents": latents, "image": image, "float16": float16_stats}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--space-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument("--chunks", type=int, default=4)
    parser.add_argument("--text-bits", type=int, default=8)
    parser.add_argument("--unet-bits", type=int, default=8)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(max(1, torch.get_num_threads()))
    report: dict = {"prompt": PROMPT, "seed": args.seed, "steps": args.steps}
    started = time.time()

    ref = reference_run(args.model_dir, args.space_dir, args.seed, args.steps)
    Image.fromarray((ref["image"] * 255).round().astype(np.uint8)).save(args.out / "reference.png")
    print(f"reference done in {time.time() - started:.0f}s", flush=True)

    ids, valid = encode_generate_prompt(ref["tokenizer"], PROMPT, m.TEXT_SEQUENCE_LENGTH)
    reference_ids = ref["input_ids"][0].tolist()
    report["token_ids_match_reference"] = ids[: len(reference_ids)] == reference_ids
    report["prompt_tokens"] = len(reference_ids)

    sigmas = m.flow_match_sigmas(args.steps, m.IMAGE_SIZE // m.VAE_SCALE_FACTOR, m.IMAGE_SIZE // m.VAE_SCALE_FACTOR, ref["scheduler_config"])
    report["timesteps"] = [s * 1000 for s in sigmas[:-1]]
    report["timesteps_max_abs_diff_vs_reference"] = max(
        abs(a - float(b)) for a, b in zip(report["timesteps"], ref["unet_t"])
    )
    width = m.IMAGE_SIZE // m.VAE_SCALE_FACTOR
    initial_noise = ref["unet_in"][0][..., :width].clone()

    variants = (
        ("fp32", None, None, False),
        ("quantized", args.text_bits, args.unet_bits, False),
        ("quantized_float16", args.text_bits, args.unet_bits, True),
    )
    for label, text_bits, unet_bits, float16 in variants:
        run = run_decomposed(args.model_dir, args.space_dir, ids, valid, initial_noise, sigmas, args.chunks, text_bits, unet_bits, float16)
        reference_embeddings = ref["encoder_hidden_states"][0]
        embeddings = run["embeddings"][0, :valid]
        section = {
            "valid_embeddings": valid,
            "embeddings_shape_matches": tuple(embeddings.shape) == tuple(reference_embeddings.shape),
            "embeddings_max_abs_diff": float((embeddings - reference_embeddings).abs().max()),
            "embeddings_cosine": float(torch.nn.functional.cosine_similarity(embeddings.flatten(), reference_embeddings.flatten(), dim=0)),
            "unet_step_max_abs_diff": [
                float((out - ref_out[..., :width]).abs().max()) for out, ref_out in zip(run["unet_out"], ref["unet_out"])
            ],
            "image_psnr_db_vs_reference": psnr(run["image"], ref["image"]),
        }
        if run["float16"]:
            section["float16"] = run["float16"]
        report[label] = section
        Image.fromarray((run["image"] * 255).round().astype(np.uint8)).save(args.out / f"decomposed_{label}.png")
        print(label, json.dumps(section), flush=True)

    report["elapsed_s"] = time.time() - started
    (args.out / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
