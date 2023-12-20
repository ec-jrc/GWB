"""Configuration file for the Sphinx documentation builder.

For the full list of built-in configuration values, see the documentation:
https://www.sphinx-doc.org/en/master/usage/configuration.html
"""

# -- Project information -----------------------------------------------------

project = "GWB"
copyright = "European Union, 2024, Peter Vogt"
author = "Vogt Peter"
release = "1.9.4"

# -- General configuration ---------------------------------------------------

extensions = []

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]


# -- Options for HTML output -------------------------------------------------

html_theme = "pydata_sphinx_theme"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_favicon = "https://forest.jrc.ec.europa.eu/static/forest/images/logos/eu/favicon.ico"
html_sidebars = {"index": []}
html_context = {
    "github_user": "ec-jrc",
    "github_repo": "GWB",
    "github_version": "main",
    "doc_path": "docs",
    "default_mode": "light",
}

# -- Option for the pydata-sphinx-theme ----------------------------------------

html_theme_options = {
    "logo": {
        "text": "GWB",
        "image_light": "https://forest.jrc.ec.europa.eu/static/forest/images/logos/eu/logo-ec--en.svg",
        "image_dark": "https://forest.jrc.ec.europa.eu/static/forest/images/logos/eu/logo-ec--en.svg",
    },
    "icon_links": [
        {
            "name": "GitHub",
            "url": "https://github.com/ec-jrc/GWB",
            "icon": "fa-brands fa-github",
        },
    ],
    "use_edit_page_button": True,
}