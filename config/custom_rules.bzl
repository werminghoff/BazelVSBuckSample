# This file includes several macros to easily setup your build system
# The logic in this file is builtool agnostic

# The rule_interfaces.bzl is the file that contains the concrete implementation 
# of the rules for the different buildtools
load("//config/selected_config:rule_interfaces.bzl", "swift_library_target", "swift_test_target")

# Constants
srcs_glob = ["Sources/**/*.swift"]
test_srcs_glob = ["Tests/**/*.swift"]

# Functions
def generate_test_name(name): 
    return name + "Tests"

# Macros
def first_party_library(
    name,
    deps = [],
    test_deps = [],
    ):
    srcs = native.glob(srcs_glob)
    swift_library_target(
        name = name,
        srcs = srcs,
        deps = deps,
    )

    test_name = generate_test_name(name)
    test_srcs = native.glob(test_srcs_glob)
    swift_test_target(
        name = test_name,
        deps = [":" + name] + test_deps,
        srcs = test_srcs,
    )