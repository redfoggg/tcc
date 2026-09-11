#[derive(Debug, Clone, PartialEq)]
pub enum SolverError {
    SolverFailure { reason: String },
    Timeout { reason: String },
}
