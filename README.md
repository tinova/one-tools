
OpenNebula CLI Tools
====================

This a collection of scripts useful for OpenNebula administrators. Their aim is
to improve the user experience in the shell with simple, short and elegant
scripts that use the power and simplicity of OpenNebula's CLI commands.

Contributions, hacks, ideas, improvements are more than welcome!

Commands
--------

- [__onelog__](#onelog): Displays OpenNebula logs.
- [__oneinstantiate__](#oneinstantiate): Instantiates template with a name.
- [__onedeploy__](#onedeploy): Creates and deploys instantaneously a Virtual Machine.
- [__onereport__](#onereport): Displays a summary of running VMs.
- [__onessh__](#onessh): SSH's into a running VM.
- [__onevnc__](#onevnc): Opens the VNC console of a running VM.
- [__oneirb__](#oneirb): Opens an IRB session with all the OpenNebula libraries.
- [__oneconf__](#oneconf): Modifies the default configuration files.
- [__onebootstrap__](#onebootstrap): Creates initial OpenNebula resources.

onelog
------

If no argument is passed it displays `oned.log`. If a `VM_ID` is passed as a
paramenter, the vm.log is displayed:

    $ onelog
    [ opens oned.log in your $PAGER ]
    $ onelog 10
    [ opens the vm.log for VM 10 in your $PAGER ]

oneinstantiate
--------------

A wrapper for the `onetemplate instantiate` command. It instantiates a template
using the name of the template as the Virtual Machine name:

    $ oneinstantiate 0
    onetemplate instantiate 0 -n ubuntu
    VM ID: 11


onedeploy
---------

Creates a Virtual Machine and deploys it instantaneously in the first available
host it founds:

    $ onedeploy vm_template.one

onereport
---------

Displays a summary of running Virtual Machines:

    $ onereport
    VM: 9
    NAME: one-9
    HOSTNAME: localhost
    VNC PORT: 5909
    IP: 172.16.0.205
    IP: 172.16.1.1

    VM: 10
    NAME: ttylinux
    HOSTNAME: localhost

onessh
------

SSH's into a running VM:

    $ onessh 9 -l root

onevnc
------

Opens the VNC console of a running VM:

    $ onevnc 9

oneirb
------

Enters an irb environment with all the OpenNebula libraries loaded. The instance
variable `@client` is available in the IRB shell.

    $ oneirb
    >> vm = VirtualMachine.new(VirtualMachine.build_xml('10'), @client);
    ?> vm.info;
    ?> vm['NAME']
    => "ttylinux"

oneconf
-------

This ruby script backs up and rewrites `oned.conf` and `sched.conf`, performing
the following changes:

#### oned.conf

- `MANAGER_TIMER`: 5 seconds
- `HOST_MONITORING_INTERVAL`: 10 seconds
- `VM_POLLING_INTERVAL`: 10 seconds
- Enables `TM_SSH`
- Enables `TM_DUMMY`
- Enables `IM_DUMMY`
- Enables `VMM_DUMMY`

#### sched.conf

- `SCHED_INTERVAL`: 5 seconds

onebootstrap
------------

This command should be executed only with a fresh OpenNebula installation. It
will create some resources:

* __host__: localhost with KVM configuration
* __vnet__: a few IPs in the 172.16.0.0/24 network connected to bridge `br0`
* __datastore__: a file-system based user datastore
* __image__: an Ubuntu image (users will have to execute first
`bootstrap/image/download_ubuntu.sh`)
* __template__: an Ubuntu template ready to be instantiated

All of these resources can be customized by editing the files inside
`bootstrap/`. Other resources can be added and they will also be created.

The datastore where the images will be instantiated needs to have `DEFAULT =
YES` inside the template. This is only necessary if more than one datastore is
created.
