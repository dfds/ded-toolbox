# GitHub offboarding tool

A tool written in Rust that checks all repositories within DFDS for deploy keys and collaborators.

## How?

If you don't already have Rust installed, you'll need that. See https://rustup.rs/ for instructions for your OS.

With Rust installed, run `cargo run` within this directory to build and run the tool.

The tool will be expecting a GITHUB_TOKEN environment variable, e.g.

macOS/Unix: 
```
GITHUB_TOKEN=1234 cargo run
```


Windows (Powershell): 
```
$env:GITHUB_TOKEN=1234
cargo run
```
