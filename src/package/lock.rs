/**
 * @file lock.rs
 * @brief 锁文件管理 (xy.lock)
 * @description 记录精确的依赖版本，确保可重复构建
 * 
 * xy.lock 示例:
 * ```toml
 * # 此文件由 xy 自动生成，请勿手动编辑
 * 
 * [[package]]
 * name = "std"
 * version = "0.1.0"
 * source = "registry"
 * checksum = "sha256:abc123..."
 * ```
 */

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use super::dependency::Dependency;

/**
 * 锁文件
 */
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LockFile {
    /// 锁文件版本
    version: u32,
    /// 锁定的包
    #[serde(default)]
    pub packages: Vec<LockedPackage>,
}

/**
 * 锁定的包
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LockedPackage {
    /// 包名
    pub name: String,
    /// 精确版本
    pub version: String,
    /// 来源
    pub source: String,
    /// 校验和
    #[serde(default)]
    pub checksum: String,
    /// 依赖
    #[serde(default)]
    pub dependencies: Vec<String>,
}

impl LockFile {
    /**
     * 创建新的锁文件
     */
    pub fn new() -> Self {
        Self {
            version: 1,
            packages: Vec::new(),
        }
    }

    /**
     * 从依赖列表创建锁文件
     */
    pub fn from_dependencies(deps: &[Dependency]) -> Self {
        let packages: Vec<LockedPackage> = deps.iter()
            .map(|dep| {
                let source = match &dep.source {
                    super::dependency::DependencySource::Registry => "registry".to_string(),
                    super::dependency::DependencySource::Git { url, .. } => format!("git:{}", url),
                    super::dependency::DependencySource::Path(p) => format!("path:{}", p.display()),
                    super::dependency::DependencySource::GitHub { user, repo } => format!("github:{}/{}", user, repo),
                };

                LockedPackage {
                    name: dep.name.clone(),
                    version: dep.resolved_version
                        .as_ref()
                        .map(|v| v.to_string())
                        .unwrap_or_else(|| dep.version_req.clone()),
                    source,
                    checksum: String::new(),
                    dependencies: dep.dependencies.iter()
                        .map(|d| d.name.clone())
                        .collect(),
                }
            })
            .collect();

        Self {
            version: 1,
            packages,
        }
    }

    /**
     * 从文件加载
     */
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self, LockError> {
        let content = fs::read_to_string(path.as_ref())
            .map_err(|e| LockError::IoError(e.to_string()))?;
        
        toml::from_str(&content)
            .map_err(|e| LockError::ParseError(e.to_string()))
    }

    /**
     * 保存到文件
     */
    pub fn save<P: AsRef<Path>>(&self, path: P) -> Result<(), LockError> {
        let mut content = String::new();
        content.push_str("# 此文件由 xy 自动生成，请勿手动编辑\n");
        content.push_str(&format!("# 版本: {}\n\n", self.version));

        let toml_content = toml::to_string_pretty(self)
            .map_err(|e| LockError::SerializeError(e.to_string()))?;
        
        content.push_str(&toml_content);

        fs::write(path.as_ref(), content)
            .map_err(|e| LockError::IoError(e.to_string()))?;

        Ok(())
    }

    /**
     * 获取包
     */
    pub fn get_package(&self, name: &str) -> Option<&LockedPackage> {
        self.packages.iter().find(|p| p.name == name)
    }

    /**
     * 检查包是否已锁定
     */
    pub fn has_package(&self, name: &str) -> bool {
        self.packages.iter().any(|p| p.name == name)
    }

    /**
     * 添加包
     */
    pub fn add_package(&mut self, pkg: LockedPackage) {
        // 如果已存在，更新
        if let Some(pos) = self.packages.iter().position(|p| p.name == pkg.name) {
            self.packages[pos] = pkg;
        } else {
            self.packages.push(pkg);
        }
    }

    /**
     * 移除包
     */
    pub fn remove_package(&mut self, name: &str) -> bool {
        if let Some(pos) = self.packages.iter().position(|p| p.name == name) {
            self.packages.remove(pos);
            true
        } else {
            false
        }
    }

    /**
     * 检查是否需要更新
     */
    pub fn needs_update(&self, dependencies: &HashMap<String, String>) -> bool {
        // 检查数量是否匹配
        if self.packages.len() != dependencies.len() {
            return true;
        }

        // 检查每个依赖
        for (name, version) in dependencies {
            if let Some(pkg) = self.get_package(name) {
                if &pkg.version != version {
                    return true;
                }
            } else {
                return true;
            }
        }

        false
    }

    /**
     * 获取依赖图
     */
    pub fn dependency_graph(&self) -> HashMap<String, Vec<String>> {
        let mut graph = HashMap::new();

        for pkg in &self.packages {
            graph.insert(pkg.name.clone(), pkg.dependencies.clone());
        }

        graph
    }
}

/**
 * 锁文件错误
 */
#[derive(Debug, Clone)]
pub enum LockError {
    /// IO 错误
    IoError(String),
    /// 解析错误
    ParseError(String),
    /// 序列化错误
    SerializeError(String),
}

impl std::fmt::Display for LockError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LockError::IoError(e) => write!(f, "IO 错误: {}", e),
            LockError::ParseError(e) => write!(f, "解析错误: {}", e),
            LockError::SerializeError(e) => write!(f, "序列化错误: {}", e),
        }
    }
}

impl std::error::Error for LockError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lock_file() {
        let mut lock = LockFile::new();
        lock.add_package(LockedPackage {
            name: "std".to_string(),
            version: "0.1.0".to_string(),
            source: "registry".to_string(),
            checksum: "abc123".to_string(),
            dependencies: Vec::new(),
        });

        assert!(lock.has_package("std"));
        assert!(!lock.has_package("json"));
    }
}
