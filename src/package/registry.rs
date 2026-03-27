/**
 * @file registry.rs
 * @brief 包仓库管理
 * @description 实现包仓库的注册、搜索、下载等功能
 */

use std::collections::HashMap;
use std::path::PathBuf;
use std::fs;

use serde::{Deserialize, Serialize};

/**
 * 包仓库配置
 */
#[derive(Debug, Clone)]
pub struct RegistryConfig {
    /// 仓库名称
    pub name: String,
    /// 仓库地址
    pub url: String,
    /// 认证令牌
    pub token: Option<String>,
    /// 是否默认仓库
    pub default: bool,
}

impl Default for RegistryConfig {
    fn default() -> Self {
        Self {
            name: "官方仓库".to_string(),
            url: "https://registry.xuanyu-lang.org".to_string(),
            token: None,
            default: true,
        }
    }
}

/**
 * 包仓库
 */
#[derive(Debug, Clone)]
pub struct PackageRegistry {
    /// 配置
    config: RegistryConfig,
    /// 本地缓存目录
    cache_dir: PathBuf,
    /// 包索引
    index: HashMap<String, PackageIndex>,
}

/**
 * 包索引信息
 */
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageIndex {
    /// 包名
    pub name: String,
    /// 描述
    pub description: String,
    /// 最新版本
    pub latest_version: String,
    /// 所有版本
    pub versions: Vec<String>,
    /// 下载次数
    pub downloads: u64,
    /// 作者
    pub authors: Vec<String>,
    /// 关键词
    pub keywords: Vec<String>,
    /// 依赖
    pub dependencies: HashMap<String, String>,
}

/**
 * 包搜索结果
 */
#[derive(Debug, Clone)]
pub struct SearchResult {
    /// 包名
    pub name: String,
    /// 版本
    pub version: String,
    /// 描述
    pub description: String,
    /// 下载次数
    pub downloads: u64,
}

impl PackageRegistry {
    /**
     * 创建新的包仓库
     */
    pub fn new(config: RegistryConfig, cache_dir: PathBuf) -> Self {
        Self {
            config,
            cache_dir,
            index: HashMap::new(),
        }
    }

    /**
     * 初始化仓库
     */
    pub fn init(&mut self) -> Result<(), RegistryError> {
        // 创建缓存目录
        fs::create_dir_all(&self.cache_dir)?;

        // 加载本地索引
        self.load_local_index()?;

        Ok(())
    }

    /**
     * 加载本地索引
     */
    fn load_local_index(&mut self) -> Result<(), RegistryError> {
        let index_file = self.cache_dir.join("index.json");

        if index_file.exists() {
            let content = fs::read_to_string(&index_file)?;
            self.index = serde_json::from_str(&content)
                .unwrap_or_default();
        }

        Ok(())
    }

    /**
     * 保存本地索引
     */
    fn save_local_index(&self) -> Result<(), RegistryError> {
        let index_file = self.cache_dir.join("index.json");
        let content = serde_json::to_string_pretty(&self.index)
            .map_err(|e| RegistryError::IoError(e.to_string()))?;
        fs::write(&index_file, content)?;

        Ok(())
    }

    /**
     * 搜索包
     */
    pub fn search(&self, query: &str, limit: usize) -> Vec<SearchResult> {
        let query_lower = query.to_lowercase();
        let mut results: Vec<SearchResult> = self.index.values()
            .filter(|pkg| {
                pkg.name.to_lowercase().contains(&query_lower) ||
                pkg.description.to_lowercase().contains(&query_lower) ||
                pkg.keywords.iter().any(|k| k.to_lowercase().contains(&query_lower))
            })
            .map(|pkg| SearchResult {
                name: pkg.name.clone(),
                version: pkg.latest_version.clone(),
                description: pkg.description.clone(),
                downloads: pkg.downloads,
            })
            .collect();

        // 按下载次数排序
        results.sort_by(|a, b| b.downloads.cmp(&a.downloads));
        results.truncate(limit);

        results
    }

    /**
     * 获取包信息
     */
    pub fn get_package(&self, name: &str) -> Option<&PackageIndex> {
        self.index.get(name)
    }

    /**
     * 发布包
     */
    pub fn publish(&mut self, pkg: PackageIndex) -> Result<(), RegistryError> {
        // 检查包名是否已存在
        if let Some(existing) = self.index.get(&pkg.name) {
            // 检查版本是否已存在
            if existing.versions.contains(&pkg.latest_version) {
                return Err(RegistryError::VersionExists(pkg.name, pkg.latest_version));
            }
        }

        // 添加到索引
        self.index.insert(pkg.name.clone(), pkg);

        // 保存索引
        self.save_local_index()?;

        Ok(())
    }

    /**
     * 下载包
     */
    pub fn download(&self, name: &str, version: &str) -> Result<PathBuf, RegistryError> {
        let pkg_dir = self.cache_dir.join("packages").join(name).join(version);

        if pkg_dir.exists() {
            return Ok(pkg_dir);
        }

        // 创建目录
        fs::create_dir_all(&pkg_dir)?;

        // TODO: 从远程仓库下载

        println!("[下载] {} v{}", name, version);

        Ok(pkg_dir)
    }

    /**
     * 获取仓库 URL
     */
    pub fn url(&self) -> &str {
        &self.config.url
    }

    /**
     * 获取缓存目录
     */
    pub fn cache_dir(&self) -> &PathBuf {
        &self.cache_dir
    }
}

/**
 * 仓库错误
 */
#[derive(Debug, Clone)]
pub enum RegistryError {
    /// 网络错误
    NetworkError(String),
    /// 包不存在
    PackageNotFound(String),
    /// 版本已存在
    VersionExists(String, String),
    /// 认证失败
    AuthFailed(String),
    /// IO 错误
    IoError(String),
}

impl std::fmt::Display for RegistryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RegistryError::NetworkError(e) => write!(f, "网络错误: {}", e),
            RegistryError::PackageNotFound(name) => write!(f, "包不存在: {}", name),
            RegistryError::VersionExists(name, version) => {
                write!(f, "版本已存在: {} v{}", name, version)
            }
            RegistryError::AuthFailed(e) => write!(f, "认证失败: {}", e),
            RegistryError::IoError(e) => write!(f, "IO 错误: {}", e),
        }
    }
}

impl std::error::Error for RegistryError {}

impl From<std::io::Error> for RegistryError {
    fn from(e: std::io::Error) -> Self {
        RegistryError::IoError(e.to_string())
    }
}
