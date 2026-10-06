use crate::error::SolverError;
use crate::model::{FacilityInput, FacilityResult, SolverInput, SolverOutput};
use good_lp::solvers::{SolutionStatus, WithTimeLimit};
use good_lp::variable::ProblemVariables;
use good_lp::{
    constraint, default_solver, variable, Constraint, Expression, ResolutionError, Solution,
    SolverModel, Variable,
};

const DEFICIT_WEIGHT: f64 = 1.0;
const UTILIZATION_WEIGHT: f64 = 1e-4;

struct FacilityVars<'a> {
    facility: &'a FacilityInput,
    allocation: Variable,
    active: Variable,
}

pub fn solve(input: &SolverInput, time_limit_secs: f64) -> Result<SolverOutput, SolverError> {
    let mut vars = ProblemVariables::new();
    let mut facility_vars = Vec::with_capacity(input.facilities.len());

    for facility in &input.facilities {
        let allocation = vars.add(variable().min(0.0).max(facility.capacity));
        let active = vars.add(variable().binary());
        facility_vars.push(FacilityVars {
            facility,
            allocation,
            active,
        });
    }

    let deficit = vars.add(variable().min(0.0));
    let ending_inventory = vars.add(variable().min(0.0));

    let mut production_expr = Expression::with_capacity(facility_vars.len());
    let mut objective = Expression::with_capacity(facility_vars.len() + 1);
    objective.add_mul(DEFICIT_WEIGHT, deficit);
    for fv in &facility_vars {
        production_expr.add_mul(1.0, fv.allocation);
        if fv.facility.capacity > 0.0 {
            objective.add_mul(UTILIZATION_WEIGHT / fv.facility.capacity, fv.allocation);
        }
    }

    let mut constraints: Vec<Constraint> = Vec::with_capacity(facility_vars.len() * 3 + 1);
    for fv in &facility_vars {
        constraints.push(constraint!(fv.active == 1));
        constraints.push(constraint!(
            fv.allocation <= fv.active * fv.facility.capacity
        ));
        constraints.push(constraint!(fv.allocation >= fv.active * fv.facility.floor));
    }
    let balance_lhs = production_expr + deficit - ending_inventory;
    constraints.push(constraint!(
        balance_lhs == (input.demand - input.initial_inventory)
    ));

    let solution = vars
        .minimise(objective)
        .using(default_solver)
        .with_time_limit(time_limit_secs)
        .with_all(constraints)
        .solve()
        .map_err(|error| map_resolution_error(error, time_limit_secs))?;
    check_solution_status(solution.status(), time_limit_secs)?;

    let facilities: Vec<FacilityResult> = facility_vars
        .iter()
        .map(|fv| build_facility_result(fv, &solution))
        .collect();

    let production: f64 = facilities.iter().map(|result| result.allocated).sum();
    let deficit_value = solution.value(deficit).max(0.0);
    let ending_inventory_value = solution.value(ending_inventory).max(0.0);
    let served_demand = input.demand - deficit_value;
    let coverage = served_demand / input.demand;

    Ok(SolverOutput {
        demand: input.demand,
        starting_inventory: input.initial_inventory,
        ending_inventory: ending_inventory_value,
        production,
        served_demand,
        deficit: deficit_value,
        coverage,
        facilities,
    })
}

fn build_facility_result(fv: &FacilityVars<'_>, solution: &impl Solution) -> FacilityResult {
    let allocated = solution.value(fv.allocation).max(0.0);
    let active = solution.value(fv.active) > 0.5;

    FacilityResult {
        id: fv.facility.id.clone(),
        allocated,
        active,
    }
}

fn map_resolution_error(error: ResolutionError, time_limit_secs: f64) -> SolverError {
    match error {
        ResolutionError::Infeasible => SolverError::SolverFailure {
            reason: "solver unexpectedly reported no feasible allocation".to_string(),
        },
        ResolutionError::Unbounded => SolverError::SolverFailure {
            reason: "objective is unbounded".to_string(),
        },
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
