#!/usr/bin/ruby

# This inventory extracts VM information from OpenNebula to be used by Ansible.

# The following information is obtained:

# * All the parameters in the Context and in the User Template
# * Disk information: size, image_id and persistancy
# * Network information: IP, MAC address, etc

# Only VMs that meet any of these conditions are returned by the inventory

# * It has a context variable called "ANSIBLE". The content of this variable is
#   the ansible group it will be placed into
# * It has the "ansible" label
# * It has a label under "ansible". Whatever the label is will be the ansible
#   group it will be placed into

# If there is no DNS for the VM, you may use the User Template variable
# "ANSIBLE_HOST" in order to specify what IP should this inventory report to
# ansible:

# * ANSIBLE_HOST is undefined: Ansible will use the VM name
# * ANSIBLE_HOST=yes: Ansible will use the IP of the first interface
# * ANSIBLE_HOST=eth0: Ansible will use the IP of the first interface
# * ANSIBLE_HOST=eth1: Ansible will use the IP of the second interface
# * ANSIBLE_HOST=ethN: Ansible will use the IP of the N-1 interface

ONE_LOCATION=ENV["ONE_LOCATION"]

if !ONE_LOCATION
    RUBY_LIB_LOCATION = "/usr/lib/one/ruby"
    VAR_LOCATION      = "/var/lib/one"
    LIB_LOCATION      = "/usr/lib/one"
    ETC_LOCATION      = "/etc/one"
else
    RUBY_LIB_LOCATION = ONE_LOCATION + "/lib/ruby"
    VAR_LOCATION      = ONE_LOCATION + "/var"
    LIB_LOCATION      = ONE_LOCATION + "/lib"
    ETC_LOCATION      = ONE_LOCATION + "/etc"
end

$: << RUBY_LIB_LOCATION

require 'opennebula'
include OpenNebula

require 'pp'
require 'json'

class Inventory
    attr_reader :inventory, :hostvars

    def initialize
        @inventory = {}
        @hostvars = {}

        mkgroup(:all)
    end

    def host(name, group = :all)
        mkgroup(group)
        @inventory[group][:hosts] << name
    end

    def groupvar(group, var, val)
        mkgroup(group)
        @inventory[group][:vars][var.downcase] = val
    end

    def hostvar(host, var, val)
        @hostvars[host] = {} if @hostvars[host].nil?
        @hostvars[host][var.downcase] = val
    end

    def to_json
        {
            "_meta" => {
                "hostvars" => @hostvars
            },
        }.merge(@inventory).to_json
    end

private

    def mkgroup(group)
        @inventory[group] = {} if @inventory[group].nil?
        @inventory[group][:hosts] = [] if @inventory[group][:hosts].nil?
        @inventory[group][:vars]  = {} if @inventory[group][:vars].nil?
    end
end

client = Client.new

vm_pool = VirtualMachinePool.new(client, -1)

rc = vm_pool.info

if OpenNebula.is_error?(rc)
     puts rc.message
     exit -1
end

inventory = Inventory.new
vm_pool.each do |vm|
    # Require READY=YES if REPORT_READY=YES
    if  vm["TEMPLATE/CONTEXT/REPORT_READY"] == "YES" &&
        vm["TEMPLATE/CONTEXT/TOKEN"] == "YES" &&
        vm["USER_TEMPLATE/READY"] != "YES" then

        next
    end

    labels = vm["USER_TEMPLATE/LABELS"].split(",").select do |e|
        e.match(/ansible(\/|$)/)
    end rescue nil

    ansible_role = vm["TEMPLATE/CONTEXT/ANSIBLE_ROLE"] rescue nil

    if (labels.nil? || labels.empty?) && (ansible_role.nil? || ansible_role.empty?)
        next
    end

    id   = "one-#{vm['ID']}"
    name = vm["NAME"]

    vm.each('TEMPLATE/CONTEXT/*') do |e|
        var = e.name
        val = e.text

        next if %w(DISK_ID NETWORK TARGET).include?(var)

        inventory.hostvar(name, var, val)
    end

    vm.each('USER_TEMPLATE/*') do |e|
        var = e.name
        val = e.text

        next if %w(ANSIBLE_HOST).include?(var)

        inventory.hostvar(name, var, val)
    end

    i=0
    vm.each('TEMPLATE/DISK') do |disk|
        %w(image image_id size).each do |key|
            val = disk[key.upcase]

            if !val.nil? && !val.empty?
                inventory.hostvar(name, "disk_#{i}_#{key}", val)
            end
        end

        persistent = !(disk['CLONE'] == 'YES')
        inventory.hostvar(name, "disk_#{i}_persistent", persistent)

        i+=1
    end

    ansible_host = vm["USER_TEMPLATE/ANSIBLE_HOST"]
    ansible_host ||= vm["TEMPLATE/CONTEXT/ANSIBLE_HOST"]
    ansible_host ||= ENV['ANSIBLE_HOST']

    if ansible_host
        var_ip = if ansible_host.match(/^eth\d+$/i)
            ansible_host.upcase + "_IP"
        else
            "ETH0_IP"
        end

        ip = vm["TEMPLATE/CONTEXT/#{var_ip}"]

        inventory.hostvar(name, "ansible_host", ip) if ip
    end

    labels.each do |label|
        _, group = label.split("/", 2)
        inventory.host(name, group.gsub("/", ",")) if group
    end if labels

    if ansible_role && !ansible_role.empty?
        inventory.host(name, ansible_role)
    end

    inventory.host(name)
end

puts inventory.to_json

exit 0
