import os
from setuptools import setup

about = {}
here = os.path.abspath(os.path.dirname(__file__))

with open(file=os.path.join(here, "diff_json", "__version__.py"), mode="r", encoding="utf-8") as f:
    exec(f.read(), about)

setup(
    name=about["__title__"],
    version=about["__version__"],
    description=about["__description__"],
    author=about["__author__"],
    author_email=about["__author_email__"],
    packages=["diff_json"],
    package_dir={"diff_json": "diff_json"}
)
