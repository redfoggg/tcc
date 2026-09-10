use gasoline_solver::{solve, FacilityInput, SolverError, SolverInput};

const LIMIT: f64 = 5.0;
const EPS: f64 = 1e-6;

fn facility(id: &str, simulated_yield: f64, capacity: f64, floor: f64) -> FacilityInput {
    FacilityInput {
        id: id.into(),
        simulated_yield,
        capacity,
        floor,
    }
}

fn plant_petroleum(facilities: &[FacilityInput]) -> f64 {
    facilities
        .iter()
        .map(|facility| facility.capacity / facility.simulated_yield)
        .sum()
}

fn input(demand: f64, inventory: f64, facilities: Vec<FacilityInput>) -> SolverInput {
    let petroleum = plant_petroleum(&facilities);
    input_with_max_petroleum(demand, inventory, facilities, petroleum)
}

fn input_with_max_petroleum(
    demand: f64,
    inventory: f64,
    facilities: Vec<FacilityInput>,
    max_petroleum: f64,
) -> SolverInput {
    SolverInput {
        demand,
        initial_inventory: inventory,
        max_petroleum,
        facilities,
    }
}

#[test]
fn solves_normal_allocation() {
    let output = solve(
        &input(100.0, 0.0, vec![facility("T1", 10.0, 200.0, 0.0)]),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 100.0).abs() < EPS);
    assert!(output.deficit.abs() < EPS);
    assert!((output.coverage - 1.0).abs() < EPS);
}

#[test]
fn reports_deficit_when_capacity_is_insufficient() {
    let output = solve(
        &input(500.0, 0.0, vec![facility("T1", 10.0, 100.0, 0.0)]),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 100.0).abs() < EPS);
    assert!((output.deficit - 400.0).abs() < EPS);
}

#[test]
fn respects_operating_floor() {
    let output = solve(
        &input(10.0, 0.0, vec![facility("T1", 1.0, 50.0, 30.0)]),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 30.0).abs() < EPS);
    assert!((output.ending_inventory - 20.0).abs() < EPS);
}

#[test]
fn lowers_utilization_when_demand_is_below_the_safe_cap() {
    let output = solve(
        &input(40.0, 0.0, vec![facility("T1", 0.2, 200.0, 0.0)]),
        LIMIT,
    )
    .unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 40.0).abs() < EPS);
    assert!(output.ending_inventory.abs() < EPS);
}

#[test]
fn does_not_trade_deficit_for_lower_throughput() {
    let output = solve(
        &input(100.0, 0.0, vec![facility("T1", 1.0, 30.0, 0.0)]),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 30.0).abs() < EPS);
    assert!((output.deficit - 70.0).abs() < EPS);
}

#[test]
fn stays_at_expected_petroleum_when_that_already_clears_deficit() {
    let facilities = vec![facility("T1", 0.2, 200.0, 0.0)];
    let output = solve(
        &input_with_max_petroleum(160.0, 0.0, facilities, 1_000.0),
        LIMIT,
    )
    .unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 160.0).abs() < EPS);
}

#[test]
fn raises_petroleum_above_expected_only_to_clear_deficit() {
    let facilities = vec![facility("T1", 0.2, 200.0, 0.0)];
    let output = solve(
        &input_with_max_petroleum(190.0, 0.0, facilities, 1_000.0),
        LIMIT,
    )
    .unwrap();

    assert!(output.deficit.abs() < EPS);
    assert!((output.production - 190.0).abs() < EPS);
}

#[test]
fn respects_remaining_annual_petroleum_budget() {
    let facilities = vec![facility("T1", 0.2, 200.0, 0.0)];
    let output = solve(
        &input_with_max_petroleum(190.0, 0.0, facilities, 800.0),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 160.0).abs() < EPS);
    assert!((output.deficit - 30.0).abs() < EPS);
}

#[test]
fn rejects_invalid_mathematical_input() {
    let error = solve(
        &input_with_max_petroleum(10.0, 0.0, vec![facility("T1", 0.0, 100.0, 0.0)], 100.0),
        LIMIT,
    )
    .unwrap_err();

    assert!(matches!(error, SolverError::InvalidInput { .. }));
}

#[test]
fn rejects_invalid_petroleum_bounds() {
    let error = solve(
        &input_with_max_petroleum(10.0, 0.0, vec![facility("T1", 1.0, 100.0, 0.0)], -1.0),
        LIMIT,
    )
    .unwrap_err();

    assert!(matches!(error, SolverError::InvalidInput { .. }));
}

#[test]
fn reports_timeout() {
    let error = solve(
        &input(10.0, 0.0, vec![facility("T1", 1.0, 100.0, 0.0)]),
        0.0,
    )
    .unwrap_err();

    assert!(matches!(error, SolverError::Timeout { .. }));
}
