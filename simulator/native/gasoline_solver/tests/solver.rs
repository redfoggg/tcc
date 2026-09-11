use gasoline_solver::{solve, FacilityInput, SolverError, SolverInput};

const LIMIT: f64 = 5.0;
const EPS: f64 = 1e-6;

fn facility(id: &str, capacity: f64, floor: f64) -> FacilityInput {
    FacilityInput {
        id: id.into(),
        capacity,
        floor,
    }
}

fn input(demand: f64, inventory: f64, facilities: Vec<FacilityInput>) -> SolverInput {
    SolverInput {
        demand,
        initial_inventory: inventory,
        facilities,
    }
}

#[test]
fn solves_normal_allocation() {
    let output = solve(&input(100.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!((output.production - 100.0).abs() < EPS);
    assert!(output.deficit.abs() < EPS);
    assert!((output.coverage - 1.0).abs() < EPS);
}

#[test]
fn reports_deficit_when_capacity_is_insufficient() {
    let output = solve(&input(500.0, 0.0, vec![facility("T1", 100.0, 0.0)]), LIMIT).unwrap();

    assert!((output.production - 100.0).abs() < EPS);
    assert!((output.deficit - 400.0).abs() < EPS);
}

#[test]
fn respects_operating_floor() {
    let output = solve(&input(10.0, 0.0, vec![facility("T1", 50.0, 30.0)]), LIMIT).unwrap();

    assert!((output.production - 30.0).abs() < EPS);
    assert!((output.ending_inventory - 20.0).abs() < EPS);
}

#[test]
fn lowers_utilization_when_demand_is_below_the_safe_cap() {
    let output = solve(&input(40.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 40.0).abs() < EPS);
    assert!(output.ending_inventory.abs() < EPS);
}

#[test]
fn does_not_trade_deficit_for_lower_throughput() {
    let output = solve(&input(100.0, 0.0, vec![facility("T1", 30.0, 0.0)]), LIMIT).unwrap();

    assert!((output.production - 30.0).abs() < EPS);
    assert!((output.deficit - 70.0).abs() < EPS);
}

#[test]
fn stays_at_demand_when_that_already_clears_deficit() {
    let output = solve(&input(160.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 160.0).abs() < EPS);
}

#[test]
fn uses_plant_cap_when_demand_exceeds_it() {
    let output = solve(&input(190.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 190.0).abs() < EPS);
}

#[test]
fn reports_timeout() {
    let error = solve(&input(10.0, 0.0, vec![facility("T1", 100.0, 0.0)]), 0.0).unwrap_err();

    assert!(matches!(error, SolverError::Timeout { .. }));
}
