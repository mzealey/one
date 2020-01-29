# -------------------------------------------------------------------------- #
# Copyright 2002-2019, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

include OpenNebula

module Migrator

    def db_version
        '5.12.0'
    end

    def one_version
        'OpenNebula 5.9.80'
    end

    def up
        feature_3859
        true
    end

    private

    def feature_3859
        # host monitoring
        @db.run 'DROP TABLE IF EXISTS old_host_monitoring;'
        @db.run 'ALTER TABLE host_monitoring RENAME TO old_host_monitoring;'

        create_table(:host_monitoring)

        db.transaction do
            # Adjust host monitoring
            @db.fetch('SELECT * FROM old_host_monitoring') do |row|
                doc_old = Nokogiri::XML(row[:body], nil, NOKOGIRI_ENCODING) do |c|
                    c.default_xml.noblanks
                end

                doc = Nokogiri::XML("", nil, NOKOGIRI_ENCODING)

                # id and timestamp
                monitoring = doc.create_element('MONITORING');
                monitoring.add_child(doc_old.xpath('HOST/ID'))
                monitoring.add_child(doc.create_element(
                    'TIMESTAMP', doc_old.xpath('HOST/LAST_MON_TIME').text))

                # capacity
                capacity = doc.create_element('CAPACITY')
                capacity.add_child(doc_old.xpath('HOST/HOST_SHARE/FREE_CPU'))
                capacity.add_child(doc.create_element(
                    'FREE_MEMORY', doc_old.xpath('HOST/HOST_SHARE/FREE_MEM').text))
                capacity.add_child(doc_old.xpath('HOST/HOST_SHARE/USED_CPU'))
                capacity.add_child(doc.create_element(
                    'USED_MEMORY', doc_old.xpath('HOST/HOST_SHARE/USED_MEM').text))
                monitoring.add_child(capacity)

                # system
                system = doc.create_element('SYSTEM')
                system.add_child(doc_old.xpath('HOST/TEMPLATE/NETRX'))
                system.add_child(doc_old.xpath('HOST/TEMPLATE/NETTX'))
                monitoring.add_child(system)

                doc.root = monitoring

                row[:body] = doc.root.to_s

                @db[:host_monitoring].insert(row)
            end
        end

        @db.run 'DROP TABLE IF EXISTS old_host_monitoring;'

        # host pool
        @db.run 'DROP TABLE IF EXISTS old_host_pool;'
        @db.run 'ALTER TABLE host_pool RENAME TO old_host_pool;'

        create_table(:host_pool)

        db.transaction do
            # Adjust host pool
            @db.fetch('SELECT * FROM old_host_pool') do |row|
                doc = Nokogiri::XML(row[:body], nil, NOKOGIRI_ENCODING) do |c|
                    c.default_xml.noblanks
                end

                doc.xpath('HOST/LAST_MON_TIME').remove
                doc.xpath('HOST/TEMPLATE/NETRX').remove
                doc.xpath('HOST/TEMPLATE/NETTX').remove
                hs = doc.xpath('HOST/HOST_SHARE').pop
                hs.xpath('FREE_MEM').remove
                hs.xpath('FREE_CPU').remove
                hs.xpath('USED_MEM').remove
                hs.xpath('USED_CPU').remove

                disk_usage = hs.xpath('DISK_USAGE').remove.pop
                max_disk =   hs.xpath('MAX_DISK').remove.pop
                free_disk =  hs.xpath('FREE_DISK').remove.pop
                used_disk =  hs.xpath('USED_DISK').remove.pop

                ds = doc.xpath('HOST/HOST_SHARE/DATASTORES').pop
                ds.add_child(disk_usage)
                ds.add_child(max_disk)
                ds.add_child(free_disk)
                ds.add_child(used_disk)

                row[:body] = doc.root.to_s
                row.delete(:last_mon_time)

                @db[:host_pool].insert(row)
            end
        end

        @db.run 'DROP TABLE IF EXISTS old_host_pool;'

        # VM monitoring
        @db.run 'DROP TABLE IF EXISTS old_vm_monitoring;'
        @db.run 'ALTER TABLE vm_monitoring RENAME TO old_vm_monitoring;'

        create_table(:vm_monitoring)

        db.transaction do
            # Adjust VM monitoring
            @db.fetch('SELECT * FROM old_vm_monitoring') do |row|
                doc = Nokogiri::XML(row[:body], nil, NOKOGIRI_ENCODING) do |c|
                    c.default_xml.noblanks
                end

                doc.xpath('VM/STATE').remove
                doc.xpath('VM/TEMPLATE').remove
                doc.xpath('VM/LAST_POLL').pop.name = 'TIMESTAMP'
                doc.xpath('VM').pop.name = 'MONITORING'

                row[:body] = doc.root.to_s

                @db[:vm_monitoring].insert(row)
            end
        end

        @db.run 'DROP TABLE IF EXISTS old_vm_monitoring;'

        # VM pool
        @db.run 'DROP TABLE IF EXISTS old_vm_pool;'
        @db.run 'ALTER TABLE vm_pool RENAME TO old_vm_pool;'

        create_table(:vm_pool)

        db.transaction do
            # Adjust host pool
            @db.fetch('SELECT * FROM old_vm_pool') do |row|
                doc = Nokogiri::XML(row[:body], nil, NOKOGIRI_ENCODING) do |c|
                    c.default_xml.noblanks
                end

                doc.xpath('VM/LAST_POLL').remove
                doc.xpath('VM/MONITORING').remove
                doc.xpath('VM/DEPLOY_ID').after(doc.create_element('MONITORING'))

                row[:body] = doc.root.to_s
                row.delete(:last_poll)

                @db[:vm_pool].insert(row)
            end
        end

        @db.run 'DROP TABLE IF EXISTS old_vm_pool;'
    end

end
