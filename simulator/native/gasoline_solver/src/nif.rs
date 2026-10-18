use crate::error::SolverError;
use crate::model::{FacilityResult, SolverInput};
use crate::solve::solve;
use rustler::Atom;

mod atoms {
    rustler::atoms! {
        solver_failure,
        timeout,
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn solve_nif(
    input: SolverInput,
    time_limit_secs: f64,
) -> Result<Vec<FacilityResult>, (Atom, String)> {
    solve(&input, time_limit_secs).map_err(|error| match error {
        SolverError::SolverFailure { reason } => (atoms::solver_failure(), reason),
        SolverError::Timeout { reason } => (atoms::timeout(), reason),
    })
}

rustler::init!("Elixir.GasolineSimulator.Solver.Native");
