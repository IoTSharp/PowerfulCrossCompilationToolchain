# LaneApp HyperLPR3 Static Profile

## Pinned Baseline

- Upstream: `szad670401/HyperLPR`
- Revision: `9307450f7b7915be18f23a539ec05b41fe6629f4`
- PCCT package version: `3.0.1.9307450.1`
- Target: X86/i386 only
- Runtime shape: static HyperLPR3, MNN, and OpenCV archives with six read-only
  embedded model objects

`sources/rebuildhyperlpr.sh` verifies and applies the patches in this order:

1. `hyperlpr3-embedded-models.patch` keeps the upstream file-loading API and
   adds the separate `embedded://` resolver.
2. `hyperlpr3-detector-observations.patch` adds the extend-only
   `HLPR_ContextObserveDetections` ABI without changing
   `HLPR_ContextUpdateStream`.

Both patch hashes are pinned in `sources/dependency-versions.sh` and installed
as `PATCH-SHA256SUMS`. Model hashes remain independently pinned in
`MODEL-SHA256SUMS`.

## Detection Observation ABI

The installed `hyper_lpr_sdk_observation.h` header defines ABI version 1:

- fixed capacity of 5 observations;
- 100-byte items and a 516-byte batch, matching the LaneApp C adapter layout;
- detector confidence and a clamped finite bbox copied immediately after NMS;
- `OCR_VALID` only for finite OCR confidence that passes the configured
  threshold and the existing minimum 8-byte text gate;
- an empty first text byte whenever `OCR_VALID` is absent.

The observation function runs the same context and image buffer pipeline as
the existing update function. It does not open media, load runtime models, or
introduce another shared library.

## Verification Gates

The HyperLPR rebuild performs a production-helper smoke for OCR inference
failure, low confidence, short text, and valid text. The X86 image verification
then checks the public ABI sizes, pkg-config capability variables, patch and
model manifests, both old and new archive symbols, a real embedded-model
context, a blank BGR inference call through the observation API, and the
absence of recognition or C++ runtime shared dependencies.

When the observation ABI changes, update all of the following together:

- package version and capability variables in `dependency-versions.sh`;
- the public header, projection smoke, patch hashes, NOTICE, and this document;
- LaneApp's exact pkg-config version pin and its ABI contract test.
