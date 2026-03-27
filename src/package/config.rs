/**
 * @file config.rs
 * @brief 包配置文件解析 (xy.toml)
 * @description 定义项目配置结构，支持 TOML 格式的配置文件
 * 
 * xy.toml 示例:
 * ```toml
 * [package]
 * name = "my-project"
 * version = "0.1.0"
 * edition = "2024"
 * authors = ["作者名 <email@example.com>"]
 * description = "项目描述"
 * license = "MIT"
 * 
 * [dependencies]
 * std = "0.1.0"
 * json = { version = "0.2.0", source = "github:user/repo" }
 * 
 * [dev-dependencies]
 * test-utils = "0.1.0"
 * 
 * [build]
 * target = "native"
 * opt-level = 2
 * ```
 */

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use serde::{Deserialize, Serialize};

/**
 * 包配置文件 (xy.toml)
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageConfig {
    /// 包信息
    pub package: PackageMetadata,
    /// 生产依赖
    #[serde(default)]
    pub dependencies: HashMap<String, DependencySpec>,
    /// 开发依赖
    #[serde(default, rename = "dev-dependencies")]
    pub dev_dependencies: HashMap<String, DependencySpec>,
    /// 构建配置
    #[serde(default)]
    pub build: BuildConfig,
    /// 包仓库配置
    #[serde(default)]
    pub registry: Option<RegistryInfo>,
}

/**
 * 包元数据
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageMetadata {
    /// 包名称 (必须符合命名规范: 小写字母、数字、连字符)
    pub name: String,
    /// 版本号 (语义化版本)
    pub version: String,
    /// 语言版本
    #[serde(default = "default_edition")]
    pub edition: String,
    /// 作者列表
    #[serde(default)]
    pub authors: Vec<String>,
    /// 项目描述
    #[serde(default)]
    pub description: String,
    /// 许可证
    #[serde(default)]
    pub license: String,
    /// 仓库地址
    #[serde(default)]
    pub repository: Option<String>,
    /// 关键词
    #[serde(default)]
    pub keywords: Vec<String>,
    /// 分类
    #[serde(default)]
    pub categories: Vec<String>,
    /// 是否发布
    #[serde(default = "default_publish")]
    pub publish: bool,
    /// 文档地址
    #[serde(default)]
    pub documentation: Option<String>,
    /// 主页地址
    #[serde(default)]
    pub homepage: Option<String>,
    /// README 文件路径
    #[serde(default = "default_readme")]
    pub readme: String,
    /// 排除文件
    #[serde(default)]
    pub exclude: Vec<String>,
    /// 包含文件
    #[serde(default)]
    pub include: Vec<String>,
}

fn default_edition() -> String { "2024".to_string() }
fn default_publish() -> bool { true }
fn default_readme() -> String { "README.md".to_string() }

impl Default for PackageMetadata {
    fn default() -> Self {
        Self {
            name: String::new(),
            version: "0.1.0".to_string(),
            edition: default_edition(),
            authors: Vec::new(),
            description: String::new(),
            license: String::new(),
            repository: None,
            keywords: Vec::new(),
            categories: Vec::new(),
            publish: true,
            documentation: None,
            homepage: None,
            readme: default_readme(),
            exclude: Vec::new(),
            include: Vec::new(),
        }
    }
}

/**
 * 依赖规格
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum DependencySpec {
    /// 简单版本字符串: "依赖名" = "1.0.0"
    Simple(String),
    /// 详细配置: "依赖名" = { version = "1.0.0", ... }
    Detailed(DetailedDependency),
}

/**
 * 详细依赖配置
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetailedDependency {
    /// 版本号
    pub version: String,
    /// 来源 (git, path, registry)
    #[serde(default)]
    pub source: Option<String>,
    /// 特性
    #[serde(default)]
    pub features: Vec<String>,
    /// 可选依赖
    #[serde(default)]
    pub optional: bool,
    /// 默认特性
    #[serde(default = "default_true")]
    pub default_features: bool,
}

fn default_true() -> bool { true }

impl DependencySpec {
    /// 获取版本号
    pub fn version(&self) -> &str {
        match self {
            DependencySpec::Simple(v) => v,
            DependencySpec::Detailed(d) => &d.version,
        }
    }

    /// 获取来源
    pub fn source(&self) -> Option<&str> {
        match self {
            DependencySpec::Simple(_) => None,
            DependencySpec::Detailed(d) => d.source.as_deref(),
        }
    }

    /// 是否可选
    pub fn is_optional(&self) -> bool {
        match self {
            DependencySpec::Simple(_) => false,
            DependencySpec::Detailed(d) => d.optional,
        }
    }
}

/**
 * 构建配置
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BuildConfig {
    /// 目标平台
    #[serde(default = "default_target")]
    pub target: String,
    /// 优化级别 (0-3)
    #[serde(default = "default_opt_level")]
    pub opt_level: u8,
    /// 链接时优化
    #[serde(default)]
    pub lto: bool,
    /// 调试信息
    #[serde(default)]
    pub debug: bool,
    /// 输出目录
    #[serde(default = "default_out_dir")]
    pub out_dir: String,
    /// 源码目录
    #[serde(default = "default_src_dir")]
    pub src_dir: String,
    /// 入口文件
    #[serde(default = "default_entry")]
    pub entry: String,
}

fn default_target() -> String { "native".to_string() }
fn default_opt_level() -> u8 { 2 }
fn default_out_dir() -> String { "dist".to_string() }
fn default_src_dir() -> String { "src".to_string() }
fn default_entry() -> String { "main.xy".to_string() }

impl Default for BuildConfig {
    fn default() -> Self {
        Self {
            target: default_target(),
            opt_level: default_opt_level(),
            lto: false,
            debug: false,
            out_dir: default_out_dir(),
            src_dir: default_src_dir(),
            entry: default_entry(),
        }
    }
}

/**
 * 包仓库信息
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryInfo {
    /// 仓库地址
    pub url: String,
    /// 认证令牌
    #[serde(default)]
    pub token: Option<String>,
}

impl PackageConfig {
    /**
     * 从文件加载配置
     */
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self, ConfigError> {
        let content = fs::read_to_string(path.as_ref())
            .map_err(|e| ConfigError::IoError(e.to_string()))?;
        
        Self::parse(&content)
    }

    /**
     * 解析 TOML 内容
     */
    pub fn parse(content: &str) -> Result<Self, ConfigError> {
        toml::from_str(content)
            .map_err(|e| ConfigError::ParseError(e.to_string()))
    }

    /**
     * 保存到文件
     */
    pub fn save<P: AsRef<Path>>(&self, path: P) -> Result<(), ConfigError> {
        let content = toml::to_string_pretty(self)
            .map_err(|e| ConfigError::SerializeError(e.to_string()))?;
        
        fs::write(path.as_ref(), content)
            .map_err(|e| ConfigError::IoError(e.to_string()))?;
        
        Ok(())
    }

    /**
     * 创建新的包配置
     */
    pub fn new(name: &str) -> Self {
        Self {
            package: PackageMetadata {
                name: name.to_string(),
                ..Default::default()
            },
            dependencies: HashMap::new(),
            dev_dependencies: HashMap::new(),
            build: BuildConfig::default(),
            registry: None,
        }
    }

    /**
     * 添加依赖
     */
    pub fn add_dependency(&mut self, name: &str, spec: DependencySpec) {
        self.dependencies.insert(name.to_string(), spec);
    }

    /**
     * 移除依赖
     */
    pub fn remove_dependency(&mut self, name: &str) -> bool {
        self.dependencies.remove(name).is_some()
    }

    /**
     * 检查依赖是否存在
     */
    pub fn has_dependency(&self, name: &str) -> bool {
        self.dependencies.contains_key(name)
    }

    /**
     * 获取所有依赖
     */
    pub fn all_dependencies(&self) -> Vec<(&String, &DependencySpec)> {
        self.dependencies.iter()
            .chain(self.dev_dependencies.iter())
            .collect()
    }
}

/**
 * 配置错误类型
 */
#[derive(Debug, Clone)]
pub enum ConfigError {
    /// IO 错误
    IoError(String),
    /// 解析错误
    ParseError(String),
    /// 序列化错误
    SerializeError(String),
    /// 验证错误
    ValidationError(String),
}

impl std::fmt::Display for ConfigError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConfigError::IoError(e) => write!(f, "IO 错误: {}", e),
            ConfigError::ParseError(e) => write!(f, "解析错误: {}", e),
            ConfigError::SerializeError(e) => write!(f, "序列化错误: {}", e),
            ConfigError::ValidationError(e) => write!(f, "验证错误: {}", e),
        }
    }
}

impl std::error::Error for ConfigError {}

/**
 * 版本号解析
 */
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    pub pre: Option<String>,
    pub build: Option<String>,
}

impl Version {
    /**
     * 解析版本字符串
     */
    pub fn parse(s: &str) -> Result<Self, ConfigError> {
        let s = s.trim();
        
        // 移除前缀 'v'
        let s = s.strip_prefix('v').unwrap_or(s);
        
        // 分离预发布和构建元数据
        let (version_part, pre) = if let Some(pos) = s.find('-') {
            (&s[..pos], Some(s[pos + 1..].to_string()))
        } else {
            (s, None)
        };
        
        let (version_part, build) = if let Some(pos) = version_part.find('+') {
            (version_part[..pos].to_string(), Some(version_part[pos + 1..].to_string()))
        } else {
            (version_part.to_string(), None)
        };
        
        // 解析主版本号
        let parts: Vec<&str> = version_part.split('.').collect();
        let major = parts.get(0)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        let minor = parts.get(1)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        let patch = parts.get(2)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Ok(Self {
            major,
            minor,
            patch,
            pre,
            build,
        })
    }

    /**
     * 检查版本是否满足要求
     */
    pub fn satisfies(&self, requirement: &str) -> bool {
        // 简化实现：只检查精确匹配和通配符
        if requirement == "*" {
            return true;
        }
        
        if requirement.starts_with('^') {
            // 兼容版本: ^1.2.3 表示 >= 1.2.3 且 < 2.0.0
            if let Ok(req) = Self::parse(&requirement[1..]) {
                return self.major == req.major && 
                       (self.minor > req.minor || 
                        (self.minor == req.minor && self.patch >= req.patch));
            }
        }
        
        if requirement.starts_with('~') {
            // 近似版本: ~1.2.3 表示 >= 1.2.3 且 < 1.3.0
            if let Ok(req) = Self::parse(&requirement[1..]) {
                return self.major == req.major && 
                       self.minor == req.minor && 
                       self.patch >= req.patch;
            }
        }
        
        if requirement.starts_with(">=") {
            if let Ok(req) = Self::parse(&requirement[2..]) {
                return self >= &req;
            }
        }
        
        if requirement.starts_with("<=") {
            if let Ok(req) = Self::parse(&requirement[2..]) {
                return self <= &req;
            }
        }
        
        if requirement.starts_with('>') {
            if let Ok(req) = Self::parse(&requirement[1..]) {
                return self > &req;
            }
        }
        
        if requirement.starts_with('<') {
            if let Ok(req) = Self::parse(&requirement[1..]) {
                return self < &req;
            }
        }
        
        // 精确匹配
        if let Ok(req) = Self::parse(requirement) {
            return self == &req;
        }
        
        false
    }
}

impl std::fmt::Display for Version {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}.{}", self.major, self.minor, self.patch)?;
        if let Some(ref pre) = self.pre {
            write!(f, "-{}", pre)?;
        }
        if let Some(ref build) = self.build {
            write!(f, "+{}", build)?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parse() {
        let v = Version::parse("1.2.3").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
    }

    #[test]
    fn test_version_satisfies() {
        let v = Version::parse("1.2.3").unwrap();
        assert!(v.satisfies("^1.0.0"));
        assert!(v.satisfies("~1.2.0"));
        assert!(!v.satisfies("^2.0.0"));
    }

    #[test]
    fn test_config_parse() {
        let toml = r#"
[package]
name = "test-project"
version = "0.1.0"

[dependencies]
std = "0.1.0"
"#;
        let config = PackageConfig::parse(toml).unwrap();
        assert_eq!(config.package.name, "test-project");
        assert!(config.has_dependency("std"));
    }
}
