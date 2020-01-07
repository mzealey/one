#!/usr/bin/ruby

require 'sequel'
require 'yaml'

# ------------------------------------------------------------------------------
# SQlite Interface for the status probes. It stores the last known state of
# each domain and the number of times the domain has been reported as missing
#
# IMPORTANT. This class needs to include/require a DomainList module with
# the state_info method.
# ------------------------------------------------------------------------------
class VirtualMachineDB

    # Default configuration attributes for the Database probe
    DEFAULT_CONFIGURATION = {
        :times_missing => 3,
        :obsolete      => 720,
        :db_path       => "#{__dir__}/../status.db",
        :missing_state => "POWEROFF"
    }

    def initialize(hyperv, opts = {})
        conf_path = "#{__dir__}/../../etc/im/#{hyperv}-probes.d/probe_db.conf"
        etc_conf  = YAML.load_file(conf_path) rescue nil

        @conf = DEFAULT_CONFIGURATION.clone
        @conf[:hyperv] = hyperv

        @conf.merge! etc_conf if etc_conf

        @conf.merge! opts

        @db = Sequel.connect("sqlite://#{@conf[:db_path]}")

        bootstrap

        @dataset = @db[:states]
    end

    # Deletes obsolete VM entries
    def purge
        limit = Time.now.to_i - (@conf[:obsolete] * 60) # conf in minutes

        @dataset.where { timestamp < limit }.delete
    end

    # Returns the VM status that changed compared to the DB info as well
    # as VMs that have been reported as missing more than missing_times
    def to_status
        status_str = ''

        time = Time.now.to_i
        vms  = DomainList.state_info

        known_ids = []

        # ----------------------------------------------------------------------
        # report state changes in vms
        # ----------------------------------------------------------------------
        vms.each do |uuid, vm|
            vm_db = @dataset.first(:uuid => uuid)

            known_ids << vm[:uuid]

            if vm_db.nil? || vm_db.empty?
                @dataset.insert({
                    :uuid      => uuid,
                    :timestamp => time,
                    :id        => vm[:id],
                    :name      => vm[:name],
                    :state     => vm[:state],
                    :hyperv    => @conf[:hyperv],
                    :missing   => 0
                })
                next
            end

            next if vm_db[:state] == vm[:state]

            status_str << "VM = [ ID=\"#{vm[:id]}\", "
            status_str << "DEPLOY_ID=\"#{vm[:name]}\", "
            status_str << "STATE=\"#{vm[:state]}\" ]\n"

            @dataset.where(:uuid => uuid).update(:state => vm[:state],
                                                 :timestamp => time)
        end

        # ----------------------------------------------------------------------
        # check missing VMs
        # ----------------------------------------------------------------------
        (@dataset.map(:uuid) - known_ids).each do |uuid|
            vm_db = @dataset.first(:uuid => uuid)

            next if vm_db.nil? || vm_db.empty?

            miss = vm_db[:missing]

            if miss > @conf[:times_missing]
                status_str << "VM = [ ID=\"#{vm_db[:id]}\", "
                status_str << "DEPLOY_ID=\"#{vm_db[:name]}\", "
                status_str << "STATE=\"#{@conf[:missing_state]}\" ]\n"
            end

            @dataset.where(:uuid => uuid).update(:timestamp => time,
                                                 :missing   => miss + 1)
        end

        status_str
    end

    #  TODO describe DB schema
    #
    #
    def bootstrap
        return if @db.table_exists?(:states)

        @db.create_table :states do
            String  :uuid, primary_key: true
            Integer :id
            String  :name
            Integer :timestamp
            Integer :missing
            String  :state
            String  :hyperv
        end
    end

end
