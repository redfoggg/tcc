use good_lp::{default_solver, variable, variables, Solution, SolverModel};

fn main() {
    // 1. Decision variables (volumes in m^3)
    let mut vars = variables!();
    let replan_to_ba = vars.add(variable().min(0.0).max(40_000.0)); // REPLAN volume to Bahia
    let reduc_to_ba = vars.add(variable().min(0.0).max(20_000.0)); // REDUC volume to Bahia
    let import_ba = vars.add(variable().min(0.0)); // Imports as last resort

    // 2. Cost parameters (distance / freight / effort)
    let reduc_cost_ba = 150.0; // Shorter sea route
    let replan_cost_ba = 250.0; // Longer/more expensive route
    let import_cost_ba = 1000.0; // High penalty to avoid imports

    // 3. OBJECTIVE: minimize total supply cost
    let objective = (reduc_to_ba * reduc_cost_ba)
        + (replan_to_ba * replan_cost_ba)
        + (import_ba * import_cost_ba);

    // 4. Solve (Highs) with 2025 physical constraints
    let solution = vars
        .minimise(&objective)
        .using(default_solver) // Requires the "highs" feature in Cargo.toml
        // Constraint 1: Bahia demand (e.g. 50,000 m^3)
        .with((replan_to_ba + reduc_to_ba + import_ba).eq(50_000.0))
        .solve()
        .expect("Failed to find an optimal solution");

    // 5. Results
    println!(
        "Optimized total logistics cost: {}",
        solution.eval(&objective)
    );
    println!("Shipment REDUC -> BA: {}", solution.value(reduc_to_ba));
    println!("Shipment REPLAN -> BA: {}", solution.value(replan_to_ba));
    println!("Required imports: {}", solution.value(import_ba));
}
