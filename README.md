# Tydi-tools

The Docker image resulting from the Dockerfile in this repository is meant to contain all Tydi related tooling, so you can easily get started with Tydi based development.

The tools included, together with the necessary software to run them, are:

- [Tydi-lang](https://github.com/twoentartian/tydi-lang-2) – Tydi-lang compiler
- [Tydi-lang-2-Chisel](https://github.com/ccromjongh/tydi-lang-2-chisel) – A Tydi-lang-IR to Chisel transpiler
- [Tydi-Chisel](https://github.com/abs-tudelft/Tydi-Chisel) – The Scala library for integrating Tydi concepts inside Chisel
- [TIL-JSON](https://github.com/jhaenen/JSON_hierachy) – A tool for automatically generating a JSON to Tydi streams parser  
  _Note: not actively maintained anymore_
- [TIL](https://github.com/matthijsr/til-vhdl) – The Tydi Intermediate Representation to VHDL compiler  
  _Note: not actively maintained anymore_

## Usage

To use the container, build the image.

```bash
docker build -t tydi-tools .
```

Then, run the container with terminal like:

```bash
docker run -it --rm --name tydi-tools-container -v .:/root/tvlsi-example tydi-tools /bin/bash
```

The container contains some example files for a simple passthrough to test with. The commands to compile this project to Verilog from the Tydi-lang description are as follows:

```shell
tydi-lang-complier -c tydi_passthrough_project.toml
tl2chisel output/ output/json_IR.json
scala-cli output/json_IR_generation_stub.scala output/json_IR_main.scala
```
Commands will look similar for a custom project. See the details of the specific tools for configuration specifics.

## Container contents
The following commands are available inside the container:

- Tydi tools
  - `tydi-lang-complier`
  - `tl2chisel`
  - `til-demo`
  - `json_hierachy`
- Java/scala tools
  - `cs`
  - `java`
  - `scala-cli`
  - `sbt`
- Chisel tools
  - `firtool`
- Other tools
  - `graphviz`
