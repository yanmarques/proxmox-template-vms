from templated.vars import hooks_path
from setuptools import setup, find_packages
from setuptools.command import install

import sys
import os


class HookInstallerCommand(install.install):
    def run(self):
        super().run()
        target_path = os.path.join(hooks_path, 'templated-hook')
        self.copy_file('templated-hook', hooks_path)
        os.chmod(target_path, 0o755)


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