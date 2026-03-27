/**
 * @file mod.rs
 * @brief 玄语包管理器 (cargo.xy)
 * @description 提供项目创建、依赖管理、构建、测试、发布等功能
 * 
 * 功能特性:
 * - 项目初始化
 * - 依赖管理
 * - 项目构建
 * - 运行程序
 * - 测试执行
 * - 包发布
 * - 包搜索
 * - 包安装
 */

mod config;
mod dependency;
mod commands;
mod registry;
mod lock;

pub use config::{PackageConfig, PackageMetadata};
pub use dependency::{Dependency, DependencyResolver};
pub use commands::{PackageManager, run_package_command};
pub use registry::{PackageRegistry, RegistryConfig};
pub use lock::LockFile;
