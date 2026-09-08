#[derive(Debug, Clone, PartialEq)]
pub enum SolverError {
    InvalidInput { reason: String },
    SolverFailure { reason: String },
    Timeout { reason: String },
}
