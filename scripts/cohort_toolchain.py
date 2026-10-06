"""Use the stock cohort compiler, independently of updater-shell libraries."""
import os


def compiler_args():
    compiler = os.environ.get("COHORT_GHC")
    package_tool = os.environ.get("COHORT_GHC_PKG")
    if not compiler or not package_tool:
        raise SystemExit("Run cohort solves in nix develop .#cohort-inventory; stock compiler paths are required.")
    return ["--with-compiler=" + compiler, "--with-hc-pkg=" + package_tool]


def compiler_environment():
    environment = os.environ.copy()
    environment.pop("GHC_PACKAGE_PATH", None)
    environment.pop("GHC_ENVIRONMENT", None)
    return environment
