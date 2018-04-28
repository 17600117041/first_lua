local io = require("io")
local module = {}
local json = require("cjson")
-- @function use reparator incision str
-- @param str
-- @param separator
-- @return array
function module.split( str,reps )
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

-- @function write log into file
-- @param filePath
-- @param info
function module.writefile(filename, info)  
    local wfile=io.open(filename, "a") --写入文件(w覆盖)  
    assert(wfile)  --打开时验证是否出错        
    wfile:write(info)  --写入传入的内容  
    wfile:close()  --调用结束后记得关闭  
end

-- @function matching params with square bracket  匹配带有中括号的参数
-- @param string
-- @return boolean 如果匹配成功 retuen false  否则return true
function module.pattern_square_bracket(args)
	local pattern = '.*\\[.*\\]'
	local res, err = ngx.re.match(args, pattern)
	if res then
		return false
	else
		return true
	end
end

-- function:parallel request
-- @param table {'urlPath', {args = { arg1 = 'var1', arg2 = 'var2',}}}
-- @return table {{status = '', header = {}, body = {}, truncated = {},}, {status = '', header = {}, body = {}, truncated = {},}}
function module.capture_multi(request_data)
 	local resps = { ngx.location.capture_multi(request_data) }
 	return resps
end

-- function:get result
-- @param table request
-- @param table temp_alias_data
-- @return table result
function module.getResult(request_data, temp_alias_data)
	local result = {}
	local resps = {}
	if #request_data ~= 0 then
		resps = module.capture_multi(request_data)
	end
	if #resps ~= 0 then
		for i, resp in ipairs(resps) do
			if resp.status == 200 then
				local api_alias = temp_alias_data[i]
				result[api_alias] = json.decode(resp.body)
			end
	 	end
	end
 	return result
end

-- function:hanel query_string apis
-- @param table $_GET
-- @return table request_data_table  temp_alias_data_table
function module.handleApisParam(get_data_table)
	local request_data_table = {}
	local temp_alias_data_table = {}
	if get_data_table['apis'] then
		local data_table = module.split(get_data_table['apis'],',')
		if type(data_table) == 'table' then
			for _,value in ipairs(data_table) do
				-- ngx.say('-------------------------')
				local request_args_table = module.DeepCopy(get_data_table)
				local api_info_table = module.split(value, ':')
				local api_name_sting = api_info_table[1]
				local url_path_string, times = '/'..string.gsub(api_name_sting, '-', '/')
				local alias_string
				if api_info_table[2] then
					 alias_string = api_info_table[2]
				else 
					 alias_string = api_info_table[1]
				end
				local return_alias_string = alias_string
				alias_string, times = string.gsub(alias_string, '-', '%%-')
				alias_string, times = string.gsub(alias_string, '_', '%%_')
				local pattern_param_string = alias_string..'%[.*%]'
				local pattern_api_param_string = '%[(.*)%]'
				for k,v in pairs(get_data_table) do
					local param_string = string.match(k, pattern_param_string)
					if param_string then 
						local api_param_string = string.match(k, pattern_api_param_string)
						if api_param_string then
							request_args_table[api_param_string] = v
						end
					end
				end
				request_args_table['apis'] = nil
				local new_get_data_table = {}
				for kk,vv in pairs(request_args_table) do
					is_really_key = module.pattern_square_bracket(kk)
					if is_really_key then
						new_get_data_table[kk] = vv
					end
				end
				table.insert(request_data_table, {url_path_string, { args = new_get_data_table,}})
				table.insert(temp_alias_data_table, return_alias_string)
				request_args_table = nil
				collectgarbage()
			end	
		end
	end
	return request_data_table, temp_alias_data_table
end

-- function deep copy table
-- @param table
-- @return table
function module.DeepCopy( obj )      
    local InTable = {};  
    local function Func(obj)
        if type(obj) ~= "table" then   --判断表中是否有表  
            return obj;  
        end  
        local NewTable = {};  --定义一个新表  
        InTable[obj] = NewTable;  --若表中有表，则先把表给InTable，再用NewTable去接收内嵌的表  
        for k,v in pairs(obj) do  --把旧表的key和Value赋给新表  
            NewTable[Func(k)] = Func(v);  
        end  
        return setmetatable(NewTable, getmetatable(obj))--赋值元表  
    end  
    return Func(obj) --若表中有表，则把内嵌的表也复制了  
end

-- function format data
-- @param table  
-- @return table return_data
function module.returnData(result)
	local return_data = {}
	return_data['data'] = {}
	return_data['extra'] = {}
	return_data['status'] = 0
	return_data['info'] = 'Ok'
	return_data['times'] = 0
	for key, value in pairs(result) do
		return_data['status'] = value.status
		return_data['info'] = value.info
		return_data['times'] = value.times
		if value.data ~= nil then
			return_data['data'][key] = value.data
		else
			return_data['data'][key] = ''
		end
		if value.extra ~= nil then
			return_data['extra'][key] = value.extra
		else
			return_data['extra'][key] = ''
		end
	end
	return return_data
end

return module