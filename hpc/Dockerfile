
FROM alphafold3:latest AS build-stage


FROM nvidia/cuda:12.6.0-base-ubuntu22.04 AS run-stage


RUN apt update --quiet \
    && apt install --yes --quiet software-properties-common \
    && apt install --yes --quiet zstd


# Get apt repository of specific Python versions. Then install Python. Tell APT
# this isn't an interactive TTY to avoid timezone prompt when installing.
RUN add-apt-repository ppa:deadsnakes/ppa \
    && DEBIAN_FRONTEND=noninteractive apt install --yes --quiet python3.11 python3.11-venv

COPY --from=build-stage /alphafold3_venv /alphafold3_venv
COPY --from=build-stage /hmmer /hmmer

RUN python3.11 -m venv /alphafold3_venv

ENV PATH="/hmmer/bin:/alphafold3_venv/bin:$PATH"
COPY --from=build-stage /app/alphafold /app/alphafold

# To work around a known XLA issue causing the compilation time to greatly
# increase, the following environment variable setting XLA flags must be enabled
# when running AlphaFold 3. Note that if using CUDA capability 7 GPUs, it is
# necessary to set the following XLA_FLAGS value instead:
# ENV XLA_FLAGS="--xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
# (no need to disable gemm in that case as it is not supported for such GPU).
ENV XLA_FLAGS="--xla_gpu_enable_triton_gemm=false"
# Memory settings used for folding up to 5,120 tokens on A100 80 GB.
ENV XLA_PYTHON_CLIENT_PREALLOCATE=true
ENV XLA_CLIENT_MEM_FRACTION=0.95

CMD ["python3", "run_alphafold.py"]
