#!/usr/bin/ruby


# Special variables:
# ANSIBLE_HOST: 'eth0', 'eth1', etc... or 'yes'
# ANSIBLE_GROUP: comma separated
#

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
    ETC_LOCATION      = ONE_LOCATION +"/etc"
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
    if ansible_host
        var_ip = if ansible_host.match(/^eth\d+$/)
            ansible_host.upcase + "_IP"
        else
            "ETH0_IP"
        end

        ip = vm["TEMPLATE/CONTEXT/#{var_ip}"]

        if ip
            inventory.hostvar(name, "ansible_host", ip)
        end
    end

    ansible_group = vm["USER_TEMPLATE/ANSIBLE_GROUP"]

    if ansible_group
        ansible_group.split(",").each{|g| inventory.host(name, g.strip)}
    end

    inventory.host(name)
end

puts inventory.to_json

exit 0
