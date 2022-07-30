import sys

from setuptools import find_packages
from setuptools import setup

assert sys.version_info[0] == 3 and sys.version_info[1] >= 6, "Global Notification System (Hive Blockchain) requires Python 3.6 or newer"

setup(
    name='hive_gns',
    version='0.1.0',
    description='Global notification system for dApps on the Hive Blockchain.',
    long_description=open('README.md', 'r', encoding='UTF-8').read(),
    packages=find_packages(exclude=['scripts']),
    install_requires=[
        'requests',
        'psycopg2-binary',
        'fastapi',
        'uvicorn'
    ],
    entry_points = {
        'console_scripts': [
            'hive_gns = hive_gns.run_hive_gns:run'
        ]
    }
)
