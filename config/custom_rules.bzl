# This file includes several macros to easily setup your build system
# The logic in this file is builtool agnostic

# The rule_interfaces.bzl is the file that contains the concrete implementation 
# of the rules for the different buildtools
load(
    "//config/selected_config:rule_interfaces.bzl", 
    "build_system",
    "exports_files_interface",
    "resources_group_interface",
    "objc_library_interface",
    "objc_test_interface",
    "swift_library_interface", 
    "swift_test_interface", 
    "prebuilt_dynamic_framework_interface",
    "application_interface",
    )

load(
    "//config:configs.bzl", 
    "swift_library_compiler_flags",
    )

load(
    "//config:constants.bzl", 
    "SWIFT_VERSION",
    "SWIFT_DEBUG_COMPILER_FLAGS",
    )

load(
    "//config:functions.bzl", 
    "get_basename_without_extension",
    "get_basename",
    "contains_files",
    "get_files",
    )

# Constants
Sources = "Sources"
Tests = "Tests"
AppTests = "AppTests"

swift = "swift"
m = "m"
h = "h"
objc = "objc"

# Target names
def swift_tests_name(name): return name + Tests
def swift_app_tests_name(name): return name + AppTests
def objc_tests_name(name): return name + objc.capitalize() + Tests
def objc_app_tests_name(name): return name + objc.capitalize() + AppTests
def app_name(name): return name + "Application"

# Resource constants
Unbundled = "Unbundled"
Resources = "Resources"
TestResources = "TestResources"

# Macros
def first_party_library(
    deps = [],
    test_deps = [],
    app_test_deps = [],
    swift_version = SWIFT_VERSION,
    host_app = None,
    ):
    # Infer name from the path of the package
    name = get_basename(native.package_name())

    # No compiler flags are allowed when using this macro: 
    # build implementation detais should not be present in the BUILD files
    swift_compiler_flags = []

    _first_party_library(
        name = name,
        deps = deps,
        test_deps = test_deps,
        app_test_deps = app_test_deps,
        swift_compiler_flags = swift_compiler_flags,
        swift_version = swift_version,
        host_app = host_app,
    )

def _first_party_library(
    name,
    deps,
    test_deps,
    app_test_deps,
    swift_compiler_flags,
    swift_version,
    host_app,
    ):
    # Infer name from the path of the package
    name = name or get_basename(native.package_name())

    # The test targets that are created together with this library
    tests = []

    # The test targets can be swift, objc or both
    test_deps = [":" + name] + test_deps
    if contains_files(Tests, swift):
        test_name = swift_tests_name(name)
        tests = tests + [":" + test_name]
        swift_test_interface(
            name = test_name,
            deps = test_deps,
            srcs = get_files(package_name = name, path = Tests, language = swift, extension = swift),
            swift_version = swift_version,
            host_app = None,
        )

    if contains_files(Tests, m):
        test_name = objc_tests_name(name)
        tests = tests + [":" + test_name]
        objc_test_interface(
            name = test_name,
            deps = test_deps,
            srcs = get_files(package_name = name, path = Tests, language = objc, extension = m),
            host_app = None,
        )

    # The app test targets can be swift, objc or both
    app_test_deps = [":" + name] + app_test_deps
    test_resources = _resources(name = name, are_test_resources = True)
    host_app = _create_host_app_if_needed(name, deps, test_resources, host_app)

    if contains_files(AppTests, swift):
        test_name = swift_app_tests_name(name)
        tests = tests + [":" + test_name]
        swift_test_interface(
            name = test_name,
            deps = app_test_deps,
            srcs = get_files(package_name = name, path = AppTests, language = swift, extension = swift),
            swift_version = swift_version,
            host_app = host_app,
        )

    if contains_files(AppTests, m):
        test_name = objc_app_tests_name(name)
        tests = tests + [":" + test_name]
        objc_test_interface(
            name = test_name,
            deps = app_test_deps,
            srcs = get_files(package_name = name, path = AppTests, language = objc, extension = m),
            host_app = host_app,
        )

    # The main target has to be swift or objc, not both
    resources = _resources(name = name, are_test_resources = False)
    if contains_files(Sources, swift):
        swift_library_interface(
            name = name,
            tests = tests,
            srcs = get_files(package_name = name, path = Sources, extension = swift),
            deps = deps,
            swift_compiler_flags = swift_compiler_flags + swift_library_compiler_flags(),
            swift_version = swift_version,
            resources = resources,
        )

    if contains_files(Sources, m):
        objc_library_interface(
            name = name,
            tests = tests,
            srcs = get_files(package_name = name, path = Sources, extension = m, allowed_extensions = [h]),
            headers = get_files(package_name = name, path = Sources, extension = h, allowed_extensions = [m]),
            deps = deps,
            resources = resources,
        )

def _resources(
    name,
    are_test_resources,
    ):
    resources_rules = []
    base_path = TestResources if are_test_resources else Resources

    for bundled in [False, True]:
        path = base_path if bundled else (Unbundled + base_path)

        resources = get_files(name, path)
        if len(resources) > 0:
            resources_rule_name = name + path
            resources_group_interface(
                name = resources_rule_name,
                files = resources,
                bundled = bundled,
            )
            resources_rules = resources_rules + [":" + resources_rule_name]

    return resources_rules

def _create_host_app_if_needed(
    name,
    deps,
    resources,
    host_app,
    ):
    if host_app == None:
        host_app_name = name + "HostApp"
        host_app_lib_name = host_app_name + "Lib"

        swift_library_interface(
            name = host_app_lib_name,
            tests = [],
            srcs = ["//Support/Files:AppDelegate.swift"],
            deps = [":" + name] + deps,
            swift_compiler_flags = SWIFT_DEBUG_COMPILER_FLAGS,
            swift_version = SWIFT_VERSION,
            resources = resources,
        )

        # - strip_unused_symbols: when testing a library inside an app, by default the unused symbols are
        #   removed from the binary. If the binary needs to be tested, the symbols are needed to avoid the
        #   linker error 'ld: symbol(s) not found for architecture ...'
        application_interface(
            name = host_app_name,
            infoplist = "//Support/Files:Info.plist",
            main_target = ":" + host_app_lib_name,
            strip_unused_symbols = False, 
        )
        host_app = ":" + host_app_name

    return host_app

def application(
    infoplist,
    deps = [],
    test_deps = [],
    app_test_deps = [],
    swift_version = SWIFT_VERSION,
    ):
    # Infer name from the path of the package
    name = get_basename(native.package_name())

    # Library with the code of the app
    _first_party_library(
        name = name,
        deps = deps,
        test_deps = test_deps,
        app_test_deps = app_test_deps,
        swift_compiler_flags = [],
        swift_version = swift_version,
        host_app = ":" + app_name(name),
    )

    # The application bundle
    application_interface(
        name = app_name(name),
        infoplist = infoplist,
        main_target = ":" + name,
        strip_unused_symbols = True,
    )

def prebuilt_dynamic_framework(
    path,
    ):
    basename_without_extension = get_basename_without_extension(path)
    prebuilt_dynamic_framework_interface(
        name = basename_without_extension,
        path = path,
    )

def exports_files(
    files,
    ):
    exports_files_interface(
        files = files
    )
