use crate::error::SolverError;
use crate::model::{FacilityInput, FacilityResult, SolverInput, SolverOutput};
use good_lp::solvers::{SolutionStatus, WithTimeLimit};
use good_lp::variable::ProblemVariables;
use good_lp::{
    constraint, default_solver, variable, Constraint, Expression, ResolutionError, Solution,
    SolverModel, Variable,
};
use std::time::Instant;

const BINDING_EPS: f64 = 1e-6;
const DEFICIT_TOLERANCE: f64 = 1e-6;

struct FacilityVars<'a> {
    facility: &'a FacilityInput,
    allocation: Variable,
    active: Variable,
}

pub fn solve(input: &SolverInput, time_limit_secs: f64) -> Result<SolverOutput, SolverError> {
    validate(input)?;

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

    let mut throughput_objective = Expression::with_capacity(facility_vars.len());
    let mut production_expr = Expression::with_capacity(facility_vars.len());
    for fv in &facility_vars {
        throughput_objective.add_mul(1.0 / fv.facility.reference_yield, fv.allocation);
        production_expr.add_mul(1.0, fv.allocation);
    }

    let mut common_constraints: Vec<Constraint> = Vec::with_capacity(facility_vars.len() * 2 + 1);
    for fv in &facility_vars {
        common_constraints.push(constraint!(
            fv.allocation <= fv.active * fv.facility.capacity
        ));
        common_constraints.push(constraint!(fv.allocation >= fv.active * fv.facility.floor));
    }
    let balance_lhs = production_expr + deficit - ending_inventory;
    common_constraints.push(constraint!(
        balance_lhs == (input.demand - input.initial_inventory)
    ));

    let stage_started_at = Instant::now();

    let stage1_solution = vars
        .clone()
        .minimise(deficit)
        .using(default_solver)
        .with_time_limit(time_limit_secs)
        .with_all(common_constraints.clone())
        .solve()
        .map_err(|error| map_resolution_error(error, time_limit_secs, 1))?;
    check_solution_status(stage1_solution.status(), time_limit_secs, 1)?;

    let stage1_deficit = stage1_solution.value(deficit);
    let stage2_time_limit = (time_limit_secs - stage_started_at.elapsed().as_secs_f64()).max(0.0);

    let mut stage2_constraints = common_constraints;
    stage2_constraints.push(constraint!(deficit <= stage1_deficit + DEFICIT_TOLERANCE));
    stage2_constraints.push(constraint!(deficit >= stage1_deficit - DEFICIT_TOLERANCE));

    let stage2_solution = vars
        .minimise(throughput_objective)
        .using(default_solver)
        .with_time_limit(stage2_time_limit)
        .with_all(stage2_constraints)
        .solve()
        .map_err(|error| map_resolution_error(error, stage2_time_limit, 2))?;
    check_solution_status(stage2_solution.status(), stage2_time_limit, 2)?;

    let facilities: Vec<FacilityResult> = facility_vars
        .iter()
        .map(|fv| build_facility_result(fv, &stage2_solution))
        .collect();

    let production: f64 = facilities.iter().map(|result| result.allocated).sum();
    let deficit_value = stage2_solution.value(deficit);
    let ending_inventory_value = stage2_solution.value(ending_inventory);
    let served_demand = input.demand - deficit_value;
    let coverage = if input.demand > 0.0 {
        served_demand / input.demand
    } else {
        1.0
    };

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
    let allocated = solution.value(fv.allocation);
    let active = solution.value(fv.active) > 0.5;
    let utilization = if fv.facility.capacity > 0.0 {
        allocated / fv.facility.capacity
    } else {
        0.0
    };
    let binding_capacity = active && (fv.facility.capacity - allocated) <= BINDING_EPS;

    FacilityResult {
        id: fv.facility.id.clone(),
        allocated,
        active,
        utilization,
        binding_capacity,
    }
}

fn map_resolution_error(error: ResolutionError, time_limit_secs: f64, stage: u8) -> SolverError {
    match error {
        ResolutionError::Infeasible => SolverError::SolverFailure {
            reason: format!("stage {stage} solver unexpectedly reported no feasible allocation"),
        },
        ResolutionError::Unbounded => SolverError::SolverFailure {
            reason: format!("stage {stage} objective is unbounded"),
        },
        ResolutionError::Other("NoSolutionFound") => SolverError::Timeout {
            reason: format!(
                "stage {stage} solver reached its time limit of {time_limit_secs}s before finding a feasible allocation"
            ),
        },
        other => SolverError::SolverFailure {
            reason: format!("stage {stage} {other}"),
        },
    }
}

fn validate(input: &SolverInput) -> Result<(), SolverError> {
    let valid = input
        .facilities
        .iter()
        .all(|facility| facility.reference_yield.is_finite() && facility.reference_yield > 0.0);

    if valid {
        Ok(())
    } else {
        Err(SolverError::InvalidInput {
            reason: "reference yield must be finite and positive".to_string(),
        })
    }
}

fn check_solution_status(
    status: SolutionStatus,
    time_limit_secs: f64,
    stage: u8,
) -> Result<(), SolverError> {
    match status {
        SolutionStatus::TimeLimit => Err(SolverError::Timeout {
            reason: format!(
                "stage {stage} solver reached its time limit of {time_limit_secs}s before proving optimality"
            ),
        }),
        SolutionStatus::Optimal | SolutionStatus::GapLimit => Ok(()),
    }
}
