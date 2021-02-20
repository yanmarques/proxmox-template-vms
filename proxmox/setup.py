from templated.vars import hooks_storage
from setuptools import setup, find_packages
from setuptools.command import install

import sys


class HookInstallerCommand(install.install):
    def run(self):
        super().run()
        self.copy_file('templated-hook', hooks_storage)


setup(name='proxmox-templated',
      version='0.0.1',
      license='BSD (3 clause)',
      description='',
      author='Yan Marques de Cerqueira',
      author_email='marques_yan@outlook.com',
      url='https://github.com/yanmarques/proxmox-template-vms/',
      classifiers=[
          'Intended Audience :: End Users/Desktop',
      ],
      entry_points={
            'console_scripts': [
                'templated=templated.cli:main',
            ],
      },
      packages=find_packages(),
      python_requires='>=3',
      cmdclass={
          'install': HookInstallerCommand,
      },
     )