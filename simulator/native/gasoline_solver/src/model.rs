use rustler::NifMap;

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct FacilityInput {
    pub id: String,
    pub region: String,
    pub capacity: f64,
    pub floor: f64,
}

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct RegionInput {
    pub id: String,
    pub demand: f64,
    pub landed: f64,
}

#[derive(Debug, Clone, PartialEq, NifMap)]
pub struct SolverInput {
    pub demand: f64,
    pub landed: f64,
    pub regions: Vec<RegionInput>,
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
    pub landed: f64,
    pub excess: f64,
    pub production: f64,
    pub served_demand: f64,
    pub deficit: f64,
    pub coverage: f64,
    pub facilities: Vec<FacilityResult>,
}
