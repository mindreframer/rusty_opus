# Security policy

Report vulnerabilities privately through the repository security advisory facility at
`https://github.com/mindreframer/rusty_opus/security/advisories/new`. Do not open a
public issue or include audio content, PCM payloads, or production keys. Maintainers
will acknowledge a report, assess affected supported versions, and coordinate a fix and
disclosure.

RustyOpus runs native Rust codec code inside the BEAM through a Rustler NIF. A memory
unsafety or native abort in the codec can terminate or corrupt the VM; OTP supervision is
not an isolation boundary. Panics are contained at the NIF boundary where possible and
poison the affected codec resource, but hostile or malformed audio should be treated as
untrusted input.

Supported versions receive fixes on the latest 0.1.x line. Rust, Cargo, Hex, `opus-rs`,
and transitive dependency advisories are reviewed before releases; exact versions and the
toolchain are documented in `docs/provenance.md`. Release NIFs are built from an exact
tag and checksum-verified as described in `docs/release.md` (roadmap Epic 7). A checksum
proves artifact identity, not native-code safety.
