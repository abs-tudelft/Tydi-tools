# amd64 must be used as there is no aarch64 build available for firtool
FROM --platform=linux/amd64 rust:1-trixie AS rust-tydi-lang

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/twoentartian/tydi-lang-2.git
WORKDIR /usr/src/tydi-lang-2
RUN cargo build --release

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/matthijsr/til-vhdl.git
WORKDIR /usr/src/til-vhdl
RUN cargo build --release

FROM --platform=linux/amd64 rust:1-trixie AS rust-json-hierarchy
# Required for building JSON_hierachy
RUN apt-get update &&  \
    apt-get install -y python3-dev &&  \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

WORKDIR /usr/src/
ENV PYO3_PYTHON=/usr/bin/python3
RUN git clone --depth 1 --recurse-submodules https://github.com/abs-tudelft/JSON_hierachy.git
WORKDIR /usr/src/JSON_hierachy
RUN cargo build --release

FROM --platform=linux/amd64 rust:1-trixie AS rust-tywaves
RUN apt-get update && \
    apt-get install -y openssl libssl-dev && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

WORKDIR /usr/src/
RUN git clone https://github.com/jarlb/surfer-tywaves.git
WORKDIR /usr/src/surfer-tywaves
RUN git submodule update --init --recursive
RUN cargo build --release

FROM --platform=linux/amd64 rust:1-trixie AS rust-chiseltrace
RUN apt-get update && \
    apt-get install -y libwebkit2gtk-4.1-dev build-essential curl wget file libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev nodejs npm && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

RUN cargo install tauri-cli --version "^2.0.0" --locked

WORKDIR /usr/src/
RUN git clone --depth 1 https://github.com/jarlb/chiseltrace.git
WORKDIR /usr/src/chiseltrace
RUN git submodule update --init --recursive
WORKDIR /usr/src/chiseltrace/gui
RUN npm ci --no-cache
RUN npm i @tauri-apps/api@~2.6 --no-cache
RUN npm i @tauri-apps/plugin-opener@~2.4 --no-cache
WORKDIR /usr/src/chiseltrace
RUN cargo tauri build --no-bundle

FROM eclipse-temurin:25 AS java-builder-base
RUN apt-get update && \
    apt-get install -y curl git && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENV SBT_VERSION=1.11.7

# Install sbt
RUN curl -fsL --show-error "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xfz - -C /usr/share && \
    chown -R root:root /usr/share/sbt && \
    chmod -R 755 /usr/share/sbt && \
    ln -s /usr/share/sbt/bin/sbt /usr/local/bin/sbt

FROM java-builder-base AS java-tydi-libs

WORKDIR /usr/src/
# Get Tydi-Chisel and execute a local publish
RUN git clone --depth 1 https://github.com/abs-tudelft/Tydi-Chisel.git
WORKDIR /usr/src/Tydi-Chisel
RUN sbt publishLocal

WORKDIR /usr/src/
# Get Tydi-Chisel and execute a local publish
RUN git clone --depth 1 https://github.com/abs-tudelft/ScalaTydiPayloadKit.git
WORKDIR /usr/src/ScalaTydiPayloadKit/lib
RUN sbt publishLocal

WORKDIR /usr/src/
# Get Tydi-Chisel and execute a local publish
RUN git clone --depth 1 https://github.com/abs-tudelft/TydiPostProcessorDemo.git
WORKDIR /usr/src/TydiPostProcessorDemo
RUN sbt publishLocal

FROM java-builder-base AS java-chisel

WORKDIR /usr/src/
# Get the ChiselTrace version of Chisel and execute a local publish
RUN git clone https://github.com/jarlb/chisel.git
WORKDIR /usr/src/chisel
RUN git checkout chiseltrace
RUN sbt "unipublish / publishLocal"

WORKDIR /usr/src/
# Get Tywaves-Chisel and execute a local publish
RUN git clone --depth 1 https://github.com/jarlb/tywaves-chisel.git
WORKDIR /usr/src/tywaves-chisel
RUN sbt publishLocal

# amd64 must be used as there is no aarch64 build available for firtool
FROM --platform=linux/amd64 python:3.12-trixie AS tydi-tools-cli
LABEL authors="Casper Cromjongh"

WORKDIR /usr/src/
# Clone and install Tydi-lang-2-Chisel
RUN git clone --depth 1 https://github.com/ccromjongh/tydi-lang-2-chisel.git
WORKDIR /usr/src/tydi-lang-2-chisel
RUN chmod -R +x tl2chisel/
RUN pip3 install -e . --no-cache-dir
RUN ln -s /usr/src/tydi-lang-2-chisel/tl2chisel/tl2chisel.py /usr/bin/tl2chisel

ENV XDG_CACHE_HOME=/var/cache
ENV COURSIER_CACHE=/var/cache/coursier

RUN apt-get update &&  \
    apt-get install -y python3-dev graphviz verilator &&  \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENV PYTHONPATH=/usr/local/lib/python3.12/site-packages
RUN pip3 install funcparserlib --no-cache-dir

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
RUN echo "n" | cs setup --apps sbt,scala-cli --install-dir /usr/bin && \
    rm -rf $COURSIER_CACHE/https

WORKDIR /root
# Download and run chisel example file to fetch dependencies
RUN curl -O -L https://github.com/chipsalliance/chisel/releases/latest/download/chisel-example.scala

COPY --from=java-tydi-libs /root/.ivy2/local/ /root/.ivy2/local/

# Copy executables compiled in the Rust image
COPY --from=rust-tydi-lang /usr/src/tydi-lang-2/target/release/tydi-lang-complier /usr/bin/
COPY --from=rust-tydi-lang /usr/src/til-vhdl/target/release/til-demo /usr/bin/
COPY --from=rust-json-hierarchy /usr/src/JSON_hierachy/target/release/json_hierachy /usr/bin/

WORKDIR /root

COPY passthrough.td .
COPY tydi_passthrough_project.toml .
RUN tydi-lang-complier -c tydi_passthrough_project.toml
RUN tl2chisel output/ output/json_IR.json
RUN scala-cli output/json_IR_generation_stub.scala output/json_IR_main.scala &&  \
    rm -rf $COURSIER_CACHE/https

# Link the java version that scala-cli downloads to the system location
RUN ln -s $(find -O3 $COURSIER_CACHE/arc/https/github.com/adoptium/temurin17-binaries -name java) /usr/bin/java

FROM tydi-tools-cli AS tydi-tools

RUN apt-get update &&  \
    apt-get install -y libwebkit2gtk-4.1-dev &&  \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

WORKDIR /usr/src/
# Get the Chiselwatt demo, remove the tests folder (not needed for demo, 130 MB)
RUN git clone --depth 1 https://github.com/jarlb/chiselwatt.git &&  \
    rm -r chiselwatt/tests
WORKDIR /usr/src/chiselwatt
# The hex file is normally generated and put in this location by the makefile, we take a shortcut
RUN ln -sf ./samples/binaries/simple_asm/program.hex ./insns.hex
# Get the firtool and put it in the right place
ARG FIR_NAME="firtool-type-dbg-info"
RUN curl -L "https://github.com/rameloni/circt/releases/download/v0.1.5-tywaves-SNAPSHOT/firtool-bin-linux-x64.tar.gz" | tar zx && \
    chmod +x bin/${FIR_NAME}-0.1.5 &&  \
    mv bin/${FIR_NAME}-0.1.5 /usr/bin/${FIR_NAME}-0.1.6 &&  \
    rm -r bin

# Scala libs
COPY --from=java-chisel /root/.ivy2/local/ /root/.ivy2/local/
# chiseltrace and tywaves binaries
COPY --from=rust-chiseltrace /usr/src/chiseltrace/target/release/chiseltrace /usr/bin/
COPY --from=rust-tywaves /usr/src/surfer-tywaves/target/release/surfer-tywaves /usr/bin/
# For some reason a specific name is required for surfer
RUN ln -s /usr/bin/surfer-tywaves /usr/bin/surfer-tywaves-0.3.3

# Test can finally be ran with
# sbt "testOnly *CoreTest"
# It doesn't make much sense to run this in the build proces.

CMD ["bash"]

FROM tydi-tools AS tydi-tools-desktop
LABEL authors="Casper Cromjongh"

RUN apt-get update &&  \
    apt-get install -y \
        xfce4 \
        xfce4-terminal \
        x11vnc \
        xvfb \
        novnc \
        websockify \
        dbus-x11 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

COPY start-desktop.sh /usr/local/bin/
CMD ["/usr/local/bin/start-desktop.sh"]
