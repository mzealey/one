#!/usr/bin/ruby

require_relative '../../../lib/probe_db'
require_relative '../../../lib/lxd'

module DomainList

    def self.state_info
        containers = Container.get_all(LXD::CLIENT)
        return unless containers

        vms = {}

        containers.each do |container|
            vm = {}
            name = container.name

            vm[:name] = name
            vm[:uuid] = name # not applicable to LXD
            vm[:state] = one_status(container)

            # Wilderness
            if vm[:name] =~ /^one-(\d*)$/
                vm[:id] = vm[:name].split('-').last
            else
                vm[:id] = -1
            end

            vms[name] = vm
        end

        vms
    end

    def self.one_status(container)
        u = 'UNKNOWN'

        begin
            status = container.status.upcase
        rescue StandardError
            status = U
        end

        case status
        when 'RUNNING'
            status
        when 'FROZEN'
            'PAUSED'
        when 'STOPPED'
            'POWEROFF'

            u if container.config['user.one_status'] == '0'
        when 'FAILURE'
            status
        else
            u
        end
    end

end

begin
    vmdb = VirtualMachineDB.new('lxd', :missing_state => 'POWEROFF')

    vmdb.purge

    puts vmdb.to_status
rescue StandardError => e
    puts e
end
