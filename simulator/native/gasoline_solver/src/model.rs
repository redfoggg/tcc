use rustler::NifMap;

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct FacilityInput {
    pub id: String,
    pub capacity: f64,
    pub floor: f64,
}

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct SolverInput {
    pub demand: f64,
    pub initial_inventory: f64,
    pub facilities: Vec<FacilityInput>,
}

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct FacilityResult {
    pub id: String,
    pub allocated: f64,
    pub active: bool,
}

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct SolverOutput {
    pub demand: f64,
    pub starting_inventory: f64,
    pub ending_inventory: f64,
    pub production: f64,
    pub served_demand: f64,
    pub deficit: f64,
    pub coverage: f64,
    pub facilities: Vec<FacilityResult>,
}
