local is_wirte_log = true
local log_path = '/tmp/access.lua'
local module = require("module")
local config = require("config")
local json = require("cjson")
json.encode_empty_table_as_object(false)
-- json.decode_array_with_array_mt(true)
local request_uri = ngx.var.request_uri
local receive_headers = ngx.req.get_headers()
local request_method = ngx.var.request_method
local request_time = os.date("%Y-%m-%d %H:%M:%S")
local args = {}
if request_method == "GET" then
	args = ngx.req.get_uri_args()
elseif request_method == "POST" then
	ngx.req.read_body()
	args = ngx.req.get_post_args()
end

local get_data = {}
for i,v in pairs(args) do
	get_data[i] = v
	
end
local start_time = ngx.now()
local request_data, temp_alias_data = module.handleApisParam(get_data)
local result = module.getResult(request_data, temp_alias_data)
local return_data = module.returnData(result)

-- write log
if is_wirte_log then
	local end_time = ngx.now()
	local make_time = end_time - start_time
	local log_data =  "--------start --------\nrequest_time:"..request_time.."\nrequest_uri: "..request_uri.."\nresponse_time: "..make_time.."s\n---------end--------\n"
	module.writefile(log_path, log_data)
end
ngx.header.content_type = 'application/json;charset=UTF-8'
ngx.say(json.encode(return_data))