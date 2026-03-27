/**
 * @file mod.rs
 * @brief CCAS 语义分析模块
 */

pub mod sema;
pub mod type_inference;

pub use sema::{SemanticAnalyzer, analyze};
pub use type_inference::{TypeInferenceEngine, InferenceResult};
