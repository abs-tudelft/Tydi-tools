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

# Add Adoptium sources
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
# Update and install packages
RUN apt-get update && apt-get install -y temurin-17-jdk

WORKDIR /usr/bin
RUN curl -fL "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz" | gzip -d > cs
RUN chmod +x cs
RUN cs setup --apps sbt,scala-cli --install-dir /usr/bin
RUN echo $(cs java-home)
ENV PATH="$PATH:/usr/lib/jvm/temurin-17-jdk-amd64"
RUN echo $PATH

WORKDIR /usr/src/
# Somehow
RUN git clone --depth 1 https://github.com/ccromjongh/tydi-lang-2-chisel.git
WORKDIR /usr/src/tydi-lang-2-chisel
RUN sbt publishLocal

WORKDIR /root
RUN curl -O -L https://github.com/chipsalliance/chisel/releases/latest/download/chisel-example.scala
RUN scala-cli chisel-example.scala

RUN find -O3 / -name java

# Copy executables compiled in the Rust image
COPY --from=rust /usr/src/tydi-lang-2/target/release/tydi-lang-complier /usr/bin/
COPY --from=rust /usr/src/til-vhdl/target/release/til-demo /usr/bin/
COPY --from=rust /usr/src/JSON_hierachy/target/release/json_hierachy /usr/bin/



CMD ["bash"]
