use crate::error::SolverError;
use crate::model::{FacilityResult, SolverInput};
use good_lp::solvers::{SolutionStatus, WithTimeLimit};
use good_lp::{
    constraint, default_solver, variable, Expression, ProblemVariables, ResolutionError, Solution,
    SolverModel, Variable,
};

const DEFICIT_WEIGHT: f64 = 1.0;
const EXCESS_WEIGHT: f64 = 1e-4;
const UTILIZATION_WEIGHT: f64 = 1e-4;

pub fn solve(
    input: &SolverInput,
    time_limit_secs: f64,
) -> Result<Vec<FacilityResult>, SolverError> {
    let mut vars = ProblemVariables::new();
    let allocations: Vec<Variable> = input
        .facilities
        .iter()
        .map(|facility| vars.add(variable().min(facility.floor).max(facility.capacity)))
        .collect();

    let mut objective: Expression = input
        .facilities
        .iter()
        .zip(&allocations)
        .filter(|(facility, _)| facility.capacity > 0.0)
        .map(|(facility, &allocation)| (UTILIZATION_WEIGHT / facility.capacity) * allocation)
        .sum();

    let mut balance = |production: Expression, landed: f64, demand: f64| {
        let deficit = vars.add(variable().min(0.0));
        let excess = vars.add(variable().min(0.0));
        objective += DEFICIT_WEIGHT * deficit + EXCESS_WEIGHT * excess;
        constraint!(production + deficit + landed - excess == demand)
    };

    let mut constraints: Vec<_> = input
        .regions
        .iter()
        .map(|region| {
            let production = input
                .facilities
                .iter()
                .zip(&allocations)
                .filter(|(facility, _)| facility.region == region.id)
                .map(|(_, &allocation)| allocation)
                .sum();
            balance(production, region.landed, region.demand)
        })
        .collect();
    constraints.push(balance(
        allocations.iter().sum(),
        input.landed,
        input.demand,
    ));

    let solution = vars
        .minimise(objective)
        .using(default_solver)
        .with_time_limit(time_limit_secs)
        .with_all(constraints)
        .solve()
        .map_err(|error| map_resolution_error(error, time_limit_secs))?;
    check_solution_status(solution.status(), time_limit_secs)?;

    Ok(input
        .facilities
        .iter()
        .zip(&allocations)
        .map(|(facility, &allocation)| FacilityResult {
            id: facility.id.clone(),
            allocated: solution.value(allocation),
        })
        .collect())
}

fn map_resolution_error(error: ResolutionError, time_limit_secs: f64) -> SolverError {
    match error {
        ResolutionError::Other("NoSolutionFound") => SolverError::Timeout {
            reason: format!(
                "solver reached its time limit of {time_limit_secs}s before finding a feasible allocation"
            ),
        },
        other => SolverError::SolverFailure {
            reason: other.to_string(),
        },
    }
}

fn check_solution_status(status: SolutionStatus, time_limit_secs: f64) -> Result<(), SolverError> {
    match status {
        SolutionStatus::TimeLimit => Err(SolverError::Timeout {
            reason: format!(
                "solver reached its time limit of {time_limit_secs}s before proving optimality"
            ),
        }),
        SolutionStatus::Optimal | SolutionStatus::GapLimit => Ok(()),
    }
}
