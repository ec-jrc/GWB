Installation
============

GWB is completely self-contained and fully functional in its own directory. 
Installation packages are available on the 
`project homepage <https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/>`_. 
To ensure package integrity, compare the md5sum against the 
`GWB md5sum list <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_md5sums.txt>`_. 
GWB requires :code:`gdal`, :code:`xvfb`, :code:`time`, :code:`libgomp1` and can 
be installed in either:

* **System-wide mode:** installation requires root-privileges. GWB will be available to 
  all system users.
* **Standalone mode:** installation per user and *not* requiring root-privileges. GWB is 
  available for the user only and the standalone directory GWB can be used in any 
  user-accessible location or any external device, provided :code:`gdal`, 
  :code:`xvfb`, :code:`time`, :code:`libgomp1` is installed in the system.


System-wide mode:
-----------------

As root, install GWB into the updated current version of your operating system 
by using one of the following options:

* PCLinuxOS: Open Synaptic and search for/install: :code:`GWB`
* Fedora: Download the package 
  `GWB-Fedora.x86_64.rpm <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB-Fedora.x86_64.rpm>`_ 
  to a local directory. From a root-terminal enter the command:
  
  .. code-block:: console

    $ yum install <full path to the downloaded GWB-Fedora.x86_64.rpm>
  
  
* Mageia: Download the package 
  `GWB-Mageia.x86_64.rpm <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB-Mageia.x86_64.rpm>`_ 
  to a local directory. From a root-terminal enter the command: 
  
  .. code-block:: console

    $ urpmi <full path to the downloaded GWB-Mageia.x86_64.rpm>
  
* Suse: Download the package 
  `GWB-Suse.x86_64.rpm <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB-Suse.x86_64.rpm>`_ 
  to a local directory. From a root-terminal enter the command: 
  
  .. code-block:: console

    $ zypper install --allow-unsigned-rpm <full path to the downloaded GWB-Suse.x86_64.rpm> 
  
* Debian/\*buntu: Download the package 
  `gwb_amd64.deb <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/gwb_amd64.deb>`_ to a local 
  directory. From a root-terminal enter the command: 
  
  .. code-block:: console

    $ apt install <full path to the downloaded gwb_amd64.deb>
  
* Other Linux distributions: Download the generic installer 
  `GWB_linux64.run <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_linux64.run>`_ to a 
  local directory. From a *regular-user* (non root!) terminal enter the command: 
  
  .. code-block:: console

    $ chmod u+x GWB_linux64.run
    $ ./GWB_linux64.run

  and follow the instructions. The installer creates the new directory :code:`GWB<version>` 
  providing the standalone directory :code:`GWB` and system installation scripts.
  From a root-terminal in this new directory :code:`GWB<version>` enter the command:

  .. code-block:: console

    $ ./installGWB.sh

  The script will copy the standalone directory :code:`GWB` under :code:`/opt/` and setup 
  symlinks to each GWB-module in :code:`/usr/bin/`. 
  
.. note::

   CentOS 7 requires the additional installation of :code:`gdal-python` 


Standalone mode:
----------------

From a *regular-user* (non-root!) account:

* Download the generic installer 
  `GWB_linux64.run <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_linux64.run>`_ to 
  your :code:`$HOME` account
* Open a terminal, make the installer executable, and run it using the command: 

  .. code-block:: console

    $ chmod u+x GWB_linux64.run
    $ ./GWB_linux64.run

A local copy of GWB is now installed in :code:`$HOME/GWB<version>/GWB/`. To uninstall, 
simply delete the directory :code:`$HOME/GWB<version>`.



Upgrade/Uninstall:
------------------

Note that support will be provided for the **uptodate version of GWB only**. The command: 

.. code-block:: console

  $ GWB_check4updates

will show the installed version of GWB and check for/list a potential newer version of GWB.

To upgrade to a newer version, or to uninstall GWB, please follow the distribution-specific 
instructions below:

* PCLinuxOS: open the package manager Synaptic to find/upgrade to a newer version of GWB, 
  or to uninstall GWB.
* rpm-distributions: download any newer version of GWB from the 
  `project homepage <https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/>`_. Then use 
  your distribution-specific command line package management tool to upgrade to the newer
  version. To uninstall GWB, use your distribution-specific command line package 
  management tool.
* deb-distributions: from a root-terminal, use the command:
  
  .. code-block:: console
  
    $ /opt/GWB/tools/GWBupdate_deb.sh
  
  to automatically download and upgrade to the latest version of GWB. To uninstall GWB, 
  use the command:
  
  .. code-block:: console
  
    $ apt remove gwb
  
* If GWB was installed via the generic installer: open a root-terminal in the 
  directory :code:`GWB<version>` and enter the command:

  .. code-block:: console
  
    $ ./uninstallGWB.sh

