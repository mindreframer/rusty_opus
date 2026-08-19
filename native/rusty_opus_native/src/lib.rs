//! `RustyOpus` native NIF library.
//!
//! Epic 1 wires only the deterministic smoke/error boundary. Encoder and decoder
//! NIFs are added in later epics.

use std::panic::{catch_unwind, AssertUnwindSafe};

use rustler::{Atom, Env, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        native,
        contained_panic
    }
}

#[rustler::nif]
fn smoke() -> (Atom, &'static str) {
    (atoms::ok(), env!("CARGO_PKG_VERSION"))
}

#[rustler::nif]
fn translated_error() -> (Atom, Atom, &'static str) {
    (
        atoms::error(),
        atoms::native(),
        "deterministic native error",
    )
}

#[rustler::nif]
fn contained_panic() -> (Atom, Atom, &'static str) {
    let result = catch_unwind(AssertUnwindSafe(|| {
        std::panic::resume_unwind(Box::new("contained test panic"));
    }));
    match result {
        Ok(()) => (atoms::ok(), atoms::native(), "unexpected success"),
        Err(_) => (
            atoms::error(),
            atoms::contained_panic(),
            "native panic contained",
        ),
    }
}

const fn load(_env: Env<'_>, _load_info: Term<'_>) -> bool {
    true
}

rustler::init!("Elixir.RustyOpus.Native", load = load);
