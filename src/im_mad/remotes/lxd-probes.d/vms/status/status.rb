#!/usr/bin/ruby

require_relative '../../../lib/probe_db'
require_relative '../../../lib/lxd'

#  -----------------------------------------------------------
#  This module implements the functions needed by probe_db.rb
#  -----------------------------------------------------------
module DomainList
    # LXD to OpenNebula state mapping
    STATE_MAP = {
        'RUNNING' => 'RUNNING',
        'FROZEN'  => 'PAUSED',
        'STOPPED' => 'POWEROFF',
        'FAILURE' => 'FAILURE',
        'POWEROFF'=> 'POWEROFF'
    }

    # Returns a vm hash with the containers running in LXD
    def self.state_info
        containers = Container.get_all(LXD::CLIENT)
        return unless containers

        vms = {}

        containers.each do |container|
            vm   = {}
            name = container.name

            next if container.config['user.one_status'] == '0'

            vm[:name]  = name
            vm[:state] = one_status(container)

            # return if wild
            next unless vm[:name] =~ /^one-(\d*)$/

            vm[:id] = vm[:name].split('-').last

            vms[name] = vm
        end

        vms
    end

    def self.one_status(container)
        state = STATE_MAP[container.status.upcase]
        state ||= 'UNKNOWN'

        state
    rescue StandardError
        'UNKNOWN'
    end

end

begin
    vmdb = VirtualMachineDB.new('lxd', :missing_state => 'POWEROFF')

    vmdb.purge

    puts vmdb.to_status
rescue StandardError => e
    puts e
end
