OpenNebula CLI Tools
====================

This a collection of scripts useful for OpenNebula administrators.
Contributions are welcome.

oneconf
-------

This script backs up and rewrites `oned.conf` and `sched.conf`, performing the
following changes:

### oned.conf

- `MANAGER_TIMER`: 5 seconds
- `HOST_MONITORING_INTERVAL`: 10 seconds
- `VM_POLLING_INTERVAL`: 10 seconds
- Enables `TM_SSH`
- Enables `TM_DUMMY`
- Enables `IM_DUMMY`
- Enables `VMM_DUMMY`

### sched.conf

- `SCHED_INTERVAL`: 5 seconds

onedeploy
---------

Creates a Virtual Machines and deploys it instantaneously in the first host it
founds:

    $ onedeploy vm_template.one

oneinstantiate
--------------

A wrapper for the instantiate command. It instantiates a template using the name
of the template as the Virtual Machine name:

    $ oneinstantiate 0
    onetemplate instantiate 0 -n ubuntu
    VM ID: 11

oneirb
------

Enters a irb environment with all the OpenNebula libraries loaded. The instance
variable `@client` is already available in the IRB shell.

    $ oneirb
    >> vm = VirtualMachine.new(VirtualMachine.build_xml('10'), @client);
    ?> vm.info;
    ?> vm['NAME']
    => "ttylinux"

onelog
------

If no argument is passed it displays `oned.log`. If a `VM_ID` is passed as a
paramenter, the vm.log is displayed:

    $ onelog
    [ opens oned.log in your $PAGER ]
    $ onelog 10
    [ opens the vm.log for VM 10 in your $PAGER ]


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

