//! Typed harness error categories mapped to CLI exit policy (`docs/CLI.md`).

pub const Category = enum {
    /// Unknown subcommand or bad invocation (exit 1).
    unknown_command,
    /// Invalid probe spec or validation failure (exit 2).
    invalid_spec,
    /// I/O failure, allocation failure, or unexpected runtime fault (exit 3).
    runtime_failure,

    pub fn exitCode(self: Category) u8 {
        return switch (self) {
            .unknown_command => 1,
            .invalid_spec => 2,
            .runtime_failure => 3,
        };
    }
};

