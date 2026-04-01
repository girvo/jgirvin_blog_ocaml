# Stage 1: Build the OCaml generator
FROM ocaml/opam:debian-12-ocaml-5.4 AS builder

WORKDIR /build

COPY . .

RUN sudo apt-get update && sudo apt-get install -y pkg-config

# Install deps and compile the SSG
RUN opam install . --deps-only
RUN opam exec -- dune build --release ./bin/main.exe

# Stage 2: Minimal runtime image
FROM debian:12-slim AS runner

RUN apt-get update && apt-get install -y --no-install-recommends gmp libgmp10 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/_build/default/bin/main.exe /usr/local/bin/jgirvin_blog

ENTRYPOINT ["jgirvin_blog"]
CMD ["--input", "/input", "--output", "/output"]
