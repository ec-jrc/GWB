"""Build the documentation in isolated environment

The nox run are build in isolated environment that will be stored in .nox.
To force the venv update, remove the .nox/xxx folder.
"""

import nox

nox.options.envdir = "../.nox"


@nox.session(name="docs", reuse_venv=True)
def docs(session):
    """Build the documentation."""
    session.install("-r", "requirements.txt")
    builder = session.posargs[0] if len(session.posargs) > 0 else "html"
    session.run("sphinx-build", "-b", builder, "./", f"_build/{builder}")
