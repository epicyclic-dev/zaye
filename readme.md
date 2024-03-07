# ZAYE Ain't a Yaml Emitter

zaye is a very simple libyaml-based YAML parser for zig. In the spirit of describing
things by defining what they aren't, it is not capable of emitting YAML. If that
changes in the future, then this will have been a poor naming choice.

## Status

A single YAML document can be parsed one-shot into a nested tagged-union structure in
zig. No automatic type conversion happens, all scalars left as strings. Most advanced
YAML features are ignored or not supported (e.g. anchors/aliases and tags).

It does what I need it to do.

zig 0.11.0 build system for now.
