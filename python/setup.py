from setuptools import setup, find_packages

setup(
    name='brainframe',
    version='0.0.1',
    description='BrainFrame - Zettelkasten management tools',
    author='Michael J. Pedersen',
    author_email='m.pedersen@icelus.org',
    url='https://github.com/pedersen/brainframe',
    packages=find_packages(),
    include_package_data=True,
    zip_safe=True,
    license="GPLv3",
    tests_require=[
    ],
    setup_requires=[
    ],
    install_requires=[
    ],
    extras_require={
    },
    entry_points={
        'console_scripts': [
            'brainframe = brainframe.repl:repl'
        ]
    }
)
