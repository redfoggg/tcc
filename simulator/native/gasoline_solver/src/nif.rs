use crate::error::SolverError;
use crate::model::{SolverInput, SolverOutput};
use crate::solve::solve;
use rustler::{Atom, Encoder, Env, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        invalid_input,
        solver_failure,
        timeout,
    }
}

enum NifSolveResult {
    Solved(SolverOutput),
    Failed(Atom, String),
}

impl Encoder for NifSolveResult {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            NifSolveResult::Solved(output) => (atoms::ok(), output).encode(env),
            NifSolveResult::Failed(kind, reason) => (atoms::error(), (*kind, reason)).encode(env),
        }
    }
}

impl From<SolverError> for NifSolveResult {
    fn from(value: SolverError) -> Self {
        match value {
            SolverError::InvalidInput { reason } => {
                NifSolveResult::Failed(atoms::invalid_input(), reason)
            }
            SolverError::SolverFailure { reason } => {
                NifSolveResult::Failed(atoms::solver_failure(), reason)
            }
            SolverError::Timeout { reason } => NifSolveResult::Failed(atoms::timeout(), reason),
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn solve_nif(input: SolverInput, time_limit_secs: f64) -> NifSolveResult {
    match solve(&input, time_limit_secs) {
        Ok(output) => NifSolveResult::Solved(output),
        Err(error) => NifSolveResult::from(error),
    }
}

rustler::init!("Elixir.GasolineSimulator.Solver.Native");
