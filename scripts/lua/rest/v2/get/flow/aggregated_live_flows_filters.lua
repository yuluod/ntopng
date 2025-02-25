--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end


if ntop.isEnterpriseM() then
    require "aggregate_live_flows"
 end

-- =============================

local ifid = _GET["ifid"]
local action = _GET["action"]
local vlan_id = _GET["vlan_id"]


local ifid = _GET["ifid"]
local vlan = tonumber(_GET["vlan_id"] or -1)
local criteria = _GET["aggregation_criteria"] or ""
local rc = rest_utils.consts.success.ok
local filters = {}
interface.select(ifid)
filters["page"] = tonumber(_GET["draw"] or 0)
filters["sort_column"] = _GET["sort"] or 'flows'
filters["sort_order"] = _GET["order"] or 'desc'
filters["start"] = tonumber(_GET["start"] or 0)
filters["length"] = tonumber(_GET["length"] or 10)
filters["map_search"] = _GET["map_search"]
filters["host"] = _GET["host"]
interface.select(ifid)
-- Aggregation criteria 
local criteria_type_id = 1 -- by default application_protocol
if criteria == "client" then
   criteria_type_id = 2
elseif criteria == "server" then
      criteria_type_id = 3
elseif criteria == "client_server_srv_port" then
   criteria_type_id = 7
elseif ntop.isEnterpriseM() then
   criteria_type_id = get_criteria_type_id(criteria)
end

local isView = interface.isView()
local x = 0

-- Retrieve the flows
local aggregated_info = interface.getProtocolFlowsStats(criteria_type_id, filters["page"], filters["sort_column"],
							filters["sort_order"], filters["start"], filters["length"], ternary(not isEmptyString(filters["map_search"]), filters["map_search"], nil) , ternary(filters["host"]~= "", filters["host"], nil), vlan)

local formatted_vlan_filters = {}

local function is_vlan_already_inserted(formatted_vlan_filters, vlan_id)
    for _,x in ipairs(formatted_vlan_filters) do
        if(x.value == vlan_id) then
            x.count = x.count + 1
            return true
        end
    end
    return false
end

for _, data in pairs(aggregated_info or {}) do

    if not is_vlan_already_inserted(formatted_vlan_filters, data.vlan_id) then
        local vlan_name = i18n('no_vlan')

        if data.vlan_id ~= 0 then
            vlan_name = getFullVlanName(data.vlan_id)
        end
        local vlan = {
            count = 1,
            value = data.vlan_id,
            label = vlan_name,
            key = "vlan_id"
        }
        formatted_vlan_filters[#formatted_vlan_filters+1] = vlan
    end
end


table.insert(formatted_vlan_filters, 1, {
    key = "vlan_id",
    label = i18n('all'),
    value =""
})
if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end


local rsp = {
    {
        action = "vlan_id",
        label = i18n("vlan"),
        tooltip = i18n("vlan_filter"),
        name = "vlan_filter",
        value = formatted_vlan_filters
    }
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
