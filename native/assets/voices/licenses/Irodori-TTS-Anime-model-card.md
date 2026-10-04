---
license: mit
pipeline_tag: text-to-speech
base_model: Aratako/Irodori-TTS-v4.1-Small
base_model_relation: finetune
---

# Irodori-TTS-v4.1-Anime

A Japanese text-to-speech model fine-tuned from
[Aratako/Irodori-TTS-v4.1-Small](https://huggingface.co/Aratako/Irodori-TTS-v4.1-Small)
using anime-style speech data.

The base model's annotation pipeline is not publicly documented, so the
fine-tuning data was annotated independently. Consequently, caption
conditioning and emoji controls may behave differently from the base model.

## Checkpoints

The full-precision checkpoint is available at the repository root.

Quantized variants are provided in the following subdirectories:

- `int8-weight-only`
- `int8-dynamic`
- `int4-weight-only`
- `float8-weight-only`
- `float8-dynamic`

For inference and installation instructions, see the
[original Irodori-TTS repository](https://github.com/Aratako/Irodori-TTS).

## License

This model follows the same MIT License and ethical restrictions as the base model.