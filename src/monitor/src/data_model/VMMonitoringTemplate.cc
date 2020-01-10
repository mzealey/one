/* -------------------------------------------------------------------------- */
/* Copyright 2002-2019, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

#include "VMMonitoringTemplate.h"
#include "ObjectXML.h"

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

using namespace std;

#define xml_print(name, value) "<"#name">" << value << "</"#name">"

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

string VMMonitoringTemplate::to_xml() const
{
    string monitor_str;
    ostringstream oss;

    oss << "<MONITORING>";

    oss << xml_print(TIMESTAMP, _timestamp);
    oss << xml_print(ID, _oid);
    oss << monitoring.to_xml(monitor_str);

    oss << "</MONITORING>";

    return oss.str();
}

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

int VMMonitoringTemplate::from_xml(const std::string& xml_string)
{
    ObjectXML xml(xml_string);

    int rc = xml.xpath(_timestamp, "/MONITORING/TIMESTAMP", 0L);
    rc += xml.xpath(_oid, "/MONITORING/ID", -1);

    if (rc < 0)
    {
        return -1;
    }

    vector<xmlNodePtr> content;
    xml.get_nodes("/MONITORING/TEMPLATE", content);

    if (!content.empty())
    {
        monitoring.from_xml_node(content[0]);

        xml.free_nodes(content);
        content.clear();
    }

    return 0;
}

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

int VMMonitoringTemplate::from_template(const Template &tmpl)
{
    int tmp;
    if (tmpl.get("OID", tmp))
    {
        _oid = tmp;
    }

    if (_oid < 0)
    {
        return -1;
    }

    monitoring.merge(&tmpl);

    return 0;
}
