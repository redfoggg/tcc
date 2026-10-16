use crate::error::SolverError;
use crate::model::{FacilityInput, FacilityResult, SolverInput, SolverOutput};
use good_lp::solvers::{SolutionStatus, WithTimeLimit};
use good_lp::variable::ProblemVariables;
use good_lp::{
    constraint, default_solver, variable, Constraint, Expression, ResolutionError, Solution,
    SolverModel, Variable,
};
use std::collections::HashMap;

const DEFICIT_WEIGHT: f64 = 1.0;
const EXCESS_WEIGHT: f64 = 1e-4;
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

    let mut production_expr = Expression::with_capacity(facility_vars.len());
    let mut objective = Expression::with_capacity(facility_vars.len() + input.regions.len() * 2);
    let mut constraints: Vec<Constraint> = Vec::with_capacity(facility_vars.len() * 3 + input.regions.len());
    let mut deficit_vars = Vec::with_capacity(input.regions.len().max(1));
    let mut excess_vars = Vec::with_capacity(input.regions.len().max(1));
    let mut reported_deficit: Option<Variable> = None;
    let mut reported_excess: Option<Variable> = None;

    for fv in &facility_vars {
        production_expr.add_mul(1.0, fv.allocation);
        if fv.facility.capacity > 0.0 {
            objective.add_mul(UTILIZATION_WEIGHT / fv.facility.capacity, fv.allocation);
        }
        constraints.push(constraint!(fv.active == 1));
        constraints.push(constraint!(
            fv.allocation <= fv.active * fv.facility.capacity
        ));
        constraints.push(constraint!(fv.allocation >= fv.active * fv.facility.floor));
    }

    if input.regions.is_empty() {
        let deficit = vars.add(variable().min(0.0));
        let excess = vars.add(variable().min(0.0));
        objective.add_mul(DEFICIT_WEIGHT, deficit);
        objective.add_mul(EXCESS_WEIGHT, excess);
        deficit_vars.push(deficit);
        excess_vars.push(excess);
        let balance_lhs = production_expr + deficit + input.landed - excess;
        constraints.push(constraint!(balance_lhs == input.demand));
    } else {
        let mut grouped: HashMap<&str, Vec<&FacilityVars>> = HashMap::new();
        for fv in &facility_vars {
            grouped.entry(fv.facility.region.as_str()).or_default().push(fv);
        }

        for region in &input.regions {
            let deficit = vars.add(variable().min(0.0));
            let excess = vars.add(variable().min(0.0));
            objective.add_mul(DEFICIT_WEIGHT, deficit);
            objective.add_mul(EXCESS_WEIGHT, excess);
            deficit_vars.push(deficit);
            excess_vars.push(excess);

            let members = grouped.get(region.id.as_str()).map(Vec::as_slice).unwrap_or(&[]);
            let mut regional_production = Expression::with_capacity(members.len());
            for fv in members {
                regional_production.add_mul(1.0, fv.allocation);
            }
            let balance_lhs = regional_production + deficit + region.landed - excess;
            constraints.push(constraint!(balance_lhs == region.demand));
        }

        let national_deficit = vars.add(variable().min(0.0));
        let national_excess = vars.add(variable().min(0.0));
        objective.add_mul(DEFICIT_WEIGHT, national_deficit);
        objective.add_mul(EXCESS_WEIGHT, national_excess);
        reported_deficit = Some(national_deficit);
        reported_excess = Some(national_excess);
        let national_balance = production_expr + national_deficit + input.landed - national_excess;
        constraints.push(constraint!(national_balance == input.demand));
    }

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
    let deficit_value = match reported_deficit {
        Some(deficit) => solution.value(deficit).max(0.0),
        None => deficit_vars
            .iter()
            .map(|deficit| solution.value(*deficit).max(0.0))
            .sum(),
    };
    let excess_value = match reported_excess {
        Some(excess) => solution.value(excess).max(0.0),
        None => excess_vars
            .iter()
            .map(|excess| solution.value(*excess).max(0.0))
            .sum(),
    };
    let demand = if input.regions.is_empty() {
        input.demand
    } else {
        input.regions.iter().map(|region| region.demand).sum()
    };
    let landed = if input.regions.is_empty() {
        input.landed
    } else {
        input.regions.iter().map(|region| region.landed).sum()
    };
    let served_demand = demand - deficit_value;
    let coverage = if demand == 0.0 { 0.0 } else { served_demand / demand };

    Ok(SolverOutput {
        demand,
        landed,
        excess: excess_value,
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
