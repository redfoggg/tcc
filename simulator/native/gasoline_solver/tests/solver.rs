use gasoline_solver::{solve, FacilityInput, SolverError, SolverInput};

const LIMIT: f64 = 5.0;
const EPS: f64 = 1e-6;

fn facility(id: &str, reference_yield: f64, capacity: f64, floor: f64) -> FacilityInput {
    FacilityInput {
        id: id.into(),
        reference_yield,
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
fn carries_surplus_as_inventory() {
    let output = solve(
        &input(
            10.0,
            0.0,
            vec![
                facility("cheap", 1_000_000.0, 50.0, 30.0),
                facility("costly", 1.0, 100.0, 0.0),
            ],
        ),
        LIMIT,
    )
    .unwrap();

    assert!((output.production - 30.0).abs() < EPS);
    assert!((output.ending_inventory - 20.0).abs() < EPS);
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
fn minimizes_petroleum_throughput_after_pinning_minimal_deficit() {
    let output = solve(
        &input(
            50.0,
            0.0,
            vec![
                facility("efficient", 1.0, 100.0, 0.0),
                facility("inefficient", 0.1, 100.0, 0.0),
            ],
        ),
        LIMIT,
    )
    .unwrap();

    assert!(output.deficit.abs() < EPS);

    let efficient = output
        .facilities
        .iter()
        .find(|f| f.id == "efficient")
        .unwrap();
    let inefficient = output
        .facilities
        .iter()
        .find(|f| f.id == "inefficient")
        .unwrap();

    assert!((efficient.allocated - 50.0).abs() < EPS);
    assert!(inefficient.allocated.abs() < EPS);
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
fn rejects_invalid_mathematical_input() {
    let error = solve(
        &input(10.0, 0.0, vec![facility("T1", 0.0, 100.0, 0.0)]),
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
