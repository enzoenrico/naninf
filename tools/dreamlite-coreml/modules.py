"""Traceable PyTorch modules that mirror DreamLiteMobilePipeline for Core ML conversion.

The on-device pipeline is split into three stages:

* ``TextEncoderChunk``: the Qwen3-VL text decoder (vision tower unused for text-to-image),
  run on a fixed-length, right-padded token window. Attention is causal, so padding after the
  prompt cannot change the hidden states of real tokens.
* ``UNetStep``: one DreamLite UNet evaluation for text-to-image (zero image latents, fixed time ids).
* ``LatentDecoder``: TAESDXL decoder producing RGB in [0, 1].
"""

from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import torch
import torch.nn.functional as F
from safetensors import safe_open
from torch import nn

GENERATE_SYSTEM_PROMPT = (
    "<|im_start|>system\nDescribe the image by detailing the color, shape, size, texture, "
    "quantity, text, spatial relationships of the objects and background:<|im_end|>\n"
    "<|im_start|>user\n{}<|im_end|>\n<|im_start|>assistant\n"
)
GENERATE_PROMPT_PREFIX = "[Generate]: "
DROP_TOKEN_COUNT = 34
PAD_TOKEN_ID = 151643
TEXT_SEQUENCE_LENGTH = 256
IMAGE_SIZE = 1024
VAE_SCALE_FACTOR = 8
LATENT_CHANNELS = 4
MASK_VALUE = -1e4


@dataclass(frozen=True)
class TextConfig:
    hidden_size: int
    intermediate_size: int
    num_layers: int
    num_heads: int
    num_kv_heads: int
    head_dim: int
    rms_norm_eps: float
    rope_theta: float
    vocab_size: int

    @staticmethod
    def load(model_dir: Path) -> "TextConfig":
        text = json.loads((model_dir / "text_encoder" / "config.json").read_text())["text_config"]
        return TextConfig(
            hidden_size=text["hidden_size"],
            intermediate_size=text["intermediate_size"],
            num_layers=text["num_hidden_layers"],
            num_heads=text["num_attention_heads"],
            num_kv_heads=text["num_key_value_heads"],
            head_dim=text["head_dim"],
            rms_norm_eps=text["rms_norm_eps"],
            rope_theta=text["rope_theta"],
            vocab_size=text["vocab_size"],
        )


class StableRMSNorm(nn.Module):
    """RMSNorm that pre-scales by max |x| so the squared mean cannot overflow in float16.

    x / sqrt(mean(x^2) + eps) == (x/s) / sqrt(mean((x/s)^2) + eps/s^2) for any s > 0.
    """

    def __init__(self, dim: int, eps: float):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))
        self.eps_sqrt = math.sqrt(eps)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        scale = x.abs().amax(dim=-1, keepdim=True).clamp(min=1e-4)
        scaled = x / scale
        variance = scaled.pow(2).mean(dim=-1, keepdim=True) + (self.eps_sqrt / scale).pow(2)
        return self.weight * (scaled * torch.rsqrt(variance))


def rotate_half(x: torch.Tensor) -> torch.Tensor:
    half = x.shape[-1] // 2
    return torch.cat((-x[..., half:], x[..., :half]), dim=-1)


class Qwen3DecoderLayer(nn.Module):
    def __init__(self, config: TextConfig):
        super().__init__()
        c = config
        self.num_heads = c.num_heads
        self.num_kv_heads = c.num_kv_heads
        self.head_dim = c.head_dim
        self.input_layernorm = StableRMSNorm(c.hidden_size, c.rms_norm_eps)
        self.post_attention_layernorm = StableRMSNorm(c.hidden_size, c.rms_norm_eps)
        self.q_proj = nn.Linear(c.hidden_size, c.num_heads * c.head_dim, bias=False)
        self.k_proj = nn.Linear(c.hidden_size, c.num_kv_heads * c.head_dim, bias=False)
        self.v_proj = nn.Linear(c.hidden_size, c.num_kv_heads * c.head_dim, bias=False)
        self.o_proj = nn.Linear(c.num_heads * c.head_dim, c.hidden_size, bias=False)
        self.q_norm = StableRMSNorm(c.head_dim, c.rms_norm_eps)
        self.k_norm = StableRMSNorm(c.head_dim, c.rms_norm_eps)
        self.gate_proj = nn.Linear(c.hidden_size, c.intermediate_size, bias=False)
        self.up_proj = nn.Linear(c.hidden_size, c.intermediate_size, bias=False)
        self.down_proj = nn.Linear(c.intermediate_size, c.hidden_size, bias=False)

    def forward(self, h: torch.Tensor, cos: torch.Tensor, sin: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
        batch, length, _ = h.shape
        x = self.input_layernorm(h)
        q = self.q_norm(self.q_proj(x).view(batch, length, self.num_heads, self.head_dim)).transpose(1, 2)
        k = self.k_norm(self.k_proj(x).view(batch, length, self.num_kv_heads, self.head_dim)).transpose(1, 2)
        v = self.v_proj(x).view(batch, length, self.num_kv_heads, self.head_dim).transpose(1, 2)
        q = q * cos + rotate_half(q) * sin
        k = k * cos + rotate_half(k) * sin
        repeats = self.num_heads // self.num_kv_heads
        k = k.repeat_interleave(repeats, dim=1)
        v = v.repeat_interleave(repeats, dim=1)
        scores = torch.matmul(q, k.transpose(-1, -2)) * (self.head_dim**-0.5) + mask
        attention = torch.matmul(torch.softmax(scores, dim=-1), v)
        h = h + self.o_proj(attention.transpose(1, 2).reshape(batch, length, self.num_heads * self.head_dim))
        x = self.post_attention_layernorm(h)
        return h + self.down_proj(F.silu(self.gate_proj(x)) * self.up_proj(x))


class TextEncoderChunk(nn.Module):
    """Layers ``[start, end)`` of the Qwen3-VL text decoder over a fixed ``sequence_length`` window.

    The first chunk embeds ``input_ids``; the last drops the ``DROP_TOKEN_COUNT`` system-prompt
    positions. DreamLite conditions on ``hidden_states[-1]`` of ``Qwen3VLForConditionalGeneration``,
    which is the last decoder layer's output *without* the final norm, so no norm is applied here.
    """

    def __init__(self, config: TextConfig, start: int, end: int, sequence_length: int = TEXT_SEQUENCE_LENGTH):
        super().__init__()
        self.start = start
        self.end = end
        self.is_first = start == 0
        self.is_last = end == config.num_layers
        self.embed_tokens = nn.Embedding(config.vocab_size, config.hidden_size) if self.is_first else None
        self.layers = nn.ModuleList(Qwen3DecoderLayer(config) for _ in range(start, end))

        inv_freq = 1.0 / (config.rope_theta ** (torch.arange(0, config.head_dim, 2, dtype=torch.float64) / config.head_dim))
        positions = torch.arange(sequence_length, dtype=torch.float64)
        freqs = torch.outer(positions, inv_freq)
        emb = torch.cat((freqs, freqs), dim=-1)
        self.register_buffer("cos", emb.cos().float()[None, None], persistent=False)
        self.register_buffer("sin", emb.sin().float()[None, None], persistent=False)
        causal = torch.full((sequence_length, sequence_length), MASK_VALUE).triu(1)
        self.register_buffer("mask", causal[None, None], persistent=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        h = self.embed_tokens(x) if self.embed_tokens is not None else x
        for layer in self.layers:
            h = layer(h, self.cos, self.sin, self.mask)
        if self.is_last:
            h = h[:, DROP_TOKEN_COUNT:, :]
        return h

    @staticmethod
    def load(model_dir: Path, config: TextConfig, start: int, end: int, sequence_length: int = TEXT_SEQUENCE_LENGTH) -> "TextEncoderChunk":
        chunk = TextEncoderChunk(config, start, end, sequence_length)
        prefix = "model.language_model."
        state: dict[str, torch.Tensor] = {}
        with safe_open(str(model_dir / "text_encoder" / "model.safetensors"), framework="pt") as weights:
            if chunk.is_first:
                state["embed_tokens.weight"] = weights.get_tensor(prefix + "embed_tokens.weight")
            for local, layer in enumerate(range(start, end)):
                source = f"{prefix}layers.{layer}."
                for name in weights.keys():
                    if not name.startswith(source):
                        continue
                    leaf = name[len(source):]
                    leaf = leaf.replace("self_attn.", "").replace("mlp.", "")
                    state[f"layers.{local}.{leaf}"] = weights.get_tensor(name)
        chunk.load_state_dict({k: v.float() for k, v in state.items()}, strict=True)
        return chunk.eval()


def chunk_boundaries(num_layers: int, num_chunks: int) -> list[tuple[int, int]]:
    edges = [round(i * num_layers / num_chunks) for i in range(num_chunks + 1)]
    return list(zip(edges[:-1], edges[1:]))


def import_dreamlite(space_dir: Path):
    if str(space_dir) not in sys.path:
        sys.path.insert(0, str(space_dir))
    from dreamlite import DreamLiteUNetModel  # noqa: PLC0415

    return DreamLiteUNetModel


def make_rms_norms_stable(module: nn.Module) -> nn.Module:
    """Swap every RMSNorm in ``module`` for the overflow-safe variant with identical weights."""
    for name, child in list(module.named_children()):
        if type(child).__name__ == "RMSNorm":
            weight = getattr(child, "weight", None)
            dim = weight.shape[0] if weight is not None else child.dim[0] if isinstance(child.dim, tuple) else child.dim
            stable = StableRMSNorm(dim, child.eps)
            with torch.no_grad():
                if weight is not None:
                    stable.weight.copy_(weight)
                else:
                    stable.weight.fill_(1.0)
            setattr(module, name, stable)
        else:
            make_rms_norms_stable(child)
    return module


class UNetStep(nn.Module):
    """One text-to-image UNet evaluation: ``noise_pred = unet([latents | zeros], t, text)[..., :W]``."""

    def __init__(self, unet: nn.Module, image_size: int = IMAGE_SIZE):
        super().__init__()
        self.unet = unet
        self.register_buffer("time_ids", torch.tensor([[float(image_size), float(image_size)]]), persistent=False)

    def forward(
        self,
        latents: torch.Tensor,
        timestep: torch.Tensor,
        encoder_hidden_states: torch.Tensor,
        encoder_attention_mask: torch.Tensor,
    ) -> torch.Tensor:
        sample = torch.cat([latents, torch.zeros_like(latents)], dim=3)
        noise = self.unet(
            sample,
            timestep,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            added_cond_kwargs={"time_ids": self.time_ids},
            return_dict=False,
        )[0]
        return noise[..., : latents.shape[-1]]

    @staticmethod
    def load(model_dir: Path, space_dir: Path) -> "UNetStep":
        unet_class = import_dreamlite(space_dir)
        unet = unet_class.from_pretrained(str(model_dir / "unet"), torch_dtype=torch.float32)
        return UNetStep(make_rms_norms_stable(unet.eval())).eval()


class LatentDecoder(nn.Module):
    """TAESDXL decode with the pipeline's post-processing folded in: RGB in [0, 1]."""

    def __init__(self, vae: nn.Module):
        super().__init__()
        self.decoder = vae.decoder
        self.scaling_factor = float(vae.config.scaling_factor)
        self.shift_factor = float(getattr(vae.config, "shift_factor", 0.0) or 0.0)

    def forward(self, latents: torch.Tensor) -> torch.Tensor:
        image = self.decoder(latents / self.scaling_factor + self.shift_factor)
        return (image / 2 + 0.5).clamp(0, 1)

    @staticmethod
    def load(model_dir: Path) -> "LatentDecoder":
        from diffusers import AutoencoderTiny  # noqa: PLC0415

        vae = AutoencoderTiny.from_pretrained(str(model_dir / "vae"), torch_dtype=torch.float32)
        return LatentDecoder(vae.eval()).eval()


def flow_match_sigmas(num_steps: int, latent_height: int, latent_width: int, scheduler_config: dict) -> list[float]:
    """FlowMatchEulerDiscreteScheduler sigmas as configured by DreamLiteMobilePipeline (trailing 0 included)."""
    base_len = scheduler_config.get("base_image_seq_len", 256)
    max_len = scheduler_config.get("max_image_seq_len", 4096)
    base_shift = scheduler_config.get("base_shift", 0.5)
    max_shift = scheduler_config.get("max_shift", 1.16)
    image_seq_len = latent_height * latent_width // 4
    slope = (max_shift - base_shift) / (max_len - base_len)
    mu = image_seq_len * slope + (base_shift - slope * base_len)
    sigmas = []
    for i in range(num_steps):
        sigma = 1.0 - i * (1.0 - 1.0 / num_steps) / max(1, num_steps - 1)
        sigmas.append(math.exp(mu) / (math.exp(mu) + (1.0 / sigma - 1.0)))
    return sigmas + [0.0]
