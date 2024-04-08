FROM rust:latest as rust

# Required for building JSON_hierachy
RUN apt-get update && apt-get install -y python3-dev

# Clone and compile various Rust-based Tydi tools
WORKDIR /usr/src/
ENV PYO3_PYTHON=/usr/bin/python3
RUN git clone --depth 1 --recurse-submodules https://github.com/jhaenen/JSON_hierachy.git
WORKDIR /usr/src/JSON_hierachy
RUN cargo build --release

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/twoentartian/tydi-lang-2.git
WORKDIR /usr/src/tydi-lang-2
RUN cargo build --release

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/matthijsr/til-vhdl.git
WORKDIR /usr/src/til-vhdl
RUN cargo build --release

FROM python:3.12-bookworm as python
LABEL authors="Casper Cromjongh"

RUN apt-get update
RUN apt-get install -y python3-dev graphviz

WORKDIR /usr/bin
# Install coursier and with it install sbt and scala-cli
RUN curl -fL "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz" | gzip -d > cs
RUN chmod +x cs
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

WORKDIR ~

CMD ["bash"]
