use gasoline_solver::{solve, FacilityInput, FacilityResult, RegionInput, SolverInput};

const LIMIT: f64 = 5.0;
const EPS: f64 = 1e-6;

fn facility(id: &str, capacity: f64, floor: f64) -> FacilityInput {
    FacilityInput {
        id: id.into(),
        region: "all".into(),
        capacity,
        floor,
    }
}

fn input(demand: f64, landed: f64, facilities: Vec<FacilityInput>) -> SolverInput {
    SolverInput {
        demand,
        landed,
        regions: vec![RegionInput {
            id: "all".into(),
            demand,
            landed,
        }],
        facilities,
    }
}

fn production(facilities: &[FacilityResult]) -> f64 {
    facilities.iter().map(|plant| plant.allocated).sum()
}

fn allocated(facilities: &[FacilityResult], id: &str) -> f64 {
    facilities
        .iter()
        .find(|plant| plant.id == id)
        .unwrap()
        .allocated
}

#[test]
fn solves_normal_allocation() {
    let output = solve(&input(100.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 100.0).abs() < EPS);
}

#[test]
fn reports_deficit_when_capacity_is_insufficient() {
    let output = solve(&input(500.0, 0.0, vec![facility("T1", 100.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 100.0).abs() < EPS);
}

#[test]
fn respects_operating_floor() {
    let output = solve(&input(10.0, 0.0, vec![facility("T1", 50.0, 30.0)]), LIMIT).unwrap();

    assert!((production(&output) - 30.0).abs() < EPS);
}

#[test]
fn lowers_utilization_when_demand_is_below_the_safe_cap() {
    let output = solve(&input(40.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 40.0).abs() < EPS);
}

#[test]
fn fills_a_small_plant_when_the_large_one_is_at_cap() {
    let output = solve(
        &input(
            100.0,
            0.0,
            vec![facility("BIG", 50.0, 0.0), facility("SMALL", 30.0, 0.0)],
        ),
        LIMIT,
    )
    .unwrap();

    assert!((production(&output) - 80.0).abs() < EPS);
    assert!((allocated(&output, "BIG") - 50.0).abs() < EPS);
    assert!((allocated(&output, "SMALL") - 30.0).abs() < EPS);
}

#[test]
fn uses_a_small_plant_up_to_its_cap_when_demand_remains() {
    let output = solve(&input(100.0, 0.0, vec![facility("T1", 30.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 30.0).abs() < EPS);
}

#[test]
fn keeps_every_plant_running_when_one_could_cover_demand() {
    let output = solve(
        &input(
            100.0,
            0.0,
            vec![facility("BIG", 500.0, 0.0), facility("SMALL", 80.0, 20.0)],
        ),
        LIMIT,
    )
    .unwrap();

    assert!((production(&output) - 100.0).abs() < EPS);
    assert!(allocated(&output, "SMALL") + EPS >= 20.0);
}

#[test]
fn stays_at_demand_when_that_already_clears_deficit() {
    let output = solve(&input(160.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 160.0).abs() < EPS);
}

#[test]
fn uses_plant_cap_when_demand_exceeds_it() {
    let output = solve(&input(190.0, 0.0, vec![facility("T1", 200.0, 0.0)]), LIMIT).unwrap();

    assert!((production(&output) - 190.0).abs() < EPS);
}
