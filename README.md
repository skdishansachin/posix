# posix

POSIX.1-2024 utilities implemented in [Zig 0.16.0](https://ziglang.org/download/0.16.0/release-notes.html).

**Not an official implementation.** This project is for educational and
reference purposes only. It aims to follow the [POSIX.1-2024 specification](https://pubs.opengroup.org/onlinepubs/9799919799/)
as closely as possible.

## Philosophy

This project is built on the principle that the best way to understand a
system is to implement it. Every utility here is written to match the
[IEEE Std 1003.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/)
specification as closely as possible.

- **Strict compliance** — Behavior follows the POSIX specification, not
  common conventions or habits.
- **Minimal abstractions** — Direct use of Linux syscalls where possible,
  avoiding unnecessary layers.
- **Explicit over implicit** — Every decision is intentional and traceable
  to the specification.

## Implemented

- [`true`](src/true.zig)
- [`false`](src/false.zig)
- [`echo`](src/echo.zig)
- [`dirname`](src/dirname.zig)

## Building

```bash
zig build
```

## Running

```bash
zig build run-echo -- "hello world"
zig build run-true
zig build run-false
zig build run-dirname -- /usr/bin
```

## Testing

```bash
zig build test-true
zig build test-false
zig build test-echo
zig build test-dirname
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for
details.

## Contributing

Contributions are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines.

## Acknowledgments

- [IEEE](https://www.ieee.org/) and [The Open Group](https://www.open-group.org/)
  for the POSIX specification.
- [Zig Software Foundation](https://ziglang.org/) for the Zig programming
  language.
- [toybox](https://github.com/landley/toybox),
  [coreutils](https://github.com/coreutils/coreutils), and
  [uutils](https://github.com/uutils/coreutils) for inspiration.

## Disclaimer

This is not an official POSIX implementation. It is provided as-is for
educational and reference purposes. Do not use this in production systems
that require certified POSIX compliance.
