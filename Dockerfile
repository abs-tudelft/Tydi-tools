# amd64 must be used as there is no aarch64 build available for firtool
FROM --platform=linux/amd64 rust:latest AS rust

# Required for building JSON_hierachy
RUN apt-get update && apt-get install -y python3-dev

# Clone and compile various Rust-based Tydi tools
WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/twoentartian/tydi-lang-2.git
WORKDIR /usr/src/tydi-lang-2
RUN cargo build --release

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/matthijsr/til-vhdl.git
WORKDIR /usr/src/til-vhdl
RUN cargo build --release

WORKDIR /usr/src/
ENV PYO3_PYTHON=/usr/bin/python3
RUN git clone --depth 1 --recurse-submodules https://github.com/abs-tudelft/JSON_hierachy.git
WORKDIR /usr/src/JSON_hierachy
RUN cargo build --release

# amd64 must be used as there is no aarch64 build available for firtool
FROM --platform=linux/amd64 python:3.12-bookworm AS python
LABEL authors="Casper Cromjongh"

RUN apt-get update
RUN apt-get install -y python3-dev graphviz

ENV PYTHONPATH=/usr/local/lib/python3.12/site-packages
RUN pip3 install funcparserlib

WORKDIR /usr/bin
# Install coursier and with it install sbt and scala-cli
# This is available for arm, but cannot be used for now
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        URL="https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        URL="https://github.com/VirtusLab/coursier-m1/releases/latest/download/cs-aarch64-pc-linux.gz"; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    curl -fL "$URL" | gzip -d > /usr/local/bin/cs && \
    chmod +x /usr/local/bin/cs
RUN echo "n" | cs setup --apps sbt,scala-cli --install-dir /usr/bin

WORKDIR /root
# Download and run chisel example file to fetch dependencies
RUN curl -O -L https://github.com/chipsalliance/chisel/releases/latest/download/chisel-example.scala
RUN scala-cli chisel-example.scala

# Link the java version that scala-cli downloads to the system location
RUN ln -s $(find -O3 /root/.cache/coursier/arc/https/github.com/adoptium/temurin17-binaries -name java) /usr/bin/java

WORKDIR /usr/src/
# Get Tydi-Chisel and execute a local publish
RUN git clone --depth 1 https://github.com/abs-tudelft/Tydi-Chisel.git
WORKDIR /usr/src/Tydi-Chisel
RUN sbt publishLocal

WORKDIR /usr/src/
# Clone and install Tydi-lang-2-Chisel
RUN git clone --depth 1 https://github.com/ccromjongh/tydi-lang-2-chisel.git
WORKDIR /usr/src/tydi-lang-2-chisel
RUN chmod -R +x tl2chisel/
RUN pip3 install -e .
RUN ln -s /usr/src/tydi-lang-2-chisel/tl2chisel/tl2chisel.py /usr/bin/tl2chisel

# Copy executables compiled in the Rust image
COPY --from=rust /usr/src/tydi-lang-2/target/release/tydi-lang-complier /usr/bin/
COPY --from=rust /usr/src/til-vhdl/target/release/til-demo /usr/bin/
COPY --from=rust /usr/src/JSON_hierachy/target/release/json_hierachy /usr/bin/

WORKDIR /root

COPY passthrough.td .
COPY tydi_passthrough_project.toml .
RUN tydi-lang-complier -c tydi_passthrough_project.toml
RUN tl2chisel output/ output/json_IR.json
RUN scala-cli output/json_IR_generation_stub.scala output/json_IR_main.scala

CMD ["bash"]
