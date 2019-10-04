MINIMUM_OS_VERSION = "10.0"
SWIFT_VERSION = "5"
PRODUCT_BUNDLE_IDENTIFIER_PREFIX = "com.example."

# Compiler flags
SWIFT_COMPILER_FLAGS = [
    # Look at the files as a unit instead of separately: compilation is faster
    # See: https://www.skilled.io/u/swiftsummit/swift-with-a-hundred-engineers
    "-whole-module-optimization", 
]
SWIFT_DEBUG_COMPILER_FLAGS = [
    # Enable the DEBUG flag, for using it in macros
    "-DDEBUG",
    # Do not make optimizations: compilation is faster
    "-Onone",   
    # Print debug information
    "-g",
] + SWIFT_COMPILER_FLAGS