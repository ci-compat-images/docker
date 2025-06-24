#### Global variables #########################################################
variable "REGISTRY" { default = "ci-compat-images" }

variable "PLATFORMS" { default = ["linux/amd64", "linux/arm64"] }

variable "UBUNTU_VERSIONS" {
    default = ["20.04", "22.04", "24.04"]
}

variable "PHP_COMPAT" {
    default = {
        "7.3" = { version = "7.3.33", ubuntu = ["20.04"] }
        "7.4" = { version = "7.4.33", ubuntu = ["20.04"] }
        "8.1" = { version = "8.1.32", ubuntu = ["22.04", "24.04"] }
        "8.2" = { version = "8.2.28", ubuntu = ["22.04", "24.04"] }
        "8.3" = { version = "8.3.22", ubuntu = ["22.04", "24.04"] }
        "8.4" = { version = "8.4.8",  ubuntu = ["22.04", "24.04"] }
    }
}

variable "NODE_COMPAT" {
    default = {
        "16" = { version = "16.20.2", ubuntu = ["20.04", "22.04", "24.04"] }
        "18" = { version = "18.20.8", ubuntu = ["20.04", "22.04", "24.04"] }
        "20" = { version = "20.19.2", ubuntu = ["22.04", "24.04"] }
        "22" = { version = "22.16.0", ubuntu = ["22.04", "24.04"] }
        "24" = { version = "24.2.0",  ubuntu = ["22.04", "24.04"] }
    }
}

variable "COMPOSER_VERSION" { default = "2.8.4" }
variable "YARN_VERSION" { default = "1.22.22" }
variable "PNPM_VERSION" { default = "9.1.3" }

# Default versions for "latest" tags
variable "DEFAULT_PHP" { default = "8.3" }
variable "DEFAULT_NODE" { default = "22" }
variable "DEFAULT_UBUNTU" { default = "24.04" }

################ Helper functions #############################################
function "dash" {
    params = [str]
    result = replace(str, ".", "-")
}

function "php_matrix" {
    params = []
    result = flatten([
        for minor, config in PHP_COMPAT : [
            for ubuntu in config.ubuntu : {
                minor   = minor
                version = config.version
                ubuntu  = ubuntu
            }
        ]
    ])
}

function "node_matrix" {
    params = []
    result = flatten([
        for minor, config in NODE_COMPAT : [
            for ubuntu in config.ubuntu : {
                minor   = minor
                version = config.version
                ubuntu  = ubuntu
            }
        ]
    ])
}

function "php_node_matrix" {
    params = []
    result = flatten([
        for php_minor, php_config in PHP_COMPAT : [
            for node_minor, node_config in NODE_COMPAT : [
                for ubuntu in setintersection(php_config.ubuntu, node_config.ubuntu) : {
                    php_minor    = php_minor
                    php_version  = php_config.version
                    node_minor   = node_minor
                    node_version = node_config.version
                    ubuntu       = ubuntu
                }
            ]
        ]
    ])
}

#### Common settings ##########################################################
target "_common" {
    # output    = ["type=docker"]
    platforms = PLATFORMS
}

#### Base #####################################################################
target "base" {
    name = "base-${dash(ubuntu)}"
    matrix = {
        ubuntu = UBUNTU_VERSIONS
    }

    inherits   = ["_common"]
    dockerfile = "./Dockerfile.base"
    args       = { UBUNTU_VERSION = ubuntu }
    tags       = ["${REGISTRY}/ci-base:${ubuntu}"]
}

#### PHP ######################################################################
target "php" {
    name = "php-${dash(item.minor)}-${dash(item.ubuntu)}"
    matrix = {
        item = php_matrix()
    }
    
    inherits   = ["_common"]
    context    = "./php"
    dockerfile = "./Dockerfile"
    contexts = {
        base = "target:base-${dash(item.ubuntu)}"
    }
    args = {
        PHP_VERSION      = item.version
        PHP_MINOR        = item.minor
        COMPOSER_VERSION = COMPOSER_VERSION
    }
    
    tags = concat(
        ["${REGISTRY}/ci-php:${item.minor}-ubuntu${item.ubuntu}"],
        item.minor == DEFAULT_PHP && item.ubuntu == DEFAULT_UBUNTU ? 
            ["${REGISTRY}/ci-php:latest"] : []
    )
}

#### Node #####################################################################
target "node" {
    name = "node-${dash(item.minor)}-${dash(item.ubuntu)}"
    matrix = {
        item = node_matrix()
    }
    
    inherits   = ["_common"]
    dockerfile = "./Dockerfile.node"
    contexts = {
        base = "target:base-${dash(item.ubuntu)}"
    }
    args = {
        NODE_VERSION = item.version
        YARN_VERSION = YARN_VERSION
        PNPM_VERSION = PNPM_VERSION
    }
    
    tags = concat(
        ["${REGISTRY}/ci-node:${item.minor}-ubuntu${item.ubuntu}"],
        item.minor == DEFAULT_NODE && item.ubuntu == DEFAULT_UBUNTU ? 
            ["${REGISTRY}/ci-node:latest"] : []
    )
}

#### PHP-Node Combined ########################################################
target "php-node" {
    name = "php-node-${dash(item.php_minor)}-${dash(item.node_minor)}-${dash(item.ubuntu)}"
    matrix = {
        item = php_node_matrix()
    }
    
    inherits   = ["_common"]
    dockerfile = "./Dockerfile.node"
    contexts = {
        base = "target:php-${dash(item.php_minor)}-${dash(item.ubuntu)}"
    }
    args = {
        NODE_VERSION = item.node_version
        YARN_VERSION = YARN_VERSION
        PNPM_VERSION = PNPM_VERSION
    }
    
    tags = concat(
        ["${REGISTRY}/ci-php${item.php_minor}-node${item.node_minor}:ubuntu${item.ubuntu}"],
        item.php_minor == DEFAULT_PHP && 
        item.node_minor == DEFAULT_NODE && 
        item.ubuntu == DEFAULT_UBUNTU ? 
            ["${REGISTRY}/ci-php-node:latest"] : []
    )
}

#### Groups ###################################################################
group "default" { 
    targets = ["php-node"] 
}

group "all" { 
    targets = ["base", "php", "node", "php-node"] 
}

# Additional custom groups
group "latest" {
    targets = [
        "php-${dash(DEFAULT_PHP)}-${dash(DEFAULT_UBUNTU)}",
        "node-${dash(DEFAULT_NODE)}-${dash(DEFAULT_UBUNTU)}",
        "php-node-${dash(DEFAULT_PHP)}-${dash(DEFAULT_NODE)}-${dash(DEFAULT_UBUNTU)}"
    ]
}

# Debug: Print matrix sizes
function "debug_info" {
    params = []
    result = {
        php_combinations = length(php_matrix())
        node_combinations = length(node_matrix())
        php_node_combinations = length(php_node_matrix())
        php_ubuntu_compat = PHP_COMPAT
        node_ubuntu_compat = NODE_COMPAT
    }
}