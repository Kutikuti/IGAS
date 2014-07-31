--[[
Copyright (c) 2011-2014 WangXH <kurapica.igas@gmail.com>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
--]]

------------------------------------------------------------------------
--
--	 Pure Lua Object-Oriented Program System
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Author			kurapica.igas@gmail.com
-- Create Date		2011/02/01
-- Last Update Date 2014/07/25
-- Version			r102
------------------------------------------------------------------------

------------------------------------------------------
-- Object oriented program syntax system environment
------------------------------------------------------
do
	-- Local Environment
	setfenv(1, setmetatable({}, {
		__index = function(self,  key)
			if type(key) == "string" and key ~= "_G" and key:find("^_") then return end

			if _G[key] then rawset(self, key, _G[key]) return rawget(self, key) end
		end,
		__metatable = true,
	}))

	-- Common features
	getfenv = getfenv
	setfenv = setfenv

	strlen = string.len
	strformat = string.format
	strfind = string.find
	strsub = string.sub
	strbyte = string.byte
	strchar = string.char
	strrep = string.rep
	strsub = string.gsub
	strupper = string.upper
	strlower = string.lower
	strtrim = strtrim or function(s) return s and (s:gsub("^%s*(.-)%s*$", "%1")) or "" end
	wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

	tblconcat = tblconcat or table.concat
	tinsert = tinsert or table.insert
	tremove = tremove or table.remove
	sort = sort or table.sort
	floor = floor or math.floor
	log = log or math.log

	create = coroutine.create
	resume = coroutine.resume
	running = coroutine.running
	status = coroutine.status
	wrap = coroutine.wrap
	yield = coroutine.yield

	local _ErrorHandler = print

	seterrorhandler = seterrorhandler or function(handler) if type(handler) == "function" then _ErrorHandler = handler end end
	geterrorhandler = geterrorhandler or function() return _ErrorHandler end
	errorhandler = errorhandler or function(err) return pcall(geterrorhandler(), err) end

	newproxy = newproxy

	if not newproxy then
		local _METATABLE_MAP = setmetatable({}, {__mode = "k"})

		function newproxy(prototype)
			-- mean no userdata can be created in lua, use the table instead
			if type(prototype) == "table" and _METATABLE_MAP[prototype] then
				return setmetatable({}, _METATABLE_MAP[prototype])
			elseif prototype == true then
				local meta = {}
				prototype = setmetatable({}, meta)
				_METATABLE_MAP[prototype] = meta
				return prototype
			else
				return setmetatable({}, {__metatable = false})
			end
		end
	end
end

------------------------------------------------------
-- GLOBAL Definition
------------------------------------------------------
do
	-- Used to enable/disable document system, not started with '_', so can be disabled outsider
	DOCUMENT_ENABLED = DOCUMENT_ENABLED == nil and true or false

	TYPE_CLASS = "Class"
	TYPE_ENUM = "Enum"
	TYPE_STRUCT = "Struct"
	TYPE_INTERFACE = "Interface"

	TYPE_NAMESPACE = "NameSpace"
	TYPE_SUPERALIAS = "SuperAlias"
	TYPE_TYPE = "TYPE"

	-- Disposing method name
	DISPOSE_METHOD = "Dispose"

	-- Namespace field
	NAMESPACE_FIELD = "__PLOOP_NameSpace"

	-- Owner field
	OWNER_FIELD = "__PLOOP_OWNER"

	-- Base env field
	BASE_ENV_FIELD = "__PLOOP_BASE_ENV"

	-- Local env field
	LOCAL_ENV_FIELD = "__PLOOP_LOCAL"
end

------------------------------------------------------
-- Thread Pool & Tools
------------------------------------------------------
do
	ATTRIBUTE_INSTALLED = false

	WEAK_KEY = {__mode = "k"}
	WEAK_VALUE = {__mode = "v"}
	WEAK_ALL = {__mode = "kv"}

	SYNTHESIZE_ENV = {
		rawset = rawset,
		rawget = rawget,
		type = type,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		pcall = pcall,
		errorhandler = errorhandler,
		WEAK_VALUE = WEAK_VALUE,
	}

	THREAD_POOL_SIZE = 100

	-- This func means the function call is finished successful, so, we need send the running thread back to the pool
	local function retValueAndRecycle(...) THREAD_POOL( running() ) return ... end

	local function callFunc(func, ...) return retValueAndRecycle( func(...) ) end

	local function newRycThread(pool, func)
		while pool == THREAD_POOL and type(func) == "function" do pool, func = yield( callFunc ( func, yield() ) ) end
	end

	THREAD_POOL = setmetatable({}, {
		__call = function(self, value)
			if value then
				-- re-use the thread or use resume to kill
				if #self < THREAD_POOL_SIZE then tinsert(self, value) else resume(value) end
			else
				-- Keep safe from unexpected resume
				while not value or status(value) == "dead" do value = tremove(self) or create(newRycThread) end
				return value
			end
		end,
	})

	local function chkValue(flag, msg, ...)
		if flag then
			return msg, ...
		else
			return error(type(msg) == "string" and msg:match(":%d+:%s*(.-)$") or msg, 3)
		end
	end

	function CallThread(func, ...)
		if type(func) == "thread" and status(func) == "suspended" then return chkValue( resume(func, ...) ) end

		local th = THREAD_POOL()

		-- Register the function
		resume(th, THREAD_POOL, func)

		-- Call and return the result
		return chkValue( resume(th, ...) )
	end

	CACHE_TABLE = setmetatable({}, {
		__call = function(self, key)
			if key then
				wipe(key)
				tinsert(self, key)
			elseif next(self) then
				return tremove(self)
			else
				return {}
			end
		end,
	})

	function SaveFixedMethod(storage, key, value, owner, targetType)
		if ATTRIBUTE_INSTALLED then
			value = __Attribute__._ConsumePreparedAttributes(value, targetType or AttributeTargets.Method, targetType ~= AttributeTargets.Constructor and GetSuperMethod(owner, key) or nil, owner, key) or value
		end

		if ATTRIBUTE_INSTALLED and targetType ~= AttributeTargets.Constructor then
			-- Hide the real fixed method for method and meta-method, started with '0', strange but useful
			local rKey = "0" .. key

			if storage[rKey] then
				if type(value) == "function" and (not getmetatable(storage[rKey]) or storage[rKey].Owner ~= owner) then
					-- roll back to normal meta-methods
					storage[key] = value
					storage[rKey] = nil
					return
				end

				key = rKey
			elseif getmetatable(value) then
				storage[rKey] = storage[key]

				-- table can't be meta-methods & hide the details
				storage[key] = function(...)
					return storage[rKey](...)
				end

				key = rKey
			end
		end

		if getmetatable(storage[key]) then
			local prev
			local fixedMethod = storage[key]

			while getmetatable(fixedMethod) and fixedMethod.Owner == owner do
				if getmetatable(value) and #fixedMethod == #value and fixedMethod.MinArgs == value.MinArgs then
					local isEqual = true

					if fixedMethod == value then return end

					for i = 1, #fixedMethod do
						if not Reflector.IsEqual(fixedMethod[i], value[i]) then
							isEqual = false
							break
						end
					end

					if isEqual then
						if prev then
							value.Next = fixedMethod.Next
							prev.Next = value
							value = nil
						else
							value.Next = fixedMethod.Next
							storage[key] = value
							value = nil
						end

						break
					end
				end

				prev = fixedMethod
				fixedMethod = fixedMethod.Next
			end

			if getmetatable(value) then
				value.Next = storage[key]
				storage[key] = value
			elseif value then
				if prev then prev.Next = value else storage[key] = value end
			end
		elseif storage[key] and getmetatable(value) then
			value.Next = storage[key]
			storage[key] = value
		else
			storage[key] = value
		end
	end

	local function deepCloneObj(obj, cache)
		if type(obj) == "table" then
			if cache[obj] ~= nil then
				return cache[obj]
			elseif getmetatable(obj) then
				cache[obj] = type(obj.Clone) == "function" and obj:Clone(true) or obj
				return cache[obj]
			else
				local ret = {}
				cache[obj] = ret

				for k, v in pairs(obj) do ret[k] = deepCloneObj(v, cache) end

				return ret
			end
		else
			return obj
		end
	end

	function CloneObj(obj, deep)
		if type(obj) == "table" then
			if getmetatable(obj) then
				if type(obj.Clone) == "function" then return obj:Clone(deep) else return obj end
			else
				local ret = {}
				local cache = deep and CACHE_TABLE()

				if cache then cache[obj] = ret end

				for k, v in pairs(obj) do
					if deep then ret[k] = deepCloneObj(v, cache) else ret[k] = v == obj and ret or v end
				end

				if cache then CACHE_TABLE(cache) end

				return ret
			end
		else
			return obj
		end
	end

	SYNTHESIZE_ENV.clone = CloneObj

	-- Local marker
	LOCAL_CACHE = setmetatable({}, WEAK_KEY)

	function SetLocal(flag) LOCAL_CACHE[running() or 0] = flag or nil end
	function IsLocal() return LOCAL_CACHE[running() or 0] end
end

------------------------------------------------------
-- NameSpace & SuperAlias
------------------------------------------------------
do
	_NameSpace = newproxy(true)
	_SuperAlias = newproxy(true)

	_NSInfo = setmetatable({}, {
		__index = function(self, key)
			if not IsNameSpace(key) then return end
			self[key] = { Owner = key }
			return rawget(self, key)
		end,
		__mode = "k",
	})

	_SuperMap = setmetatable({}, WEAK_ALL)

	-- metatable for namespaces
	_MetaNS = getmetatable(_NameSpace)
	do
		_MetaNS.__call = function(self, ...)
			local info = _NSInfo[self]

			if info.Type == TYPE_CLASS then
				-- Create Class object
				return Class2Obj(self, ...)
			elseif info.Type == TYPE_STRUCT then
				-- Create Struct
				return Struct2Obj(self, ...)
			elseif info.Type == TYPE_ENUM then
				-- For short parse
				return Reflector.ParseEnum(self, ...)
			end

			error(("%s can't be used as a constructor."):format(tostring(self)), 2)
		end

		_MetaNS.__index = function(self, key)
			local info = _NSInfo[self]

			if info.Type == TYPE_STRUCT then
				if key == "Validate" then
					if not info.Validate then BuildStructValidate(self) end
					return info.Validate
				elseif info.Method[key] then
					return info.Method[key]
				else
					return info.SubNS and info.SubNS[key]
				end
			elseif info.Type == TYPE_CLASS then
				if info.SubNS and info.SubNS[key] then
					return info.SubNS[key]
				elseif _KeyMeta[key] ~= nil then
					if _KeyMeta[key] then return info.MetaTable[key] else return info.MetaTable["_"..key] end
				else
					return info.Method[key] or info.Cache4Method[key]
				end
			elseif info.Type == TYPE_ENUM then
				return type(key) == "string" and info.Enum[strupper(key)] or error(("%s is not an enumeration value of %s."):format(tostring(key), tostring(self)), 2)
			elseif info.Type == TYPE_INTERFACE then
				if info.SubNS and info.SubNS[key] then return info.SubNS[key] else return info.Method[key] or info.Cache4Method[key] end
			else
				return info.SubNS and info.SubNS[key]
			end
		end

		_MetaNS.__newindex = function(self, key, value)
			local info = _NSInfo[self]

			if info.Type == TYPE_CLASS and not info.NonExpandable and type(key) == "string" and type(value) == "function" then
				if not info.Cache4Method[key] then
					SaveFixedMethod(info.Method, key, value, info.Owner)
					return RefreshCache(self)
				else
					error("Can't override the existed method.", 2)
				end
			elseif info.Type == TYPE_INTERFACE and not info.NonExpandable and type(key) == "string" and type(value) == "function" then
				if not info.Cache4Method[key] then
					SaveFixedMethod(info.Method, key, value, info.Owner)
					return RefreshCache(self)
				else
					error("Can't override the existed method.", 2)
				end
			end
			error(("Can't set value for %s, it's readonly."):format(tostring(self)), 2)
		end

		_MetaNS.__add = function(v1, v2)
			local ok, _type1, _type2

			ok, _type1 = pcall(BuildType, v1)
			if not ok then error(strtrim(_type1:match(":%d+:%s*(.-)$") or _type1), 2) end

			ok, _type2 = pcall(BuildType, v2)
			if not ok then error(strtrim(_type2:match(":%d+:%s*(.-)$") or _type2), 2) end

			return _type1 + _type2
		end

		_MetaNS.__sub = function(v1, v2)
			local ok, _type1, _type2

			ok, _type1 = pcall(BuildType, v1)
			if not ok then error(strtrim(_type1:match(":%d+:%s*(.-)$") or _type1), 2) end

			ok, _type2 = pcall(BuildType, v2, true)
			if not ok then error(strtrim(_type2:match(":%d+:%s*(.-)$") or _type2), 2) end

			return _type1 + _type2
		end

		_MetaNS.__unm = function(v1)
			local ok, _type1

			ok, _type1 = pcall(BuildType, v1, true)
			if not ok then error(strtrim(_type1:match(":%d+:%s*(.-)$") or _type1), 2) end

			return _type1
		end

		_MetaNS.__tostring = function(self) return GetFullName4NS(self) end
		_MetaNS.__metatable = TYPE_NAMESPACE
	end

	-- metatable for super alias
	_MetaSA = getmetatable(_SuperAlias)
	do
		_MetaSA.__call = function(self, ...)
			-- Init the class object
			local cls = _SuperMap[self].Owner
			local obj = select(1, ...)

			if getmetatable(obj) and Reflector.ObjectIsClass(obj, cls) then return Class1Obj(cls, obj, select(2, ...)) end
		end

		_MetaSA.__index = function(self, key)
			local info = _SuperMap[self]

			if info.SubNS and info.SubNS[key] then
				return info.SubNS[key]
			elseif _KeyMeta[key] ~= nil then
				if _KeyMeta[key] then return info.MetaTable[key] else return info.MetaTable["_"..key] end
			else
				return info.Method[key] or info.Cache4Method[key]
			end
		end

		_MetaSA.__tostring = function(self) return GetFullName4NS(_SuperMap[self].Owner) end
		_MetaSA.__metatable = TYPE_SUPERALIAS
	end

	-- IsNameSpace
	function IsNameSpace(ns) return getmetatable(ns) == TYPE_NAMESPACE or false end

	-- BuildNameSpace
	function BuildNameSpace(ns, namelist)
		if type(namelist) ~= "string" or (ns ~= nil and not IsNameSpace(ns)) then return end

		local cls = ns
		local info = _NSInfo[cls]
		local parent = cls

		for name in namelist:gmatch("[_%w]+") do
			if not info then
				cls = newproxy(_NameSpace)
			elseif info.Type ~= TYPE_ENUM then
				info.SubNS = info.SubNS or {}
				info.SubNS[name] = info.SubNS[name] or newproxy(_NameSpace)

				cls = info.SubNS[name]
			else
				error(("can't add item to a %s."):format(tostring(info.Type)), 2)
			end

			info = _NSInfo[cls]
			info.Name = name
			if not info.NameSpace and parent ~= _NameSpace then info.NameSpace = parent end
			parent = cls
		end

		if cls == ns then return end

		return cls
	end

	-- GetNameSpace
	function GetNameSpace(ns, namelist)
		if type(namelist) ~= "string" or not IsNameSpace(ns) then return end

		local cls = ns

		for name in namelist:gmatch("[_%w]+") do
			cls = cls[name]
			if not cls then return end
		end

		if cls == ns then return end

		return cls
	end

	-- GetDefaultNameSpace
	function GetDefaultNameSpace() return _NameSpace end

	-- SetNameSpace
	function SetNameSpace4Env(env, name)
		if type(env) ~= "table" then return end

		local ns = type(name) == "string" and BuildNameSpace(GetDefaultNameSpace(), name) or IsNameSpace(name) and name or nil
		rawset(env, NAMESPACE_FIELD, ns)

		return ns
	end

	-- GetEnvNameSpace
	function GetNameSpace4Env(env, rawOnly)
		local ns = type(env) == "table" and ((rawOnly and rawget(env, NAMESPACE_FIELD)) or (not rawOnly and env[NAMESPACE_FIELD]))

		if IsNameSpace(ns) then return ns end
	end

	-- GetFullName4NS
	function GetFullName4NS(ns)
		local info = _NSInfo[ns]

		if info then
			local name = info.Name

			while info and info.NameSpace do
				info = _NSInfo[info.NameSpace]

				if info then name = info.Name.."."..name end
			end

			return name
		end
	end

	------------------------------------
	--- Set the default namespace for the current environment, the class defined in this environment will be stored in this namespace
	-- @name namespace
	-- @class function
	-- <param name="name">the namespace's name list, using "." to split.</param>
	-- <usage>namespace "Widget"</usage>
	------------------------------------
	function namespace(name)
		if name ~= nil and type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: namespace "namespace"]], 2) end

		local ns = SetNameSpace4Env(getfenv(2), name)

		return ns and ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(ns, AttributeTargets.NameSpace)
	end
end

------------------------------------------------------
-- Type
------------------------------------------------------
do
	function IsType(self) return getmetatable(self) == Type end

	function BuildType(ns, onlyClass)
		local allowNil = false

		if ns == nil then
			allowNil = true
		elseif IsType(ns) then
			return ns
		end

		if ns == nil or IsNameSpace(ns) then
			local _type = Type()

			_type.AllowNil = allowNil or nil
			if ns then if onlyClass then _type[-1] = ns else _type[1] = ns end end

			return _type
		else
			error("The type must be combination of nil, struct, enum, interface or class.")
		end
	end

	_UniqueType = setmetatable({}, WEAK_KEY)
	_UniqueWithNilType = setmetatable({}, WEAK_VALUE)

	function GetUniqueType(self)
		if IsType(self) then
			-- No unique for complex type
			if self[-1] or #self ~= 1 then return self end

			if self.AllowNil then
				if _UniqueWithNilType[self[1]] then return _UniqueWithNilType[self[1]] end
				_UniqueWithNilType[self[1]] = self
				return self
			else
				if _UniqueType[self[1]] then return _UniqueType[self[1]] end
				_UniqueType[self[1]] = self
				return self
			end
		else
			return self
		end
	end
end

------------------------------------------------------
-- Documentation
------------------------------------------------------
do
	function getSuperDoc(info, key, dkey)
		if info.SuperClass then
			local sinfo = _NSInfo[info.SuperClass]

			while sinfo do
				if sinfo.Documentation and (sinfo.Documentation[key] or sinfo.Documentation[dkey]) then
					return sinfo.Documentation[key] or sinfo.Documentation[dkey]
				end

				if sinfo.SuperClass then
					sinfo = _NSInfo[sinfo.SuperClass]
				else
					break
				end
			end
		end

		-- Check Interface
		if info.Cache4Interface then
			for _, IF in ipairs(info.Cache4Interface) do
				local sinfo = _NSInfo[IF]

				if sinfo.Documentation and (sinfo.Documentation[key] or sinfo.Documentation[dkey]) then
					return sinfo.Documentation[key] or sinfo.Documentation[dkey]
				end
			end
		end
	end

	function getTargetType(info, name, targetType)
		if targetType == nil then
			-- Find the targetType based on the name
			if name == info.Name then
				targetType = AttributeTargets[info.Type or TYPE_NAMESPACE]
			elseif info.Cache4Event[name] then
				targetType = AttributeTargets.Event
			elseif info.Cache4Property[name] then
				targetType = AttributeTargets.Property
			elseif info.Cache4Method[name] then
				targetType = AttributeTargets.Method
			end
		elseif type(targetType) == "string" then
			targetType = AttributeTargets[targetType]
		elseif type(targetType) ~= "number" then
			targetType = nil
		end

		return targetType
	end

	function SaveDocument(data, name, targetType, owner)
		if not DOCUMENT_ENABLED or type(data) ~= "string" then return end

		local info = _NSInfo[owner]

		if not info then return end

		if not name then name = info.Name end

		-- Check the type
		targetType = getTargetType(info, name, targetType)

		-- Get the head space in the first line and remove it from all lines
		local space = data:match("^%s+")

		if space then data = data:gsub("^%s+", ""):gsub("([\n\r]+)"..space, "%1"):gsub("([\n\r]+)%s+$", "%1") end

		local key = name

		if targetType then key = tostring(targetType) .. name end

		info.Documentation = info.Documentation or {}
		info.Documentation[key] = data
	end

	function GetDocument(owner, name, targetType)
		if not DOCUMENT_ENABLED then return end

		if type(owner) == "string" then owner = GetNameSpace(GetDefaultNameSpace(), owner) end

		local info = _NSInfo[owner]
		if not info then return end

		name = name or info.Name
		if type(name) ~= "string" then return end

		targetType = getTargetType(info, name, targetType)

		local key = targetType and tostring(targetType) .. name or nil

		return info.Documentation and (info.Documentation[key] or info.Documentation[name]) or (targetType ~= "CLASS" and targetType ~= "INTERFACE") and getSuperDoc(info, key, name) or nil
	end

	do
		local _name
		local _owner

		local function parseDoc(data)
			local info = _NSInfo[_owner]
			if _name == info.Name then
				return SaveDocument(data, _name, AttributeTargets[info.Type], _owner)
			else
				return SaveDocument(data, _name, AttributeTargets.Method, _owner)
			end
		end

		function document(name)
			_name = name
			_owner = getfenv(2)[OWNER_FIELD]

			return parseDoc
		end
	end
end

------------------------------------------------------
-- Interface
------------------------------------------------------
do
	_KeyWord4IFEnv = {}

	do
		local Verb2Adj = {
			"(.+)(ed)$",
			"(.+)(able)$",
			"(.+)(ing)$",
			"(.+)(ive)$",
			"(.+)(ary)$",
			"(.+)(al)$",
			"(.+)(ous)$",
			"(.+)(ior)$",
			"(.+)(ful)$",
		}

		local function ParseAdj(str, useIs)
			local noun, adj = str:match("^(.-)(%u%l+)$")

			if noun and adj and #noun > 0 and #adj > 0 then
				for _, pattern in ipairs(Verb2Adj) do
					local head, tail = adj:match(pattern)

					if head and tail and #head > 0 and #tail > 0 then
						local c = head:sub(1, 1)

						if useIs then
							return "^[Ii]s[" .. strupper(c) .. strlower(c).."]" .. head:sub(2) .. "%w*" .. noun .. "$"
						else
							return "^[" .. strupper(c) .. strlower(c).."]" .. head:sub(2) .. "%w*" .. noun .. "$"
						end
					end
				end
			end
		end

		function CloneWithoutOverride(dest, src)
			for key, value in pairs(src) do
				if dest[key] == nil then dest[key] = value end
			end
		end

		function CloneWithoutOverride4Method(dest, src)
			for key, value in pairs(src) do
				if not dest[key] and not key:match("^[%d_]") then dest[key] = src[key] end
			end
		end

		function CloneInterfaceCache(dest, src, cache)
			if not src then return end
			for _, IF in ipairs(src) do
				if not cache[IF] then cache[IF] = true tinsert(dest, IF) end
			end
		end

		function RefreshCache(ns, env)
			local info = _NSInfo[ns]

			-- Cache4Interface
			local cache = CACHE_TABLE()
			wipe(info.Cache4Interface)
			-- superclass interface
			if info.SuperClass then CloneInterfaceCache(info.Cache4Interface, _NSInfo[info.SuperClass].Cache4Interface, cache) end
			-- extend interface
			for _, IF in ipairs(info.ExtendInterface) do CloneInterfaceCache(info.Cache4Interface, _NSInfo[IF].Cache4Interface, cache) end
			-- self interface
			CloneInterfaceCache(info.Cache4Interface, info.ExtendInterface, cache)
			CACHE_TABLE(cache)

			-- Cache4Event
			wipe(info.Cache4Event)
			--- self event
			CloneWithoutOverride(info.Cache4Event, info.Event)
			--- superclass event
			if info.SuperClass then CloneWithoutOverride(info.Cache4Event, _NSInfo[info.SuperClass].Cache4Event) end
			--- extend event
			for _, IF in ipairs(info.ExtendInterface) do CloneWithoutOverride(info.Cache4Event, _NSInfo[IF].Cache4Event) end

			-- Cache4Method
			wipe(info.Cache4Method)
			-- Validate fixedMethods, remove link to parent
			for name, method in pairs(info.Method) do
				if getmetatable(method) then
					while method.Next do
						if getmetatable(method.Next) then
							if method.Next.Owner ~= info.Owner then
								method.Next = nil
								break
							else
								method = method.Next
							end
						else
							-- Remove header 0
							name = name:match("^%d*(.-)$")

							--- superclass method
							if info.SuperClass and _NSInfo[info.SuperClass].Cache4Method[name] == method.Next then
								method.Next = nil
							elseif info.ExtendInterface then
								--- extend method
								for _, IF in ipairs(info.ExtendInterface) do
									if _NSInfo[IF].Cache4Method[name] == method.Next then
										method.Next = nil
										break
									end
								end
							end

							break
						end
					end
				end
			end
			--- self method
			CloneWithoutOverride4Method(info.Cache4Method, info.Method)
			--- superclass method
			if info.SuperClass then CloneWithoutOverride4Method(info.Cache4Method, _NSInfo[info.SuperClass].Cache4Method) end
			--- extend method
			for _, IF in ipairs(info.ExtendInterface) do CloneWithoutOverride4Method(info.Cache4Method, _NSInfo[IF].Cache4Method) end

			-- Cache4Property
			wipe(info.Cache4Property)
			-- Validate the properties
			for name, prop in pairs(info.Property) do
				if prop.Predefined then
					local set = prop.Predefined

					prop.Predefined = nil

					for k, v in pairs(set) do
						if type(k) == "string" then
							k = strlower(k)

							if k == "get" then
								if type(v) == "function" or type(v) == "boolean" then
									prop.Get = v
								elseif type(v) == "string" then
									prop.GetMethod = v
								end
							elseif k == "set" then
								if type(v) == "function" or type(v) == "boolean" then
									prop.Set = v
								elseif type(v) == "string" then
									prop.SetMethod = v
								end
							elseif k == "getmethod" then
								if type(v) == "string" then prop.GetMethod = v end
							elseif k == "setmethod" then
								if type(v) == "string" then prop.SetMethod = v end
							elseif k == "field" then
								if v ~= name then prop.Field = v end
							elseif k == "type" then
								local ok, ret = pcall(BuildType, v)
								if ok then
									prop.Type = GetUniqueType(ret)
								else
									errorhandler(strtrim(ret:match(":%d+:%s*(.-)$") or ret))
								end
							elseif k == "default" then
								prop.Default = v
							elseif k == "event" and type(v) == "string" then
								prop.Event = v
							elseif k == "handler" then
								if type(v) == "string" then
									prop.HandlerName = v
								elseif type(v) == "function" then
									prop.Handler = v
								end
							elseif k == "setter" and type(v) == "number" and floor(v) == v and v > 0 and v <= _NSInfo[Setter].MaxValue then
								prop.Setter = v
							elseif k == "getter" and type(v) == "number" and floor(v) == v and v > 0 and v <= _NSInfo[Getter].MaxValue then
								prop.Getter = v
							end
						end
					end

					-- Validate the default
					if prop.Type and prop.Default ~= nil and prop.Type:GetObjectType(prop.Default) == false then prop.Default = nil end

					-- Clear
					if prop.Get ~= nil then prop.GetMethod = nil end
					if prop.Set ~= nil then prop.SetMethod = nil end

					local uname = name:gsub("^%a", strupper)

					if prop.GetMethod and not info.Cache4Method[prop.GetMethod] then prop.GetMethod = nil end
					if prop.SetMethod and not info.Cache4Method[prop.SetMethod] then prop.SetMethod = nil end

					-- Auto generate GetMethod
					if ( prop.Get == nil or prop.Get == true ) and not prop.GetMethod and prop.Field == nil then
						-- GetMethod
						if info.Cache4Method["get" .. uname] then
							prop.GetMethod = "get" .. uname
						elseif info.Cache4Method["Get" .. uname] then
							prop.GetMethod = "Get" .. uname
						elseif prop.Type and prop.Type:Is(Boolean) then
							-- FlagEnabled -> IsFlagEnabled
							if info.Cache4Method["is" .. uname] then
								prop.GetMethod = "is" .. uname
							elseif info.Cache4Method["Is" .. uname] then
								prop.GetMethod = "Is" .. uname
							else
								-- FlagEnable -> IsEnableFlag
								local pattern = ParseAdj(uname, true)

								if pattern then
									for mname in pairs(info.Cache4Method) do
										if mname:match(pattern) then prop.GetMethod = mname break end
									end
								end
							end
						end
					end

					-- Auto generate SetMethod
					if ( prop.Set == nil or prop.Set == true ) and not prop.SetMethod and prop.Field == nil then
						-- SetMethod
						if info.Cache4Method["set" .. uname] then
							prop.SetMethod = "set" .. uname
						elseif info.Cache4Method["Set" .. uname] then
							prop.SetMethod = "Set" .. uname
						elseif prop.Type and prop.Type:Is(Boolean) then
							-- FlagEnabled -> EnableFlag, FlagDisabled -> DisableFlag
							local pattern = ParseAdj(uname)

							if pattern then
								for mname in pairs(info.Cache4Method) do
									if mname:match(pattern) then prop.SetMethod = mname break end
								end
							end
						end
					end

					-- Validate the Event
					if prop.Event and not info.Cache4Event[prop.Event] then prop.Event = nil end

					-- Validate the Handler
					if prop.HandlerName then prop.Handler = info.Cache4Method[prop.HandlerName] end

					-- Validate the Setter
					if prop.Setter then
						prop.SetClone = Reflector.ValidateFlags(Setter.Clone, prop.Setter) or nil
						prop.SetDeepClone = Reflector.ValidateFlags(Setter.DeepClone, prop.Setter) or nil

						if prop.Set == nil and not prop.SetMethod then
							if Reflector.ValidateFlags(Setter.Retain, prop.Setter) and prop.Type and #(prop.Type) > 0 then
								for _, ty in ipairs(prop.Type) do
									local tinfo = _NSInfo[ty]

									if tinfo.Type == TYPE_CLASS or tinfo.Type == TYPE_INTERFACE then
										prop.SetRetain = true
										break
									end
								end
							end

							if prop.Get == nil and not prop.GetMethod then
								if Reflector.ValidateFlags(Setter.Weak, prop.Setter) then prop.SetWeak = true end
							end
						end

						prop.Setter = nil
					end

					-- Validate the Getter
					if prop.Getter then
						prop.GetDeepClone = Reflector.ValidateFlags(Getter.DeepClone, prop.Getter) or nil
						prop.GetClone = Reflector.ValidateFlags(Getter.Clone, prop.Getter) or prop.GetDeepClone

						prop.Getter = nil
					end

					-- Auto generate Field or methods
					if prop.Set == nil and not prop.SetMethod and prop.Get == nil and not prop.GetMethod then
						local field = prop.Field or "_" .. info.Name:match("^_*(.-)$") .. "_" .. uname

						if set.Synthesize then
							local getName, setName

							if set.Synthesize == __Synthesize__.NameCase.Pascal then
								getName, setName = "Get" .. uname, "Set" .. uname
							elseif set.Synthesize == __Synthesize__.NameCase.Camel then
								getName, setName = "get" .. uname, "set" .. uname
							end

							-- Generate getMethod
							local gbody = CACHE_TABLE()
							if prop.Default ~= nil then
								tinsert(gbody, [[local field, default = ...]])
							else
								tinsert(gbody, [[local field = ...]])
							end
							tinsert(gbody, [[return function (self)]])
							tinsert(gbody, [[local value]])
							if prop.SetWeak then
								tinsert(gbody, [[value = rawget(self, "__WeakFields")]])
								tinsert(gbody, [[if type(value) == "table" then]])
								tinsert(gbody, [[value = value[field] ]])
								tinsert(gbody, [[else]])
								tinsert(gbody, [[value = nil]])
								tinsert(gbody, [[end]])
							else
								tinsert(gbody, [[value = rawget(self, field)]])
							end
							if prop.Default ~= nil then tinsert(gbody, [[if value == nil then value = default end]]) end
							if prop.GetClone then
								if prop.GetDeepClone then
									tinsert(gbody, [[value = clone(value, true)]])
								else
									tinsert(gbody, [[value = clone(value)]])
								end
							end
							tinsert(gbody, [[return value]])
							tinsert(gbody, [[end]])

							info.Method[getName] = loadstring(tblconcat(gbody, "\n"))(field, prop.Default)

							-- Generate setMethod
							wipe(gbody)
							if prop.Default ~= nil then
								if prop.Handler then
									tinsert(gbody, [[local field, default, handler = ...]])
								else
									tinsert(gbody, [[local field, default = ...]])
								end
							elseif prop.Handler then
								tinsert(gbody, [[local field, handler = ...]])
							else
								tinsert(gbody, [[local field = ...]])
							end
							tinsert(gbody, [[return function (self, value)]])
							if prop.SetClone or prop.SetDeepClone then
								if prop.SetDeepClone then
									tinsert(gbody, [[value = clone(value, true)]])
								else
									tinsert(gbody, [[value = clone(value)]])
								end
							end
							tinsert(gbody, [[local container = self]])
							if prop.SetWeak then
								tinsert(gbody, [[container = rawget(self, "__WeakFields")]])
								tinsert(gbody, [[if type(container) ~= "table" then]])
								tinsert(gbody, [[	container = setmetatable({}, WEAK_VALUE)]])
								tinsert(gbody, [[	rawset(self, "__WeakFields", container)]])
								tinsert(gbody, [[end]])
							end
							tinsert(gbody, [[local old = rawget(container, field)]])
							if prop.Default ~= nil then tinsert(gbody, [[if old == nil then old = default end]]) end
							tinsert(gbody, [[if old == value then return end]])
							tinsert(gbody, [[rawset(container, field, value)]])
							if prop.SetRetain then
								tinsert(gbody, [[if type(old) == "table" and getmetatable(old) and old ~= default then]])
								tinsert(gbody, [[DisposeObject(old)]])
								tinsert(gbody, [[old = nil]])
								tinsert(gbody, [[end]])
							end
							if prop.Handler then
								tinsert(gbody, ([[local ok, err = pcall(handler, self, value, old, "%s")]]):format(name))
								tinsert(gbody, [[if not ok then errorhandler(err) end]])
							end
							if prop.Event then
								tinsert(gbody, [[local evt = rawget(self, "__Events")]])
								tinsert(gbody, ([[evt = evt and rawget(evt, "%s")]]):format(prop.Event))
								tinsert(gbody, ([[if evt then return evt(self, value, old, "%s") end]]):format(name))
							end
							tinsert(gbody, [[end]])
							if prop.Default ~= nil then
								info.Method[setName] = loadstring(tblconcat(gbody, "\n"))(field, prop.Default, prop.Handler)
							else
								info.Method[setName] = loadstring(tblconcat(gbody, "\n"))(field, prop.Handler)
							end

							CACHE_TABLE(gbody)

							-- Keep in the definition environment
							setfenv(info.Method[getName], SYNTHESIZE_ENV)
							setfenv(info.Method[setName], SYNTHESIZE_ENV)

							info.Cache4Method[getName] = info.Method[getName]
							info.Cache4Method[setName] = info.Method[setName]

							prop.GetMethod = getName
							prop.SetMethod = setName
						else
							prop.Field = field
						end
					end

					-- Auto generate Default
					if prop.Type and not prop.Type:Is(nil) and prop.Default == nil and #(prop.Type) == 1 then
						local info = _NSInfo[prop.Type[1]]

						if info and (info.Type == TYPE_STRUCT or info.Type == TYPE_ENUM) then prop.Default = info.Default end
					end
				end
			end
			--- self property
			CloneWithoutOverride(info.Cache4Property, info.Property)
			--- superclass property
			if info.SuperClass then CloneWithoutOverride(info.Cache4Property, _NSInfo[info.SuperClass].Cache4Property) end
			--- extend property
			for _, IF in ipairs(info.ExtendInterface) do CloneWithoutOverride(info.Cache4Property, _NSInfo[IF].Cache4Property) end

			-- Requires
			if info.Type == TYPE_INTERFACE then
				for _, IF in ipairs(info.ExtendInterface) do
					if _NSInfo[IF].Requires then
						info.Requires = info.Requires or {}
						CloneWithoutOverride(info.Requires, _NSInfo[IF].Requires)
					end
				end
			end

			-- Refresh branch
			if info.ChildClass then
				for subcls in pairs(info.ChildClass) do RefreshCache(subcls) end
			elseif info.ExtendClass then
				for subcls in pairs(info.ExtendClass) do RefreshCache(subcls) end
			end
		end

		function GetSuperProperty(cls, name)
			local info = _NSInfo[cls]

			if info.SuperClass and _NSInfo[info.SuperClass].Cache4Property[name] then
				return _NSInfo[info.SuperClass].Cache4Property[name]
			end

			if info.ExtendInterface then
				for _, IF in ipairs(info.ExtendInterface) do
					if _NSInfo[IF].Cache4Property[name] then return _NSInfo[IF].Cache4Property[name] end
				end
			end
		end

		function GetSuperMethod(cls, name)
			local info = _NSInfo[cls]

			if info.SuperClass and _NSInfo[info.SuperClass].Cache4Method[name] then
				return _NSInfo[info.SuperClass].Cache4Method[name]
			end

			if info.ExtendInterface then
				for _, IF in ipairs(info.ExtendInterface) do
					if _NSInfo[IF].Cache4Method[name] then return _NSInfo[IF].Cache4Method[name] end
				end
			end
		end
	end

	-- metatable for interface's env
	_MetaIFEnv = {}
	_MetaIFDefEnv = {}
	do
		_MetaIFEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			-- Check keywords
			if _KeyWord4IFEnv[key] then return _KeyWord4IFEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					value = info.NameSpace
					rawset(self, key, value)
					return value
				elseif info.NameSpace[key] then
					value = info.NameSpace[key]
					rawset(self, key, value)
					return value
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						value = ns
						rawset(self, key, value)
						return value
					elseif ns[key] then
						value = ns[key]
						rawset(self, key, value)
						return value
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then rawset(self, key, value) return value end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same interface
			value = info.Method[key]
			if value then rawset(self, key, value) return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then rawset(self, key, value) return value end
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]
			if value ~= nil then rawset(self, key, value) return value end
		end

		-- Don't cache item in definition to reduce some one time access feature
		_MetaIFDefEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			-- Check keywords
			if _KeyWord4IFEnv[key] then return _KeyWord4IFEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					return info.NameSpace
				elseif info.NameSpace[key] then
					return info.NameSpace[key]
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						return ns
					elseif ns[key] then
						return ns[key]
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then return value end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same interface
			value = info.Method[key]
			if value then return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then return value end
			end

			-- Check Base
			return self[BASE_ENV_FIELD][key]
		end

		_MetaIFDefEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4IFEnv[key] then error(("'%s' is a keyword."):format(key), 2) end

			if key == info.Name then
				-- No attribute for the initializer
				if type(value) == "function" then
					info.Initializer = value
					return
				else
					error(("'%s' must be a function as the Initializer."):format(key), 2)
				end
			end

			if key == DISPOSE_METHOD then
				if type(value) == "function" then
					info[DISPOSE_METHOD] = value
					return
				else
					error(("'%s' must be a function as dispose method."):format(DISPOSE_METHOD), 2)
				end
			end

			if type(key) == "string" and type(value) == "function" then
				-- Don't save to environment until need it
				if IsLocal() then
					return SaveFixedMethod(self[LOCAL_ENV_FIELD], key, value, info.Owner)
				else
					return SaveFixedMethod(info.Method, key, value, info.Owner)
				end
			end

			rawset(self, key, value)
		end
	end

	function IsExtend(IF, cls)
		if not IF or not cls or not _NSInfo[IF] or _NSInfo[IF].Type ~= TYPE_INTERFACE or not _NSInfo[cls] then return false end

		if IF == cls then return true end

		if _NSInfo[cls].Cache4Interface then
			for _, pIF in ipairs(_NSInfo[cls].Cache4Interface) do
				if pIF == IF then return true end
			end
		end

		return false
	end

	------------------------------------
	--- Create interface in currect environment's namespace or default namespace
	------------------------------------
	function interface(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then error([[Usage: interface "interfacename"]], 2) end
		local fenv = getfenv(2)
		local ns = not IsLocal() and GetNameSpace4Env(fenv) or nil

		-- Create interface or get it
		local IF

		if ns then
			IF = BuildNameSpace(ns, name)

			if _NSInfo[IF] then
				if _NSInfo[IF].Type and _NSInfo[IF].Type ~= TYPE_INTERFACE then
					error(("%s is existed as %s, not interface."):format(name, tostring(_NSInfo[IF].Type)), 2)
				end
			end
		else
			IF = fenv[name]

			if not (IF and _NSInfo[IF] and _NSInfo[IF].NameSpace == nil and _NSInfo[IF].Type == TYPE_INTERFACE ) then
				IF = BuildNameSpace(nil, name)
			end
		end

		if not IF then error("No interface is created.", 2) end

		-- Build interface
		info = _NSInfo[IF]

		-- Check if the class is final
		if info.IsFinal then error("The interface is final, can't be re-defined.", 2) end

		info.Type = TYPE_INTERFACE
		info.NameSpace = ns
		info.Event = info.Event or {}
		info.Property = info.Property or {}
		info.Method = info.Method or {}

		-- save interface to the environment
		rawset(fenv, name, IF)

		-- Generate the interface environment
		local interfaceEnv = setmetatable({
			[OWNER_FIELD] = IF,
			[BASE_ENV_FIELD] = fenv,
		}, _MetaIFDefEnv)

		-- Set namespace
		SetNameSpace4Env(interfaceEnv, IF)

		-- Cache
		info.Cache4Event = info.Cache4Event or {}
		info.Cache4Property = info.Cache4Property or {}
		info.Cache4Method = info.Cache4Method or {}
		info.Cache4Interface = info.Cache4Interface or {}

		-- ExtendInterface
		info.ExtendInterface = info.ExtendInterface or {}

		-- Import
		info.Import4Env = info.Import4Env or {}

		-- Set the environment to interface's environment
		setfenv(2, interfaceEnv)

		-- No super target for interface
		return ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Interface)
	end

	------------------------------------
	--- Set the current interface' extended interface
	-- @name extend
	-- @class function
	-- <param name="name">the namespace's name list, using "." to split.</param>
	-- <usage>extend "System.IFSocket"</usage>
	------------------------------------
	function extend_IF(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: extend "namespace.interfacename"]], 2) end

		if type(name) == "string" and name:find("%.%s*%.") then error("The namespace 's name can't have empty string between dots.", 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local IF

		if type(name) == "string" then
			IF = GetNameSpace(info.NameSpace, name) or env[name]

			if not IF then
				for subname in name:gmatch("[_%w]+") do
					IF = IF and IF[subname] or env[subname]

					if not IsNameSpace(IF) then
						error(("No interface is found with the name : %s"):format(name), 2)
					end
				end
			end
		else
			IF = name
		end

		local IFInfo = _NSInfo[IF]

		if not IFInfo or IFInfo.Type ~= TYPE_INTERFACE then
			error("Usage: extend (interface) : 'interface' - interface expected", 2)
		elseif IFInfo.NonInheritable then
			error(("%s is non-inheritable."):format(tostring(IF)), 2)
		end

		if IsExtend(info.Owner, IF) then error(("%s is extended from %s, can't be used here."):format(tostring(IF), tostring(info.Owner)), 2) end

		IFInfo.ExtendClass = IFInfo.ExtendClass or {}
		IFInfo.ExtendClass[info.Owner] = true

		info.ExtendInterface = info.ExtendInterface or {}

		-- Check if IF is already extend by extend tree
		for _, pIF in ipairs(info.ExtendInterface) do if IsExtend(IF, pIF) then return extend_IF end end

		-- Clear
		for i = #(info.ExtendInterface), 1, -1 do
			if IsExtend(info.ExtendInterface[i], IF) then tremove(info.ExtendInterface, i) end
		end

		tinsert(info.ExtendInterface, IF)

		return extend_IF
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	------------------------------------
	function import_IF(name)
		if type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: import "namespaceA.namespaceB"]], 2) end

		if type(name) == "string" and name:find("%.%s*%.") then error("The namespace 's name can't have empty string between dots.", 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then error(("No namespace is found with name : %s"):format(name), 2) end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do if v == ns then return end end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- Add an event for current interface
	------------------------------------
	function event_IF(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: event "eventName"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		info.Event[name] = info.Event[name] or Event(name)

		return ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(info.Event[name], AttributeTargets.Event, nil, info.Owner, name)
	end

	function SetPropertyWithSet(info, name, set)
		if type(set) ~= "table" then error([=[Usage: property "Name" { -- Property Definition }]=], 2) end

		local prop = info.Property[name] or {}
		info.Property[name] = prop

		wipe(prop)

		prop.Name = name
		prop.Predefined = set

		return ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(prop, AttributeTargets.Property, GetSuperProperty(info.Owner, name), info.Owner, name)
	end

	------------------------------------
	--- set a propert to the current interface
	------------------------------------
	function property_IF(name)
		if type(name) ~= "string" or strtrim(name:match("[_%w]+")) == "" then error([=[Usage: property "Name" { -- Property Definition }]=], 2) end

		return function(set) return SetPropertyWithSet(_NSInfo[getfenv(2)[OWNER_FIELD]], name:match("[_%w]+"), set) end
	end

	------------------------------------
	--- End the interface's definition and restore the environment
	------------------------------------
	function endinterface(name)
		if ATTRIBUTE_INSTALLED then __Attribute__._ClearPreparedAttributes() end

		if type(name) ~= "string" or name:find("%.") then error([[Usage: endinterface "interfacename"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			setmetatable(env, _MetaIFEnv)
			setfenv(2, env[BASE_ENV_FIELD])
			RefreshCache(info.Owner, env)
		else
			error(("%s is not closed."):format(info.Name), 2)
		end
	end

	function require_IF(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: require "namespace.interfacename|classname"]], 2) end

		if type(name) == "string" and name:find("%.%s*%.") then error("The namespace's name can't have empty string between dots.", 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local IF

		if type(name) == "string" then
			IF = GetNameSpace(info.NameSpace, name) or env[name]

			if not IF then
				for subname in name:gmatch("[_%w]+") do
					IF = IF and IF[subname] or env[subname]

					if not IsNameSpace(IF) then error(("No interface|class is found with the name : %s"):format(name), 2) end
				end
			end
		else
			IF = name
		end

		local IFInfo = _NSInfo[IF]

		if not IFInfo or (IFInfo.Type ~= TYPE_INTERFACE and IFInfo.Type ~= TYPE_CLASS) then
			error("Usage: require (interface|class) : interface or class expected", 2)
		elseif IFInfo.NonInheritable then
			error(("%s is non-inheritable."):format(tostring(IF)), 2)
		end

		info.Requires = info.Requires or {}
		info.Requires[IF] = true

		return require_IF
	end

	_KeyWord4IFEnv.extend = extend_IF
	_KeyWord4IFEnv.import = import_IF
	_KeyWord4IFEnv.event = event_IF
	_KeyWord4IFEnv.property = property_IF
	_KeyWord4IFEnv.endinterface = endinterface
	_KeyWord4IFEnv.require = require_IF

	_KeyWord4IFEnv.doc = document
end

------------------------------------------------------
-- Class
------------------------------------------------------
do
	_SuperIndex = "Super"
	_ThisIndex = "This"

	_KeyWord4ClsEnv = {}

	_KeyMeta = {
		__add = true,		-- a + b
		__sub = true,		-- a - b
		__mul = true,		-- a * b
		__div = true,		-- a / b
		__mod = true,		-- a % b
		__pow = true,		-- a ^ b
		__unm = true,		-- - a
		__concat = true,	-- a..b
		__len = true,		-- #a
		__eq = true,		-- a == b
		__lt = true,		-- a < b
		__le = true,		-- a <= b
		__index = false,	-- return a[b]
		__newindex = false,	-- a[b] = v
		__call = true,		-- a()
		-- __gc = false,		-- dispose a
		__tostring = true,	-- tostring(a)
		__exist = true,		-- ClassName(...)	-- return object if existed
	}

	--------------------------------------------------
	-- Init & Dispose System
	--------------------------------------------------
	do
		function InitObjectWithInterface(cls, obj)
			local ok, msg, info

			for _, IF in ipairs(_NSInfo[cls].Cache4Interface) do
				info = _NSInfo[IF]
				if info.Initializer then
					ok, msg = pcall(info.Initializer, obj)

					if not ok then errorhandler(msg) end
				end
			end
		end

		------------------------------------
		--- Dispose this object
		-- @name DisposeObject
		-- @class function
		------------------------------------
		function DisposeObject(self)
			local objCls = getmetatable(self)
			local IF, info, disfunc

			info = objCls and _NSInfo[objCls]

			if not info then return end

			-- No dispose to a unique object
			if info.UniqueObject then return end

			for i = #(info.Cache4Interface), 1, -1 do
				IF = info.Cache4Interface[i]
				disfunc = _NSInfo[IF][DISPOSE_METHOD]

				if disfunc then pcall(disfunc, self) end
			end

			-- Call Class Dispose
			while objCls and _NSInfo[objCls] do
				disfunc = _NSInfo[objCls][DISPOSE_METHOD]

				if disfunc then pcall(disfunc, self) end

				objCls = _NSInfo[objCls].SuperClass
			end

			-- Clear the table
			wipe(self)
			rawset(self, "Disposed", true)
		end

		SYNTHESIZE_ENV.DisposeObject = DisposeObject
	end

	-- metatable for class's env
	_MetaClsEnv = {}
	_MetaClsDefEnv = {}
	do
		_MetaClsEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			if key == _SuperIndex then
				if info.SuperClass then
					local superInfo = _NSInfo[info.SuperClass]
					value = superInfo.SuperAlias

					if not value then
						-- Generate super alias when need
						superInfo.SuperAlias = newproxy(_SuperAlias)
						_SuperMap[superInfo.SuperAlias] = superInfo

						value = superInfo.SuperAlias
					end

					rawset(self, _SuperIndex, value)
					return value
				else
					error("No super class for the class.", 2)
				end
			end

			if key == _ThisIndex then
				value = info.SuperAlias

				if not value then
					-- Generate super alias when need
					info.SuperAlias = newproxy(_SuperAlias)
					_SuperMap[info.SuperAlias] = info

					value = info.SuperAlias
				end

				rawset(self, _ThisIndex, value)
				return value
			end

			-- Check keywords
			if _KeyWord4ClsEnv[key] then return _KeyWord4ClsEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					value = info.NameSpace
					rawset(self, key, value)
					return value
				elseif info.NameSpace[key] then
					value = info.NameSpace[key]
					rawset(self, key, value)
					return value
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						value = ns
						rawset(self, key, value)
						return value
					elseif ns[key] then
						value = ns[key]
						rawset(self, key, value)
						return value
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then rawset(self, key, value) return value end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same class
			value = info.Method[key]
			if value then rawset(self, key, value) return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then rawset(self, key, value) return value end
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]
			if value ~= nil then rawset(self, key, value) return value end
		end

		_MetaClsDefEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			if key == _SuperIndex then
				if info.SuperClass then
					local superInfo = _NSInfo[info.SuperClass]
					value = superInfo.SuperAlias

					if not value then
						-- Generate super alias when need
						superInfo.SuperAlias = newproxy(_SuperAlias)
						_SuperMap[superInfo.SuperAlias] = superInfo

						value = superInfo.SuperAlias
					end

					rawset(self, _SuperIndex, value)
					return value
				else
					error("No super class for the class.", 2)
				end
			end

			if key == _ThisIndex then
				value = info.SuperAlias

				if not value then
					-- Generate super alias when need
					info.SuperAlias = newproxy(_SuperAlias)
					_SuperMap[info.SuperAlias] = info

					value = info.SuperAlias
				end

				rawset(self, _ThisIndex, value)
				return value
			end

			-- Check keywords
			if _KeyWord4ClsEnv[key] then return _KeyWord4ClsEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					return info.NameSpace
				elseif info.NameSpace[key] then
					return info.NameSpace[key]
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						return ns
					elseif ns[key] then
						return ns[key]
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then return value end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same class
			value = info.Method[key]
			if value then return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then return value end
			end

			-- Check Base
			return self[BASE_ENV_FIELD][key]
		end

		_MetaClsDefEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4ClsEnv[key] then error(("'%s' is a keyword."):format(key), 2) end

			if key == info.Name then
				if type(value) == "function" then
					return SaveFixedMethod(info, "Constructor", value, info.Owner, AttributeTargets and AttributeTargets.Constructor or nil)
				else
					error(("'%s' must be a function as constructor."):format(key), 2)
				end
			end

			if key == DISPOSE_METHOD then
				if type(value) == "function" then
					info[DISPOSE_METHOD] = value
					return
				else
					error(("'%s' must be a function as dispose method."):format(DISPOSE_METHOD), 2)
				end
			end

			if _KeyMeta[key] ~= nil then
				if type(value) == "function" then
					local rMeta = _KeyMeta[key] and key or "_"..key
					local oldValue = info.MetaTable["0" .. rMeta] or info.MetaTable[rMeta]

					SaveFixedMethod(info.MetaTable, rMeta, value, info.Owner)

					return UpdateMeta4Children(rMeta, info.ChildClass, oldValue, info.MetaTable["0" .. rMeta] or info.MetaTable[rMeta])
				else
					error(("'%s' must be a function."):format(key), 2)
				end
			end

			if type(key) == "string" and type(value) == "function" then
				-- Don't save to environment until need it
				if IsLocal() then
					return SaveFixedMethod(self[LOCAL_ENV_FIELD], key, value, info.Owner)
				else
					return SaveFixedMethod(info.Method, key, value, info.Owner)
				end
			end

			rawset(self, key, value)
		end
	end

	function IsChildClass(cls, child)
		if not cls or not child or not _NSInfo[cls] or _NSInfo[cls].Type ~= TYPE_CLASS or not _NSInfo[child] or _NSInfo[child].Type ~= TYPE_CLASS then return false end

		if cls == child then return true end

		local info = _NSInfo[child]

		while info and info.SuperClass and info.SuperClass ~= cls do info = _NSInfo[info.SuperClass] end

		if info and info.SuperClass == cls then return true end

		return false
	end

	function UpdateMeta4Child(meta, cls, pre, now)
		if pre == now then return end

		local info = _NSInfo[cls]
		local rMeta = "0" .. meta

		if not info.MetaTable[meta] then
			-- simple clone
			SaveFixedMethod(info.MetaTable, meta, now, cls)
			UpdateMeta4Children(meta, info.ChildClass, pre, now)
		elseif not info.MetaTable[rMeta] then
			-- mean not fixed method, can't make link on it
			if info.MetaTable[meta] == pre then
				info.MetaTable[meta] = nil

				SaveFixedMethod(info.MetaTable, meta, now, cls)
				UpdateMeta4Children(meta, info.ChildClass, pre, now)
			end
		else
			-- Update the fixed method link
			local fixedMethod = info.MetaTable[rMeta]

			if fixedMethod == pre then
				info.MetaTable[rMeta] = now
				UpdateMeta4Children(meta, info.ChildClass, pre, now)
			else
				while getmetatable(fixedMethod) and fixedMethod.Owner == cls and fixedMethod.Next ~= pre do fixedMethod = fixedMethod.Next end

				if getmetatable(fixedMethod) and fixedMethod.Next == pre then fixedMethod.Next = now end
			end
		end
	end

	function UpdateMeta4Children(meta, sub, pre, now)
		if sub and pre ~= now then for cls in pairs(sub) do UpdateMeta4Child(meta, cls, pre, now) end end
	end

	function TrySetProperty(self, name, value) self[name] = value end

	function UpdateMetaTable4Cls(cls, update)
		local info = _NSInfo[cls]
		local MetaTable = info.MetaTable

		local Cache4Event = info.Cache4Event
		local Cache4Property = info.Cache4Property
		local Cache4Method = info.Cache4Method

		local DISPOSE_METHOD = DISPOSE_METHOD
		local type = type
		local rawget = rawget
		local rawset = rawset
		local error = error
		local tostring = tostring
		local clone = CloneObj

		local isCached = info.AutoCache or false

		if update then MetaTable.__index = nil end

		MetaTable.__metatable = cls

		MetaTable.__index = MetaTable.__index or function(self, key)
			local oper

			-- Dispose Method
			if key == DISPOSE_METHOD then return DisposeObject end

			-- Property Get
			oper = Cache4Property[key]
			if oper then
				local value

				if oper.Get then
					value = oper.Get(self)
				elseif oper.GetMethod then
					local func = rawget(self, oper.GetMethod)
					if type(func) == "function" then
						value = func(self)
					else
						value = Cache4Method[oper.GetMethod](self)
					end
				elseif oper.Field then
					if oper.SetWeak then
						value = rawget(self, "__WeakFields")
						if type(value) == "table" then
							value = value[oper.Field]
						else
							value = nil
						end
					else
						value = rawget(self, oper.Field)
					end
				elseif oper.Default == nil then
					error(("%s can't be read."):format(tostring(key)),2)
				end

				if value == nil then value = oper.Default end

				if oper.GetClone then value = clone(value, oper.GetDeepClone) end

				return value
			end

			-- Method Get
			oper = Cache4Method[key]
			if oper then
				if isCached then
					rawset(self, key, oper)
					return oper
				else
					return oper
				end
			end

			-- Events
			if Cache4Event[key] then
				oper = rawget(self, "__Events")
				if type(oper) ~= "table" then
					oper = {}
					rawset(self, "__Events", oper)
				end

				-- No more check
				if oper[key] then
					return oper[key]
				else
					oper[key] = EventHandler(Cache4Event[key], self)
					return oper[key]
				end
			end

			-- Custom index metametods
			oper = MetaTable["___index"]
			if oper then
				if type(oper) == "function" or getmetatable(oper) == FixedMethod then
					return oper(self, key)
				elseif type(oper) == "table" then
					return oper[key]
				end
			end
		end

		MetaTable.__newindex = MetaTable.__newindex or function(self, key, value)
			local oper

			-- Property Set
			oper = Cache4Property[key]
			if oper then
				if oper.Type then value = oper.Type:Validate(value, key, key, 2) end
				if oper.SetClone then value = clone(value, oper.SetDeepClone) end

				if oper.Set then
					return oper.Set(self, value)
				elseif oper.SetMethod then
					oper = oper.SetMethod
					local func = rawget(self, oper)
					if type(func) == "function" then
						return func(self, value)
					else
						return Cache4Method[oper](self, value)
					end
				elseif oper.Field then
					-- Check container
					local container = self
					if oper.SetWeak then
						container = rawget(self, "__WeakFields")
						if type(container) ~= "table" then
							container = setmetatable({}, WEAK_VALUE)
							rawset(self, "__WeakFields", container)
						end
					end

					-- Check old value
					local old = rawget(container, oper.Field)
					if old == nil then old = oper.Default end
					if old == value then return end -- ?should I compare it with fields?

					-- Set the value
					rawset(container, oper.Field, value)

					-- Dispose old
					if oper.SetRetain and old and old ~= oper.Default then
						DisposeObject(old)
						old = nil
					end

					-- Call handler
					if oper.Handler then
						local ok, err = pcall(oper.Handler, self, value, old, key)

						if not ok then errorhandler(err) end
					end

					-- Fire event
					if oper.Event then
						-- Fire the event
						local evt = rawget(self, "__Events")
						evt = evt and rawget(evt, oper.Event)
						if evt then return evt(self, value, old, key) end
					end

					return
				else
					error(("%s can't be written."):format(tostring(key)), 2)
				end
			end

			-- Events
			if Cache4Event[key] then
				oper = rawget(self, "__Events")
				if type(oper) ~= "table" then
					oper = {}
					rawset(self, "__Events", oper)
				end

				if value == nil and not oper[key] then return end

				if not oper[key] then oper[key] = EventHandler(Cache4Event[key], self) end
				oper = oper[key]

				if value == nil or type(value) == "function" then
					oper.Handler = value
					return
				elseif type(value) == "table" and Reflector.ObjectIsClass(value, EventHandler) then
					return oper:Copy(value)
				else
					error("Can't set this value to the event handler.", 2)
				end
			end

			-- Custom newindex metametods
			oper = MetaTable["___newindex"]
			if oper and (type(oper) == "function" or getmetatable(oper) == FixedMethod) then
				return oper(self, key, value)
			end

			rawset(self, key, value)			-- Other key can be set as usual
		end
	end

	-- Init the object with class's constructor
	function Class1Obj(cls, obj, ...)
		local info = _NSInfo[cls]
		local count = select('#', ...)
		local initTable = select(1, ...)

		if not ( count == 1 and type(initTable) == "table" and getmetatable(initTable) == nil ) then initTable = nil end

		while info do
			if not info.Constructor then
				info = info.SuperClass and _NSInfo[info.SuperClass]
			elseif type(info.Constructor) == "function" then
				return info.Constructor(obj, ...)
			elseif getmetatable(info.Constructor) == FixedMethod then
				local fixedMethod = info.Constructor
				local noArgMethod = nil

				while getmetatable(fixedMethod) do
					fixedMethod.Thread = nil

					if #fixedMethod == 0 and initTable then
						noArgMethod = noArgMethod or fixedMethod
					elseif fixedMethod:MatchArgs(obj, ...) then
						if fixedMethod.Thread then
							return fixedMethod.Method(select(2, resume(fixedMethod.Thread, false)))
						else
							return fixedMethod.Method(obj, ...)
						end
					elseif fixedMethod.Thread then
						-- Remove argument container
						resume(fixedMethod.Thread, false)
						fixedMethod.Thread = nil
					end

					fixedMethod = fixedMethod.Next
				end

				if noArgMethod then
					-- No arguments method can still using init table
					noArgMethod.Method(obj)
					break
				end

				if type(fixedMethod) == "function" then
					return fixedMethod(obj, ...)
				else
					error(("%s has no constructor support such arguments"):format(tostring(cls)), 2)
				end
			end
		end

		-- No constructor or constructor with no arguments, so try init table
		if initTable then
			for name, value in pairs(initTable) do
				local ok, msg = pcall(TrySetProperty, obj, name, value)

				if not ok then
					errorhandler(strtrim(msg:match(":%d+:%s*(.-)$") or msg))
				end
			end
		end
	end

	-- The cache for constructor parameters
	function Class2Obj(cls, ...)
		local info = _NSInfo[cls]

		-- Check if the class is unique and already created one object to be return
		if getmetatable(info.UniqueObject) then
			-- Init the obj with new arguments
			Class1Obj(cls, info.UniqueObject, ...)

			-- Don't think there would be interfaces for the unique class, just for safe
			InitObjectWithInterface(cls, info.UniqueObject)

			return info.UniqueObject
		end

		-- Check if this class has __exist so no need to create again.
		if info.MetaTable.__exist then
			local ok, obj = pcall(info.MetaTable.__exist, ...)

			if ok and getmetatable(obj) == cls then return obj end
		end

		-- Create new object
		local obj = setmetatable({}, info.MetaTable)

		local ok, ret = pcall(Class1Obj, cls, obj, ...)

		if not ok then DisposeObject(obj) error(ret, 2) end

		InitObjectWithInterface(cls, obj)

		if info.UniqueObject then info.UniqueObject = obj end

		return obj
	end

	------------------------------------
	--- Create class in currect environment's namespace or default namespace
	------------------------------------
	function class(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then error([[Usage: class "classname"]], 2) end

		local fenv = getfenv(2)
		local ns = not IsLocal() and GetNameSpace4Env(fenv) or nil

		-- Create class or get it
		local cls

		if ns then
			cls = BuildNameSpace(ns, name)

			if _NSInfo[cls] then
				if _NSInfo[cls].Type and _NSInfo[cls].Type ~= TYPE_CLASS then
					error(("%s is existed as %s, not class."):format(name, tostring(_NSInfo[cls].Type)), 2)
				end
			end
		else
			cls = fenv[name]

			if not ( cls and _NSInfo[cls] and _NSInfo[cls].NameSpace == nil and _NSInfo[cls].Type == TYPE_CLASS ) then
				cls = BuildNameSpace(nil, name)
			end
		end

		if not cls then error("No class is created.", 2) end

		-- Build class
		info = _NSInfo[cls]

		-- Check if the class is final
		if info.IsFinal then error("The class is final, can't be re-defined.", 2) end

		info.Type = TYPE_CLASS
		info.NameSpace = ns
		info.Event = info.Event or {}
		info.Property = info.Property or {}
		info.Method = info.Method or {}

		-- save class to the environment
		rawset(fenv, name, cls)

		local classEnv = setmetatable({
			[OWNER_FIELD] = cls,
			[BASE_ENV_FIELD] = fenv,
		}, _MetaClsDefEnv)

		-- Set namespace
		SetNameSpace4Env(classEnv, cls)

		-- Cache
		info.Cache4Event = info.Cache4Event or {}
		info.Cache4Property = info.Cache4Property or {}
		info.Cache4Method = info.Cache4Method or {}
		info.Cache4Interface = info.Cache4Interface or {}

		-- ExtendInterface
		info.ExtendInterface = info.ExtendInterface or {}

		-- Import
		info.Import4Env = info.Import4Env or {}

		-- MetaTable
		info.MetaTable = info.MetaTable or {}

		if ATTRIBUTE_INSTALLED then
			local isCached = info.AutoCache or false

			__Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Class, info.SuperClass)

			-- So, the __index need re-build
			if not isCached and info.AutoCache then info.MetaTable.__index = nil end
		end

		UpdateMetaTable4Cls(cls)

		-- Set the environment to class's environment
		setfenv(2, classEnv)
	end

	------------------------------------
	--- Set the current class' super class
	------------------------------------
	function inherit_Cls(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: inherit "namespace.classname"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		local superCls

		if type(name) == "string" then
			superCls = GetNameSpace(info.NameSpace, name) or env[name]

			if not superCls then
				for subname in name:gmatch("[_%w]+") do
					if not superCls then
						superCls = env[subname]
					else
						superCls = superCls[subname]
					end

					if not IsNameSpace(superCls) then error(("No class is found with the name : %s"):format(name), 2) end
				end
			end
		else
			superCls = name
		end

		local superInfo = _NSInfo[superCls]

		if not superInfo or superInfo.Type ~= TYPE_CLASS then error("Usage: inherit (class) : 'class' - class expected", 2) end
		if superInfo.NonInheritable then error(("%s is non-inheritable."):format(tostring(superCls)), 2) end
		if IsChildClass(info.Owner, superCls) then error(("%s is inherited from %s, can't be used as super class."):format(tostring(superCls), tostring(info.Owner)), 2) end
		if info.SuperClass == superCls then return end
		if info.SuperClass then error(("%s is inherited from %s, can't inherit another class."):format(tostring(info.Owner), tostring(info.SuperClass)), 2) end

		superInfo.ChildClass = superInfo.ChildClass or {}
		superInfo.ChildClass[info.Owner] = true

		info.SuperClass = superCls

		-- Keep to the environmenet
		-- rawset(env, _SuperIndex, superCls)

		-- Copy Metatable
		if ATTRIBUTE_INSTALLED then __Attribute__._ClearPreparedAttributes() end

		for meta, flag in pairs(_KeyMeta) do
			local rMeta = flag and meta or "_" .. meta

			if superInfo.MetaTable[rMeta] then UpdateMeta4Child(rMeta, info.Owner, nil, superInfo.MetaTable["0" .. rMeta] or superInfo.MetaTable[rMeta]) end
		end

		-- Clone Attributes
		if ATTRIBUTE_INSTALLED then
			local isCached = info.AutoCache or false

			__Attribute__._CloneAttributes(superCls, info.Owner, AttributeTargets.Class)

			if not isCached and info.AutoCache then
				-- So, the __index need re-build
				UpdateMetaTable4Cls(info.Owner, true)
			end
		end
	end

	------------------------------------
	--- Set the current class' extended interface
	------------------------------------
	function extend_Cls(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: extend "namespace.interfacename"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		local IF

		if type(name) == "string" then
			IF = GetNameSpace(info.NameSpace, name) or env[name]

			if not IF then
				for subname in name:gmatch("[_%w]+") do
					IF = IF and IF[subname] or env[subname]

					if not IsNameSpace(IF) then error(("No interface is found with the name : %s"):format(name), 2) end
				end
			end
		else
			IF = name
		end

		local IFInfo = _NSInfo[IF]

		if not IFInfo or IFInfo.Type ~= TYPE_INTERFACE then
			error("Usage: extend (interface) : 'interface' - interface expected", 2)
		elseif IFInfo.NonInheritable then
			error(("%s is non-inheritable."):format(tostring(IF)), 2)
		end

		if IFInfo.Requires and next(IFInfo.Requires) then
			local pass = false

			for prototype in pairs(IFInfo.Requires) do
				if _NSInfo[prototype].Type == TYPE_INTERFACE then
					if IsExtend(prototype, info.Owner) then
						pass = true
						break
					end
				elseif _NSInfo[prototype].Type == TYPE_CLASS then
					if IsChildClass(prototype, info.Owner) then
						pass = true
						break
					end
				end
			end

			if not pass then
				local desc

				for prototype in pairs(IFInfo.Requires) do desc = desc and (desc .. "|" .. tostring(prototype)) or tostring(prototype) end

				error(("Usage: extend (%s) : %s should be sub-class of %s."):format(tostring(IF), tostring(info.Owner), desc), 2)
			end
		end

		IFInfo.ExtendClass = IFInfo.ExtendClass or {}
		IFInfo.ExtendClass[info.Owner] = true

		info.ExtendInterface = info.ExtendInterface or {}

		-- Check if IF is already extend by extend tree
		for _, pIF in ipairs(info.ExtendInterface) do if IsExtend(IF, pIF) then return extend_Cls end end
		for i = #(info.ExtendInterface), 1, -1 do if IsExtend(info.ExtendInterface[i], IF) then tremove(info.ExtendInterface, i) end end

		tinsert(info.ExtendInterface, IF)

		return extend_Cls
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	------------------------------------
	function import_Cls(name)
		if type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: import "namespaceA.namespaceB"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then error(("No namespace is found with name : %s"):format(name), 2) end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do if v == ns then return end end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- Add an event for current class
	------------------------------------
	function event_Cls(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then error([[Usage: event "eventName"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if not info then error("can't use event here.", 2) end

		info.Event[name] = info.Event[name] or Event(name)

		return ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(info.Event[name], AttributeTargets.Event, nil, info.Owner, name)
	end

	------------------------------------
	--- set a propert to the current class
	------------------------------------
	function property_Cls(name)
		if type(name) ~= "string" or strtrim(name:match("[_%w]+")) == "" then error([=[Usage: property "Name" { -- Property Definition }]=], 2) end

		return function(set) return SetPropertyWithSet(_NSInfo[getfenv(2)[OWNER_FIELD]], name:match("[_%w]+"), set) end
	end

	------------------------------------
	--- End the class's definition and restore the environment
	------------------------------------
	function endclass(name)
		if ATTRIBUTE_INSTALLED then __Attribute__._ClearPreparedAttributes() end

		if type(name) ~= "string" or name:find("%.") then error([[Usage: endclass "classname"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			setmetatable(env, _MetaClsEnv)
			setfenv(2, env[BASE_ENV_FIELD])
			RefreshCache(info.Owner, env)
		else
			error(("%s is not closed."):format(info.Name), 2)
		end

		-- Validate the interface
		if info.ExtendInterface then
			local cache = CACHE_TABLE()
			local cacheIF = CACHE_TABLE()
			local ret

			for _, IF in ipairs(info.ExtendInterface) do
				local sinfo = _NSInfo[IF]
				local msg

				wipe(cacheIF)

				if sinfo.RequireMethod then
					for name in pairs(sinfo.RequireMethod) do
						if sinfo.Method[name] == info.Cache4Method[name] then tinsert(cacheIF, name) end
					end

					if #cacheIF > 0 then msg = "[Method]" .. tblconcat(cacheIF, ", ") end
				end

				wipe(cacheIF)

				if sinfo.RequireProperty then
					for name in pairs(sinfo.RequireProperty) do
						if sinfo.Property[name] == info.Cache4Property[name] then tinsert(cacheIF, name) end
					end

					if #cacheIF > 0 then
						msg = msg and (msg .. " ") or ""
						msg = msg .. "[Property]" .. tblconcat(cacheIF, ", ")
					end
				end

				if msg then tinsert(cache, tostring(IF) .. " - " .. msg) end
			end

			if #cache > 0 then
				tinsert(cache, 1, tostring(info.Owner) .. " lack declaration of :")
				ret = tblconcat(cache, "\n")
			end

			CACHE_TABLE(cacheIF)
			CACHE_TABLE(cache)

			if ret then error(ret, 2) end
		end
	end

	_KeyWord4ClsEnv.inherit = inherit_Cls
	_KeyWord4ClsEnv.extend = extend_Cls
	_KeyWord4ClsEnv.import = import_Cls
	_KeyWord4ClsEnv.event = event_Cls
	_KeyWord4ClsEnv.property = property_Cls
	_KeyWord4ClsEnv.endclass = endclass

	_KeyWord4ClsEnv.doc = document
end

------------------------------------------------------
-- Enum
------------------------------------------------------
do
	function BuildEnum(info, set)
		if type(set) ~= "table" then
			error([[Usage: enum "enumName" {
				"enumValue1",
				"enumValue2",
			}]], 2)
		end

		info.Enum = info.Enum or {}

		wipe(info.Enum)

		for i, v in pairs(set) do
			if type(i) == "string" then
				info.Enum[strupper(i)] = v
			elseif type(v) == "string" then
				info.Enum[strupper(v)] = v
			end
		end

		if ATTRIBUTE_INSTALLED then __Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Enum) end

		-- Cache
		info.Cache = info.Cache or {}
		wipe(info.Cache)
		for k, v in pairs(info.Enum) do info.Cache[v] = k end

		if info.Default ~= nil then
			local default = info.Default

			if type(default) == "string" and info.Enum[strupper(default)] then
				info.Default = info.Enum[strupper(default)]
			elseif info.Cache[default] == nil then
				info.Default = nil
			end
		end
	end

	function GetShortEnumInfo(cls)
		if _NSInfo[cls] then
			local str

			for n in pairs(_NSInfo[cls].Enum) do
				if str and #str > 30 then str = str .. " | ..." break end

				str = str and (str .. " | " .. n) or n
			end

			return str or ""
		end

		return ""
	end

	------------------------------------
	--- create a enumeration
	------------------------------------
	function enum(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: enum "enumName" {
				"enumValue1",
				"enumValue2",
			}]], 2)
		end

		local fenv = getfenv(2)
		local ns = not IsLocal() and GetNameSpace4Env(fenv) or nil

		-- Create class or get it
		local enm

		if ns then
			enm = BuildNameSpace(ns, name)

			if _NSInfo[cls] then
				if _NSInfo[cls].Type and _NSInfo[cls].Type ~= TYPE_ENUM then error(("%s is existed as %s, not enumeration."):format(name, tostring(_NSInfo[cls].Type)), 2) end
			end
		else
			enm = fenv[name]

			if not(_NSInfo[enm] and _NSInfo[enm].Type == TYPE_ENUM) then enm = BuildNameSpace(nil, name) end
		end

		if not enm then error("No enumeration is created.", 2) end

		-- save class to the environment
		rawset(fenv, name, enm)

		-- Build enm
		local info = _NSInfo[enm]

		-- Check if the enum is final
		if info.IsFinal then error("The enum is final, can't be re-defined.", 2) end

		info.Type = TYPE_ENUM
		info.NameSpace = ns

		return function(set) return BuildEnum(info, set) end
	end
end

------------------------------------------------------
-- Struct
------------------------------------------------------
do
	_KeyWord4StrtEnv = {}

	_STRUCT_TYPE_MEMBER = "MEMBER"
	_STRUCT_TYPE_ARRAY = "ARRAY"
	_STRUCT_TYPE_CUSTOM = "CUSTOM"

	-- metatable for struct's env
	_MetaStrtEnv = {}
	_MetaStrtDefEnv = {}
	do
		_MetaStrtEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			-- Check keywords
			if _KeyWord4StrtEnv[key] then return _KeyWord4StrtEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					value = info.NameSpace
					rawset(self, key, value)
					return value
				elseif info.NameSpace[key] then
					value = info.NameSpace[key]
					rawset(self, key, value)
					return value
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						value = ns
						rawset(self, key, value)
						return value
					elseif ns[key] then
						value = ns[key]
						rawset(self, key, value)
						return value
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then rawset(self, key, value) return value end

			-- Check Method
			value = info.Method and info.Method[key]
			if value then rawset(self, key, value) return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then rawset(self, key, value) return value end
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]
			if value ~= nil then rawset(self, key, value) return value end
		end

		_MetaStrtDefEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then return info.Owner end

			-- Check local
			if key == LOCAL_ENV_FIELD then local ret = {} rawset(self, key, ret) return ret end

			-- Check keywords
			if _KeyWord4StrtEnv[key] then return _KeyWord4StrtEnv[key] end

			-- Check namespace
			if info.NameSpace then
				if key == _NSInfo[info.NameSpace].Name then
					return info.NameSpace
				elseif info.NameSpace[key] then
					return info.NameSpace[key]
				end
			end

			-- Check imports
			if info.Import4Env then
				for _, ns in ipairs(info.Import4Env) do
					if key == _NSInfo[ns].Name then
						return ns
					elseif ns[key] then
						return ns[key]
					end
				end
			end

			-- Check base namespace
			value = GetNameSpace(GetDefaultNameSpace(), key)
			if value then return value end

			-- Check Method
			value = info.Method and info.Method[key]
			if value then return value end

			-- Check Local
			if rawget(self, LOCAL_ENV_FIELD) then
				value = self[LOCAL_ENV_FIELD][key]
				if value then return value end
			end

			-- Check Base
			return self[BASE_ENV_FIELD][key]
		end

		_MetaStrtDefEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4StrtEnv[key] then error(("'%s' is a keyword."):format(key), 2) end

			if key == info.Name then
				if type(value) == "function" then
					info.Validator = value
					return
				else
					error(("'%s' must be a function as the Validator."):format(key), 2)
				end
			end

			if type(key) == "string"  then
				if type(value) == "function" then
					if IsLocal() then
						return SaveFixedMethod(self[LOCAL_ENV_FIELD], key, value, info.Owner)
					else
						-- Cache the method for the struct data
						info.Method = info.Method or {}

						-- Don't save to environment until need it
						return SaveFixedMethod(info.Method, key, value, info.Owner)
					end
				elseif (value == nil or IsType(value) or IsNameSpace(value)) then
					local ok, ret = pcall(BuildType, value)

					if ok then
						rawset(self, key, ret)

						if info.SubType == _STRUCT_TYPE_MEMBER then
							info.Members = info.Members or {}
							tinsert(info.Members, key)
							if ATTRIBUTE_INSTALLED then __Attribute__._ConsumePreparedAttributes(ret, AttributeTargets.Field, nil, info.Owner, key) end

							-- Auto generate Default
							if not ret:Is(nil) and #ret == 1 and (not info.DefaultField or info.DefaultField[key] == nil) then
								local rinfo = _NSInfo[ret[1]]

								if rinfo and (rinfo.Type == TYPE_STRUCT or rinfo.Type == TYPE_ENUM) and rinfo.Default ~= nil then
									info.DefaultField = info.DefaultField or {}
									info.DefaultField[key] = rinfo.Default
								end
							end
						elseif info.SubType == _STRUCT_TYPE_ARRAY then
							info.ArrayElement = ret
							if ATTRIBUTE_INSTALLED then __Attribute__._ConsumePreparedAttributes(ret, AttributeTargets.Field, nil, info.Owner, key) end
						end

						return
					else
						error(strtrim(ret:match(":%d+:%s*(.-)$") or ret), 2)
					end
				end
			end

			rawset(self, key, value)
		end
	end

	-- Some struct object may ref to each others, that would crash the validation
	_ValidatedCache = setmetatable({}, WEAK_ALL)

	function ValidateStruct(strt, value)
		if _ValidatedCache[value] then return value end

		local info = _NSInfo[strt]

		if info.SubType ~= _STRUCT_TYPE_CUSTOM then
			if type(value) ~= "table" then wipe(_ValidatedCache) error(("%s must be a table, got %s."):format("%s", type(value))) end

			if not _ValidatedCache[1] then _ValidatedCache[1] = value end
			_ValidatedCache[value] = true

			if info.SubType == _STRUCT_TYPE_MEMBER and info.Members then
				for _, n in ipairs(info.Members) do
					if value[n] == nil and info.DefaultField and info.DefaultField[n] ~= nil then
						-- Deep clone to make sure no change on default value
						value[n] = CloneObj(info.DefaultField[n], true)
					else
						value[n] = info.StructEnv[n]:Validate(value[n], n)
					end
				end
			elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
				local flag, ret
				local ele = info.ArrayElement

				for i, v in ipairs(value) do
					flag, ret = pcall(ele.Validate, ele, v, "Element")

					if flag then
						value[i] = ret
					else
						wipe(_ValidatedCache)
						error(strtrim(ret:match(":%d+:%s*(.-)$") or ret):gsub("%%s[_%w]+", "%%s["..i.."]"))
					end
				end
			end
		end

		if type(info.Validator) == "function" then
			local flag, ret = pcall(info.Validator, value)

			if not flag then
				wipe(_ValidatedCache)
				error(strtrim(ret:match(":%d+:%s*(.-)$") or ret))
			end

			if info.SubType == _STRUCT_TYPE_CUSTOM and ret ~= nil then value = ret end
		end

		if info.SubType ~= _STRUCT_TYPE_CUSTOM and _ValidatedCache[1] == value then wipe(_ValidatedCache) end

		return value
	end

	function CopyStructMethods(info, obj)
		if info.Method and type(obj) == "table" then
			for k, v in pairs(info.Method) do
				if obj[k] == nil then obj[k] = v end
			end
		end

		return obj
	end

	function Struct2Obj(strt, ...)
		local info = _NSInfo[strt]

		local count = select("#", ...)
		local initTable = select(1, ...)
		local initErrMsg

		if not ( count == 1 and type(initTable) == "table" and getmetatable(initTable) == nil ) then initTable = nil end

		if initTable then
			local ok, value = pcall(ValidateStruct, strt, initTable)

			if ok then return CopyStructMethods(info, value) end

			initErrMsg = value
		end

		-- Default Constructor
		if info.SubType == _STRUCT_TYPE_MEMBER then
			local ret = {}

			if info.Members then for i, n in ipairs(info.Members) do ret[n] = select(i, ...) end end

			local ok, value = pcall(ValidateStruct, strt, ret)

			if ok then
				return CopyStructMethods(info, value)
			else
				value = initErrMsg or value
				value = strtrim(value:match(":%d+:%s*(.-)$") or value)
				value = value:gsub("%%s%.", ""):gsub("%%s", "")

				local args = ""
				for i, n in ipairs(info.Members) do
					if info.StructEnv[n]:Is(nil) and not args:find("%[") then n = "["..n end
					if i == 1 then args = n else args = args..", "..n end
				end
				if args:find("%[") then args = args.."]" end
				error(("Usage : %s(%s) - %s"):format(tostring(strt), args, value), 3)
			end
		elseif info.SubType == _STRUCT_TYPE_ARRAY then
			local ret = {}

			for i = 1, select('#', ...) do ret[i] = select(i, ...) end

			local ok, value = pcall(ValidateStruct, strt, ret)

			if ok then
				return CopyStructMethods(info, value)
			else
				value = initErrMsg or value
				value = strtrim(value:match(":%d+:%s*(.-)$") or value)
				value = value:gsub("%%s%.", ""):gsub("%%s", "")
				error(("Usage : %s(...) - %s"):format(tostring(strt), value), 3)
			end
		else
			-- For custom struct
			local ok, value = pcall(ValidateStruct, strt, ...)

			if not ok then error(strtrim(value:match(":%d+:%s*(.-)$") or value):gsub("%%s", "[".. info.Name .."]"), 3) end

			return value
		end
	end

	function BuildStructValidate(strt)
		local info = _NSInfo[strt]

		info.Validate = function ( value )
			local ok, ret = pcall(ValidateStruct, strt, value)

			if not ok then error(strtrim(ret:match(":%d+:%s*(.-)$") or ret):gsub("%%s", "[".. info.Name .."]"), 2) end

			return ret
		end
	end

	------------------------------------
	--- create a structure
	------------------------------------
	function struct(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then error([[Usage: struct "structname"]], 2) end
		local fenv = getfenv(2)
		local ns = not IsLocal() and GetNameSpace4Env(fenv) or nil

		-- Create class or get it
		local strt

		if ns then
			strt = BuildNameSpace(ns, name)

			if _NSInfo[strt] and _NSInfo[strt].Type and _NSInfo[strt].Type ~= TYPE_STRUCT then
				error(("%s is existed as %s, not struct."):format(name, tostring(_NSInfo[strt].Type)), 2)
			end
		else
			strt = fenv[name]

			if not ( strt and _NSInfo[strt] and _NSInfo[strt].NameSpace == nil and _NSInfo[strt].Type == TYPE_STRUCT ) then
				strt = BuildNameSpace(nil, name)
			end
		end

		if not strt then error("No struct is created.", 2) end

		-- save class to the environment
		rawset(fenv, name, strt)

		-- Build class
		info = _NSInfo[strt]

		-- Check if the struct is final
		if info.IsFinal then error("The struct is final, can't be re-defined.", 2) end

		info.Type = TYPE_STRUCT
		info.SubType = _STRUCT_TYPE_MEMBER
		info.NameSpace = ns
		info.Members = nil
		info.Default = nil
		info.DefaultField = nil
		info.ArrayElement = nil
		info.Validator = nil
		info.Validate = nil
		info.Method = nil
		info.Import4Env = nil

		info.StructEnv = setmetatable({
			[OWNER_FIELD] = strt,
			[BASE_ENV_FIELD] = fenv,
		}, _MetaStrtDefEnv)

		-- Set namespace
		SetNameSpace4Env(info.StructEnv, strt)

		-- Set the environment to class's environment
		setfenv(2, info.StructEnv)

		return ATTRIBUTE_INSTALLED and __Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Struct)
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	------------------------------------
	function import_STRT(name)
		if type(name) ~= "string" and not IsNameSpace(name) then error([[Usage: import "namespaceA.namespaceB"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then error(("No namespace is found with name : %s"):format(name), 2) end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do if v == ns then return end end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- End the class's definition and restore the environment
	------------------------------------
	function endstruct(name)
		if ATTRIBUTE_INSTALLED then __Attribute__._ClearPreparedAttributes() end

		if type(name) ~= "string" or name:find("%.") then error([[Usage: endstruct "structname"]], 2) end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			setmetatable(env, _MetaStrtEnv)
			setfenv(2, env[BASE_ENV_FIELD])

			-- validate default value if existed
			if info.Default ~= nil then
				if info.SubType ~= _STRUCT_TYPE_CUSTOM then
					info.Default = nil
				elseif not pcall(ValidateStruct, info.Owner, info.Default) then
					info.Default = nil
				end
			end

			-- Make field type unique
			if info.SubType == _STRUCT_TYPE_MEMBER and info.Members then
				for _, n in ipairs(info.Members) do
					if not ATTRIBUTE_INSTALLED or not __Attribute__._IsFieldAttributeDefined(info.Owner, n) then
						info.StructEnv[n] = GetUniqueType(info.StructEnv[n])
					end
				end
			elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
				if not ATTRIBUTE_INSTALLED or not __Attribute__._IsFieldAttributeDefined(info.Owner) then
					info.ArrayElement = GetUniqueType(info.ArrayElement)
				end
			end
		else
			error(("%s is not closed."):format(info.Name), 2)
		end
	end

	function structtype(_type_)
		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		_type_ = strupper(_type_)

		if _type_ == _STRUCT_TYPE_MEMBER then
			-- use member list, default type
			info.SubType = _STRUCT_TYPE_MEMBER
			info.ArrayElement = nil
		elseif _type_ == _STRUCT_TYPE_ARRAY then
			-- user array list
			info.SubType = _STRUCT_TYPE_ARRAY
			info.Members = nil
		else
			-- else all custom
			info.SubType = _STRUCT_TYPE_CUSTOM
			info.Members = nil
			info.DefaultField = nil
			info.ArrayElement = nil
		end
	end

	_KeyWord4StrtEnv.struct = struct
	_KeyWord4StrtEnv.structtype = structtype
	_KeyWord4StrtEnv.default = function (value) _NSInfo[getfenv(2)[OWNER_FIELD]].Default = value end
	_KeyWord4StrtEnv.import = import_STRT
	_KeyWord4StrtEnv.endstruct = endstruct
end

------------------------------------------------------
-- Definition Environment Update
------------------------------------------------------
do
	function Install_KeyWord(env)
		env.interface = interface
		env.class = class
		env.enum = enum
		env.struct = struct
	end

	Install_KeyWord(_KeyWord4IFEnv)
	Install_KeyWord(_KeyWord4ClsEnv)
	Install_KeyWord(_KeyWord4StrtEnv)
	Install_KeyWord = nil
end

------------------------------------------------------
-- System Namespace (Base structs & Reflector)
------------------------------------------------------
do
	namespace "System"

	struct "Boolean"
		structtype "CUSTOM"
		default( false )

		function Boolean(value) return value and true or false end
	endstruct "Boolean"

	struct "String"
		structtype "CUSTOM"
		default( "" )

		function String(value)
			if type(value) ~= "string" then error(("%s must be a string, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "String"

	struct "Number"
		structtype "CUSTOM"
		default( 0 )

		function Number(value)
			if type(value) ~= "number" then error(("%s must be a number, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "Number"

	struct "Function"
		structtype "CUSTOM"

		function Function(value)
			if type(value) ~= "function" then error(("%s must be a function, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "Function"

	struct "Table"
		structtype "CUSTOM"

		function Table(value)
			if type(value) ~= "table" then error(("%s must be a table, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "Table"

	struct "RawTable"
		structtype "CUSTOM"

		function RawTable(value)
			if type(value) ~= "table" then
				error(("%s must be a table, got %s."):format("%s", type(value)))
			elseif getmetatable(value) ~= nil then
				error("%s must be a table without metatable.")
			end
			return value
		end
	endstruct "RawTable"

	struct "Userdata"
		structtype "CUSTOM"

		function Userdata(value)
			if type(value) ~= "userdata" then error(("%s must be a userdata, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "Userdata"

	struct "Thread"
		structtype "CUSTOM"

		function Thread(value)
			if type(value) ~= "thread" then error(("%s must be a thread, got %s."):format("%s", type(value))) end
			return value
		end
	endstruct "Thread"

	struct "Any"
		structtype "CUSTOM"

		function Any(value)
			assert(value ~= nil, "%s can't be nil.")

			return value
		end
	endstruct "Any"

	------------------------------------------------------
	-- System.AttributeTargets
	------------------------------------------------------
	enum "AttributeTargets" {
		All = 0,
		Class = 1,
		Constructor = 2,
		Enum = 4,
		Event = 8,
		Interface = 16,
		Method = 32,
		Property = 64,
		Struct = 128,
		Field = 256,
		NameSpace = 512,
	}

	------------------------------------------------------
	-- System.Reflector
	------------------------------------------------------
	interface "Reflector"

		doc "Reflector" [[This interface contains many apis used to get the running object-oriented system's informations.]]

		doc "GetCurrentNameSpace" [[
			<desc>Get the namespace used by the environment</desc>
			<param name="env" type="table" optional="true">the environment, default the current environment</param>
			<param name="rawOnly" type="boolean" optional="true">skip metatable settings if true</param>
			<return type="namespace">the namespace of the environment</return>
		]]
		function GetCurrentNameSpace(env, rawOnly)
			env = type(env) == "table" and env or getfenv(2)

			return GetNameSpace4Env(env, rawOnly)
		end

		doc "SetCurrentNameSpace" [[
			<desc>set the namespace used by the environment</desc>
			<param name="ns" type="namespace|string|nil">the namespace that set for the environment</param>
			<param name="env" type="table" optional="true">the environment, default the current environment</param>
		]]
		function SetCurrentNameSpace(ns, env)
			env = type(env) == "table" and env or getfenv(2)

			return SetNameSpace4Env(env, ns)
		end

		doc "GetNameSpaceForName" [[
			<desc>Get the namespace by the name</desc>
			<param name="name" type="string">the namespace's name, split by "."</param>
			<return type="namespace">the namespace</return>
			<usage>ns = System.Reflector.GetNameSpaceForName("System")</usage>
		]]
		function GetNameSpaceForName(name)
			return GetNameSpace(GetDefaultNameSpace(), name)
		end

		doc "GetNameSpaceType" [[
			<desc>Get the type of the namespace</desc>
			<param name="name" type="namespace|string">the namespace</param>
			<return type="string">The namespace's type like NameSpace|Class|Struct|Enum|Interface</return>
			<usage>type = System.Reflector.GetNameSpaceType("System.Object")</usage>
		]]
		function GetNameSpaceType(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].Type
		end

		doc "GetNameSpaceName" [[
			<desc>Get the name of the namespace</desc>
			<param name="namespace">the namespace to query</param>
			<return type="string">the namespace's name</return>
			<usage>System.Reflector.GetNameSpaceName(System.Object)</usage>
		]]
		function GetNameSpaceName(ns)
			return ns and _NSInfo[ns] and _NSInfo[ns].Name
		end

		doc "GetNameSpaceFullName" [[
			<desc>Get the full name of the namespace</desc>
			<param name="namespace|string">the namespace to query</param>
			<return type="string">the full path of the namespace</return>
			<usage>path = System.Reflector.GetNameSpaceFullName(System.Object)</usage>
		]]
		function GetNameSpaceFullName(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return GetFullName4NS(ns)
		end

		doc "GetSuperClass" [[
			<desc>Get the superclass of the class</desc>
			<param name="class">the class object to query</param>
			<return type="class">the super class if existed</return>
			<usage>System.Reflector.GetSuperClass(System.Object)</usage>
		]]
		function GetSuperClass(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].SuperClass
		end

		doc "IsNameSpace" [[
			<desc>Check if the object is a NameSpace</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the object is a NameSpace</return>
			<usage>System.Reflector.IsNameSpace(System.Object)</usage>
		]]
		function IsNameSpace(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and true or false
		end

		doc "IsClass" [[
			<desc>Check if the namespace is a class</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the object is a class</return>
			<usage>System.Reflector.IsClass(System.Object)</usage>
		]]
		function IsClass(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].Type == TYPE_CLASS or false
		end

		doc "IsStruct" [[
			<desc>Check if the namespace is a struct</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the object is a struct</return>
			<usage>System.Reflector.IsStruct(System.Object)</usage>
		]]
		function IsStruct(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].Type == TYPE_STRUCT or false
		end

		doc "IsEnum" [[
			<desc>Check if the namespace is an enum</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the object is a enum</return>
			<usage>System.Reflector.IsEnum(System.Object)</usage>
		]]
		function IsEnum(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].Type == TYPE_ENUM or false
		end

		doc "IsInterface" [[
			<desc>Check if the namespace is an interface</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the object is an Interface</return>
			<usage>System.Reflector.IsInterface(System.IFSocket)</usage>
		]]
		function IsInterface(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].Type == TYPE_INTERFACE or false
		end

		doc "IsFinal" [[
			<desc>Check if the class|interface is final, can't be re-defined</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the class|interface is final</return>
			<usage>System.Reflector.IsFinal(System.Object)</usage>
		]]
		function IsFinal(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].IsFinal or false
		end

		doc "IsNonInheritable" [[
			<desc>Check if the class|interface is non-inheritable</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the class|interface is non-inheritable</return>
			<usage>System.Reflector.IsNonInheritable(System.Object)</usage>
		]]
		function IsNonInheritable(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].NonInheritable or false
		end

		doc "IsUniqueClass" [[
			<desc>Check if the class is unique, can only have one object</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the class is unique</return>
			<usage>System.Reflector.IsUniqueClass(System.Object)</usage>
		]]
		function IsUniqueClass(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].UniqueObject and true or false
		end

		doc "IsAutoCacheClass" [[
			<desc>Whether the class is auto-cache, the objects of the class will keep methods in itself when called</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the class is auto-cache</return>
			<usage>System.Reflector.IsAutoCacheClass(System.Object)</usage>
		]]
		function IsAutoCacheClass(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].AutoCache or false
		end

		doc "IsNonExpandable" [[
			<desc>Check if the class|interface is non-expandable</desc>
			<param name="object">the object to query</param>
			<return type="boolean">true if the class|interface is non-expandable</return>
			<usage>System.Reflector.IsNonExpandable(System.Object)</usage>
		]]
		function IsNonExpandable(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].NonExpandable or false
		end

		doc "GetSubNamespace" [[
			<desc>Get the sub namespace of the namespace</desc>
			<param name="namespace">the object to query</param>
			<return type="table">the sub-namespace list</return>
			<usage>System.Reflector.GetSubNamespace(System)</usage>
		]]
		function GetSubNamespace(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and info.SubNS then
				local ret = {}

				for key in pairs(info.SubNS) do tinsert(ret, key) end

				sort(ret)

				return ret
			end
		end

		doc "GetExtendInterfaces" [[
			<desc>Get the extend interfaces of the class|interface</desc>
			<param name="object">the object to query</param>
			<return type="table">the extend interface list</return>
			<usage>System.Reflector.GetExtendInterfaces(System.Object)</usage>
		]]
		function GetExtendInterfaces(cls)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end

			local info = _NSInfo[cls]

			if info.ExtendInterface then
				local ret = {}

				for _, IF in ipairs(info.ExtendInterface) do tinsert(ret, IF) end

				return ret
			end
		end

		doc "GetAllExtendInterfaces" [[
			<desc>Get all the extend interfaces of the class|interface</desc>
			<param name="object">the object to query</param>
			<return type="table">the full extend interface list in the inheritance tree</return>
			<usage>System.Reflector.GetAllExtendInterfaces(System.Object)</usage>
		]]
		function GetAllExtendInterfaces(cls)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end

			local info = _NSInfo[cls]

			if info.Cache4Interface then
				local ret = {}

				for _, IF in ipairs(info.Cache4Interface) do tinsert(ret, IF) end

				return ret
			end
		end

		doc "GetChildClasses" [[
			<desc>Get the classes that inherited from the class</desc>
			<param name="object">the object to query</param>
			<return type="table">the child class list</return>
			<usage>System.Reflector.GetChildClasses(System.Object)</usage>
		]]
		function GetChildClasses(cls)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end

			local info = _NSInfo[cls]

			if info.Type == TYPE_CLASS and info.ChildClass then
				local ret = {}

				for subCls in pairs(info.ChildClass) do tinsert(ret, subCls) end

				return ret
			end
		end

		doc "GetEvents" [[
			<desc>Get the events of the class</desc>
			<format>class|interface[, noSuper]</format>
			<param name="class"></param>|interface the class or interface to query
			<param name="noSuper">no super event handlers</param>
			<return name="table">the event handler list</return>
			<usage>System.Reflector.GetEvents(System.Object)</usage>
		]]
		function GetEvents(ns, noSuper)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				local ret = {}

				for i, v in pairs(noSuper and info.Event or info.Cache4Event) do if v then tinsert(ret, i) end end

				sort(ret)

				return ret
			end
		end

		doc "GetProperties" [[
			<desc>Get the properties of the class|interface</desc>
			<param name="object">the class or interface to query</param>|
			<param name="noSuper" optional="true" type="boolean">no super properties</param>
			<return type="table">the property list</return>
			<usage>System.Reflector.GetProperties(System.Object)</usage>
		]]
		function GetProperties(ns, noSuper)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				local ret = {}

				for i, v in pairs(noSuper and info.Property or info.Cache4Property) do if v then tinsert(ret, i) end end

				sort(ret)

				return ret
			end
		end

		doc "GetMethods" [[
			<desc>Get the methods of the class|interface</desc>
			<param name="object">the class or interface to query</param>
			<param name="noSuper" optional="true" type="boolean">no super methodes</param>
			<return type="table">the method list</return>
			<usage>System.Reflector.GetMethods(System.Object)</usage>
		]]
		function GetMethods(ns, noSuper)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE or info.Type == TYPE_STRUCT) then
				local ret = {}

				if info.Type == TYPE_STRUCT then
					if not info.Method then return end
					noSuper = true
				end

				for k, v in pairs(noSuper and info.Method or info.Cache4Method) do tinsert(ret, k) end

				if not noSuper then for k, v in pairs(info.Method) do if k:match("^_") then tinsert(ret, k) end end end

				sort(ret)

				return ret
			end
		end

		doc "GetPropertyType" [[
			<desc>Get the property type of the property</desc>
			<param name="owner" type="class|interface">the property's owner</param>
			<param name="propName" type="string">the property name</param>
			<return type="System.Type">the property type</return>
			<usage>System.Reflector.GetPropertyType(System.Object, "Name")</usage>
		]]
		function GetPropertyType(ns, propName)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local ty = info.Cache4Property[propName].Type

				return ty and ty:Clone()
			end
		end

		doc "HasProperty" [[
			<desc>whether the property is existed</desc>
			<param name="owner" type="class|interface">The owner of the property</param>
			<param name="propName" type="string">The property's name</param>
			<return type="boolean">true if the class|interface has the property</return>
			<usage>System.Reflector.HasProperty(System.Object, "Name")</usage>
		]]
		function HasProperty(ns, propName)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			return info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] and true or false
		end

		doc "IsPropertyReadable" [[
			<desc>whether the property is readable</desc>
			<param name="owner" type="class|interface">the property's owner</param>
			<param name="propName" type="string">the property's name</param>
			<return type="boolean">true if the property is readable</return>
			<usage>System.Reflector.IsPropertyReadable(System.Object, "Name")</usage>
		]]
		function IsPropertyReadable(ns, propName)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local prop = info.Cache4Property[propName]
				return (prop.Get or prop.GetMethod or prop.Field) and true or false
			end
		end

		doc "IsPropertyWritable" [[
			<desc>whether the property is writable</desc>
			<param name="owner" type="class|interface">the property's owner</param>
			<param name="propName" type="string">the property's name</param>
			<return type="boolean">true if the property is writable</return>
			<usage>System.Reflector.IsPropertyWritable(System.Object, "Name")</usage>
		]]
		function IsPropertyWritable(ns, propName)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local prop = info.Cache4Property[propName]
				return (prop.Set or prop.SetMethod or prop.Field) and true or false
			end
		end

		doc "IsRequireMethod" [[
			<desc>Whether the method is required to be overridden</desc>
			<param name="owner" type="interface">the method's owner</param>
			<param name="name" type="string">the method's name</param>
			<return type="boolean">true if the method must be overridden</return>
		]]
		function IsRequireMethod(ns, name)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			return info and info.Type == TYPE_INTERFACE and info.RequireMethod and info.RequireMethod[name] or false
		end

		doc "IsRequireProperty" [[
			<desc>Whether the property is required to be overridden</desc>
			<param name="owner" type="interface">the property's owner</param>
			<param name="name" type="string">the property's name</param>
			<return type="boolean">true if the property must be overridden</return>
		]]
		function IsRequireProperty(ns, name)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			return info and info.Type == TYPE_INTERFACE and info.RequireProperty and info.RequireProperty[name] or false
		end

		doc "IsOptionalMethod" [[
			<desc>Whether the method is optional to be overridden</desc>
			<param name="owner" type="interface">the method's owner</param>
			<param name="name" type="string">the method's name</param>
			<return type="boolean">true if the method should be overridden</return>
		]]
		function IsOptionalMethod(ns, name)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			return info and info.Type == TYPE_INTERFACE and info.OptionalMethod and info.OptionalMethod[name] or false
		end

		doc "IsOptionalProperty" [[
			<desc>Whether the property is optional to be overridden</desc>
			<param name="owner" type="interface">the property's owner</param>
			<param name="name" type="string">the property's name</param>
			<return type="boolean">true if the property should be overridden</return>
		]]
		function IsOptionalProperty(ns, name)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			return info and info.Type == TYPE_INTERFACE and info.OptionalProperty and info.OptionalProperty[name] or false
		end

		doc "IsFlagsEnum" [[
			<desc>Whether the enum is flags or not</desc>
			<param name="object" type="enum">The enum type</param>
			<return name="boolean">true if the enum is a flag enumeration</return>
			<usage>System.Reflector.IsFlagsEnum(System.AttributeTargets)</usage>
		]]
		function IsFlagsEnum(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			return ns and _NSInfo[ns] and _NSInfo[ns].IsFlags or false
		end

		doc "GetEnums" [[
			<desc>Get the enumeration keys of the enum</desc>
			<param name="enum" type="enum">the enum tyep</param>
			<return type="table">the enum key list</return>
			<usage>System.Reflector.GetEnums(System.AttributeTargets)</usage>
		]]
		function GetEnums(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = _NSInfo[ns]

			if info and info.Type == TYPE_ENUM then
				if info.IsFlags then
					local tmp = {}
					local zero = nil

					for i, v in pairs(info.Enum) do
						if type(v) == "number" then
							if v > 0 then tmp[floor(log(v)/log(2)) + 1] = i else zero = i end
						end
					end

					if zero then tinsert(tmp, 1, zero) end

					return tmp
				else
					local tmp = {}

					for i in pairs(info.Enum) do tinsert(tmp, i) end

					sort(tmp)

					return tmp
				end
			end
		end

		doc "ParseEnum" [[
			<desc>Get the enum key of the enum value</desc>
			<param name="enum" type="enum">the enum type</param>
			<param name="value">the value</param>
			<return type="string">the key of the value</return>
			<usage>System.Reflector.ParseEnum(System.SampleEnum, 1)</usage>
		]]
		function ParseEnum(ns, value)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end
			local info = _NSInfo[ns]

			if info and info.Type == TYPE_ENUM then
				if info.IsFlags and type(value) == "number" then

					if value == 0 then
						return info.Cache[value]
					else
						local ret = {}

						for n, v in pairs(info.Enum) do if ValidateFlags(v, value) then tinsert(ret, n) end end

						return unpack(ret)
					end
				else
					return info.Cache[value]
				end
			end
		end

		doc "ValidateFlags" [[
			<desc>Whether the value is contains on the target value</desc>
			<param name="checkValue" type="number">like 1, 2, 4, 8, ...</param>
			<param name="targetValue" type="number">like 3 : (1 + 2)</param>
			<return type="boolean">true if the targetValue contains the checkValue</return>
		]]
		function ValidateFlags(checkValue, targetValue)
			targetValue = targetValue % (2 * checkValue)
			return (targetValue - targetValue % checkValue) == checkValue
		end

		doc "HasEvent" [[
			<desc>Check if the class|interface has that event</desc>
			<param name="owner" type="class|interface">the event's owner</param>|interface
			<param name="event" type="string">the event's name</param>
			<return type="boolean">if the owner has the event</return>
			<usage>System.Reflector.HasEvent(Addon, "OnEvent")</usage>
		]]
		function HasEvent(cls, evt)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end

			local info = _NSInfo[cls]

			return info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Event[evt] or false
		end

		doc "GetStructType" [[
			<desc>Get the type of the struct type</desc>
			<param name="struct" type="struct">the structtype</param>
			<return type="string">the type of the struct type</return>
		]]
		function GetStructType(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = ns and _NSInfo[ns]

			return info and info.Type == TYPE_STRUCT and info.SubType or nil
		end

		doc "GetStructArrayElement" [[
			<desc>Get the array element types of the struct</desc>
			<param name="struct" type="struct">the struct type</param>
			<return type="System.Type">the array element's type</return>
		]]
		function GetStructArrayElement(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = ns and _NSInfo[ns]

			return info and info.Type == TYPE_STRUCT and info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement and info.ArrayElement:Clone() or nil
		end

		doc "GetStructParts" [[
			<desc>Get the parts of the struct type</desc>
			<param name="struct" type="struct">the struct type</param>
			<return type="table">the struct part name list</return>
			<usage>System.Reflector.GetStructParts(Position)</usage>
		]]
		function GetStructParts(ns)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					local tmp = {}

					for _, part in ipairs(info.Members) do tinsert(tmp, part) end

					return tmp
				elseif info.SubType == _STRUCT_TYPE_ARRAY then
					return { "element" }
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					local tmp = {}

					for key, value in pairs(info.StructEnv) do if type(key) == "string" and IsType(value) then tinsert(tmp, key) end end

					sort(tmp)

					return tmp
				end
			end
		end

		doc "GetStructPart" [[
			<desc>Get the part's type of the struct</desc>
			<param name="struct" type="struct">the struct type</param>
			<param name="part" type="string">the part's name</param>
			<return type="System.Type">the part's type</return>
			<usage>System.Reflector.GetStructPart(Position, "x")</usage>
		]]
		function GetStructPart(ns, part)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0  then
					for _, p in ipairs(info.Members) do
						if p == part and IsType(info.StructEnv[part]) then return info.StructEnv[part]:Clone() end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return info.ArrayElement:Clone()
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					if IsType(info.StructEnv[part]) then return info.StructEnv[part]:Clone() end
				end
			end
		end

		doc "IsSuperClass" [[
			<desc>Check if this class is inherited from the target class</desc>
			<param name="class" type="class">the child class</param>
			<param name="superclass" type="class">the super class</param>
			<return type="boolean">true if the class is inherited from the target class</return>
			<usage>System.Reflector.IsSuperClass(UIObject, Object)</usage>
		]]
		function IsSuperClass(child, super)
			if type(child) == "string" then child = GetNameSpaceForName(child) end
			if type(super) == "string" then super = GetNameSpaceForName(super) end

			return IsClass(child) and IsClass(super) and IsChildClass(super, child)
		end

		doc "IsExtendedInterface" [[
			<desc>Check if the class|interface is extended from the interface</desc>
			<param name="object" type="interface|class">the class or interface</param>
			<param name="interface" type="interface">the target interface</param>
			<return type="boolean">true if the first arg is extend from the second</return>
			<usage>System.Reflector.IsExtendedInterface(UIObject, IFSocket)</usage>
		]]
		function IsExtendedInterface(cls, IF)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end
			if type(IF) == "string" then IF = GetNameSpaceForName(IF) end

			return IsExtend(IF, cls)
		end

		doc "GetObjectClass" [[
			<desc>Get the class type of the object</desc>
			<param name="object">the object</param>
			<return type="class">the object's class</return>
			<usage>System.Reflector.GetObjectClass(obj)</usage>
		]]
		function GetObjectClass(obj)
			return type(obj) == "table" and getmetatable(obj)
		end

		doc "ObjectIsClass" [[
			<desc>Check if this object is an instance of the class</desc>
			<param name="object">the object</param>
			<param name="class">the class</param>
			<return type="boolean">true if the object is an instance of the class or it's child class</return>
			<usage>System.Reflector.ObjectIsClass(obj, Object)</usage>
		]]
		function ObjectIsClass(obj, cls)
			if type(cls) == "string" then cls = GetNameSpaceForName(cls) end
			return (obj and cls and IsChildClass(cls, GetObjectClass(obj))) or false
		end

		doc "ObjectIsInterface" [[
			<desc>Check if this object is an instance of the interface</desc>
			<param name="object">the object</param>
			<param name="interface">the interface</param>
			<return type="boolean">true if the object's class is extended from the interface</return>
			<usage>System.Reflector.ObjectIsInterface(obj, IFSocket)</usage>
		]]
		function ObjectIsInterface(obj, IF)
			if type(IF) == "string" then IF = GetNameSpaceForName(IF) end
			return (obj and IF and IsExtend(IF, GetObjectClass(obj))) or false
		end

		doc "FireObjectEvent" [[
			<desc>Fire an object's event, to trigger the object's event handlers</desc>
			<param name="object">the object</param>
			<param name="event">the event name</param>
			<param name="...">the event's arguments</param>
		]]
		function FireObjectEvent(obj, evt, ...)
			-- No more check , just fire the event as quick as we can
			local handler = rawget(obj, "__Events")
			handler = handler and rawget(handler, evt)
			if handler then return handler(obj, ...) end
		end

		doc "BlockEvent" [[
			<desc>Block event for object</desc>
			<param name="object">the object</param>
			<param name="...">the event name list</param>
			<usage>System.Reflector.BlockEvent(obj, "OnClick", "OnEnter")</usage>
		]]
		function BlockEvent(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then obj[name].Blocked = true end
				end
			end
		end

		doc "IsEventBlocked" [[
			<desc>Whether the event is blocked for object</desc>
			<param name="object">the object</param>
			<param name="event">the event's name</param>
			<return type="boolean">true if the event is blocked</return>
			<usage>System.Reflector.IsEventBlocked(obj, "OnClick")</usage>
		]]
		function IsEventBlocked(obj, sc)
			local cls = GetObjectClass(obj)
			local name

			if cls and HasEvent(cls, sc) then return obj[sc].Blocked end

			return false
		end

		doc "UnBlockEvent" [[
			<desc>Un-Block event for object</desc>
			<param name="object">the object</param>
			<param name="...">the event name list</param>
			<usage>System.Reflector.UnBlockEvent(obj, "OnClick", "OnEnter")</usage>
		]]
		function UnBlockEvent(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then obj[name].Blocked = false end
				end
			end
		end

		-- Recycle the test type object
		_Validate_Type = setmetatable({}, {
			__call = function(self, key)
				if key then
					key.AllowNil = nil
					key[1] = nil
					key.Name = nil

					tinsert(self, key)
				else
					if next(self) then return tremove(self) else return BuildType(nil) end
				end
			end,
		})

		doc "Validate" [[
			<desc>Validating the value to the given type.</desc>
			<format>type, value, name[, prefix[, stacklevel] ]</format>
			<param name="type">such like Object+String+nil</param>
			<param name="value">the test value</param>
			<param name="name">the parameter's name</param>
			<param name="prefix">the prefix string</param>
			<param name="stacklevel">set if not in the main function call, only work when prefix is setted</param>
			<return>the validated value</return>
			<usage>System.Reflector.Validate(System.String+nil, "Test")</usage>
		]]
		function Validate(types, value, name, prefix, stacklevel)
			stacklevel = type(stacklevel) == "number" and stacklevel > 0 and stacklevel or 0

			stacklevel = math.floor(stacklevel)

			if type(name) ~= "string" then name = "value" end
			if types == nil then return value end

			if IsNameSpace(types) then
				local vtype = _Validate_Type()

				vtype.AllowNil = nil
				vtype[1] = types
				vtype.Name = name

				types = vtype
			end

			local ok, _type = pcall(BuildType, types)

			if ok then
				if _type then
					ok, value = pcall(_type.Validate, _type, value)

					-- Recycle
					_Validate_Type(types)

					if not ok then
						value = strtrim(value:match(":%d+:%s*(.-)$") or value):gsub("%%s[_%w]*", name)

						if type(prefix) == "string" then
							error(prefix .. value, 3 + stacklevel)
						else
							error(value, 2)
						end
					end
				else
					-- Recycle
					_Validate_Type(types)
				end

				return value
			else
				-- Recycle
				_Validate_Type(types)

				error("Usage : System.Reflector.Validate(type, value[, name[, prefix]]) : type - must be nil, enum, struct or class.", 2)
			end

			return value
		end

		doc "GetDocument" [[
			<desc>Get the document</desc>
			<param name="owner">the document's owner</param>
			<param name="name" optional="true">the query name, default the owner's name</param>
			<param name="targetType" optional="true" type="System.AttributeTargets">the query target type, can be auto-generated by the name</param>
			<return type="string">the document</return>
		]]
		GetDocument = GetDocument

		doc "Help" [[
			<desc>Return help information of the target</desc>
			<param name="owner">the target's owner</param>
			<param name="name" optional="true">the query name, default the owner's name</param>
			<param name="targetType" optional="true" type="System.AttributeTargets">the query target type, can be auto-generated by the name</param>
			<return type="string">the detail information of the target</return>
		]]

		-- The cache for constructor parameters
		local function buildSubNamespace(ns, rs)
			local _Enums = CACHE_TABLE()
			local _Structs = CACHE_TABLE()
			local _Classes = CACHE_TABLE()
			local _Interfaces = CACHE_TABLE()
			local _Namespaces = CACHE_TABLE()

			local subNS = GetSubNamespace(ns)

			if subNS and next(subNS) then
				for _, sns in ipairs(subNS) do
					sns = ns[sns]

					if IsEnum(sns) then
						tinsert(_Enums, sns)
					elseif IsStruct(sns) then
						tinsert(_Structs, sns)
					elseif IsInterface(sns) then
						tinsert(_Interfaces, sns)
					elseif IsClass(sns) then
						tinsert(_Classes, sns)
					else
						tinsert(_Namespaces, sns)
					end
				end

				if next(_Enums) then
					tinsert(rs, "\n Sub Enum :")

					for _, sns in ipairs(_Enums) do tinsert(rs, "    " .. GetNameSpaceName(sns)) end
				end

				if next(_Structs) then
					tinsert(rs, "\n Sub Struct :")

					for _, sns in ipairs(_Structs) do tinsert(rs, "    " .. GetNameSpaceName(sns)) end
				end

				if next(_Interfaces) then
					tinsert(rs, "\n Sub Interface :")

					for _, sns in ipairs(_Interfaces) do tinsert(rs, "    " .. GetNameSpaceName(sns)) end
				end

				if next(_Classes) then
					tinsert(rs, "\n Sub Class :")

					for _, sns in ipairs(_Classes) do tinsert(rs, "    " .. GetNameSpaceName(sns)) end
				end

				if next(_Namespaces) then
					tinsert(rs, "\n Sub NameSpace :")

					for _, sns in ipairs(_Namespaces) do tinsert(rs, "    " .. GetNameSpaceName(sns)) end
				end
			end

			CACHE_TABLE(_Enums)
			CACHE_TABLE(_Structs)
			CACHE_TABLE(_Classes)
			CACHE_TABLE(_Interfaces)
			CACHE_TABLE(_Namespaces)
		end

		local function getDocumentPart(doc, part)
			if doc:match("^%s*<") then
				-- parse as xml
				return doc:gmatch("<" .. part .. ".->.-</" .. part .. ">")
			else
				-- only description
				if part == "desc" or "description" then return doc end
			end
		end

		local function getDescription(ns, name, targetType)
			local doc = GetDocument(ns, name, targetType)

			if doc then
				doc = getDocumentPart(doc, "desc") or getDocumentPart(doc, "description")

				if type(doc) == "function" then doc = doc() end

				return doc
			end
		end

		local function parseOptions(opt)
			if type(opt) ~= "string" then return end

			local ret = CACHE_TABLE()

			pcall(setfenv(loadstring(opt:gsub("<%w+%s+(.-)>(.-)</%w+>", "%1 desc=[[%2]]")), ret))

			return ret
		end

		function Help(ns, name, targetType)
			if type(ns) == "string" then ns = GetNameSpaceForName(ns) end

			if not IsNameSpace(ns) then return "" end

			local rs = CACHE_TABLE()

			if not name or name == GetNameSpaceName(ns) then
				-- Scan attributes
				if IsFinal(ns) then tinsert(rs, "[__Final__]") end
				if IsFlagsEnum(ns) then tinsert(rs, "[__Flags__]") end
				if IsNonInheritable(ns) then tinsert(rs, "[__NonInheritable__]") end
				if IsNonExpandable(ns) then tinsert(rs, "[__NonExpandable__]") end
				if IsAutoCacheClass(ns) then tinsert(rs, "[__Cache__]") end
				if IsUniqueClass(ns) then tinsert(rs, "[__Unique__]") end
				if IsChildClass(__Attribute__, ns) then
					local usage = __Attribute__._GetClassAttribute(ns, __AttributeUsage__)

					if usage then
						tinsert(rs,
							"[__AttributeUsage__{ " ..
							"AttributeTarget = " .. Serialize(usage.AttributeTarget, AttributeTargets) .. ", " ..
							"Inherited = " .. tostring(usage.Inherited and true or false) .. ", " ..
							"AllowMultiple = " .. tostring(usage.AllowMultiple and true or false) .. ", " ..
							"RunOnce = " .. tostring(usage.RunOnce and true or false) ..
							" }]")
					end
				end

				tinsert(rs, "[" .. (GetNameSpaceType(ns) or TYPE_NAMESPACE) .. "] " .. GetNameSpaceFullName(ns) .. " :")

				-- Scan document
				local doc = getDescription(ns)

				if type(doc) == "string" then
					tinsert(rs, "  Description :")
					tinsert(rs, "    " .. doc:gsub("[\n\r]", "%1    "))
				end

				-- Special settings
				if IsEnum(ns) then
					-- Scan enum values
					tinsert("  Enumeration :")
					for _, enums in ipairs(GetEnums(ns)) do
						local value = ns[enums]

						if type(value) == "string" then
							value = ("%q"):format(value)
						else
							value = tostring(value)
						end

						tinsert(rs, "    " .. enums .. " = " .. value)
					end
				elseif IsStruct(ns) then
					-- Scan parts
					if stype == _STRUCT_TYPE_MEMBER or stype == _STRUCT_TYPE_CUSTOM then
						local parts = GetStructParts(ns)

						if parts and next(parts) then
							tinsert(rs, "\n  Field :")

							for _, name in ipairs(parts) do
								tinsert(rs, "    " .. name .. " = " .. tostring(info.StructEnv[name]))
							end
						end
					elseif stype == _STRUCT_TYPE_ARRAY then
						local ele = GetStructArrayElement(ns)

						if ele then
							tinsert(rs, "\n  Element :\n    " .. tostring(ele))
						end
					end
				elseif IsClass(ns) or IsInterface(ns) then
					-- Scan super class
					local super = GetSuperClass(ns)
					if super then
						tinsert(rs, "\n  Super Class :\n    " .. GetNameSpaceFullName(super))
					end

					-- Scan extend interfaces
					local extends = GetExtendInterfaces(ns)
					if extends and next(extends) then
						tinsert(rs, "\n  Extend Interface :")
						for _, IF in ipairs(extends) do
							tinsert(rs, "    " .. GetNameSpaceFullName(IF))
						end
					end
				end

				-- Scan SubNameSpace
				buildSubNamespace(ns, rs)

				-- Scan events
				local evts = GetEvents(ns)

				if evts and next(evts) then
					tinsert(rs, "  Event :")

					for _, name in ipairs(evts) do
						local desc = getDescription(ns, name, AttributeTargets.Event)

						if desc then
							tinsert(rs, "    " .. name .. " - " .. desc)
						else
							tinsert(rs, "    " .. name)
						end
					end
				end

				-- Scan require or optional features
				local opt = getDocumentPart(GetDocument(ns), "optional")
				local req = getDocumentPart(GetDocument(ns), "require")

				local opts = CACHE_TABLE()
				local reqs = CACHE_TABLE()

				if opt then local v = parseOptions(opt()) while v do opts[v.name] = v; v = parseOptions(opt()) end end
				if req then local v = parseOptions(req()) while v do reqs[v.name] = v; v = parseOptions(req()) end end

				-- Scan methods
				local methods = GetMethods(ns)
				local hasMethodHeader = false

				if methods and next(methods) then
					tinsert(rs, "  Method :")
					hasMethodHeader = true

					for _, name in ipairs(methods) do
						local desc = getDescription(ns, name, AttributeTargets.Method)
						local isOptional = IsOptionalMethod(ns, name)
						local isRequire = IsRequireMethod(ns, name)

						if opts[name] then isOptional = true; desc = desc or opts[name].desc end
						if reqs[name] then isRequire = true; desc = desc or reqs[name].desc end

						tinsert(rs, "    " .. (isOptional and "[__Optional__]" or "") ..
												(isRequire and "[__Require__]" or "") ..
												name ..
												(desc and (" - " .. desc) or ""))

						if opts[name] then CACHE_TABLE(opts[name]); opts[name] = nil end
						if reqs[name] then CACHE_TABLE(reqs[name]); reqs[name] = nil end
					end
				end

				for name, req in pairs(reqs) do
					if req.type == "method" then
						if not hasMethodHeader then
							tinsert(rs, "  Method :")
							hasMethodHeader = true
						end

						tinsert(rs, "    [__Require__]" .. name .. (req.desc and (" - " .. req.desc) or ""))

						reqs[name] = nil

						CACHE_TABLE(req)
					end
				end

				for name, opt in pairs(opts) do
					if opt.type == "method" then
						if not hasMethodHeader then
							tinsert(rs, "  Method :")
							hasMethodHeader = true
						end

						tinsert(rs, "    [__Optional__]" .. name .. (opt.desc and (" - " .. opt.desc) or ""))

						opts[name] = nil

						CACHE_TABLE(opt)
					end
				end

				-- Scan properties
				local props = GetProperties(ns)
				local hasPropertyHeader = false

				if props and next(props) then
					tinsert(rs, "  Property :")
					hasPropertyHeader = true

					for _, name in ipairs(props) do
						local desc = getDescription(ns, name, AttributeTargets.Property)
						local isOptional = IsOptionalMethod(ns, name)
						local isRequire = IsRequireMethod(ns, name)

						if opts[name] then isOptional = true; desc = desc or opts[name].desc end
						if reqs[name] then isRequire = true; desc = desc or reqs[name].desc end

						tinsert(rs, "    " .. (isOptional and "[__Optional__]" or "") ..
												(isRequire and "[__Require__]" or "") ..
												name ..
												(desc and (" - " .. desc) or ""))

						if opts[name] then CACHE_TABLE(opts[name]); opts[name] = nil end
						if reqs[name] then CACHE_TABLE(reqs[name]); reqs[name] = nil end
					end
				end

				for name, req in pairs(reqs) do
					if req.type == "property" then
						if not hasPropertyHeader then
							tinsert(rs, "  Property :")
							hasPropertyHeader = true
						end

						tinsert(rs, "    [__Require__]" .. name .. (req.desc and (" - " .. req.desc) or ""))

						reqs[name] = nil

						CACHE_TABLE(req)
					end
				end

				for name, opt in pairs(opts) do
					if opt.type == "method" then
						if not hasPropertyHeader then
							tinsert(rs, "  Property :")
							hasPropertyHeader = true
						end

						tinsert(rs, "    [__Optional__]" .. name .. (opt.desc and (" - " .. opt.desc) or ""))

						opts[name] = nil

						CACHE_TABLE(opt)
					end
				end

				-- Recycle
				for name, req in pairs(reqs) do reqs[name] = nil; CACHE_TABLE(req) end CACHE_TABLE(reqs)
				for name, opt in pairs(opts) do opts[name] = nil; CACHE_TABLE(opt) end CACHE_TABLE(opts)

				-- Scan constructors
				if IsClass(ns) then

				end
			else
			end



			if ns and _NSInfo[ns] then
				local info = _NSInfo[ns]

				if info.Type == TYPE_INTERFACE or info.Type == TYPE_CLASS then
					-- Interface & Class
					if type(targetType) ~= "string" then
						-- Constructor
						local isFormat = false

						if info.Type == TYPE_CLASS then
							-- Check FixedMethod
							local sinfo = info

							while not sinfo.Constructor and sinfo.SuperClass do
								sinfo = _NSInfo[sinfo.SuperClass]
							end

							if getmetatable(sinfo.Constructor) then
								result = result .. "\n\n Fixed Constructor : "

								local cache = CACHE_TABLE()
								local owner = sinfo.Owner
								local ctor = sinfo.Constructor

								while getmetatable(ctor) do
									if ctor.Owner == owner then
										tinsert(cache, ctor)
									else
										local isEqual = false

										for _, ex in ipairs(cache) do
											if #ex == #ctor then
												isEqual = true

												for i = 1, #ctor do
													if not IsEqual(ex[i], ctor[i]) then
														isEqual = false
														break
													end
												end

												if isEqual then break end
											end
										end

										if not isEqual then
											tinsert(cache, ctor)
										end
									end

									ctor = ctor.Next
								end

								for _, ctor in ipairs(cache) do
									local usage = ctor.Usage:match("Usage : (.*)$")

									result = result .. "\n    " .. usage
								end

								CACHE_TABLE(cache)
							end

							while ns do
								isFormat = true

								desc = nil

								if HasPartDocument(ns, "class", GetNameSpaceName(ns)) then
									desc = GetPartDocument(ns, "class", GetNameSpaceName(ns), "format")
									if not desc then
										desc = GetPartDocument(ns, "class", GetNameSpaceName(ns), "param")
										isFormat = false
									end
								elseif HasPartDocument(ns, "default", GetNameSpaceName(ns)) then
									desc = GetPartDocument(ns, "default", GetNameSpaceName(ns), "desc")
									if not desc then
										desc = GetPartDocument(ns, "default", GetNameSpaceName(ns), "param")
										isFormat = false
									end
								end

								if desc then
									-- Constructor
									result = result .. "\n\n  Constructor :"
									if isFormat then
										for fmt in desc do
											result = result .. "\n    " .. GetNameSpaceName(ns) .. "(" .. fmt .. ")"
										end
									else
										result = result .. "\n    " .. GetNameSpaceName(ns) .. "("

										local isFirst = true

										for param in desc do
											if isFirst then
												isFirst = false
												result = result .. param
											else
												result = result .. ", " .. param
											end
										end

										result = result .. ")"
									end

									-- Params
									desc = GetPartDocument(ns, "class", GetNameSpaceName(ns), "param") or GetPartDocument(ns, "default", GetNameSpaceName(ns), "param")
									if desc then
										result = result .. "\n\n  Parameter :"
										for param, info in desc do
											if info and info:len() > 0 then
												result = result .. "\n    " .. param .. " - " .. info
											else
												result = result .. "\n    " .. param
											end
										end
									end

									break
								end

								ns = GetSuperClass(ns)
							end
						end

						return result
					else
						local result
						local querytype

						if info.Type == TYPE_INTERFACE then
							result = "[Interface] " .. GetNameSpaceFullName(ns) .. " - "
						else
							result = "[Class] " .. GetNameSpaceFullName(ns) .. " - "
						end

						if type(name) ~= "string" then
							targetType, name = nil, targetType
						end

						querytype = targetType

						if not querytype then
							if HasEvent(ns, name) then
								querytype = "event"
							elseif HasProperty(ns, name) then
								querytype = "property"
							elseif type(ns[name]) == "function" then
								querytype = "method"
							else
								return
							end
						end

						targetType = querytype or "default"

						if targetType:match("^%a") then
							result = result .. "[" .. strupper(targetType:match("^%a")) .. targetType:sub(2, -1) .. "] " .. name .. " :"
						else
							result = result .. "[" .. targetType .. "] " .. name .. " :"
						end

						local hasDocument = HasPartDocument(ns, targetType, name)

						-- Desc
						local desc = hasDocument and GetPartDocument(ns, targetType, name, "desc")
						desc = desc and desc()
						if desc then
							result = result .. "\n\n  Description :\n    " .. desc:gsub("<br>", "\n    ")
						end

						if querytype == "event" then
							-- __Thread__
							if IsThreadActivated(ns, name) then
								result = result .. "\n\n  [__Thread__]"
							end

							-- Format
							desc = hasDocument and GetPartDocument(ns, targetType, name, "format")
							if desc then
								result = result .. "\n\n  Format :"
								for fmt in desc do
									result = result .. "\n    " .. "function object:" .. name .. "(" .. fmt .. ")\n        -- Handle the event\n    end"
								end
							else
								result = result .. "\n\n  Format :\n    function object:" .. name .. "("

								desc = hasDocument and GetPartDocument(ns, targetType, name, "param")

								if desc then
									local isFirst = true

									for param in desc do
										if isFirst then
											isFirst = false
											result = result .. param
										else
											result = result .. ", " .. param
										end
									end
								end

								result = result .. ")\n        -- Handle the event\n    end"
							end

							-- Params
							desc = hasDocument and GetPartDocument(ns, targetType, name, "param")
							if desc then
								result = result .. "\n\n  Parameter :"
								for param, info in desc do
									if info and info:len() > 0 then
										result = result .. "\n    " .. param .. " - " .. info
									else
										result = result .. "\n    " .. param
									end
								end
							end
						elseif querytype == "property" then
							local types = GetPropertyType(ns, name)

							if types then
								result = result .. "\n\n  Type :\n    " .. tostring(types)
							end

							-- Readonly
							result = result .. "\n\n  Readable :\n    " .. tostring(IsPropertyReadable(ns, name))

							-- Writable
							result = result .. "\n\n  Writable :\n    " .. tostring(IsPropertyWritable(ns, name))
						elseif querytype == "method" then
							local isGlobal = false

							if name:match("^_") then
								isGlobal = true
							else
								if info.Type == TYPE_INTERFACE and info.NonInheritable then
									isGlobal = true
								end
							end

							-- Fixed Method
							local sinfo = info
							local func = info.Cache4Method[name] or info.Method[name]

							while sinfo and not sinfo.Method[name] do
								if sinfo.SuperClass and _NSInfo[sinfo.SuperClass].Cache4Method[name] == func then
									sinfo = _NSInfo[sinfo.SuperClass]
								elseif sinfo.ExtendInterface then
									for _, IF in ipairs(info.ExtendInterface) do
										if _NSInfo[IF].Cache4Method[name] == func then
											sinfo = _NSInfo[IF]
											break
										end
									end
								else
									break
								end
							end

							if sinfo and sinfo.Method[name] and getmetatable(sinfo.Method["0" .. name]) then
								local fm = sinfo.Method["0" .. name]

								result = result .. "\n\n Overload Format : "

								local cache = CACHE_TABLE()
								local owner = sinfo.Owner

								while getmetatable(fm) do
									if fm.Owner == owner then
										tinsert(cache, fm)
									else
										local isEqual = false

										for _, ex in ipairs(cache) do
											if #ex == #fm then
												isEqual = true

												for i = 1, #fm do
													if not IsEqual(ex[i], fm[i]) then
														isEqual = false
														break
													end
												end

												if isEqual then break end
											end
										end

										if not isEqual then
											tinsert(cache, fm)
										end
									end

									fm = fm.Next
								end

								for _, fm in ipairs(cache) do
									local usage = fm.Usage:match("Usage : (.*)$")

									result = result .. "\n    " .. usage
								end

								CACHE_TABLE(cache)
							end

							-- Format
							desc = hasDocument and GetPartDocument(ns, targetType, name, "format")
							result = result .. "\n\n  Format :"
							if desc then
								for fmt in desc do
									if isGlobal then
										result = result .. "\n    " .. GetNameSpaceName(ns) .. "." .. name .. "(" .. fmt .. ")"
									else
										result = result .. "\n    object:" .. name .. "(" .. fmt .. ")"
									end
								end
							else
								if isGlobal then
									result = result .. "\n    " .. GetNameSpaceName(ns) .. "." .. name .. "("
								else
									result = result .. "\n    object:" .. name .. "("
								end

								desc = hasDocument and GetPartDocument(ns, targetType, name, "param")

								if desc then
									local isFirst = true

									for param in desc do
										if isFirst then
											isFirst = false
											result = result .. param
										else
											result = result .. ", " .. param
										end
									end
								end

								result = result .. ")"
							end

							-- Params
							desc = hasDocument and GetPartDocument(ns, targetType, name, "param")
							if desc then
								result = result .. "\n\n  Parameter :"
								for param, info in desc do
									if info and info:len() > 0 then
										result = result .. "\n    " .. param .. " - " .. info
									else
										result = result .. "\n    " .. param
									end
								end
							end

							-- ReturnFormat
							desc = hasDocument and GetPartDocument(ns, targetType, name, "returnformat")
							if desc then
								result = result .. "\n\n  Return Format :"
								for fmt in desc do
									result = result .. "\n    " .. fmt
								end
							end

							-- Returns
							desc = hasDocument and GetPartDocument(ns, targetType, name, "return")
							if desc then
								result = result .. "\n\n  Return :"
								for ret, info in desc do
									if info and info:len() > 0 then
										result = result .. "\n    " .. ret .. " - " .. info
									else
										result = result .. "\n    " .. ret
									end
								end
							end
						else
							-- skip
						end

						-- Usage
						desc = hasDocument and GetPartDocument(ns, targetType, name, "usage")
						if desc then
							result = result .. "\n\n  Usage :"
							for usage in desc do
								result = result .. "\n    " .. usage:gsub("<br>", "\n    ")
							end
						end

						return result
					end
				else
					local result = "[NameSpace] " .. GetNameSpaceFullName(ns) .. " :"
					local desc

					if HasPartDocument(ns, "namespace", GetNameSpaceName(ns)) then
						desc = GetPartDocument(ns, "namespace", GetNameSpaceName(ns), "desc")
					elseif HasPartDocument(ns, "default", GetNameSpaceName(ns)) then
						desc = GetPartDocument(ns, "default", GetNameSpaceName(ns), "desc")
					end

					-- Desc
					desc = desc and desc()
					if desc then
						result = result .. "\n\n  Description :\n    " .. desc
					end

					-- SubNameSpace
					result = result .. buildSubNamespace(ns)

					return result
				end
			end
		end

		doc "Serialize" [[
			<desc>Serialize the data</desc>
			<param name="data">the data</param>
			<param name="type" optional="true">the data's type</param>
			<return type="string"></return>
		]]
		local function SerializeData(data)
			if type(data) == "string" then
				return strformat("%q", data)
			elseif type(data) == "number" or type(data) == "boolean" then
				return tostring(data)
			elseif type(data) == "table" then
				local cache = CACHE_TABLE()

				tinsert(cache, "{")

				for k, v in pairs(data) do
					if ( type(k) == "number" or type(k) == "string" ) and
						( type(v) == "string" or type(v) == "number" or type(v) == "boolean" or type(v) == "table" ) then

						if type(k) == "number" then
							tinsert(cache, ("[%s] = %s,"):format(tostring(k), SerializeData(v)))
						else
							tinsert(cache, ("%s = %s,"):format(k, SerializeData(v)))
						end
					end
				end

				tinsert(cache, "}")

				local ret = tblconcat(cache, " ")

				CACHE_TABLE(cache)

				return ret
			else
				-- Don't support any point values
				return nil
			end
		end

		function Serialize(data, ns)
			if ns then
				if ObjectIsClass(ns, Type) then
					ns = ns:GetObjectType(data)

					if ns == false then return nil elseif ns == nil then return "nil" end
				elseif type(ns) == "string" then
					ns = GetNameSpaceForName(ns)
				end
			end

			if ns and _NSInfo[ns] then
				if Reflector.IsEnum(ns) then
					if _NSInfo[ns].IsFlags and type(data) == "number" then
						local ret = {Reflector.ParseEnum(ns, data)}

						local result = ""

						for i, str in ipairs(ret) do
							if i > 1 then result = result .. " + " end
							result = result .. (tostring(ns) .. "." .. str)
						end

						return result
					else
						local str = Reflector.ParseEnum(ns, data)

						return str and (tostring(ns) .. "." .. str)
					end
				elseif Reflector.IsClass(ns) then
					-- Class handle the serialize itself with __tostring
					return tostring(data)
				elseif Reflector.IsStruct(ns) then
					if Reflector.GetStructType(ns) == "MEMBER" and type(data) == "table" then
						local parts = Reflector.GetStructParts(ns)

						if not parts or not next(parts) then
							-- Well, what a no member struct can be used for?
							return tostring(ns) .. "( )"
						else
							local ret = tostring(ns) .. "( "

							for i, part in ipairs(parts) do
								local sty = Reflector.GetStructPart(ns, part)
								local value = data[part]

								if sty and #sty == 1 then
									value = Serialize(value, sty[1])
								else
									value = SerializeData(value)
								end

								if i == 1 then
									ret = ret .. tostring(value)
								else
									ret = ret .. ", " .. tostring(value)
								end
							end

							ret = ret .. " )"

							return ret
						end
					elseif Reflector.GetStructType(ns) == "ARRAY" and type(data) == "table" then
						local ret = tostring(ns) .. "( "

						sty = Reflector.GetStructArrayElement(ns)

						if sty and #sty == 1 then
							for i, v in ipairs(data) do
								v = Serialize(v, sty[1])

								if i == 1 then
									ret = ret .. tostring(v)
								else
									ret = ret .. ", " .. tostring(v)
								end
							end
						else
							for i, v in ipairs(data) do
								v = SerializeData(v)

								if i == 1 then
									ret = ret .. tostring(v)
								else
									ret = ret .. ", " .. tostring(v)
								end
							end
						end

						ret = ret .. " )"

						return ret
					elseif type(data) == "table" and type(data.__tostring) == "function" then
						return data:__tostring()
					else
						return SerializeData(data)
					end
				end
			else
				-- Serialize normal datas
				return SerializeData(data)
			end
		end

		doc "ThreadCall" [[
			<desc>Call the function in a thread from the thread pool of the system</desc>
			<param name="func">the function</param>
			<param name="...">the parameters</param>
			<return>the return value of the func</return>
		]]
		ThreadCall = CallThread

		doc "IsEqual" [[
			<desc>Whether the two objects are objects with same settings</desc>
			<param name="obj1">the object used to compare</param>
			<param name="obj2">the object used to compare to</param>
			<return type="boolean">true if the obj1 has same settings with the obj2</return>
		]]
		local function checkEqual(obj1, obj2, cache)
			if obj1 == obj2 then return true end
			if type(obj1) ~= "table" then return false end
			if type(obj2) ~= "table" then return false end

			if cache[obj1] and cache[obj2] then
				return true
			elseif cache[obj1] or cache[obj2] then
				return false
			else
				cache[obj1] = true
				cache[obj2] = true
			end

			local cls = getmetatable(obj1)
			if cls == TYPE_NAMESPACE then return false end

			local info = cls and _NSInfo[cls]
			if info then
				if cls ~= getmetatable(obj2) then return false end
				if info.Metatable.__eq then return false end

				-- Check properties
				for name, prop in pairs(info.Cache4Property) do
					if prop.Get or prop.GetMethod or prop.Field then
						if not checkEqual(obj1[name], obj2[name], cache) then return false end
					end
				end

				return true
			end

			-- Check fields
			for k, v in pairs(obj1) do
				if not checkEqual(v, obj2[k], cache) then return false end
			end

			for k, v in pairs(obj2) do
				if obj1[k] == nil then return false end
			end

			return true
		end

		function IsEqual(obj1, obj2)
			local cache = CACHE_TABLE()

			local result = checkEqual(obj1, obj2, cache)

			CACHE_TABLE(cache)

			return result
		end

		doc "Clone" [[
			<desc>Clone the object if possible</desc>
			<param name="obj">the object to be cloned</param>
			<param name="deep" optional="true" type="boolean">whether deep clone</param>
			<return type="object">the clone or the object itself</return>
		]]
		Clone = CloneObj
	endinterface "Reflector"
end

------------------------------------------------------
-- Local Namespace (Inner classes)
------------------------------------------------------
do
	namespace( nil )

	class "Type"
		doc "Type" [[The type object used to handle the value's validation]]

		_ALLOW_NIL = "AllowNil"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc "Validate" [[
			<desc>Used to validate the value</desc>
			<param name="value"></param>
			<param name="partName" optional="true">the name of the field</param>
			<param name="mainName" optional="true">the name present the value</param>
			<param name="stack" optional="true">the stack level, default 1</param>
			<return>the validated value</return>
			<return>the validated type</return>
		]]
		function Validate(self, value, partName, mainName, stack)
			if value == nil and rawget(self, _ALLOW_NIL) then return value end

			local flag, errorMsg, info, tmpMsg
			local index = -1
			local types

			info = _NSInfo[rawget(self, index)]
			if info then
				while info do
					tmpMsg = nil

					if info.Type == TYPE_CLASS then
						if IsChildClass(info.Owner, value) then return value end
						tmpMsg = ("%s must be subclass of [class]%s."):format("%s", tostring(info.Owner))
					elseif info.Type == TYPE_INTERFACE then
						if IsExtend(info.Owner, value) then return value end
						tmpMsg = ("%s must extended from [interface]%s."):format("%s", tostring(info.Owner))
					elseif value == info.Owner then
						return value
					else
						types = (types or "") .. tostring(info.Owner) .. ", "
					end

					if tmpMsg and not errorMsg then
						if partName and partName ~= "" then
							if tmpMsg:find("%%s([_%w]+)") then
								errorMsg = tmpMsg:gsub("%%s", "%%s"..partName..".")
							else
								errorMsg = tmpMsg:gsub("%%s", "%%s"..partName)
							end
						else
							errorMsg = tmpMsg
						end
					end

					index = index - 1
					info = _NSInfo[rawget(self, index)]
				end

				if types and #types >= 3 and not errorMsg then
					tmpMsg = ("%s must be the type in ()."):format("%s", types:sub(1, -3))

					if partName and partName ~= "" then
						if tmpMsg:find("%%s([_%w]+)") then
							errorMsg = tmpMsg:gsub("%%s", "%%s"..partName..".")
						else
							errorMsg = tmpMsg:gsub("%%s", "%%s"..partName)
						end
					else
						errorMsg = tmpMsg
					end
				end
			end

			for _, ns in ipairs(self) do
				info = _NSInfo[ns]

				tmpMsg = nil

				if not info then
					-- do nothing
				elseif info.Type == TYPE_STRUCT then
					-- Check if the value is an enumeration value of this structure
					flag, tmpMsg = pcall(ValidateStruct, ns, value)

					if flag then return tmpMsg, ns end

					tmpMsg = strtrim(tmpMsg:match(":%d+:%s*(.-)$") or tmpMsg)
				elseif info.Type == TYPE_CLASS then
					-- Check if the value is an instance of this class
					if type(value) == "table" and getmetatable(value) and IsChildClass(ns, getmetatable(value)) then return value, ns end

					tmpMsg = ("%s must be an instance of [class]%s."):format("%s", tostring(ns))
				elseif info.Type == TYPE_INTERFACE then
					-- Check if the value is an instance of this interface
					if type(value) == "table" and getmetatable(value) and IsExtend(ns, getmetatable(value)) then return value, ns end

					tmpMsg = ("%s must be an instance extended from [interface]%s."):format("%s", tostring(ns))
				elseif info.Type == TYPE_ENUM then
					-- Check if the value is an enumeration value of this enum
					if type(value) == "string" and info.Enum[strupper(value)] then return info.Enum[strupper(value)], ns end

					if info.MaxValue then
						-- Bit flag validation, use MaxValue check to reduce cost
						value = tonumber(value)

						if value then
							if value >= 1 and value <= info.MaxValue then
								return floor(value), ns
							elseif value == 0 then
								if info.Cache[value] then return value, ns end
							end
						end
					else
						if info.Cache[value] then return value, ns end
					end

					tmpMsg = ("%s must be a value of [enum]%s ( %s )."):format("%s", tostring(ns), GetShortEnumInfo(ns))
				end

				if tmpMsg and not errorMsg then
					if partName and partName ~= "" then
						if tmpMsg:find("%%s([_%w]+)") then
							errorMsg = tmpMsg:gsub("%%s", "%%s"..partName..".")
						else
							errorMsg = tmpMsg:gsub("%%s", "%%s"..partName)
						end
					else
						errorMsg = tmpMsg
					end
				end
			end

			if errorMsg and rawget(self, _ALLOW_NIL) and not errorMsg:match("%(Optional%)$") then errorMsg = errorMsg .. "(Optional)" end

			if errorMsg then
				if mainName and errorMsg:find("%%s") then errorMsg = errorMsg:gsub("%%s[_%w]*", mainName) end

				error(errorMsg, (stack or 1) + 1)
			end

			return value
		end

		doc "Clone" [[
			<desc>Clone the type object</desc>
			<return>the clone</return>
		]]
		function Clone(self)
			local _type = Type()

			for i, v in pairs(self) do _type[i] = v end

			return _type
		end

		doc "Is" [[
			<desc>Check if the type object constains such type</desc>
			<param name="type" type="struct|enum|class|interface|nil">the target type</param>
			<param name="onlyClass" optional="true">true if the type only match class, not class' object</param>
			<return type="boolean"></return>
		]]
		function Is(self, ns, onlyClass)
			local fenv = getfenv(2)

			if ns == nil then return self.AllowNil or false end

			if IsNameSpace(ns) then
				if not onlyClass then
					for _, v in ipairs(self) do if v == ns then return true end end
				else
					local index = -1

					while self[index] do
						if self[index] == ns then return true end
						index = index - 1
					end
				end
			end

			return false
		end

		doc "GetObjectType" [[
			<desc>Get the object type if validated, false if nothing match</desc>
			<param name="value">the value</param>
			<return name="type">the value's validated type</return>
		]]
		function GetObjectType(self, value)
			if value == nil and rawget(self, _ALLOW_NIL) then return end

			local info
			local index = -1

			while self[index] do
				info = _NSInfo[self[index]]

				if not info then
					-- skip
				elseif info.Type == TYPE_CLASS then
					if value and _NSInfo[value] and _NSInfo[value].Type == TYPE_CLASS and IsChildClass(info.Owner, value) then return info.Owner end
				elseif info.Type == TYPE_INTERFACE then
					if value and _NSInfo[value] and _NSInfo[value].Type == TYPE_CLASS and IsExtend(info.Owner, value) then return info.Owner end
				elseif info.Type then
					if value == info.Owner then return info.Owner end
				end

				index = index - 1
			end

			for _, ns in ipairs(self) do
				info = _NSInfo[ns]

				if not info then
					-- do nothing
				elseif info.Type == TYPE_CLASS then
					-- Check if the value is an instance of this class
					if type(value) == "table" and getmetatable(value) and IsChildClass(ns, getmetatable(value)) then return ns end
				elseif info.Type == TYPE_INTERFACE then
					-- Check if the value is an instance of this interface
					if type(value) == "table" and getmetatable(value) and IsExtend(ns, getmetatable(value)) then return ns end
				elseif info.Type == TYPE_ENUM then
					-- Check if the value is an enumeration value of this enum
					if type(value) == "string" and info.Enum[strupper(value)] then return ns end

					if info.MaxValue then
						-- Bit flag validation, use MaxValue check to reduce cost
						value = tonumber(value)

						if value then
							if value >= 1 and value <= info.MaxValue then
								return ns
							elseif value == 0 and info.Cache[value] then
								return ns
							end
						end
					elseif info.Cache[value] then
						return ns
					end
				elseif info.Type == TYPE_STRUCT then
					-- Check if the value is an enumeration value of this structure
					if pcall(ValidateStruct, ns, value) then return ns end
				end
			end

			return false
		end

		doc "GetValidatedValue" [[
			<desc>Get the validated value if validated, nil if not match</desc>
			<param name="value">the value</param>
			<return name="value">the validated value</return>
		]]
		function GetValidatedValue(self, value)
			if value == nil and rawget(self, _ALLOW_NIL) then return end

			local info
			local index = -1

			while self[index] do
				info = _NSInfo[self[index]]

				if not info then
					-- skip
				elseif info.Type == TYPE_CLASS then
					if value and _NSInfo[value] and _NSInfo[value].Type == TYPE_CLASS and IsChildClass(info.Owner, value) then return value end
				elseif info.Type == TYPE_INTERFACE then
					if value and _NSInfo[value] and _NSInfo[value].Type == TYPE_CLASS and IsExtend(info.Owner, value) then return value end
				elseif info.Type then
					if value == info.Owner then return value end
				end

				index = index - 1
			end

			for _, ns in ipairs(self) do
				info = _NSInfo[ns]

				if not info then
					-- do nothing
				elseif info.Type == TYPE_CLASS then
					-- Check if the value is an instance of this class
					if type(value) == "table" and getmetatable(value) and IsChildClass(ns, getmetatable(value)) then return value end
				elseif info.Type == TYPE_INTERFACE then
					-- Check if the value is an instance of this interface
					if type(value) == "table" and getmetatable(value) and IsExtend(ns, getmetatable(value)) then return value end
				elseif info.Type == TYPE_ENUM then
					-- Check if the value is an enumeration value of this enum
					if type(value) == "string" then
						local uValue = info.Enum[strupper(value)]
						if uValue ~= nil then return uValue end
					end

					if info.MaxValue then
						-- Bit flag validation, use MaxValue check to reduce cost
						value = tonumber(value)

						if value then
							if value >= 1 and value <= info.MaxValue then
								return value
							elseif value == 0 and info.Cache[value] then
								return value
							end
						end
					elseif info.Cache[value] then
						return value
					end
				elseif info.Type == TYPE_STRUCT then
					-- Check if the value is an enumeration value of this structure
					local flag, new = pcall(ValidateStruct, ns, value)

					if flag then return new end
				end
			end
		end

		------------------------------------------------------
		-- MetaMethod
		------------------------------------------------------
		function __add(v1, v2)
			local ok, _type1, _type2

			ok, _type1 = pcall(BuildType, v1)
			if not ok then error(strtrim(_type1:match(":%d+:%s*(.-)$") or _type1), 2) end

			ok, _type2 = pcall(BuildType, v2)
			if not ok then error(strtrim(_type2:match(":%d+:%s*(.-)$") or _type2), 2) end

			if _type1 and _type2 then
				local _type = Type()

				_type.AllowNil = _type1.AllowNil or _type2.AllowNil

				local tmp = {}

				for _, ns in ipairs(_type1) do
					tinsert(_type, ns)
					tmp[ns] = true
				end
				for _, ns in ipairs(_type2) do if not tmp[ns] then tinsert(_type, ns) end end

				wipe(tmp)

				local index = -1
				local pos = -1

				while _type1[index] do
					tmp[_type1[index]] = true
					_type[pos] = _type1[index]
					pos = pos -1
					index = index - 1
				end

				index = -1

				while _type2[index] do
					if not tmp[_type2[index]] then
						_type[pos] = _type2[index]
						pos = pos -1
					end
					index = index - 1
				end

				tmp = nil

				return _type
			else
				return _type1 or _type2
			end
		end

		function __sub(v1, v2)
			if IsNameSpace(v2) then
				local ok, _type2

				ok, _type2 = pcall(BuildType, v2, true)
				if not ok then error(strtrim(_type2:match(":%d+:%s*(.-)$") or _type2), 2) end

				return v1 + _type2
			elseif v2 == nil then
				return v1
			else
				error("The operation '-' must be used with class or interface.", 2)
			end
		end

		function __unm(v1) error("Can't use unary '-' before a Type", 2) end

		function __eq(v1, v2)
			if getmetatable(v1) == Type and getmetatable(v2) == Type and v1.AllowNil == v2.AllowNil and #v1 == #v2 then
				local index = -1
				while rawget(v1, index) do
					if v1[index] == v2[index] then
						index = index - 1
					else
						return false
					end
				end

				if rawget(v2, index) then return false end

				for i = 1, #v1 do
					if v1[i] ~= v2[i] then return false end
				end

				return true
			else
				return false
			end
		end

		function __tostring(self)
			local ret = ""

			for _, tns in ipairs(self) do ret = ret .. " + " .. GetFullName4NS(tns) end

			local index = -1
			while self[index] do
				ret = ret .. " - " .. GetFullName4NS(self[index])
				index = index - 1
			end

			-- Allow nil
			if self.AllowNil then ret = ret .. " + nil" end
			if ret:sub(1, 2) == " +" then ret = ret:sub(4, -1) end

			return ret
		end
	endclass "Type"

	class "Event"
		doc "Event" [[The object event definition]]

		doc "Name" [[The event's name]]
		property "Name" { Type = String, Default = "Anonymous" }

		doc "Delegate" [[The delegate for the event handler, used to wrap the event call]]
		property "Delegate" { Type = Function + nil }

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function Event(self, name)
			if type(name) == "string" then self.Name = name end
		end

		------------------------------------------------------
		-- Meta-Method
		------------------------------------------------------
		function __tostring(self) return ("%s( %q )"):format(tostring(Event), self.Name) end
	endclass "Event"

	class "EventHandler"
		doc "EventHandler" [[The object event handler]]

		local function FireOnEventHandlerChanged(self) return Reflector.FireObjectEvent(self.Owner, "OnEventHandlerChanged", self.Event) end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc "IsEmpty" [[
			<desc>Check if the event handler is empty</desc>
			<return type="boolean">true if the event handler has no functions</return>
		]]
		function IsEmpty(self) return #self == 0 and self[0] == nil end

		doc "Clear" [[Clear all handlers]]
		function Clear(self)
			if #self > 0 or self[0] then
				for i = #self, 1, -1 do self[i] = nil end self[0] = nil
				return FireOnEventHandlerChanged(self)
			end
		end

		doc "Copy" [[
			<desc>Copy handlers from the source event handler</desc>
			<param name="src" type="System.EventHandler">the event handler source</param>
		]]
		function Copy(self, src)
			if self ~= src and getmetatable(src) == EventHandler and self.Event == src.Event then
				for i = #self, 1, -1 do self[i] = nil end self[0] = nil
				for i = #src, 1, -1 do self[i] = src[i] end self[0] = src[0]

				return FireOnEventHandlerChanged(self)
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Owner" [[The owner of the event handler]]
		property "Owner" { Type = Table }

		doc "Event" [[The event's name]]
		property "Event" { Type = String }

		doc "Blocked" [[Whether the event handler is blocked]]
		property "Blocked" { Type = Boolean }

		doc "Handler" [[The customer's handler]]
		property "Handler" { Field = 0, Type = Function + nil, Handler = FireOnEventHandlerChanged }

		doc "Delegate" [[The delegate for the event handler, used to wrap the event call]]
		property "Delegate" { Type = Function + nil }

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function EventHandler(self, evt, owner)
			if not Reflector.ObjectIsClass(evt, Event) then error("Usage : EventHandler(event, owner) - 'event' must be an object of 'System.Event'.") end
			if not Reflector.GetObjectClass(owner) then error("Usage : EventHandler(event, owner) - 'owner' must be an object.") end

			self.Event = evt.Name
			self.Owner = owner
			self.Delegate = evt.Delegate
		end

		------------------------------------------------------
		-- Meta-Method
		------------------------------------------------------
		function __add(self, func)
			if type(func) ~= "function" then error("Usage: obj.OnXXXX = obj.OnXXXX + func", 2) end

			for _, f in ipairs(self) do if f == func then return self end end

			tinsert(self, func)
			FireOnEventHandlerChanged(self)

			return self
		end

		function __sub(self, func)
			if type(func) ~= "function" then error("Usage: obj.OnXXXX = obj.OnXXXX - func", 2) end

			for i, f in ipairs(self) do if f == func then tremove(self, i) FireOnEventHandlerChanged(self) break end end

			return self
		end

		local function raiseEvent(self, owner, ...)
			local ret = false

			-- Call the stacked handlers
			for _, handler in ipairs(self) do
				ret = handler(owner, ...) or rawget(owner, "Disposed")

				-- Any handler return true means to stop all
				if ret then break end
			end

			-- Call the custom handler
			return not ret and self[0] and self[0](owner, ...)
		end

		function __call(self, obj, ...)
			if self.Blocked then return end

			local owner = self.Owner
			local delegte = self.Delegate

			if delegte then
				if owner == obj then
					return delegte(raiseEvent, self, obj, ...)
				else
					return delegte(raiseEvent, self, owner, obj, ...)
				end
			else
				if owner == obj then
					return raiseEvent(self, obj, ...)
				else
					return raiseEvent(self, owner, obj, ...)
				end
			end
		end
	endclass "EventHandler"

	class "FixedMethod"
		doc "FixedMethod" [[Used to control method with fixed arguments]]

		-- Reduce cache table cost
		local function keepArgs(...)
			local flag = yield( running() )

			while flag do flag = yield( ... ) end

			return ...
		end

		-- Find the real next method in class | interface
		local function getNextMethod(ns, name, noFunc, chkSelf)
			local info = _NSInfo[ns]

			if chkSelf and info.Method[name] then return info.Method["0" .. name] or (not noFunc and info.Method[name]) end

			if info.SuperClass then
				local handler = getNextMethod(info.SuperClass, name, noFunc, true)

				if handler then return handler end
			end

			if info.ExtendInterface then
				for _, IF in ipairs(info.ExtendInterface) do
					local handler = getNextMethod(IF, name, noFunc, true)

					if handler then return handler end
				end
			end
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc "MatchArgs" [[Whether the fixed method can handler the arguments]]
		function MatchArgs(self, ...)
			local base = self.HasSelf and 1 or 0
			local count = select('#', ...) - base
			local argsCount = #self
			local argsChanged = false

			-- Empty methods won't accept any arguments
			if argsCount == 0 then return count == 0 end

			-- Check argument settings
			if count >= self.MinArgs and count <= self.MaxArgs then
				local cache = CACHE_TABLE()

				-- Cache first
				if count == 1 then
					cache[1] = select(1 + base, ...)
				elseif count == 2 then
					cache[1], cache[2] = select(1 + base, ...)
				elseif count == 3 then
					cache[1], cache[2], cache[3] = select(1 + base, ...)
				elseif count == 4 then
					cache[1], cache[2], cache[3], cache[4] = select(1 + base, ...)
				else
					for i = 1, count do cache[i] = select(i + base, ...) end
				end

				-- required
				for i = 1, self.MinArgs do
					local arg = self[i]
					local value = cache[i]

					if value == nil then
						-- Required argument can't be nil
						return CACHE_TABLE(cache)
					elseif arg.Type then
						-- Clone if needed
						if arg.CloneNeeded then value = CloneObj(value, true) end
						-- Validate the value
						value = arg.Type:GetValidatedValue(value)
						if value == nil then return CACHE_TABLE(cache) end
					end

					if cache[i] ~= value then
						argsChanged = true
						cache[i] = value
					end
				end

				-- optional
				for i = self.MinArgs + 1, count do
					local arg = self[i] or self[argsCount]
					local value = cache[i]

					if value == nil then
						-- No check
						if arg.Default ~= nil then value = CloneObj(arg.Default, true) end
					elseif arg.Type then
						-- Clone if needed
						if arg.CloneNeeded then value = CloneObj(value, true) end
						-- Validate the value
						value = arg.Type:GetValidatedValue(value)
						if value == nil then return CACHE_TABLE(cache) end
					end

					if cache[i] ~= value then
						argsChanged = true
						cache[i] = value
					end
				end

				if base == 1 then tinsert(cache, 1, (select(1, ...))) end

				-- Keep arguments in thread, so cache can be recycled
				if argsChanged then
					count = base + count

					if count == 1 then
						self.Thread = CallThread(keepArgs, cache[1])
					elseif count == 2 then
						self.Thread = CallThread(keepArgs, cache[1], cache[2])
					elseif count == 3 then
						self.Thread = CallThread(keepArgs, cache[1], cache[2], cache[3])
					elseif count == 4 then
						self.Thread = CallThread(keepArgs, cache[1], cache[2], cache[3], cache[4])
					else
						self.Thread = CallThread(keepArgs, unpack(cache, 1, count))
					end
				end

				CACHE_TABLE(cache)

				return true
			end
		end

		doc "RaiseError" [[Fire the error to show the usage of the fixedMethod link list]]
		function RaiseError(self, obj)
			-- Get the root call fixmethod
			if self.HasSelf then
				local cls = getmetatable(obj)

				-- Can't figure out the class method that start the call
				if not cls then error(self.Usage, 2) end

				self = getNextMethod(cls, self.Name, true, true)
			else
				self = getNextMethod(self.Owner, self.Name, true, true)
			end

			-- Generate the usage list
			local usage = CACHE_TABLE()

			while getmetatable(self) do
				local fUsage = self.Usage
				local params = fUsage:match("Usage : %w+.(.+)")

				if params and not usage[params] then
					usage[params] = true
					tinsert(usage, fUsage)
				end

				self = self.Next
			end

			local msg = tblconcat(usage, "\n")
			CACHE_TABLE(usage)

			error(msg, 2)
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Next" [[The next fixed method]]
		property "Next" {
			Field = "__Next",
			Get = function (self)
				if self.__Next == nil and self.HasSelf then
					if self.TargetType == AttributeTargets.Method then
						self.__Next = getNextMethod(self.Owner, self.Name) or false
					elseif self.TargetType == AttributeTargets.Constructor then
						local info = _NSInfo[self.Owner]

						while info and info.SuperClass do
							info = _NSInfo[info.SuperClass]

							-- No link for constructor
							if info.Constructor then return info.Constructor end
						end
					end
				end

				return self.__Next or nil
			end,
			Type = FixedMethod + Function + nil,
		}

		doc "Usage" [[The usage of the fixed method]]
		property "Usage" {
			Get = function (self)
				if self.__Usage then return self.__Usage end

				-- Generate usage message
				local usage = CACHE_TABLE()
				local name = self.Name
				local owner = self.Owner

				if self.TargetType == AttributeTargets.Method then
					if (name:match("^_") and not (Reflector.IsClass(owner) and (_KeyMeta[name] or _KeyMeta[name:sub(2)] == false))) or
						( Reflector.IsInterface(owner) and Reflector.IsNonInheritable(owner) ) then
						tinsert(usage, "Usage : " .. tostring(owner) .. "." .. name .. "( ")
					else
						tinsert(usage, "Usage : " .. tostring(owner) .. ":" .. name .. "( ")
					end
				else
					tinsert(usage, "Usage : " .. tostring(owner) .. "( ")
				end

				for i = 1, #self do
					local arg = self[i]
					local str = ""

					if i > 1 then tinsert(usage, ", ") end

					-- [name As type = default]
					if arg.Name then
						str = str .. arg.Name

						if arg.Type then str = str .. " As " end
					end

					if arg.Type then str = str .. tostring(arg.Type) end

					if arg.Default ~= nil then
						local serialize = Reflector.Serialize(arg.Default, arg.Type)

						if serialize then str = str .. " = " .. serialize end
					end

					if not arg.Type or arg.Type:Is(nil) then str = "[" .. str .. "]" end

					tinsert(usage, str)
				end

				tinsert(usage, " )")

				self.__Usage = tblconcat(usage, "")

				CACHE_TABLE(usage)

				return self.__Usage
			end
		}

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------

		------------------------------------------------------
		-- Meta-methods
		------------------------------------------------------
		function __call(self, ...)
			--[[ Validation self once, maybe no need to waste time
			if self.HasSelf then
				local value = select(1, ...)
				local owner = self.Owner

				if not value or
					( Reflector.IsInterface(owner) and not Reflector.ObjectIsInterface(value, owner) ) or
					( Reflector.IsClass(owner) and not Reflector.ObjectIsClass(value, owner)) or
					( Reflector.IsStruct(owner) and not pcall(owner.Validate, value)) then

					error(self.Usage, 2)
				end
			end--]]
			local matchFunc = self

			-- FixedMethod
			while getmetatable(matchFunc) do
				matchFunc.Thread = nil

				if MatchArgs(matchFunc, ...) then
					if matchFunc.Thread then
						return matchFunc.Method( select(2, resume(matchFunc.Thread, false)) )
					else
						return matchFunc.Method( ... )
					end
				end

				-- Remove argument container
				if matchFunc.Thread then
					resume(matchFunc.Thread, false)
					matchFunc.Thread = nil
				end

				matchFunc = matchFunc.Next
			end

			-- Function
			if matchFunc then return matchFunc( ... ) end

			return RaiseError(self, ...)
		end

		function __tostring(self) return self.Usage end
	endclass "FixedMethod"
end

------------------------------------------------------
-- System Namespace (Attribute System)
------------------------------------------------------
do
	namespace "System"

	------------------------------------------------------
	-- System.__Attribute__
	------------------------------------------------------
	class "__Attribute__"

		doc "__Attribute__" [[The __Attribute__ class associates predefined system information or user-defined custom information with a target element.]]

		_PreparedAttributes = {}
		_ThreadPreparedAttributes = setmetatable({}, WEAK_KEY)

		_AttributeCache = {
			[AttributeTargets.Class] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Constructor] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Enum] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Event] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Interface] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Method] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Property] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Struct] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.Field] = setmetatable({}, WEAK_KEY),
			[AttributeTargets.NameSpace] = setmetatable({}, WEAK_KEY),
		}

		-- A little trick
		_AttributeTargetsCache = _NSInfo[AttributeTargets].Cache

		-- Recycle the cache for dispose attributes
		_AttributeCache4Dispose = setmetatable({}, {
			__call = function(self, key)
				if key then
					if type(key) == "table" and self[key] then
						for attr in pairs(key) do
							key[attr] = nil
							if not rawget(attr, "Disposed") then attr:Dispose() end
						end

						tinsert(self, key)
					end
				else
					if #self > 0 then
						return tremove(self, #self)
					else
						local ret = {}

						-- Mark it as recycle table
						self[ret] = true

						return ret
					end
				end
			end,
		})

		local function SendToPrepared(self)
			-- Send to prepared cache
			local thread = running()
			local prepared

			if thread then
				_ThreadPreparedAttributes[thread] = _ThreadPreparedAttributes[thread] or {}
				prepared = _ThreadPreparedAttributes[thread]
			else
				prepared = _PreparedAttributes
			end

			for i, v in ipairs(prepared) do if v == self then return end end

			tinsert(prepared, self)
		end

		local function ParseTarget(target, targetType, owner, name)
			if targetType == AttributeTargets.Class then
				return "[Class]" .. tostring(target)
			elseif targetType == AttributeTargets.Constructor then
				return "[Class.Constructor]" .. tostring(target)
			elseif targetType == AttributeTargets.Enum then
				return "[Enum]" .. tostring(target)
			elseif targetType == AttributeTargets.Event then
				return "[Class]" .. tostring(owner) .. " [Event]" .. tostring(target.Name)
			elseif targetType == AttributeTargets.Interface then
				return "[Interface]" .. tostring(target)
			elseif targetType == AttributeTargets.Method then
				if Reflector.IsClass(owner) then
					return "[Class]" .. tostring(owner) .. " [Method]" .. tostring(name or "anonymous")
				elseif Reflector.IsInterface(owner) then
					return "[Interface]" .. tostring(owner) .. " [Method]" .. tostring(name or "anonymous")
				else
					return "[Method]" .. tostring(name or "anonymous")
				end
			elseif targetType == AttributeTargets.Property then
				if Reflector.IsClass(owner) then
					return "[Class]" .. tostring(owner) .. " [Property]" .. tostring(target.Name  or "anonymous")
				elseif Reflector.IsInterface(owner) then
					return "[Interface]" .. tostring(owner) .. " [Property]" .. tostring(target.Name  or "anonymous")
				else
					return "[Property]" .. tostring(target.Name  or "anonymous")
				end
			elseif targetType == AttributeTargets.Struct then
				return "[Struct]" .. tostring(target)
			elseif targetType == AttributeTargets.Field then
				return "[Struct]" .. tostring(owner) .. " [Field]" .. tostring(name)
			elseif targetType == AttributeTargets.NameSpace then
				return "[NameSpace]" .. tostring(target)
			end
		end

		local function ValidateTargetType(target, targetType)
			if targetType == AttributeTargets.Class then
				return Reflector.IsClass(target)
			elseif targetType == AttributeTargets.Constructor then
				return type(target) == "function"
			elseif targetType == AttributeTargets.Enum then
				return Reflector.IsEnum(target)
			elseif targetType == AttributeTargets.Event then
				return Reflector.ObjectIsClass(target, Event)
			elseif targetType == AttributeTargets.Interface then
				return Reflector.IsInterface(target)
			elseif targetType == AttributeTargets.Method then
				return type(target) == "function" or getmetatable(target) == FixedMethod
			elseif targetType == AttributeTargets.Property then
				-- Normally, this only be called by the system
				return type(target) == "table" and type(target.Name) == "string"
			elseif targetType == AttributeTargets.Struct then
				return Reflector.IsStruct(target)
			elseif targetType == AttributeTargets.Field then
				return Reflector.ObjectIsClass(target, Type)
			elseif targetType == AttributeTargets.NameSpace then
				return Reflector.GetNameSpaceName(target)
			end
		end

		local function ValidateUsable(config, attr, skipMulti)
			if getmetatable(config) then
				if Reflector.IsEqual(config, attr) then return false end

				if not skipMulti and getmetatable(config) == getmetatable(attr) then
					local usage = _GetCustomAttribute(getmetatable(config), AttributeTargets.Class, __AttributeUsage__)

					if not usage or not usage.AllowMultiple then return false end
				end
			else
				for _, v in ipairs(config) do if not ValidateUsable(v, attr, skipMulti) then return false end end
			end

			return true
		end

		local function _ApplyAttributes(target, targetType, owner, name, start)
			-- Apply the attributes
			local config = _AttributeCache[targetType][target]

			if config then
				local ok, ret, arg1, arg2, arg3, arg4

				-- Some target can't be send to the attribute's ApplyAttribute directly
				if targetType == AttributeTargets.Event then
					arg1 = target.Name
					arg2 = targetType
					arg3 = owner
				elseif targetType == AttributeTargets.Method then
					arg1 = getmetatable(target) and target.Method or target
					arg2 = targetType
					arg3 = owner
					arg4 = name
				elseif targetType == AttributeTargets.Property then
					arg1 = target.Predefined
					arg2 = targetType
					arg3 = owner
					arg4 = name
				elseif targetType == AttributeTargets.Field then
					arg1 = name
					arg2 = targetType
					arg3 = owner
				elseif targetType == AttributeTargets.Constructor then
					arg1 = target
					arg2 = targetType
					arg3 = owner
					arg4 = name
				else
					arg1 = target
					arg2 = targetType
				end

				if getmetatable(config) then
					ok, ret = pcall(config.ApplyAttribute, config, arg1, arg2, arg3, arg4)

					if not ok then
						errorhandler(ret)

						_AttributeCache[targetType][target] = nil
					else
						local usage = _GetCustomAttribute(getmetatable(config), AttributeTargets.Class, __AttributeUsage__)

						if usage and not usage.Inherited and usage.RunOnce then
							_AttributeCache[targetType][target] = nil

							config:Dispose()
						end

						if targetType == AttributeTargets.Method or targetType == AttributeTargets.Constructor then
							-- The method may be wrapped in the apply operation
							if type(ret) == "function" or getmetatable(ret) == FixedMethod then target = ret end
						end
					end
				else
					local oldTarget = target

					start = start or 1

					for i = #config, start, -1 do
						ok, ret = pcall(config[i].ApplyAttribute, config[i], arg1, arg2, arg3, arg4)

						if not ok then
							errorhandler(ret)

							tremove(config, i)
						else
							local usage = _GetCustomAttribute(getmetatable(config[i]), AttributeTargets.Class, __AttributeUsage__)

							if usage and not usage.Inherited and usage.RunOnce then
								config[i]:Dispose()
								tremove(config, i)
							end

							if targetType == AttributeTargets.Method or targetType == AttributeTargets.Constructor then
								if type(ret) == "function" then
									if type(target) == "function" then
										target = ret
									else
										target.Method = ret
									end
									arg1 = ret
								elseif getmetatable(ret) == FixedMethod then
									target = ret
									arg1 = target.Method
								end
							end
						end
					end

					if #config == 0 then
						_AttributeCache[targetType][oldTarget] = nil
					elseif #config == 1 then
						_AttributeCache[targetType][oldTarget] = config[1]
					end
				end
			end

			return target
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc "_ClearPreparedAttributes" [[Clear the prepared attributes]]
		function _ClearPreparedAttributes(noDispose)
			local thread = running()

			if thread then
				if _ThreadPreparedAttributes[thread] then
					if not noDispose then
						for _, attr in ipairs(_ThreadPreparedAttributes[thread]) do attr:Dispose() end
					end
					wipe(_ThreadPreparedAttributes[thread])
				end
			else
				if not noDispose then
					for _, attr in ipairs(_PreparedAttributes) do attr:Dispose() end
				end
				wipe(_PreparedAttributes)
			end
		end

		doc "_ConsumePreparedAttributes" [[
			<desc>Set the prepared attributes for target</desc>
			<param name="target">the target's owner</param>
			<param name="targetType" type="System.AttributeTargets">the target's type</param>
			<param name="superTarget" optional="true">the super target the contains several attributes to be inherited</param>
			<param name="owner" optional="true">the class|interface object, the owner of the target</param>
			<param name="name" optional="true">the target's name</param>
			<return name="target"></return>
		]]
		function _ConsumePreparedAttributes(target, targetType, superTarget, owner, name)
			if not _AttributeCache[targetType] then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'targetType' is invalid.", 2)
			elseif not ValidateTargetType(target, targetType) then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'target' is invalid.", 2)
			elseif superTarget and not ValidateTargetType(superTarget, targetType) then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'superTarget' is invalid.", 2)
			end

			if not owner and IsNameSpace(target) then owner = target end

			-- Consume the prepared Attributes
			local prepared = _ThreadPreparedAttributes[running()] or _PreparedAttributes

			-- Filter with the usage
			if prepared and #prepared > 0 then
				local cls, usage
				local noUseAttr = _AttributeCache4Dispose()
				local usableAttr = _AttributeCache4Dispose()

				for i = 1, #prepared do
					local attr = prepared[i]
					cls = getmetatable(attr)
					usage = _GetCustomAttribute(cls, AttributeTargets.Class, __AttributeUsage__)

					if usage and usage.AttributeTarget > 0 and not Reflector.ValidateFlags(targetType, usage.AttributeTarget) then
						errorhandler("Can't apply the " .. tostring(cls) .. " attribute to the " .. ParseTarget(target, targetType, owner, name))
					elseif ValidateUsable(usableAttr, attr) then
						usableAttr[attr] = true
						tinsert(usableAttr, attr)
					else
						errorhandler("Can't apply the " .. tostring(cls) .. " attribute for multi-times.")
					end
				end

				for i = #prepared, 1, -1 do
					local attr = prepared[i]
					if not usableAttr[attr] then
						noUseAttr[attr] = true
						tremove(prepared, i)
					end
				end

				wipe(usableAttr)
				_AttributeCache4Dispose(usableAttr)
				_AttributeCache4Dispose(noUseAttr)
			end

			-- Check if already existed
			if _AttributeCache[targetType][target] then
				if prepared and #prepared > 0 then
					local config = _AttributeCache[targetType][target]
					local noUseAttr = _AttributeCache4Dispose()

					-- remove equal attributes
					for i = #prepared, 1, -1 do
						if not ValidateUsable(config, prepared[i], true) then
							noUseAttr[prepared[i]] = true
							tremove(prepared, i)
						end
					end

					_AttributeCache4Dispose(noUseAttr)

					if prepared and #prepared > 0 then
						-- Erase old no-multi attributes
						if getmetatable(config) then
							if not ValidateUsable(prepared, config) then _AttributeCache[targetType][target] = nil end
						else
							for i = #config, 1, -1 do
								if not ValidateUsable(prepared, config[i]) then tremove(config, i) end
							end

							if #config == 0 then _AttributeCache[targetType][target] = nil end
						end
					end
				end
			elseif superTarget then
				-- get inheritable attributes from superTarget
				local config = _AttributeCache[targetType][superTarget]
				local usage

				if config then
					if getmetatable(config) then
						usage = _GetCustomAttribute(getmetatable(config), AttributeTargets.Class, __AttributeUsage__)

						if not usage or usage.Inherited then
							prepared = prepared or {}

							if ValidateUsable(prepared, config) then tinsert(prepared, config) end
						end
					else
						for _, attr in ipairs(config) do
							usage = _GetCustomAttribute(getmetatable(attr), AttributeTargets.Class, __AttributeUsage__)

							if not usage or usage.Inherited then
								prepared = prepared or {}

								if ValidateUsable(prepared, attr) then tinsert(prepared, attr) end
							end
						end
					end
				end
			end

			-- Save & apply the attributes for target
			if #prepared > 0 then
				local start = 1

				if _AttributeCache[targetType][target] then
					local config = _AttributeCache[targetType][target]

					if getmetatable(config) then config = { config } end

					start = #config + 1

					for _, attr in ipairs(prepared) do tinsert(config, attr) end

					_AttributeCache[targetType][target] = config
				else
					if #prepared == 1 then
						_AttributeCache[targetType][target] = prepared[1]
					else
						_AttributeCache[targetType][target] = { unpack(prepared) }
					end
				end

				wipe(prepared)

				local ret =  _ApplyAttributes(target, targetType, owner, name, start) or target

				if target ~= ret then
					_AttributeCache[targetType][ret] = _AttributeCache[targetType][target]
					_AttributeCache[targetType][target] = nil

					target = ret
				end
			end

			_ClearPreparedAttributes()

			return target
		end

		doc "_CloneAttributes" [[
			<desc>Clone the attributes</desc>
			<param name="source">the source</param>
			<param name="target">the target</param>
			<param name="targetType" type="System.AttributeTargets">the target's type</param>
			<param name="owner" optional="true">the class|interface object, the owner of the target</param>
			<param name="name" optional="true">the target's name</param>
			<param name="removeSource" type="boolean" optional="true">true if remove attributes settings from the source</param>
			<return name="target"></return>
		]]
		function _CloneAttributes(source, target, targetType, owner, name, removeSource)
			if not _AttributeCache[targetType] then
				error("Usage : __Attribute__._CloneAttributes(source, target, targetType[, owner, name]) - 'targetType' is invalid.", 2)
			elseif  not ValidateTargetType(source, targetType) then
				error("Usage : __Attribute__._CloneAttributes(source, target, targetType[, owner, name]) - 'source' is invalid.", 2)
			elseif  not ValidateTargetType(target, targetType) then
				error("Usage : __Attribute__._CloneAttributes(source, target, targetType[, owner, name]) - 'target' is invalid.", 2)
			end

			if source == target then return end

			local config = _AttributeCache[targetType][source]

			-- Save & apply the attributes for target
			if config then
				local start = 1

				-- Check existed attributes
				if _AttributeCache[targetType][target] then
					local attrs = _AttributeCache[targetType][target]

					if getmetatable(config) then
						if not ValidateUsable(attrs, config) then
							if removeSource then _AttributeCache[targetType][source] = nil end

							return target
						end

						if getmetatable(attrs) then
							attrs = { attrs }
							_AttributeCache[targetType][target] = attrs
						end

						start = #attrs + 1

						tinsert(attrs, config)
					else
						local usableAttr = _AttributeCache4Dispose()

						for i = 1, #config do if ValidateUsable(attrs, config[i]) then tinsert(usableAttr, config[i]) end end

						if #usableAttr == 0 then
							if removeSource then _AttributeCache[targetType][source] = nil end

							_AttributeCache4Dispose(usableAttr)

							return target
						end

						if getmetatable(attrs) then
							attrs = { attrs }
							_AttributeCache[targetType][target] = attrs
						end

						start = #attrs + 1

						for i = 1, #usableAttr do tinsert(attrs, usableAttr[i]) end

						wipe(usableAttr)

						_AttributeCache4Dispose(usableAttr)
					end
				else
					_AttributeCache[targetType][target] = config
				end

				local ret =  _ApplyAttributes(target, targetType, owner, name, start) or target

				if target ~= ret then
					_AttributeCache[targetType][ret] = _AttributeCache[targetType][target]
					_AttributeCache[targetType][target] = nil

					target = ret
				end

				if removeSource then _AttributeCache[targetType][source] = nil end
			end

			return target
		end

		doc "_IsDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class | event | method | property | struct | interface | enum</param>
			<param name="targetType" type="System.AttributeTargets">the target's type</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsDefined(target, targetType, type)
			local config = _AttributeCache[targetType][target]

			if not config then
				return false
			elseif not type then
				return true
			elseif getmetatable(config) then
				return getmetatable(config) == type
			else
				for _, attr in ipairs(config) do if getmetatable(attr) == type then return true end end
				return false
			end
		end

		doc "_IsClassAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsClassAttributeDefined(target, type)
			if Reflector.IsClass(target) then return _IsDefined(target, AttributeTargets.Class, type) end
		end

		doc "_IsConstructorAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsConstructorAttributeDefined(target, type)
			if Reflector.IsClass(target) then return _IsDefined(target, AttributeTargets.Constructor, type) end
		end

		doc "_IsEnumAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">enum</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsEnumAttributeDefined(target, type)
			if Reflector.IsEnum(target) then return _IsDefined(target, AttributeTargets.Enum, type) end
		end

		doc "_IsEventAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class | interface</param>
			<param name="event">the event's name</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsEventAttributeDefined(target, event, type)
			local info = _NSInfo[target]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Event[event] then
				return _IsDefined(info.Cache4Event[event], AttributeTargets.Event, type)
			end
		end

		doc "_IsInterfaceAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">interface</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsInterfaceAttributeDefined(target, type)
			if Reflector.IsInterface(target) then return _IsDefined(target, AttributeTargets.Interface, type) end
		end

		doc "_IsMethodAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class | interface</param>
			<param name="method">the method's name</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsMethodAttributeDefined(target, method, type)
			if type(target) == "function" then
				return _IsDefined(target, AttributeTargets.Method, method)
			elseif getmetatable(target) == FixedMethod then
				while target do
					if _IsDefined(target, AttributeTargets.Method, method) then return true end

					target = getmetatable(target) and target.Next
				end
			elseif (Reflector.IsClass(target) or Reflector.IsInterface(target) or Reflector.IsStruct(target)) and type(method) == "string" then
				return _IsMethodAttributeDefined(target[method], type)
			end
		end

		doc "_IsPropertyAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">class | interface</param>
			<param name="property">the property's name</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsPropertyAttributeDefined(target, prop, type)
			local info = _NSInfo[target]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[prop] then
				return _IsDefined(info.Cache4Property[prop], AttributeTargets.Property, type)
			end
		end

		doc "_IsStructAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">struct</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsStructAttributeDefined(target, type)
			if Reflector.IsStruct(target) then return _IsDefined(target, AttributeTargets.Struct, type) end
		end

		doc "_IsFieldAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">struct</param>
			<param name="field">the field's name</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsFieldAttributeDefined(target, field, type)
			local info = _NSInfo[target]

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					for _, part in ipairs(info.Members) do
						if part == field then return _IsDefined(info.StructEnv[field], AttributeTargets.Field, type) end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return _IsDefined(info.ArrayElement, AttributeTargets.Field, type)
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					return _IsDefined(info.StructEnv[field], AttributeTargets.Field, type)
				end
			end

			return false
		end

		doc "_IsNameSpaceAttributeDefined" [[
			<desc>Check whether the target contains such type attribute</desc>
			<param name="target">the name space</param>
			<param name="type">the attribute class type</param>
			<return type="boolean">true if the target contains attribute with the type</return>
		]]
		function _IsNameSpaceAttributeDefined(target, type)
			if Reflector.IsStruct(target) then return _IsDefined(target, AttributeTargets.NameSpace, type) end
		end

		doc "_GetCustomAttribute" [[
			<desc>Return the attributes of the given type for the target</desc>
			<param name="target">class | event | method | property | struct | interface | enum</param>
			<param name="targetType" type="System.AttributeTargets">the target's type</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetCustomAttribute(target, targetType, type)
			local config = _AttributeCache[targetType][target]

			if not config then
				return
			elseif getmetatable(config) then
				return getmetatable(config) == type and config or nil
			else
				local cache = _AttributeCache4Dispose()

				for _, attr in ipairs(config) do if getmetatable(attr) == type then tinsert(cache, attr) end end

				if #cache == 0 then
					_AttributeCache4Dispose(cache)
					return
				elseif #cache == 1 then
					local ret = cache[1]
					wipe(cache)
					_AttributeCache4Dispose(cache)
					return ret
				else
					local ret = {unpack(cache)}
					wipe(cache)
					_AttributeCache4Dispose(cache)
					return unpack(ret)
				end
			end
		end

		doc "_GetClassAttribute" [[
			<desc>Return the attributes of the given type for the class</desc>
			<param name="target">class</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetClassAttribute(target, type)
			if Reflector.IsClass(target) then return _GetCustomAttribute(target, AttributeTargets.Class, type) end
		end

		doc "_GetConstructorAttribute" [[
			<desc>Return the attributes of the given type for the class's constructor</desc>
			<param name="target">class</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetConstructorAttribute(target, type)
			if Reflector.IsClass(target) then return _GetCustomAttribute(target, AttributeTargets.Constructor, type) end
		end

		doc "_GetEnumAttribute" [[
			<desc>Return the attributes of the given type for the enum</desc>
			<param name="target">enum</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetEnumAttribute(target, type)
			if Reflector.IsEnum(target) then return _GetCustomAttribute(target, AttributeTargets.Enum, type) end
		end

		doc "_GetEventAttribute" [[
			<desc>Return the attributes of the given type for the class|interface's event</desc>
			<param name="target">class|interface</param>
			<param name="event">the event's name</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetEventAttribute(target, event, type)
			local info = _NSInfo[target]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Event[event] then
				return _GetCustomAttribute(info.Cache4Event[event], AttributeTargets.Event, type)
			end
		end

		doc "_GetInterfaceAttribute" [[
			<desc>Return the attributes of the given type for the interface</desc>
			<param name="target">interface</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetInterfaceAttribute(target, type)
			if Reflector.IsInterface(target) then return _GetCustomAttribute(target, AttributeTargets.Interface, type) end
		end

		doc "_GetMethodAttribute" [[
			<desc>Return the attributes of the given type for the class|interface's method</desc>
			<format>target, method, type</format>
			<format>method, type</format>
			<param name="target">class|interface</param>
			<param name="method">the method's name(with target) or the method itself(without target)</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetMethodAttribute(target, method, type)
			if type(target) == "function" then
				return _GetCustomAttribute(target, AttributeTargets.Method, method)
			elseif getmetatable(target) == FixedMethod then
				local result

				while target do
					result = _GetCustomAttribute(target, AttributeTargets.Method, method)
					if result then return result end

					target = getmetatable(target) and target.Next
				end
			elseif (Reflector.IsClass(target) or Reflector.IsInterface(target) or Reflector.IsStruct(target)) and type(method) == "string" then
				return _GetMethodAttribute(target[method], type)
			end
		end

		doc "_GetPropertyAttribute" [[
			<desc>Return the attributes of the given type for the class|interface's property</desc>
			<param name="target">class|interface</param>
			<param name="prop">the property's name</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetPropertyAttribute(target, prop, type)
			local info = _NSInfo[target]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[prop] then
				return _GetCustomAttribute(info.Cache4Property[prop], AttributeTargets.Property, type)
			end
		end

		doc "_GetStructAttribute" [[
			<desc>Return the attributes of the given type for the struct</desc>
			<param name="target">struct</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetStructAttribute(target, type)
			if Reflector.IsStruct(target) then return _GetCustomAttribute(target, AttributeTargets.Struct, type) end
		end

		doc "_GetFieldAttribute" [[
			<desc>Return the attributes of the given type for the struct's field</desc>
			<param name="target">struct</param>
			<param name="field">the field's name</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetFieldAttribute(target, field, type)
			local info = _NSInfo[target]

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					for _, part in ipairs(info.Members) do
						if part == field then return _GetCustomAttribute(info.StructEnv[field], AttributeTargets.Field, type) end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return _GetCustomAttribute(info.ArrayElement, AttributeTargets.Field, type)
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					return _GetCustomAttribute(info.StructEnv[field], AttributeTargets.Field, type)
				end
			end
		end

		doc "_GetNameSpaceAttribute" [[
			<desc>Return the attributes of the given type for the NameSpace</desc>
			<param name="target">NameSpace</param>
			<param name="type">the attribute class type</param>
			<return>the attribute objects</return>
		]]
		function _GetNameSpaceAttribute(target, type)
			if Reflector.GetNameSpaceName(target) then return _GetCustomAttribute(target, AttributeTargets.NameSpace, type) end
		end

		doc "ApplyAttribute" [[
			<desc>Apply the attribute to the target, overridable</desc>
			<param name="target">the attribute's target</param>
			<param name="targetType" type="System.AttributeTargets">the target's type</param>
			<param name="owner">the target's owner</param>
			<param name="name">the target's name</param>
			<return>the target, also can be modified</return>
		]]
		function ApplyAttribute(self, target, targetType, owner, name)
			-- Pass
		end

		doc [[Remove self from the prepared attributes]]
		function RemoveSelf(self)-- Send to prepared cache
			local thread = running()
			local prepared

			if thread then
				_ThreadPreparedAttributes[thread] = _ThreadPreparedAttributes[thread] or {}
				prepared = _ThreadPreparedAttributes[thread]
			else
				prepared = _PreparedAttributes
			end

			for i, v in ipairs(prepared) do if v == self then return tremove(prepared, i) end end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Attribute__(self) SendToPrepared(self) end
	endclass "__Attribute__"

	-- Attribute system on
	ATTRIBUTE_INSTALLED = true

	class "__Unique__"
		inherit "__Attribute__"

		doc "__Unique__" [[Mark the class will only create one unique object, and can't be disposed, also the class can't be inherited]]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsClass(target) then
				_NSInfo[target].NonInheritable = true
				_NSInfo[target].UniqueObject = true
			end
		end
	endclass "__Unique__"

	class "__Flags__"
		inherit "__Attribute__"

		doc "__Flags__" [[Indicates that an enumeration can be treated as a bit field; that is, a set of flags.]]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsEnum(target) then
				_NSInfo[target].IsFlags = true

				local enums = _NSInfo[target].Enum

				local cache = {}
				local count = 0
				local firstZero = true

				-- Count and clear
				for k, v in pairs(enums) do
					if v == 0 and firstZero then
						-- Only one may keep zero
						firstZero = false
					else
						cache[2^count] = true
						count = count + 1

						enums[k] = tonumber(v) or -1
						if enums[k] == 0 then enums[k] = -1 end
					end
				end

				_NSInfo[target].MaxValue = 2^count - 1

				-- Scan the existed bit values
				for k, v in pairs(enums) do
					if cache[v] == true then
						cache[v] = k
					elseif v ~= 0 then
						enums[k] = -1
					end
				end

				-- Apply the bit values
				local index = 0

				for k, v in pairs(enums) do
					if v == -1 then
						while cache[2^index] and cache[2^index] ~= true do
							index = index + 1
						end

						if cache[2^index] == true then
							cache[2^index] = k
							enums[k] = 2^index

							index = index + 1
						else
							error("There is something wrong")
						end
					end
				end
			end
		end
	endclass "__Flags__"

	class "__AttributeUsage__"
		inherit "__Attribute__"

		doc "__AttributeUsage__" [[Specifies the usage of another attribute class.]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "AttributeTarget" [[The attribute target type, default AttributeTargets.All]]
		property "AttributeTarget" { Default = AttributeTargets.All, Type = AttributeTargets }

		doc "Inherited" [[Whether your attribute can be inherited by classes that are derived from the classes to which your attribute is applied. Default true]]
		property "Inherited" { Default = true, Type = Boolean }

		doc "AllowMultiple" [[whether multiple instances of your attribute can exist on an element. default false]]
		property "AllowMultiple" { Type = Boolean }

		doc "RunOnce" [[Whether the property only apply once, when the Inherited is false, and the RunOnce is true, the attribute will be removed after apply operation]]
		property "RunOnce" { Type = Boolean }
	endclass "__AttributeUsage__"

	class "__Final__"
		inherit "__Attribute__"

		doc "__Final__" [[Mark the class|interface|struct|enum to be final, and can't be re-defined again]]

		function ApplyAttribute(self, target, targetType)
			if _NSInfo[target] then _NSInfo[target].IsFinal = true end
		end
	endclass "__Final__"

	class "__NonInheritable__"
		inherit "__Attribute__"

		doc "__NonInheritable__" [[Mark the class can't be inherited]]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsClass(target) or Reflector.IsInterface(target) then _NSInfo[target].NonInheritable = true end
		end
	endclass "__NonInheritable__"

	struct "Argument"
		Name = String + nil
		Type = Any + nil
		Default = Any + nil
		IsList = Boolean + nil

		local function isCloneNeeded(self)
			if getmetatable(self) ~= Type then return end

			for _, ns in ipairs(self) do
				local info = _NSInfo[ns]

				if info and info.Type == TYPE_STRUCT then
					if info.SubType == _STRUCT_TYPE_MEMBER then
						if info.Validator then return true end

						if info.Members then
							for _, n in ipairs(info.Members) do
								if isCloneNeeded(info.StructEnv[n]) then return true end
							end
						end
					elseif info.SubType == _STRUCT_TYPE_ARRAY then
						if isCloneNeeded(info.ArrayElement) then return true end
					elseif info.SubType == _STRUCT_TYPE_CUSTOM and info.Validator then
						return true
					end
				end
			end
		end

		function Argument(value)
			value.Type = GetUniqueType(value.Type and BuildType(value.Type) or nil)

			if value.Type and value.Default ~= nil then
				value.Default = value.Type:GetValidatedValue(value.Default)
			end

			-- Whether the value should be clone, argument match would change some value, Just for safe
			value.CloneNeeded = isCloneNeeded(value.Type)
		end
	endstruct "Argument"

	class "__Arguments__"
		inherit "__Attribute__"

		doc "__Arguments__" [[The argument definitions of the target method or class's constructor]]

		_Error_Header = [[Usage : __Arguments__{ arg1[, arg2[, ...] ] } : ]]
		_Error_NotArgument = [[arg%d must be System.Argument]]
		_Error_NotOptional = [[arg%d must also be optional]]
		_Error_NotList = [[arg%d can't be a list]]

		local function ValidateArgument(self, i)
			local isLast = i == #self

			local flag, arg = pcall( Argument.Validate, self[i] )

			if flag then
				-- Check optional args
				if not arg.Type or arg.Type:Is(nil) then
					if not self.MinArgs then self.MinArgs = i - 1 end
				elseif self.MinArgs then
					-- Only optional args can be defined after optional args
					error(_Error_Header .. _Error_NotOptional:format(i))
				end

				-- Check ... args
				if arg.IsList then
					if isLast then
						if self.MinArgs then
							error(_Error_Header .. _Error_NotList:format(i))
						else
							if not arg.Type or arg.Type:Is(nil) then
								self.MinArgs = i - 1
							else
								-- Must have one parameter at least
								self.MinArgs = i
							end

							-- Just big enough
							self.MaxArgs = 9999

							arg.Name = "..."
						end
					else
						error(_Error_Header .. _Error_NotList:format(i))
					end
				end

				return
			end

			-- Convert to type
			if Reflector.IsNameSpace(self[i]) then self[i] = BuildType(self[i]) end

			-- Convert type to Argument
			if IsType(self[i]) then
				self[i] = Argument { Type = self[i] }

				-- Check optional args
				if self[i].Type:Is(nil) then
					if not self.MinArgs then self.MinArgs = i - 1 end
				elseif self.MinArgs then
					-- Only optional args can be defined after optional args
					error(_Error_Header .. _Error_NotOptional:format(i))
				end

				return
			end

			error(_Error_Header .. _Error_NotArgument:format(i))
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			-- Self validation once
			for i = 1, #self do ValidateArgument(self, i) end

			self.Owner = owner
			self.TargetType = targetType
			self.Name = name

			if targetType == AttributeTargets.Method then
				if (name:match("^_") and not (Reflector.IsClass(owner) and name ~= "__exist" and (_KeyMeta[name] or _KeyMeta[name:sub(2)] == false))) or
					( Reflector.IsInterface(owner) and Reflector.IsNonInheritable(owner) ) then
					self.HasSelf = false
				else
					self.HasSelf = true
				end
			else
				-- No self for struct constructor
				self.HasSelf = Reflector.IsClass(owner)
			end

			-- Quick match
			if not self.MinArgs then self.MinArgs = #self end
			if not self.MaxArgs then self.MaxArgs = #self end

			-- Save self to fixedmethod object
			local fixedObj = FixedMethod()

			for k, v in pairs(self) do fixedObj[k] = v end

			fixedObj.Method = target

			wipe(self)

			return fixedObj
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Arguments__(self)
			wipe(self)

			return Super(self)
		end
	endclass "__Arguments__"

	-- Apply Attribute to the previous definitions, since I can't use them before definition
	do
		------------------------------------------------------
		-- For structs
		------------------------------------------------------
		__Final__:ApplyAttribute(Boolean)
		__Final__:ApplyAttribute(String)
		__Final__:ApplyAttribute(Number)
		__Final__:ApplyAttribute(Function)
		__Final__:ApplyAttribute(Table)
		__Final__:ApplyAttribute(Userdata)
		__Final__:ApplyAttribute(Thread)
		__Final__:ApplyAttribute(Any)
		__Final__:ApplyAttribute(Argument)

		------------------------------------------------------
		-- For Attribute system
		------------------------------------------------------
		-- System.AttributeTargets
		__Flags__:ApplyAttribute(AttributeTargets)
		__Final__:ApplyAttribute(AttributeTargets)

		-- System.__Arguments__
		__Unique__:ApplyAttribute(__Arguments__)
		__Final__:ApplyAttribute(__Arguments__)

		-- System.__Attribute__
		__Final__:ApplyAttribute(__Attribute__)
		__Arguments__()
		SaveFixedMethod(_NSInfo[__Attribute__], "Constructor", _NSInfo[__Attribute__].Constructor, __Attribute__, AttributeTargets.Constructor)

		-- System.__Unique__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__Unique__, AttributeTargets.Class)
		__Unique__:ApplyAttribute(__Unique__)
		__Final__:ApplyAttribute(__Unique__)

		-- System.__Flags__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Enum, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__Flags__, AttributeTargets.Class)
		__Unique__:ApplyAttribute(__Flags__)
		__Final__:ApplyAttribute(__Flags__)

		-- System.__AttributeUsage__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false}
		__Attribute__._ConsumePreparedAttributes(__AttributeUsage__, AttributeTargets.Class)
		__Final__:ApplyAttribute(__AttributeUsage__)
		__NonInheritable__:ApplyAttribute(__AttributeUsage__)

		-- System.__Final__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class + AttributeTargets.Interface + AttributeTargets.Struct + AttributeTargets.Enum, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__Final__, AttributeTargets.Class)
		__Unique__:ApplyAttribute(__Final__)
		__Final__:ApplyAttribute(__Final__)

		-- System.__NonInheritable__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class + AttributeTargets.Interface, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__NonInheritable__, AttributeTargets.Class)
		__Unique__:ApplyAttribute(__NonInheritable__)
		__Final__:ApplyAttribute(__NonInheritable__)

		-- System.__Arguments__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Method + AttributeTargets.Constructor, Inherited = false, RunOnce = true }
		__Attribute__._ConsumePreparedAttributes(__Arguments__, AttributeTargets.Class)
		__Arguments__()
		SaveFixedMethod(_NSInfo[__Arguments__], "Constructor", _NSInfo[__Arguments__].Constructor, __Arguments__, AttributeTargets.Constructor)

		------------------------------------------------------
		-- For other classes
		------------------------------------------------------
		-- System.Reflector
		__Final__:ApplyAttribute(Reflector)
		__NonInheritable__:ApplyAttribute(Reflector)

		-- Type
		__Final__:ApplyAttribute(Type)
		__NonInheritable__:ApplyAttribute(Type)

		-- Event
		__Final__:ApplyAttribute(Event)
		__NonInheritable__:ApplyAttribute(Event)

		-- EventHandler
		__Final__:ApplyAttribute(EventHandler)
		__NonInheritable__:ApplyAttribute(EventHandler)

		-- FixedMethod
		__Final__:ApplyAttribute(FixedMethod)
		__NonInheritable__:ApplyAttribute(FixedMethod)
	end

	-- More usable attributes
	__AttributeUsage__{AttributeTarget = AttributeTargets.Event + AttributeTargets.Method, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Delegate__"
		inherit "__Attribute__"
		doc "__Delegate__" [[Wrap the method/event call in a delegate function]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Delegate" [[The delegate function]]
		property "Delegate" { Type = Function + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			local delegate = self.Delegate
			if not delegate then return end

			if targetType == AttributeTargets.Method then
				if type(target) == "function" then
					-- Wrap the target method
					return function (...) return delegate(target, ...) end
				end
			elseif targetType == AttributeTargets.Event then
				_NSInfo[owner].Event[target].Delegate = delegate
			end

			self.Delegate = nil
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Delegate__(self)
			self.Delegate = nil
			return Super(self)
		end

		__Arguments__{ Function }
		function __Delegate__(self, value)
			self.Delegate = value
			return Super(self)
		end
	endclass "__Delegate__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Cache__"
		inherit "__Attribute__"
		doc "__Cache__" [[Mark the class so its objects will cache any methods they accessed, mark the method so the objects will cache the method when they are created, if using on an interface, all object methods defined in it would be marked with __Cache__ attribute .]]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsClass(target) then _NSInfo[target].AutoCache = true end
		end
	endclass "__Cache__"

	-- Apply Attribute to Type class
	do
		__Cache__:ApplyAttribute(Type, AttributeTargets.Class)
		UpdateMetaTable4Cls(Type, true)
	end

	enum "StructType" {
		"Member",
		"Array",
		"Custom"
	}

	__AttributeUsage__{AttributeTarget = AttributeTargets.Struct, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__StructType__"
		inherit "__Attribute__"

		doc "__StructType__" [[Mark the struct's type, default 'Member']]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType)
			if Reflector.IsStruct(target) then
				local info = _NSInfo[target]

				if self.Type == StructType.Member then
					-- use member list, default type
					info.SubType = _STRUCT_TYPE_MEMBER
					info.ArrayElement = nil
				elseif self.Type == StructType.Array then
					-- user array list
					info.SubType = _STRUCT_TYPE_ARRAY
					info.Members = nil
				else
					-- else all custom
					info.SubType = _STRUCT_TYPE_CUSTOM
					info.Members = nil
					info.ArrayElement = nil
				end
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Type" [[The struct's type]]
		property "Type" { Type = StructType }

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{ StructType }
		function __StructType__(self, type)
			Super(self)

			self.Type = type
		end

		__Arguments__{ }
		function __StructType__(self)
			Super(self)

			self.Type = StructType.Member
		end
	endclass "__StructType__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Interface + AttributeTargets.Class, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__NonExpandable__"
		inherit "__Attribute__"
		doc "__NonExpandable__" [[
			<desc>Mark the class|interface can't receive functions as new methods like :</desc>
				System.Object.Print = function(self) print(self) end, give all object of System.Object a new method.
				The cost should be expensive, use it carefully.
		]]

		function ApplyAttribute(self, target, targetType)
			if _NSInfo[target] then _NSInfo[target].NonExpandable = true end
		end
	endclass "__NonExpandable__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__InitTable__"
		inherit "__Attribute__"

		doc "__InitTable__" [[Used to mark the class can use init table like: obj = cls(name) { Age = 123 }]]

		__Arguments__{ RawTable }
		function InitWithTable(self, initTable)
			for name, value in pairs(initTable) do
				local ok, msg = pcall(TrySetProperty, self, name, value)

				if not ok then
					errorhandler(strtrim(msg:match(":%d+:%s*(.-)$") or msg))
				end
			end

			return self
		end

		function ApplyAttribute(self, target, targetType)
			if _NSInfo[target] and _NSInfo[target].Type == TYPE_CLASS then
				SaveFixedMethod(_NSInfo[target].MetaTable, "__call", __InitTable__["InitWithTable"], target)
			end
		end
	endclass "__InitTable__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Method + AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Require__"
		inherit "__Attribute__"

		doc "__Require__" [[Whether the method or property of the interface is required to be override]]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			local info = _NSInfo[owner]

			if info and info.Type == TYPE_INTERFACE and type(name) == "string" then
				if targetType == AttributeTargets.Method and not name:match("^_") then
					info.RequireMethod = info.RequireMethod or {}
					info.RequireMethod[name] = true
				elseif targetType == AttributeTargets.Property then
					info.RequireProperty = info.RequireProperty or {}
					info.RequireProperty[name] = true
				end
			end
		end
	endclass "__Require__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Method + AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Optional__"
		inherit "__Attribute__"

		doc "__Optional__" [[Whether the method or property of the interface is optional to be override]]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			local info = _NSInfo[owner]

			if info and info.Type == TYPE_INTERFACE and type(name) == "string" then
				if targetType == AttributeTargets.Method and not name:match("^_") then
					info.OptionalMethod = info.RequireMethod or {}
					info.OptionalMethod[name] = true
				elseif targetType == AttributeTargets.Property then
					info.OptionalProperty = info.RequireProperty or {}
					info.OptionalProperty[name] = true
				end
			end
		end
	endclass "__Optional__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Synthesize__"
		inherit "__Attribute__"

		doc "__Synthesize__" [[Used to generate property accessors automatically]]

		enum "NameCase" {
			"Camel",	-- setName
			"Pascal",	-- SetName
		}

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "NameCase" [[The name case of the generate method, in one program, only need to be set once, default is Pascal case]]
		property "NameCase" { Type = NameCase, Default = NameCase.Pascal }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			target.Synthesize = self.NameCase
		end
	endclass "__Synthesize__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Event__"
		inherit "__Attribute__"

		doc "__Event__" [[Used to bind an event to the property]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Event" [[The event that bind to the property]]
		property "Event" { Type = String + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			target.Event = self.Event
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Event__(self)
			self.Event = nil

			return Super(self)
		end

		__Arguments__{ String }
		function __Event__(self, value)
			self.Event = value

			return Super(self)
		end
	endclass "__Event__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Handler__"
		inherit "__Attribute__"

		doc "__Handler__" [[Used to bind an handler(method name or function) to the property]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Handler" [[The handler that bind to the property]]
		property "Handler" { Type = String + Function + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			target.Handler = self.Handler
			self.Handler = nil
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Handler__(self)
			self.Handler = nil

			return Super(self)
		end

		__Arguments__{ String + Function }
		function __Handler__(self, value)
			self.Handler = value

			return Super(self)
		end
	endclass "__Handler__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Struct + AttributeTargets.Enum + AttributeTargets.Property + AttributeTargets.Field, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Default__"
		inherit "__Attribute__"

		doc "__Default__" [[Used to set a default value for custom struct or enum]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc "Default" [[The default value]]
		property "Default" { Type = Any + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			if self.Default == nil then return end

			if targetType == AttributeTargets.Property then
				target.Default = self.Default
			elseif targetType == AttributeTargets.Field then
				local info = _NSInfo[owner]
				if not info or info.SubType ~= _STRUCT_TYPE_MEMBER then return end
				local ty = rawget(info.StructEnv, target)
				if not IsType(ty) or not ty:GetObjectType(self.Default) then return end

				info.DefaultField = info.DefaultField or {}
				info.DefaultField[target] = self.Default
			else
				_NSInfo[target].Default = self.Default
			end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Default__(self)
			self.Default = nil

			return Super(self)
		end

		__Arguments__{ Any }
		function __Default__(self, value)
			self.Default = value

			return Super(self)
		end
	endclass "__Default__"

	__Default__( "Assign" )
	__Flags__()
	enum "Setter" {
		Assign = 0,	-- set directly
		"Clone",	-- Clone struct or object of ICloneable
		"DeepClone",-- Deep clone struct
		"Retain",	-- Dispose old object
		-- "Strong", this is default for lua
		"Weak",		-- Weak value
	}

	__Default__( "Origin" )
	__Flags__()
	enum "Getter" {
		Origin = 0,
		"Clone",
		"DeepClone",
	}

	__AttributeUsage__{AttributeTarget = AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Setter__"
		inherit "__Attribute__"

		doc "__Setter__" [[Used to set the assign mode of the property]]

		------------------------------------------------------
		doc "Setter" [[The setter settings]]
		property "Setter" { Type = Setter + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			target.Setter = self.Setter
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Setter__(self)
			self.Setter = nil

			return Super(self)
		end

		__Arguments__{ Setter }
		function __Setter__(self, value)
			self.Setter = value

			return Super(self)
		end
	endclass "__Setter__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Property, Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Getter__"
		inherit "__Attribute__"

		doc "__Getter__" [[Used to set the get mode of the property]]

		------------------------------------------------------
		doc "Getter" [[The getter settings]]
		property "Getter" { Type = Getter + nil }

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			target.Getter = self.Getter
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{}
		function __Getter__(self)
			self.Getter = nil

			return Super(self)
		end

		__Arguments__{ Getter }
		function __Getter__(self, value)
			self.Getter = value

			return Super(self)
		end
	endclass "__Getter__"

	__AttributeUsage__{Inherited = false, RunOnce = true}
	__Final__() __Unique__()
	class "__Doc__"
		inherit "__Attribute__"

		doc "__Doc__" [[Used to document the features like : class, struct, enum, interface, property, event and method]]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			if type(self.Doc) == "string" and targetType and (owner or target) then
				SaveDocument(self.Doc, name, targetType, owner or target)
			end

			self.Doc = nil
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Doc__(self, data)
			self.Doc = data

			return Super(self)
		end

		------------------------------------------------------
		-- Meta-method
		------------------------------------------------------
		doc "__call" [[__Doc__ "Target" "Document"]]
		function __call(self, data)
			self:RemoveSelf()

			local owner = getfenv(2)[OWNER_FIELD]

			if type(self.Doc) == "string" and owner and IsNameSpace(owner) then SaveDocument(data, self.Doc, nil, owner) end

			self.Doc = nil
		end
	endclass "__Doc__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Class + AttributeTargets.Struct + AttributeTargets.Enum + AttributeTargets.Interface + AttributeTargets.Method, Inherited = false, RunOnce = true}
	class "__Local__"
		inherit "__Attribute__"

		doc "__Local__" [[Used to mark the features like class, struct, interface, enum and method as local.]]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self) return SetLocal(false) end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Local__(self) SetLocal(true) return Super(self) end
	endclass "__Local__"
end

------------------------------------------------------
-- System Namespace (Object & Module)
------------------------------------------------------
do
	------------------------------------------------------
	-- System.ICloneable
	------------------------------------------------------
	__Doc__ [[Supports cloning, which creates a new instance of a class with the same value as an existing instance.]]
	interface "ICloneable"
		------------------------------------------------------
		-- Method
		------------------------------------------------------
		__Require__() __Doc__[[Creates a new object that is a copy of the current instance.]]
		function Clone(self) end
	endinterface "ICloneable"

	__Final__()
	__Doc__[[The root class of other classes. Object class contains several methodes for common use.]]
	class "Object"

		------------------------------------------------------
		-- Event
		------------------------------------------------------
		__Doc__[[
			<desc>Fired when an event's handler is changed</desc>
			<param name="name">the changed event handler's event name</param>
		]]
		event "OnEventHandlerChanged"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		__Doc__[[
			<desc>Check if the event type is supported by the object</desc>
			<param name="name">the event's name</param>
			<return type="boolean">true if the object has that event type</return>
		]]
		function HasEvent(self, name)
			if type(name) ~= "string" then
				error(("Usage : object:HasEvent(name) : 'name' - string expected, got %s."):format(type(name)), 2)
			end
			return Reflector.HasEvent(Reflector.GetObjectClass(self), name) or false
		end

		__Doc__[[
			<desc>Get the class type of the object</desc>
			<return type="class">the object's class</return>
		]]
		GetClass = Reflector.GetObjectClass

		__Doc__[[
			<desc>Check if the object is an instance of the class</desc>
			<param name="class"></param>
			<return type="boolean">true if the object is an instance of the class</return>
		]]
		IsClass = Reflector.ObjectIsClass

		__Doc__[[
			<desc>Check if the object is extend from the interface</desc>
			<param name="interface"></param>
			<return type="boolean">true if the object is extend from the interface</return>
		]]
		IsInterface = Reflector.ObjectIsInterface

		__Doc__[[
			<desc>Fire an object's event, to trigger the object's event handlers</desc>
			<param name="event">the event name</param>
			<param name="...">the event's arguments</param>
		]]
		Fire = Reflector.FireObjectEvent

		__Doc__[[
			<desc>Block some events for the object</desc>
			<param name="...">the event's name list</param>
		]]
		BlockEvent = Reflector.BlockEvent

		__Doc__[[
			<desc>Check if the event is blocked for the object</desc>
			<param name="event">the event's name</param>
			<return type="boolean">true if th event is blocked</return>
		]]
		IsEventBlocked = Reflector.IsEventBlocked

		__Doc__[[
			<desc>Un-Block some events for the object</desc>
			<param name="...">the event's name list</param>
		]]
		UnBlockEvent = Reflector.UnBlockEvent

		__Doc__[[
			<desc>Call method or function as a thread</desc>
			<param name="method" type="string|function">the target method</param>
			<param name="...">the arguments</param>
			<return>the return value of the target method</return>
		]]
		function ThreadCall(self, method, ...)
			if type(method) == "string" then method = self[method] end

			if type(method) == "function" then return CallThread(method, self, ...) end
		end
	endclass "Object"

	__Final__()
	__Doc__[[Used to create an hierarchical environment with class system settings, like : Module "Root.ModuleA" "v72"]]
	class "Module"
		inherit "Object"

		_Module = {}
		_ModuleInfo = setmetatable({}, WEAK_KEY)

		_ModuleEnv = {}

		_ModuleEnv.class = class
		_ModuleEnv.enum = enum
		_ModuleEnv.namespace = namespace
		_ModuleEnv.struct = struct
		_ModuleEnv.interface = interface
		_ModuleEnv.import = function(name)
			local ns = name

			if type(name) == "string" then
				ns = Reflector.GetNameSpaceForName(name)

				if not ns then error(("no namespace is found with name : %s"):format(name), 2) end
			end

			if not Reflector.IsNameSpace(ns) then error([[Usage: import "namespaceA.namespaceB"]], 2) end

			local env = getfenv(2)
			local info = _ModuleInfo[env]

			if not info then error("can't use import here.", 2) end

			info.Import = info.Import or {}

			for _, v in ipairs(info.Import) do if v == ns then return end end

			tinsert(info.Import, ns)
		end

		------------------------------------------------------
		-- Event
		------------------------------------------------------
		__Doc__[[Fired when the module is disposed]]
		event "OnDispose"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		__Doc__[[
			<desc>Return true if the version is greater than the current version of the module</desc>
			<param name="version"></param>
			<return name="boolean">true if the version is a validated version</return>
		]]
		function ValidateVersion(self, version)
			local info = _ModuleInfo[self]

			if not info then error("The module is disposed", 2) end

			-- Check version
			if type(version) == "number" then
				version = tostring(version)
			elseif type(version) == "string" then
				version = strtrim(version)

				if version == "" then version = nil end
			end

			if type(version) == "string" then
				local number = version:match("^.-(%d+[%d%.]*).-$")

				if number then
					number = number:match("^(.-)[%.]*$")

					if info.Version then
						local onumber = info.Version:match("^.-(%d+[%d%.]*).-$")

						if onumber then
							onumber = onumber:match("^(.-)[%.]*$")

							local f1 = onumber:gmatch("%d+")
							local f2 = number:gmatch("%d+")

							local v1 = f1 and f1()
							local v2 = f2 and f2()

							local pass = false

							while true do
								v1 = tonumber(v1)
								v2 = tonumber(v2)

								if not v1 then
									if v2 then pass = true end
									break
								elseif not v2 then
									break
								elseif v1 < v2 then
									pass = true
									break
								elseif v1 > v2 then
									break
								end

								v1 = f1 and f1()
								v2 = f2 and f2()
							end

							-- Clear
							while f1 and f1() do end
							while f2 and f2() do end

							-- Check falg
							if pass then
								return true
							end
						else
							return true
						end
					else
						return true
					end
				end
			end

			return false
		end

		__Doc__[[
			<desc>Get the child-module with the name</desc>
			<param name="name">string, the child-module's name</param>
			<return name="System"></return>.Module the child-module
		]]
		function GetModule(self, name)
			if type(name) ~= "string" or strtrim(name) == "" then return end

			local mdl = self

			for sub in name:gmatch("[_%w]+") do
				mdl =  _ModuleInfo[mdl] and _ModuleInfo[mdl].Modules and _ModuleInfo[mdl].Modules[sub]

				if not mdl then return end
			end

			if mdl == self then return end

			return mdl
		end

		__Doc__[[
			<desc>Get all child-modules of the module</desc>
			<return name="table">the list of the the child-modules</return>
		]]
		function GetModules(self)
			if _ModuleInfo[self] and _ModuleInfo[self].Modules then
				local lst = {}

				for _, mdl in pairs(_ModuleInfo[self].Modules) do tinsert(lst, mdl) end

				return lst
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		__Doc__[[The module itself]]
		property "_M" { Get = function(self) return self end, }

		__Doc__[[The module's name]]
		property "_Name" { Get = function(self) return _ModuleInfo[self].Name end, }

		__Doc__[[The module's parent module]]
		property "_Parent" { Get = function(self) return _ModuleInfo[self].Parent end, }

		__Doc__[[The module's version]]
		property "_Version" { Get = function(self) return _ModuleInfo[self].Version end, }

		------------------------------------------------------
		-- Dispose
		------------------------------------------------------
		function Dispose(self)
			local info = _ModuleInfo[self]

			if info then
				-- Clear child modules
				if info.Modules then
					for name, mdl in pairs(info.Modules) do mdl:Dispose() end

					wipe(info.Modules)

					info.Modules = nil
				end

				-- Fire the event
				self:Fire("OnDispose")

				-- Clear from parent
				if info.Name then
					if info.Parent then
						if _ModuleInfo[info.Parent] and _ModuleInfo[info.Parent].Modules then
							_ModuleInfo[info.Parent].Modules[info.Name] = nil
						end
					else
						_Module[info.Name] = nil
					end
				end

				-- Remove info
				_ModuleInfo[self] = nil
			end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function Module(self, parent, name)
			local prevName

			-- Check args
			name = type(parent) == "string" and parent or name

			if not Reflector.ObjectIsClass(parent, Module) then parent = nil end

			-- Check and create parent modules
			if type(name) == "string" then
				for sub in name:gmatch("[_%w]+") do
					if not prevName then
						prevName = sub
					else
						parent = Module(parent, prevName)
						prevName = sub
					end
				end
			end

			-- Save the module's information
			if prevName then
				if parent then
					_ModuleInfo[parent].Modules = _ModuleInfo[parent].Modules or {}
					_ModuleInfo[parent].Modules[prevName] = self
				else
					_Module[prevName] = self
				end
			else
				parent = nil
			end

			_ModuleInfo[self] = {
				Owner = self,
				Name = prevName,
				Parent = parent,
			}
		end

		------------------------------------------------------
		-- metamethod
		------------------------------------------------------
		function __exist(parent, name)
			local mdl = nil

			-- Check args
			if Reflector.ObjectIsClass(parent, Module) then mdl = parent end

			name = type(parent) == "string" and parent or name

			if type(name) == "string" then
				for sub in name:gmatch("[_%w]+") do
					if not mdl then
						mdl = _Module[sub]
					elseif _ModuleInfo[mdl] and _ModuleInfo[mdl].Modules then
						mdl = _ModuleInfo[mdl].Modules[sub]
					else
						mdl = nil
					end

					if not mdl then return end
				end

				if mdl == parent then return end

				return mdl
			end
		end

		function __index(self, key)
			-- Check keywords
			if _ModuleEnv[key] then return _ModuleEnv[key] end

			-- Check self's namespace
			local ns = Reflector.GetCurrentNameSpace(self, true)
			local parent = _ModuleInfo[self].Parent

			while not ns and parent do
				ns = Reflector.GetCurrentNameSpace(parent, true)
				parent = _ModuleInfo[parent].Parent
			end

			if ns and Reflector.GetNameSpaceName(ns) then
				if key == Reflector.GetNameSpaceName(ns) then
					rawset(self, key, ns)
					return rawget(self, key)
				elseif ns[key] then
					rawset(self, key, ns[key])
					return rawget(self, key)
				end
			end

			local info = _ModuleInfo[self]

			-- Check imports
			if info.Import then
				for _, ns in ipairs(info.Import) do
					if key == Reflector.GetNameSpaceName(ns) then
						rawset(self, key, ns)
						return rawget(self, key)
					elseif ns[key] then
						rawset(self, key, ns[key])
						return rawget(self, key)
					end
				end
			end

			-- Check base namespace
			if Reflector.GetNameSpaceForName(key) then
				rawset(self, key, Reflector.GetNameSpaceForName(key))
				return rawget(self, key)
			end

			if info.Parent then
				local value = info.Parent[key]

				if value ~= nil then rawset(self, key, value) end

				return value
			else
				if key ~= "_G" and type(key) == "string" and key:find("^_") then return end

				local value = _G[key]

				if value ~= nil then rawset(self, key, value) end

				return value
			end
		end

		function __newindex(self, key, value)
			if _ModuleEnv[key] then error(("%s is a keyword."):format(key), 2) end

			rawset(self, key, value)
		end

		function __call(self, version, depth)
			depth = type(depth) == "number" and depth > 0 and depth or 1

			local info = _ModuleInfo[self]

			if not info then error("The module is disposed", 2) end

			-- Check version
			if type(version) == "number" then
				version = tostring(version)
			elseif type(version) == "string" then
				version = strtrim(version)

				if version == "" then version = nil end
			end

			if type(version) == "string" then
				local number = version:match("^.-(%d+[%d%.]*).-$")

				if number then
					number = number:match("^(.-)[%.]*$")

					if info.Version then
						local onumber = info.Version:match("^.-(%d+[%d%.]*).-$")

						if onumber then
							onumber = onumber:match("^(.-)[%.]*$")

							local f1 = onumber:gmatch("%d+")
							local f2 = number:gmatch("%d+")

							local v1 = f1 and f1()
							local v2 = f2 and f2()

							local pass = false

							while true do
								v1 = tonumber(v1)
								v2 = tonumber(v2)

								if not v1 then
									if v2 then pass = true end
									break
								elseif not v2 then
									break
								elseif v1 < v2 then
									pass = true
									break
								elseif v1 > v2 then
									break
								end

								v1 = f1 and f1()
								v2 = f2 and f2()
							end

							-- Clear
							while f1 and f1() do end
							while f2 and f2() do end

							-- Check falg
							if pass then
								info.Version = version
							else
								error("The version must be greater than the current version of the module.", 2)
							end
						else
							info.Version = version
						end
					else
						info.Version = version
					end
				else
					error("The version string should contain version numbers like 'Ver 1.2323.13'.")
				end
			elseif info.Version then
				error("An available version is need for the module.", 2)
			end

			setfenv(depth + 1, self)

			__Attribute__._ClearPreparedAttributes()
		end

		--[[
		function __tostring(self)
			if _ModuleInfo[self].Name then
				return tostring(Module) .. "( " .. _ModuleInfo[self].Name .. " ) " .. (_ModuleInfo[self].Version or "")
			else
				return tostring(Module) .. "( Anonymous ) "
			end
		end--]]
	endclass "Module"
end

------------------------------------------------------
-- Global Settings
------------------------------------------------------
do
	------------------------------------------------------
	-- Clear useless keywords
	------------------------------------------------------
	_KeyWord4IFEnv.doc = nil
	_KeyWord4ClsEnv.doc = nil
	_KeyWord4StrtEnv.structtype = nil
	_KeyWord4StrtEnv.default = nil

	-- Keep the root so can't be disposed
	System = Reflector.GetNameSpaceForName("System")

	function import_install(name, all)
		local ns = Reflector.GetNameSpaceForName(name)
		local env = getfenv(2)

		if ns and env then
			env[Reflector.GetNameSpaceName(ns)] = ns

			if all then
				for _, subNs in ipairs(Reflector.GetSubNamespace(ns)) do
					env[subNs] = ns[subNs]
				end
			end
		else
			error("No such namespace.", 2)
		end
	end

	function Install_OOP(env)
		if type(env) == "table" then
			env.interface = env.interface or interface
			env.class = env.class or class
			env.enum = env.enum or enum
			env.namespace = env.namespace or namespace
			env.struct = env.struct or struct
			env.import = env.import or import_install
			env.Module = env.Module or Module
		end
	end

	-- Install to the global environment
	Install_OOP(_G)
end
