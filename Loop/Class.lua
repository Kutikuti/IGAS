--[[
Copyright (c) 2011-2013 WangXH <kurapica.igas@gmail.com>

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

-- Class System
-- Author: kurapica.igas@gmail.com
-- Create Date : 2011/02/01
-- ChangeLog   :
--               2011/04/14	System.Reflector added.
--               2011/05/11 Event handlers can run as thread.
--               2011/05/30 System.Reflector.GetParts added.
--               2011/06/24 Property definition ignore case
--               2011/07/04 Struct no longer need Constructor and Validate function
--               2011/07/08 System.Reflector.IsAbstractClass(cls) added
--               2011/07/12 System.Reflector.ParseEnum(enm, value) added
--               2011/07/27 Enum's validation method changed.
--               2011/10/26 Error report update for __index & __newindex
--               2011/10/30 System.Reflector.ConvertClass(obj, cls) added
--               2011/10/31 System.Reflector.InactiveThread added
--               2012/04/10 System.Reflector.IsNameSpace(obj) added
--               2012/05/01 System.Reflector.Validate(type, value) added
--               2012/05/06 System.Reflector.Validate(type, value, name, prefix) mod
--               2012/05/07 System.Reflector.BuildType removed
--               2012/05/14 Type add sub & unm metamethodes
--               2012/05/21 Keyword 'Super' is added to the class environment
--               2012/06/27 Interface system added
--               2012/06/28 Interface can access it's methodes
--               2012/06/29 System.Reflector Update for Interface
--               2012/06/30 BlockEvent, IsEventBlocked, UnBlockEvent added to Reflector
--               2012/07/01 Interface can extend from multi-interface
--               2012/07/08 IFDispose added to support interface disposing
--               2012/07/09 Using cache to keep interface list for class object creation
--               2012/07/26 Fix a stack overflow problem
--               2012/07/31 Improve struct system
--               2012/08/14 Struct namespace object now has Validate method.
--               2012/08/14 Class & Struct env now can access base namespace directly.
--               2012/08/14 Reduce Struct Validate method cost.
--               2012/08/19 Don't block error when create object.
--               2012/08/30 IFDispoe removed, Class system will use Dispose as a system method,
--                          Interface's Dispose will be called first when object call like obj:Dispose(),
--                          then the class's own Dispose will be called,
--                          Class.Dispose will access the class' own Dispose method, not system one.
--               2012/09/07 Fix can't extend interface that defined in the class
--               2012/09/20 class without constructor now will use Super class's constructor.
--                          System.Reflector change to Interface.
--               2012/10/08 Object Method, Property, Event can't start with '_'.
--               2012/10/13 partclass keyword added to support part class definition.
--               2012/11/07 Interface constructor invoking mechanism improved.
--               2012/11/11 Disposing objects when Object created failded.
--               2012/11/14 Fix interface constructor systfem.
--               2012/11/16 Extend interface order system added.
--               2012/12/08 Re-order inherit & extend tree.
--               2012/12/23 Class Constructor system modified.
--               2012/12/24 Dispose system modified.
--               2012/12/25 Doc system added.Interface system improved.
--               2013/01/25 object.Disposed is set to true after calling object:Dispose() as a mark
--               2013/04/07 Lower the memory usage
--               2013/06/24 IGAS:Install([env]) added, used to add keywords into current environment
--               2013/06/26 keyword script -> event
--               2013/08/05 Remove version check, seal the definition environment
--               2013/08/12 System.Module is added to create an environment for oop system
--               2013/08/27 System.Object's method ThreadCall will use the running thread instead of create new one
--               2013/08/28 Now init table can be used to init the objects, like : o = System.Object{Name = "Obj", Type = "Object"}
--               2013/08/28 partinterface is removed(canceled)
--               2013/09/01 Attribute system added
--               2013/09/07 Init-table system added for class and struct
--               2013/09/08 Reduce the cpu cost for methods, properties, events system
--               2013/09/09 Improve the property system
--               2013/09/08 New property system
--               2013/09/09 Improve the cache system to improve performance
--               2013/09/11 Fix Reflector.Help & ParseEnum
--               2013/09/17 The basic structs can validate values like custom structs now
--               2013/09/24 No single class/interface environment limit
--               2013/10/02 __Expandable__ attribute removed, __NonExpandable__ attribute added, now expandable is default attribute to all classes/interfaces
--               2013/10/11 Attribute can apply to the struct's field now.
--               2013/10/25 Redesign the definition environment, partclass & partinterface removed
--               2013/10/30 The property auto-fill system finished

------------------------------------------------------------------------
-- Class system is used to provide a object-oriented system in lua.
-- With this system, you can created a class like
--
-- namespace "System"				-- define the namespace
--
-- class "MyClass"						-- declare starting to define the class
--		inherit "Object"					-- declare the class is inherited from System.Object
--
--		event "OnNameChanged"	-- declare the class have an event named "OnNameChanged"
--
--		function Print(self)				-- the global functions will be treated as the class's methodes, self means the object
--			print(self._Name)
--		end
--
--		property "Name" {				-- declare the class have a property named "Name"
--			Get = function(self)		-- the get method for property "Name"
--				return self._Name
--			end,
--			Set = function(self, value)	-- the set method for property "Name"
--				self._Name = value
--				self:OnNameChanged(value)	-- fire the "OnNameChanged" event to trigger it's handler functions.
--			end,
--			Type = String,				-- the property "Name"'s type, so when you assign a value to Name, it should be checked.
--		}
--
--		function MyClass(self, name)	-- the function with same name of the class is treated as the Constructor of the class
--			self._Name = name			-- use self to init
--		end
--	endclass "MyClass"					-- declare the definition of the class is over.
--
--	Using MyClass:
--
--	myObj = MyClass("Test")
--
--	myObj:Print()						-- print out : Test
--
--	function myObj:OnNameChanged(name)	-- define the event handler for 'OnNameChanged'
--		print("The Name is changed to "..name)
--	end
--
--	myObj.Name = "Hello"			-- print out : The Name is changed to Hello
------------------------------------------------------------------------

------------------------------------------------------
-- Object oriented program syntax system environment
------------------------------------------------------
do
	-- Local Environment
	setfenv(1, setmetatable({}, {
		__index = function(self,  key)
			if type(key) == "string" and key ~= "_G" and key:find("^_") then
				return
			end

			if _G[key] then
				rawset(self, key, _G[key])
				return rawget(self, key)
			end
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
	strtrim = strtrim or function(s)
	  return s and (s:gsub("^%s*(.-)%s*$", "%1")) or ""
	end

	wipe = wipe or function(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end

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

	seterrorhandler = seterrorhandler or function(handler)
		if type(handler) == "function" then
			_ErrorHandler = handler
		end
	end

	geterrorhandler = geterrorhandler or function()
		return _ErrorHandler
	end

	errorhandler = errorhandler or function(err)
		return pcall(geterrorhandler(), err)
	end

	newproxy = newproxy

	if not newproxy then
		local _METATABLE_MAP = setmetatable({}, {__mode = "k"})

		function newproxy(prototype)
			-- mean no userdata can be created in lua
			-- use the table instead
			if type(prototype) == "table" then
				local meta = _METATABLE_MAP[prototype]

				return setmetatable({}, meta)
			elseif prototype then
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
	LUA_OOP_VERSION = 82

	TYPE_CLASS = "Class"
	TYPE_ENUM = "Enum"
	TYPE_STRUCT = "Struct"
	TYPE_INTERFACE = "Interface"

	TYPE_NAMESPACE = "NameSpace"
	TYPE_TYPE = "TYPE"

	-- Disposing method name
	DISPOSE_METHOD = "Dispose"

	-- Namespace field
	NAMESPACE_FIELD = "__LOOP_NameSpace"

	-- Owner field
	OWNER_FIELD = "__LOOP_OWNER"

	-- Base env field
	BASE_ENV_FIELD = "__LOOP_BASE_ENV"
end

------------------------------------------------------
-- Thread Pool & Cache
------------------------------------------------------
do
	WEAK_KEY = {__mode = "k"}

	THREAD_POOL_SIZE = 100

	local function retValueAndRecycle(...)
		-- Here means the function call is finished successful
		-- so, we need send the running thread back to the pool
		THREAD_POOL( running() )

		return ...
	end

	local function callFunc(func, ...)
		return retValueAndRecycle( func(...) )
	end

	local function newRycThread(pool, func)
		while pool == THREAD_POOL and type(func) == "function" do
			pool, func = yield( callFunc ( func, yield() ) )
		end
	end

	THREAD_POOL = setmetatable({}, {
		__call = function(self, value)
			if value then
				if #self < THREAD_POOL_SIZE then
					tinsert(self, value)
				else
					-- Kill it
					resume(value)
				end
			else
				-- Keep safe from unexpected resume
				while not value or status(value) == "dead" do
					value = tremove(self) or create(newRycThread)
				end
				return value
			end
		end,
	})

	local function chkValue(flag, ...)
		if flag then
			return ...
		else
			local value = ...

			if value then
				value = value:match(":%d+:%s*(.-)$") or value

				error(value, 4)
			else
				error(..., 4)
			end
		end
	end

	function CallThread(func, ...)
		if running() then
			return func( ... )
		end

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
end

------------------------------------------------------
-- NameSpace
------------------------------------------------------
do
	_NameSpace = _NameSpace or newproxy(true)

	_NSInfo = _NSInfo or setmetatable({}, {
		__index = function(self, key)
			if not IsNameSpace(key) then
				return
			end

			self[key] = { Owner = key }

			return rawget(self, key)
		end,
		__mode = "k",
	})

	-- metatable for class
	_MetaNS = _MetaNS or getmetatable(_NameSpace)
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
					if not info.Validate then
						BuildStructValidate(self)
					end
					return info.Validate
				else
					return info.SubNS and info.SubNS[key]
				end
			elseif info.Type == TYPE_CLASS then
				if info.SubNS and info.SubNS[key] then
					return info.SubNS[key]
				elseif _KeyMeta[key] ~= nil then
					if _KeyMeta[key] then
						return info.MetaTable[key]
					else
						return info.MetaTable["_"..key]
					end
				else
					return info.Method[key] or info.Cache4Method[key]
				end
			elseif info.Type == TYPE_ENUM then
				return type(key) == "string" and info.Enum[key:upper()] or error(("%s is not an enumeration value of %s."):format(tostring(key), tostring(self)), 2)
			elseif info.Type == TYPE_INTERFACE then
				if info.SubNS and info.SubNS[key] then
					return info.SubNS[key]
				else
					return info.Method[key] or info.Cache4Method[key]
				end
			else
				return info.SubNS and info.SubNS[key]
			end
		end

		_MetaNS.__newindex = function(self, key, value)
			local info = _NSInfo[self]

			if info.Type == TYPE_CLASS and not info.NonExpandable and type(key) == "string" and type(value) == "function" then
				if not info.Cache4Method[key] then
					if __Attribute__ then
						value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Method, nil, info.Owner, key) or value
					end

					info.Method[key] = value

					return RefreshCache(self)
				else
					error("Can't override the existed method.", 2)
				end
			elseif info.Type == TYPE_INTERFACE and not info.NonExpandable and type(key) == "string" and type(value) == "function" then
				if not info.Cache4Method[key] then
					if __Attribute__ then
						value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Method, nil, info.Owner, key) or value
					end

					info.Method[key] = value

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
			if not ok then
				_type1 = strtrim(_type1:match(":%d+:%s*(.-)$") or _type1)
				error(_type1, 2)
			end

			ok, _type2 = pcall(BuildType, v2)
			if not ok then
				_type2 = strtrim(_type2:match(":%d+:%s*(.-)$") or _type2)
				error(_type2, 2)
			end

			return _type1 + _type2
		end

		_MetaNS.__sub = function(v1, v2)
			local ok, _type1, _type2

			ok, _type1 = pcall(BuildType, v1)
			if not ok then
				_type1 = strtrim(_type1:match(":%d+:%s*(.-)$") or _type1)
				error(_type1, 2)
			end

			ok, _type2 = pcall(BuildType, v2, nil, true)
			if not ok then
				_type2 = strtrim(_type2:match(":%d+:%s*(.-)$") or _type2)
				error(_type2, 2)
			end

			return _type1 + _type2
		end

		_MetaNS.__unm = function(v1)
			local ok, _type1

			ok, _type1 = pcall(BuildType, v1, nil, true)
			if not ok then
				_type1 = strtrim(_type1:match(":%d+:%s*(.-)$") or _type1)
				error(_type1, 2)
			end

			return _type1
		end

		_MetaNS.__tostring = function(self)
			return GetFullName4NS(self)
		end

		_MetaNS.__metatable = TYPE_NAMESPACE
	end

	-- IsNameSpace
	function IsNameSpace(ns)
		return getmetatable(ns) == TYPE_NAMESPACE or false
	end

	-- BuildNameSpace
	function BuildNameSpace(ns, namelist)
		if type(namelist) ~= "string" or (ns ~= nil and not IsNameSpace(ns)) then
			return
		end

		local cls = ns
		local info = cls and _NSInfo[cls]
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
			if not info.NameSpace and parent ~= _NameSpace then
				info.NameSpace = parent
			end
			parent = cls
		end

		if cls == ns then
			return
		end

		return cls
	end

	-- GetNameSpace
	function GetNameSpace(ns, namelist)
		if type(namelist) ~= "string" or not IsNameSpace(ns) then
			return
		end

		local cls = ns

		for name in namelist:gmatch("[_%w]+") do
			cls = cls[name]
			if not cls then
				return
			end
		end

		if cls == ns then
			return
		end

		return cls
	end

	-- GetDefaultNameSpace
	function GetDefaultNameSpace()
		return _NameSpace
	end

	-- SetNameSpace
	function SetNameSpace4Env(env, name)
		if type(env) ~= "table" then
			return
		end

		if type(name) == "string" then
			local ns = BuildNameSpace(GetDefaultNameSpace(), name)

			if ns then
				rawset(env, NAMESPACE_FIELD, ns)
			else
				rawset(env, NAMESPACE_FIELD, nil)
			end
		elseif IsNameSpace(name) then
			rawset(env, NAMESPACE_FIELD, name)
		else
			rawset(env, NAMESPACE_FIELD, nil)
		end
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

				if info then
					name = info.Name.."."..name
				end
			end

			return name
		end
	end

	------------------------------------
	--- Set the default namespace for the current environment, the class defined in this environment will be stored in this namespace
	-- @name namespace
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage namespace "Widget"
	------------------------------------
	function namespace(name)
		if name ~= nil and type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: namespace "namespace"]], 2)
		end

		return SetNameSpace4Env(getfenv(2), name)
	end
end

------------------------------------------------------
-- Type
------------------------------------------------------
do
	function IsType(self)
		return getmetatable(self) == Type
	end

	function BuildType(ns, name, onlyClass)
		local allowNil = false

		if ns == nil then
			allowNil = true
		elseif IsType(ns) then
			if name then
				ns.Name = name
			end
			return ns
		end

		if ns == nil or IsNameSpace(ns) then
			local _type = Type()

			_type.AllowNil = allowNil or nil

			if ns then
				if onlyClass then
					_type[-1] = ns
				else
					_type[1] = ns
				end
			end

			if name then
				_type.Name = name
			end
			return _type
		else
			if name then
				error(("The value of %s must be combination of nil, struct, enum, interface or class."):format(name))
			else
				error("The type must be combination of nil, struct, enum, interface or class.")
			end
		end
	end
end

------------------------------------------------------
-- Documentation
------------------------------------------------------
do
	_EnableDocument = _EnableDocument == nil and true or _EnableDocument
	_MetaDoc = _MetaDoc or {}
	do
		_MetaDoc.__index = function(self,  key)
			if type(key) ~= "string" or key:match("^_") then return end

			local value, sinfo

			-- Check SuperClass
			local info = rawget(self, "__OwnerInfo")

			if key == "class-" .. info.Name or key == "interface-" .. info.Name or key == "default-" .. info.Name then
				return
			end

			if info.SuperClass then
				sinfo = _NSInfo[info.SuperClass]

				sinfo.Documentation = sinfo.Documentation or setmetatable({__OwnerInfo=sinfo}, _MetaDoc)

				value = sinfo.Documentation[key]
				if value then
					rawset(self, key, value)
					return value
				end
			end

			-- Check Interface
			if info.ExtendInterface then
				for _, IF in ipairs(info.ExtendInterface) do
					sinfo = _NSInfo[IF]

					sinfo.Documentation = sinfo.Documentation or setmetatable({__OwnerInfo=sinfo}, _MetaDoc)

					value = sinfo.Documentation[key]
					if value then
						rawset(self, key, value)
						return value
					end
				end
			end
		end
	end

	------------------------------------
	--- Registe documents
	-- @name document
	-- @class function
	-- @param string the document
	-- @usage document [[
	--	@name IFModule
	--	@type interface
	--	@desc Common methods for class addon and interface
	-- ]]
	------------------------------------
	function document(documentation)
		if not _EnableDocument or type(documentation) ~= "string" then return end

		local info = rawget(_NSInfo, getfenv(2)[OWNER_FIELD])

		if not info then return end

		documentation = documentation:gsub("\n", ""):gsub("\r", ""):gsub("%s+@", "@")

		local name = documentation:match("@name%s+([^@%s]+)")
		local doctype = documentation:match("@type%s(%w+)") or "default"

		if name then
			info.Documentation = info.Documentation or setmetatable({__OwnerInfo=info}, _MetaDoc)
			info.Documentation[doctype .. "-" .. name] = documentation
		end
	end

	function HasDocumentPart(ns, doctype, name)
		if type(ns) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), ns)
		end
		local info = rawget(_NSInfo, ns)

		doctype = type(doctype) == "string" and doctype or "default"

		if info and type(name) == "string" then
			info.Documentation = info.Documentation or setmetatable({__OwnerInfo=info}, _MetaDoc)

			if info.Documentation[doctype .. "-" .. name] then
				return true
			end
		end
	end

	function GetDocumentPart(ns, doctype, name, part)
		if type(ns) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), ns)
		end
		local info = rawget(_NSInfo, ns)

		doctype = type(doctype) == "string" and doctype or "default"

		if info and type(name) == "string" then
			info.Documentation = info.Documentation or setmetatable({__OwnerInfo=info}, _MetaDoc)

			local value = info.Documentation[doctype .. "-" .. name]

			if value then
				if type(part) == "string" then
					if part == "param" or part == "return" or part == "need" or part == "overridable" then
						if value:match("@" .. part .. "%s+([^@%s]+)%s*([^@]*)") then
							return value:gmatch("@" .. part .. "%s+([^@%s]+)%s*([^@]*)")
						end
					else
						if value:match("@" .. part .. "%s+([^@]*)") then
							return value:gmatch("@" .. part .. "%s+([^@]*)")
						end
					end
				else
					if value:match("@(%w+)%s+([^@]*)") then
						return value:gmatch("@(%w+)%s+([^@]*)")
					end
				end
			end
		end

		return
	end

	function EnableDocument(enabled)
		_EnableDocument = enabled and true or false
	end

	function IsDocumentEnabled()
		return _EnableDocument or false
	end
end

------------------------------------------------------
-- Interface
------------------------------------------------------
do
	_KeyWord4IFEnv = _KeyWord4IFEnv or {}

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
							return "^[Ii]s[" .. c:upper() .. c:lower().."]" .. head:sub(2) .. "%w*" .. noun .. "$"
						else
							return "^[" .. c:upper() .. c:lower().."]" .. head:sub(2) .. "%w*" .. noun .. "$"
						end
					end
				end
			end
		end

		function CloneWithoutOverride(dest, src)
			for key, value in pairs(src) do
				if dest[key] == nil then
					dest[key] = value
				end
			end
		end

		function CloneWithoutOverride4Method(dest, src)
			for key, value in pairs(src) do
				if not dest[key] and not key:match("^_") then
					dest[key] = src[key]
				end
			end
		end

		function CloneInterfaceCache(dest, src, cache)
			if not src then return end
			for _, IF in ipairs(src) do
				if not cache[IF] then
					cache[IF] = true
					tinsert(dest, IF)
				end
			end
		end

		function RefreshCache(ns)
			local info = _NSInfo[ns]

			-- Cache4Interface
			local cache = CACHE_TABLE()
			wipe(info.Cache4Interface)
			-- superclass interface
			if info.SuperClass then
				CloneInterfaceCache(info.Cache4Interface, _NSInfo[info.SuperClass].Cache4Interface, cache)
			end
			-- extend interface
			for _, IF in ipairs(info.ExtendInterface) do
				CloneInterfaceCache(info.Cache4Interface, _NSInfo[IF].Cache4Interface, cache)
			end
			-- self interface
			CloneInterfaceCache(info.Cache4Interface, info.ExtendInterface, cache)
			CACHE_TABLE(cache)

			-- Cache4Event
			wipe(info.Cache4Event)
			--- self event
			CloneWithoutOverride(info.Cache4Event, info.Event)
			--- superclass event
			if info.SuperClass then
				CloneWithoutOverride(info.Cache4Event, _NSInfo[info.SuperClass].Cache4Event)
			end
			--- extend event
			for _, IF in ipairs(info.ExtendInterface) do
				CloneWithoutOverride(info.Cache4Event, _NSInfo[IF].Cache4Event)
			end

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
			if info.SuperClass then
				CloneWithoutOverride4Method(info.Cache4Method, _NSInfo[info.SuperClass].Cache4Method)
			end
			--- extend method
			for _, IF in ipairs(info.ExtendInterface) do
				CloneWithoutOverride4Method(info.Cache4Method, _NSInfo[IF].Cache4Method)
			end

			-- Cache4Property
			wipe(info.Cache4Property)
			-- Validate the properties
			for _, prop in pairs(info.Property) do
				local name = prop.Name:gsub("^%a", strupper)
				local useMethod = false

				if prop.GetMethod and not info.Cache4Method[prop.GetMethod] then
					prop.GetMethod = nil
				end

				if prop.SetMethod and not info.Cache4Method[prop.SetMethod] then
					prop.SetMethod = nil
				end

				-- Auto generate GetMethod
				if ( prop.Get == nil or prop.Get == true ) and not prop.GetMethod and not prop.Field then
					-- GetMethod
					if info.Cache4Method["get" .. name] then
						useMethod = true
						prop.GetMethod = "get" .. name
					elseif info.Cache4Method["Get" .. name] then
						useMethod = true
						prop.GetMethod = "Get" .. name
					elseif prop.Type and prop.Type:Is(Boolean) then
						-- FlagEnabled -> IsFlagEnabled
						if info.Cache4Method["is" .. name] then
							useMethod = true
							prop.GetMethod = "is" .. name
						elseif info.Cache4Method["Is" .. name] then
							useMethod = true
							prop.GetMethod = "Is" .. name
						else
							-- FlagEnable -> IsEnableFlag
							local pattern = ParseAdj(name, true)

							if pattern then
								for mname in pairs(info.Cache4Method) do
									if mname:match(pattern) then
										useMethod = true
										prop.GetMethod = mname
										break
									end
								end
							end
						end
					end
				else
					useMethod = true
				end

				-- Auto generate SetMethod
				if ( prop.Set == nil or prop.Set == true ) and not prop.SetMethod and not prop.Field then
					-- SetMethod
					if info.Cache4Method["set" .. name] then
						useMethod = true
						prop.SetMethod = "set" .. name
					elseif info.Cache4Method["Set" .. name] then
						useMethod = true
						prop.SetMethod = "Set" .. name
					elseif prop.Type and prop.Type:Is(Boolean) then
						-- FlagEnabled -> EnableFlag, FlagDisabled -> DisableFlag
						local pattern = ParseAdj(name)

						if pattern then
							for mname in pairs(info.Cache4Method) do
								if mname:match(pattern) then
									useMethod = true
									prop.SetMethod = mname
									break
								end
							end
						end
					end
				else
					useMethod = true
				end

				-- Auto generate Field
				if not useMethod and not prop.Field then
					prop.Field = "_" .. info.Name:match("^_*(.-)$") .. "_" .. prop.Name
				end

				-- Auto generate Default
				if prop.Type and not prop.Type:Is(nil) and prop.Default == nil and #(prop.Type) == 1 then
					if prop.Type:Is(Boolean) then
						prop.Default = false
					elseif prop.Type:Is(Number) then
						prop.Default = 0
					elseif prop.Type:Is(String) then
						prop.Default = ""
					end
				end
			end
			--- self property
			CloneWithoutOverride(info.Cache4Property, info.Property)
			--- superclass property
			if info.SuperClass then
				CloneWithoutOverride(info.Cache4Property, _NSInfo[info.SuperClass].Cache4Property)
			end
			--- extend property
			for _, IF in ipairs(info.ExtendInterface) do
				CloneWithoutOverride(info.Cache4Property, _NSInfo[IF].Cache4Property)
			end

			-- Clear branch
			if info.ChildClass then
				for subcls in pairs(info.ChildClass) do
					RefreshCache(subcls)
				end
			elseif info.ExtendClass then
				for subcls in pairs(info.ExtendClass) do
					RefreshCache(subcls)
				end
			end
		end

		function GetSuperProperty(cls, name)
			local info = _NSInfo[cls]

			if info.SuperClass and _NSInfo[info.SuperClass].Cache4Property[name] then
				return _NSInfo[info.SuperClass].Cache4Property[name]
			end

			for _, IF in ipairs(info.ExtendInterface) do
				if _NSInfo[IF].Cache4Property[name] then
					return _NSInfo[IF].Cache4Property[name]
				end
			end
		end

		function GetSuperMethod(cls, name)
			local info = _NSInfo[cls]

			if info.SuperClass and _NSInfo[info.SuperClass].Cache4Method[name] then
				return _NSInfo[info.SuperClass].Cache4Method[name]
			end

			for _, IF in ipairs(info.ExtendInterface) do
				if _NSInfo[IF].Cache4Method[name] then
					return _NSInfo[IF].Cache4Method[name]
				end
			end
		end
	end

	-- metatable for interface's env
	_MetaIFEnv = _MetaIFEnv or {}
	do
		_MetaIFEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then
				return info.Owner
			end

			-- Check keywords
			if _KeyWord4IFEnv[key] then
				return _KeyWord4IFEnv[key]
			end

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
			if value then
				rawset(self, key, value)
				return value
			end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same interface
			value = info.Method[key]

			if value then
				rawset(self, key, value)
				return value
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]

			if value ~= nil then
				rawset(self, key, value)
				return value
			end
		end

		_MetaIFEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4IFEnv[key] then
				error(("'%s' is a keyword."):format(key), 2)
			end

			if key == info.Name then
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
				if __Attribute__ then
					value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Method, GetSuperMethod(info.Owner, key), info.Owner, key) or value
				end

				if getmetatable(info.Method[key]) and type(value) == "function" then
					-- Special settings for the fixed methods
					local fixedMethod = info.Method[key]

					while fixedMethod.Next do fixedMethod = fixedMethod.Next end

					fixedMethod.Next = value
				elseif info.Method[key] and getmetatable(value) then
					value.Next = info.Method[key]
					info.Method[key] = value
				else
					info.Method[key] = value
				end

				-- Don't save to environment until need it
				value = nil
			end

			rawset(self, key, value)
		end
	end

	function IsExtend(IF, cls)
		if not IF or not cls or not _NSInfo[IF] or _NSInfo[IF].Type ~= TYPE_INTERFACE or not _NSInfo[cls] then
			return false
		end

		if IF == cls then return true end

		if _NSInfo[cls].Cache4Interface then
			for _, pIF in ipairs(_NSInfo[cls].Cache4Interface) do
				if pIF == IF then
					return true
				end
			end
		end

		return false
	end

	------------------------------------
	--- Create interface in currect environment's namespace or default namespace
	-- @param name the interface's name
	-- @usage interface "IFSocket"
	------------------------------------
	function interface(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: interface "interfacename"]], 2)
		end
		local fenv = getfenv(2)
		local ns = GetNameSpace4Env(fenv)

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

		if not IF then
			error("No interface is created.", 2)
		end

		-- Build interface
		info = _NSInfo[IF]

		-- Check if the class is final
		if info.IsFinal then
			error("The interface is final, can't be re-defined.", 2)
		end

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
		}, _MetaIFEnv)

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

		if __Attribute__ then
			-- No super target for interface
			__Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Interface)
		end

		-- Set the environment to interface's environment
		setfenv(2, interfaceEnv)
	end

	------------------------------------
	--- Set the current interface' extended interface
	-- @name extend
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage extend "System.IFSocket"
	------------------------------------
	function extend_IF(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: extend "namespace.interfacename"]], 2)
		end

		if type(name) == "string" and name:find("%.%s*%.") then
			error("The namespace 's name can't have empty string between dots.", 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local IF

		if type(name) == "string" then
			IF = GetNameSpace(info.NameSpace, name) or env[name]

			if not IF then
				for subname in name:gmatch("[_%w]+") do
					if not IF then
						IF = env[subname]
					else
						IF = IF[subname]
					end

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

		if IsExtend(info.Owner, IF) then
			error(("%s is extended from %s, can't be used here."):format(tostring(IF), tostring(info.Owner)), 2)
		end

		IFInfo.ExtendClass = IFInfo.ExtendClass or {}
		IFInfo.ExtendClass[info.Owner] = true

		info.ExtendInterface = info.ExtendInterface or {}

		-- Check if IF is already extend by extend tree
		for _, pIF in ipairs(info.ExtendInterface) do
			if IsExtend(IF, pIF) then
				return extend_IF
			end
		end

		-- Clear
		for i = #(info.ExtendInterface), 1, -1 do
			if IsExtend(info.ExtendInterface[i], IF) then
				tremove(info.ExtendInterface, i)
			end
		end

		tinsert(info.ExtendInterface, IF)

		return extend_IF
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	-- @name import
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage import "System.Widget"
	------------------------------------
	function import_IF(name)
		if type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: import "namespaceA.namespaceB"]], 2)
		end

		if type(name) == "string" and name:find("%.%s*%.") then
			error("The namespace 's name can't have empty string between dots.", 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then
			error(("No namespace is found with name : %s"):format(name), 2)
		end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do
			if v == ns then
				return
			end
		end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- Add an event for current interface
	-- @name event
	-- @class function
	-- @param name the name of the event
	-- @usage event "OnClick"
	------------------------------------
	function event_IF(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: event "eventName"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		info.Event[name] = info.Event[name] or Event(name)

		if __Attribute__ then
			__Attribute__._ConsumePreparedAttributes(info.Event[name], AttributeTargets.Event, nil, info.Owner, name)
		end
	end

	function SetPropertyWithSet(info, name, set)
		if type(set) ~= "table" then
			error([=[Usage: property "Name" { -- Property Definition }]=], 2)
		end

		local prop = info.Property[name] or {}
		info.Property[name] = prop

		wipe(prop)

		prop.Name = name

		for k, v in pairs(set) do
			if type(k) == "string" then
				k = k:lower()

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
					if type(v) == "string" then
						prop.GetMethod = v
					end
				elseif k == "setmethod" then
					if type(v) == "string" then
						prop.SetMethod = v
					end
				elseif k == "field" then
					if type(v) == "string" and v ~= name then
						prop.Field = v
					end
				elseif k == "type" then
					local ok, ret = pcall(BuildType, v, name)
					if ok then
						prop.Type = ret
					else
						ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)

						errorhandler(ret)
					end
				elseif k == "default" then
					prop.Default = v
				end
			end
		end

		if prop.Type and prop.Default ~= nil then
			if prop.Type:GetObjectType(prop.Default) == false then
				prop.Default = nil
			end
		end

		-- Clear
		if prop.Get ~= nil then prop.GetMethod = nil end
		if prop.Set ~= nil then prop.SetMethod = nil end

		if __Attribute__ then
			__Attribute__._ConsumePreparedAttributes(prop, AttributeTargets.Property, GetSuperProperty(info.Owner, name), info.Owner, name)
		end
	end

	------------------------------------
	--- set a propert to the current interface
	-- @name property
	-- @class function
	-- @param name the name of the property
	-- @usage property "Title" {
	--		Get = function(self)
	--			-- return the property's value
	--		end,
	--		Set = function(self, value)
	--			-- Set the property's value
	--		end,
	--		Type = "XXXX",	-- set the property's type
	--}
	------------------------------------
	function property_IF(name)
		if type(name) ~= "string" or strtrim(name:match("[_%w]+")) == "" then
			error([=[Usage: property "Name" { -- Property Definition }]=], 2)
		end

		return function(set)
			return SetPropertyWithSet(_NSInfo[getfenv(2)[OWNER_FIELD]], name:match("[_%w]+"), set)
		end
	end

	------------------------------------
	--- End the interface's definition and restore the environment
	-- @name class
	-- @class function
	-- @param name the name of the interface
	-- @usage endinterface "IFSocket"
	------------------------------------
	function endinterface(name)
		if type(name) ~= "string" or name:find("%.") then
			error([[Usage: endinterface "interfacename"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			setfenv(2, env[BASE_ENV_FIELD])
			RefreshCache(info.Owner)
		else
			error(("%s is not closed."):format(info.Name), 2)
		end

		if __Attribute__ then
			__Attribute__._ClearPreparedAttributes()
		end
	end

	_KeyWord4IFEnv.extend = extend_IF
	_KeyWord4IFEnv.import = import_IF
	_KeyWord4IFEnv.event = event_IF
	_KeyWord4IFEnv.property = property_IF
	_KeyWord4IFEnv.endinterface = endinterface

	_KeyWord4IFEnv.doc = document
end

------------------------------------------------------
-- Class
------------------------------------------------------
do
	_SuperIndex = "Super"

	_KeyWord4ClsEnv = _KeyWord4ClsEnv or {}

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
		__gc = false,		-- dispose a
		__tostring = true,	-- tostring(a)
		__exist = true,		-- ClassName(...)	-- return object if existed
	}

	--------------------------------------------------
	-- Init & Dispose System
	--------------------------------------------------
	do
		function InitObjectWithClass(cls, obj, ...)
			local info = _NSInfo[cls]
			local noError = true

			if info.SuperClass then
				noError = InitObjectWithClass(info.SuperClass, obj, ...)
			end

			if noError and type(info.Constructor) == "function" then
				local ok, ret = pcall(info.Constructor, obj, ...)

				if not ok then
					errorhandler(ret)

					-- Roll back
					noError = false

					-- Call Class Dispose
					while cls and _NSInfo[cls] do
						local disfunc = _NSInfo[cls][DISPOSE_METHOD]

						if disfunc then
							pcall(disfunc, obj)
						end

						cls = _NSInfo[cls].SuperClass
					end

					wipe(obj)

					rawset(obj, "Disposed", true)
				end
			end

			return noError
		end

		function InitObjectWithInterface(cls, obj)
			local ok, msg, info

			for _, IF in ipairs(_NSInfo[cls].Cache4Interface) do
				info = _NSInfo[IF]
				if info.Initializer then
					ok, msg = pcall(info.Initializer, obj)

					if not ok then
						errorhandler(msg)
					end
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

			if __Attribute__._IsDefined(objCls, AttributeTargets.Class, __Unique__) then
				-- No dispose to a unique object
				return
			end

			info = objCls and rawget(_NSInfo, objCls)

			if not info then return end

			for i = #(info.Cache4Interface), 1, -1 do
				IF = info.Cache4Interface[i]
				disfunc = _NSInfo[IF][DISPOSE_METHOD]

				if disfunc then
					pcall(disfunc, self)
				end
			end

			-- Call Class Dispose
			while objCls and _NSInfo[objCls] do
				disfunc = _NSInfo[objCls][DISPOSE_METHOD]

				if disfunc then
					pcall(disfunc, self)
				end

				objCls = _NSInfo[objCls].SuperClass
			end

			-- Clear the table
			wipe(self)

			rawset(self, "Disposed", true)
		end
	end

	-- metatable for class's env
	_MetaClsEnv = _MetaClsEnv or {}
	do
		_MetaClsEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then
				return info.Owner
			end

			if key == _SuperIndex then
				value = info.SuperClass
				if value then
					rawset(self, _SuperIndex, value)
					return value
				else
					error("No super class for the class.", 2)
				end
			end

			-- Check keywords
			if _KeyWord4ClsEnv[key] then
				return _KeyWord4ClsEnv[key]
			end

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
			if value then
				rawset(self, key, value)
				return value
			end

			-- Check method, so definition environment can use existed method
			-- created by another definition environment for the same class
			value = info.Method[key]

			if value then
				rawset(self, key, value)
				return value
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]

			if value ~= nil then
				rawset(self, key, value)
				return value
			end
		end

		_MetaClsEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4ClsEnv[key] then
				error(("'%s' is a keyword."):format(key), 2)
			end

			if key == info.Name then
				if type(value) == "function" then
					if __Attribute__ and info.Owner ~= __Attribute__ then
						value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Constructor, nil, info.Owner, "Constructor") or value
					end

					info.Constructor = value

					return
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
					SetMetaFunc(rMeta, info.ChildClass, info.MetaTable[rMeta], value)
					info.MetaTable[rMeta] = value
					return
				else
					error(("'%s' must be a function."):format(key), 2)
				end
			end

			if type(key) == "string" and type(value) == "function" then
				-- keep function in env, just register the method
				if __Attribute__ and info.Owner ~= __Attribute__ then
					value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Method, GetSuperMethod(info.Owner, key), info.Owner, key) or value
				end

				if getmetatable(info.Method[key]) and type(value) == "function" then
					-- Special settings for the fixed methods
					local fixedMethod = info.Method[key]

					while getmetatable(fixedMethod.Next) do fixedMethod = fixedMethod.Next end

					fixedMethod.Next = value
				elseif info.Method[key] and getmetatable(value) then
					value.Next = info.Method[key]
					info.Method[key] = value
				else
					info.Method[key] = value
				end

				-- Don't save to environment until need it
				value = nil
			end

			rawset(self, key, value)
		end
	end

	function IsChildClass(cls, child)
		if not cls or not child or not _NSInfo[cls] or _NSInfo[cls].Type ~= TYPE_CLASS or not _NSInfo[child] or _NSInfo[child].Type ~= TYPE_CLASS then
			return false
		end

		if cls == child then
			return true
		end

		local info = _NSInfo[child]

		while info and info.SuperClass and info.SuperClass ~= cls do
			info = _NSInfo[info.SuperClass]
		end

		if info and info.SuperClass == cls then
			return true
		end

		return false
	end

	function SetMetaFunc(meta, sub, pre, now)
		if sub and pre ~= now then
			for cls in pairs(sub) do
				local info = _NSInfo[cls]

				if info.MetaTable[meta] == pre then
					info.MetaTable[meta] = now

					SetMetaFunc(meta, info.ChildClass, pre, now)
				end
			end
		end
	end

	function TrySetProperty(self, name, value)
		self[name] = value
	end

	function UpdateMetaTable4Cls(cls)
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

		local isCached = __Attribute__ and __Cache__ and __Attribute__._IsDefined(info.Owner, AttributeTargets.Class, __Cache__) or false

		MetaTable.__metatable = cls

		MetaTable.__index = MetaTable.__index or function(self, key)
			local oper

			-- Dispose Method
			if key == DISPOSE_METHOD then
				return DisposeObject
			end

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
					value = rawget(self, oper.Field)
				elseif oper.Default == nil then
					error(("%s can't be read."):format(tostring(key)),2)
				end

				if value == nil and oper.Default ~= nil then
					return oper.Default
				else
					return value
				end
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
				if type(oper) == "table" then
					return oper[key]
				elseif type(oper) == "function" then
					return oper(self, key)
				end
			end
		end

		MetaTable.__newindex = MetaTable.__newindex or function(self, key, value)
			local oper

			-- Property Set
			oper = Cache4Property[key]
			if oper then
				if oper.Type then
					value = oper.Type:Validate(value, key, 2)
				end

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
					return rawset(self, oper.Field, value)
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

				if not oper[key] then
					oper[key] = EventHandler(Cache4Event[key], self)
				end
				oper = oper[key]

				if value == nil or type(value) == "function" then
					oper.Handler = value
				elseif type(value) == "table" and Reflector.ObjectIsClass(value, EventHandler) then
					oper:Copy(value)
				else
					error("Can't set this value to the event handler.", 2)
				end

				return
			end

			-- Custom newindex metametods
			oper = MetaTable["___newindex"]
			if oper and type(oper) == "function" then
				return oper(self, key, value)
			end

			rawset(self, key, value)			-- Other key can be set as usual
		end
	end

	-- The cache for constructor parameters
	function Class2Obj(cls, ...)
		local info = _NSInfo[cls]
		local obj, isUnique
		local ok, msg, args
		local cache = CACHE_TABLE()
		local max = select('#', ...)
		local init = select(1, ...)

		if __Attribute__ and __Arguments__ then
			args = __Attribute__._GetCustomAttribute(cls, AttributeTargets.Constructor, __Arguments__)
		end

		if max == 1 and type(init) == "table" and getmetatable(init) == nil then
			-- Check if the init table should be the argument
			if args and #args == 1 then
				local arg = args[1]

				if arg.Type and arg.Type:GetObjectType(init) then
					init = nil
				end
			end
		else
			init = nil
		end

		if init then
			-- With the init table
			if args then
				max = #args

				for i = 1, max do
					local arg = args[i]

					if i < max or not arg.IsList then
						local value = init[arg.Name]
						if value == nil then value = arg.Default end
						init[arg.Name] = nil

						if arg.Type then
							ok, value = pcall(arg.Type.Validate, arg.Type, value)

							if not ok then
								CACHE_TABLE(cache)

								value = strtrim(value:match(":%d+:%s*(.-)$") or value)

								if value:find("%%s") then
									value = value:gsub("%%s[_%w]*", arg.Name)
								end

								error(args.Usage .. value, 3)
							end
						end

						cache[i] = value
					end
				end
			end
		else
			-- Without the init table
			for i = 1, max do
				cache[i] = select(i, ...)
			end

			if args then
				local maxArgs = #args

				if maxArgs > max then
					max = maxArgs
				end

				for i = 1, maxArgs do
					local arg = args[i]

					if i < maxArgs or not arg.IsList then
						local value = cache[i]
						if value == nil then value = arg.Default end

						if arg.Type then
							ok, value = pcall(arg.Type.Validate, arg.Type, value)

							if not ok then
								CACHE_TABLE(cache)

								value = strtrim(value:match(":%d+:%s*(.-)$") or value)

								if value:find("%%s") then
									value = value:gsub("%%s[_%w]*", arg.Name)
								end

								error(args.Usage .. value, 3)
							end
						end

						cache[i] = value
					else
						for j = maxArgs, max do
							local value = cache[j]

							if arg.Type then
								ok, value = pcall(arg.Type.Validate, arg.Type, value)

								if not ok then
									CACHE_TABLE(cache)

									value = strtrim(value:match(":%d+:%s*(.-)$") or value)

									if value:find("%%s") then
										value = value:gsub("%%s[_%w]*", "...")
									end

									error(args.Usage .. value, 3)
								end
							end

							cache[j] = value
						end
					end
				end
			end
		end

		-- No tail nil
		for i = max, 1, -1 do
			if cache[i] ~= nil then
				max = i
				break
			elseif i == 1 then
				max = 0
			end
		end

		-- Check if the class is unique and already created one object to be return
		if __Attribute__ and __Unique__ then
			isUnique = __Attribute__._IsDefined(cls, AttributeTargets.Class, __Unique__)

			if isUnique and info.UniqueObject then
				obj = info.UniqueObject

				pcall(obj, unpack(cache, 1, max))
				CACHE_TABLE(cache)

				-- Try set properties
				if type(init) == "table" then
					for name, value in pairs(init) do
						ok, msg = pcall(TrySetProperty, obj, name, value)

						if not ok then
							msg = strtrim(msg:match(":%d+:%s*(.-)$") or msg)

							errorhandler(msg)
						end
					end
				end

				return obj
			end
		else
			isUnique = false
		end

		-- Check if this class has __exist so no need to create again.
		if type(info.MetaTable.__exist) == "function" then
			ok, obj = pcall(info.MetaTable.__exist, unpack(cache, 1, max))

			if type(obj) == "table" then
				CACHE_TABLE(cache)
				if getmetatable(obj) == cls then
					return obj
				else
					error(("There is an existed object as type '%s'."):format(Reflector.GetName(Reflector.GetObjectClass(obj)) or ""), 2)
				end
			end
		end

		-- Create new object
		obj = setmetatable({}, info.MetaTable)

		if InitObjectWithClass(cls, obj, unpack(cache, 1, max)) then
			InitObjectWithInterface(cls, obj)
		else
			obj = nil
		end

		CACHE_TABLE(cache)

		if not obj then return nil end

		-- Try set properties
		if type(init) == "table" then
			for name, value in pairs(init) do
				ok, msg = pcall(TrySetProperty, obj, name, value)

				if not ok then
					msg = strtrim(msg:match(":%d+:%s*(.-)$") or msg)

					errorhandler(msg)
				end
			end
		end

		if obj and isUnique then
			info.UniqueObject = obj
		end

		return obj
	end

	------------------------------------
	--- Create class in currect environment's namespace or default namespace
	-- @param name the class's name
	-- @usage class "Form"
	------------------------------------
	function class(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: class "classname"]], 2)
		end
		local fenv = getfenv(2)
		local ns = GetNameSpace4Env(fenv)

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

		if not cls then
			error("No class is created.", 2)
		end

		-- Build class
		info = _NSInfo[cls]

		-- Check if the class is final
		if info.IsFinal then
			error("The class is final, can't be re-defined.", 2)
		end

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
		}, _MetaClsEnv)

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

		if __Attribute__ and cls ~= __Attribute__ then
			local isCached = __Cache__ and __Attribute__._IsDefined(info.Owner, AttributeTargets.Class, __Cache__) or false

			__Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Class, info.SuperClass)

			if not isCached and __Cache__ then
				if __Attribute__._IsDefined(info.Owner, AttributeTargets.Class, __Cache__) then
					-- So, the __index need re-build
					info.MetaTable.__index = nil
				end
			end
		end

		UpdateMetaTable4Cls(cls)

		-- Set the environment to class's environment
		setfenv(2, classEnv)
	end

	------------------------------------
	--- Set the current class' super class
	-- @name inherit
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage inherit "System.Widget.Frame"
	------------------------------------
	function inherit_Cls(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: inherit "namespace.classname"]], 2)
		end

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

					if not IsNameSpace(superCls) then
						error(("No class is found with the name : %s"):format(name), 2)
					end
				end
			end
		else
			superCls = name
		end

		local superInfo = _NSInfo[superCls]

		if not superInfo or superInfo.Type ~= TYPE_CLASS then
			error("Usage: inherit (class) : 'class' - class expected", 2)
		end

		if superInfo.NonInheritable then
			error(("%s is non-inheritable."):format(tostring(superCls)), 2)
		end

		if IsChildClass(info.Owner, superCls) then
			error(("%s is inherited from %s, can't be used as super class."):format(tostring(superCls), tostring(info.Owner)), 2)
		end

		if info.SuperClass == superCls then return end

		if info.SuperClass then
			error(("%s is inherited from %s, can't inherit another class."):format(tostring(info.Owner), tostring(info.SuperClass)), 2)
		end

		superInfo.ChildClass = superInfo.ChildClass or {}
		superInfo.ChildClass[info.Owner] = true
		info.SuperClass = superCls

		-- Keep to the environmenet
		-- rawset(env, _SuperIndex, superCls)

		-- Copy Metatable
		local rMeta
		for meta, flag in pairs(_KeyMeta) do
			rMeta = flag and meta or "_"..meta

			if info.MetaTable[rMeta] == nil and superInfo.MetaTable[rMeta] then
				SetMetaFunc(rMeta, info.ChildClass, nil, superInfo.MetaTable[rMeta])
				info.MetaTable[rMeta] = superInfo.MetaTable[rMeta]
			end
		end

		-- Clone Attributes
		if __Attribute__ then
			local isCached = __Cache__ and __Attribute__._IsDefined(info.Owner, AttributeTargets.Class, __Cache__) or false

			__Attribute__._CloneAttributes(superCls, info.Owner, AttributeTargets.Class)

			if not isCached and __Cache__ then
				if __Attribute__._IsDefined(info.Owner, AttributeTargets.Class, __Cache__) then
					-- So, the __index need re-build
					info.MetaTable.__index = nil
					UpdateMetaTable4Cls(info.Owner)
				end
			end
		end
	end

	------------------------------------
	--- Set the current class' extended interface
	-- @name extend
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage extend "System.IFSocket"
	------------------------------------
	function extend_Cls(name)
		if name and type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: extend "namespace.interfacename"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		local IF

		if type(name) == "string" then
			IF = GetNameSpace(info.NameSpace, name) or env[name]

			if not IF then
				for subname in name:gmatch("[_%w]+") do
					if not IF then
						IF = env[subname]
					else
						IF = IF[subname]
					end

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

		IFInfo.ExtendClass = IFInfo.ExtendClass or {}
		IFInfo.ExtendClass[info.Owner] = true

		info.ExtendInterface = info.ExtendInterface or {}

		-- Check if IF is already extend by extend tree
		for _, pIF in ipairs(info.ExtendInterface) do
			if IsExtend(IF, pIF) then
				return extend_Cls
			end
		end

		for i = #(info.ExtendInterface), 1, -1 do
			if IsExtend(info.ExtendInterface[i], IF) then
				tremove(info.ExtendInterface, i)
			end
		end

		tinsert(info.ExtendInterface, IF)

		return extend_Cls
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	-- @name import
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage import "System.Widget"
	------------------------------------
	function import_Cls(name)
		if type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: import "namespaceA.namespaceB"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then
			error(("No namespace is found with name : %s"):format(name), 2)
		end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do
			if v == ns then
				return
			end
		end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- Add an event for current class
	-- @name event
	-- @class function
	-- @param name the name of the event
	-- @usage event "OnClick"
	------------------------------------
	function event_Cls(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: event "eventName"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if not info then
			error("can't use event here.", 2)
		end

		info.Event[name] = info.Event[name] or Event(name)

		if __Attribute__ then
			__Attribute__._ConsumePreparedAttributes(info.Event[name], AttributeTargets.Event, nil, info.Owner, name)
		end
	end

	------------------------------------
	--- set a propert to the current class
	-- @name property
	-- @class function
	-- @param name the name of the property
	-- @usage property "Title" {
	--		Get = function(self)
	--			-- return the property's value
	--		end,
	--		Set = function(self, value)
	--			-- Set the property's value
	--		end,
	--		Type = "XXXX",	-- set the property's type
	--}
	------------------------------------
	function property_Cls(name)
		if type(name) ~= "string" or strtrim(name:match("[_%w]+")) == "" then
			error([=[Usage: property "Name" { -- Property Definition }]=], 2)
		end

		return function(set)
			return SetPropertyWithSet(_NSInfo[getfenv(2)[OWNER_FIELD]], name:match("[_%w]+"), set)
		end
	end

	------------------------------------
	--- End the class's definition and restore the environment
	-- @name class
	-- @class function
	-- @param name the name of the class
	-- @usage endclass "Form"
	------------------------------------
	function endclass(name)
		if type(name) ~= "string" or name:find("%.") then
			error([[Usage: endclass "classname"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			setfenv(2, env[BASE_ENV_FIELD])
			RefreshCache(info.Owner)
		else
			error(("%s is not closed."):format(info.Name), 2)
		end

		if __Attribute__ then
			__Attribute__._ClearPreparedAttributes()
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
				info.Enum[i:upper()] = v
			elseif type(v) == "string" then
				info.Enum[v:upper()] = v
			end
		end

		if __Attribute__ then
			__Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Enum)
		end
	end

	function GetShortEnumInfo(cls)
		if _NSInfo[cls] then
			local str

			for n in pairs(_NSInfo[cls].Enum) do
				if str and #str > 30 then
					str = str .. " | ..."
					break
				end

				str = str and (str .. " | " .. n) or n
			end

			return str or ""
		end

		return ""
	end

	------------------------------------
	--- create a enumeration
	-- @name enum
	-- @class function
	-- @param name the name of the enum
	-- @usage enum "ButtonState" {
	--		"PUSHED",
	--		"NORMAL",
	--}
	------------------------------------
	function enum(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: enum "enumName" {
				"enumValue1",
				"enumValue2",
			}]], 2)
		end

		local fenv = getfenv(2)
		local ns = GetNameSpace4Env(fenv)

		-- Create class or get it
		local enm

		if ns then
			enm = BuildNameSpace(ns, name)

			if _NSInfo[cls] then
				if _NSInfo[cls].Type and _NSInfo[cls].Type ~= TYPE_ENUM then
					error(("%s is existed as %s, not enumeration."):format(name, tostring(_NSInfo[cls].Type)), 2)
				end
			end
		else
			enm = fenv[name]

			if not(_NSInfo[enm] and _NSInfo[enm].Type == TYPE_ENUM) then
				enm = BuildNameSpace(nil, name)
			end
		end

		if not enm then
			error("No enumeration is created.", 2)
		end

		-- save class to the environment
		rawset(fenv, name, enm)

		-- Build enm
		local info = _NSInfo[enm]

		-- Check if the enum is final
		if info.IsFinal then
			error("The enum is final, can't be re-defined.", 2)
		end

		info.Type = TYPE_ENUM
		info.NameSpace = ns

		return function(set)
			return BuildEnum(info, set)
		end
	end
end

------------------------------------------------------
-- Struct
------------------------------------------------------
do
	_KeyWord4StrtEnv = _KeyWord4StrtEnv or {}

	_STRUCT_TYPE_MEMBER = "MEMBER"
	_STRUCT_TYPE_ARRAY = "ARRAY"
	_STRUCT_TYPE_CUSTOM = "CUSTOM"

	-- metatable for class's env
	_MetaStrtEnv = _MetaStrtEnv or {}
	do
		_MetaStrtEnv.__index = function(self, key)
			local info = _NSInfo[self[OWNER_FIELD]]
			local value

			-- Check owner
			if key == info.Name then
				return info.Owner
			end

			if key == "Validate" then
				return info.UserValidate
			end

			-- Check keywords
			if _KeyWord4StrtEnv[key] then
				return _KeyWord4StrtEnv[key]
			end

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
			if value then
				rawset(self, key, value)
				return value
			end

			-- Check Method
			value = info.Method and info.Method[key]
			if value then
				rawset(self, key, value)
				return value
			end

			-- Check Base
			value = self[BASE_ENV_FIELD][key]

			if value ~= nil then
				rawset(self, key, value)
				return value
			end
		end

		_MetaStrtEnv.__newindex = function(self, key, value)
			local info = _NSInfo[self[OWNER_FIELD]]

			if _KeyWord4StrtEnv[key] then
				error(("'%s' is a keyword."):format(key), 2)
			end

			if key == info.Name then
				if type(value) == "function" then
					info.Constructor = value
					return
				else
					error(("'%s' must be a function as the constructor."):format(key), 2)
				end
			end

			if key == "Validate" then
				if value == nil or type(value) == "function" then
					info.UserValidate = value
					return
				else
					error(("'%s' must be a function used for validation."):format(key), 2)
				end
			end

			if type(key) == "string"  then
				if type(value) == "function" then
					-- Cache the method for the struct data
					info.Method = info.Method or {}

					-- keep function in env, just register the method
					if __Attribute__ then
						value = __Attribute__._ConsumePreparedAttributes(value, AttributeTargets.Method, nil, info.Owner, key) or value
					end

					if getmetatable(info.Method[key]) and type(value) == "function" then
						-- Special settings for the fixed methods
						local fixedMethod = info.Method[key]

						while fixedMethod.Next do fixedMethod = fixedMethod.Next end

						fixedMethod.Next = value
					elseif info.Method[key] and getmetatable(value) then
						value.Next = info.Method[key]
						info.Method[key] = value
					else
						info.Method[key] = value
					end

					-- Don't save to environment until need it
					value = nil

				elseif (value == nil or IsType(value) or IsNameSpace(value)) then
					local ok, ret = pcall(BuildType, value, key)

					if ok then
						rawset(self, key, ret)

						if info.SubType == _STRUCT_TYPE_MEMBER then
							info.Members = info.Members or {}
							tinsert(info.Members, key)
						elseif info.SubType == _STRUCT_TYPE_ARRAY then
							info.ArrayElement = ret
						end

						-- Apply attribtue for fields, use the type object as the key
						if __Attribute__ then
							__Attribute__._ConsumePreparedAttributes(ret, AttributeTargets.Field, nil, info.Owner, key)
						end

						return
					else
						ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)
						error(ret, 2)
					end
				end
			end

			rawset(self, key, value)
		end
	end

	function ValidateStruct(strt, value)
		local info = _NSInfo[strt]

		if info.SubType == _STRUCT_TYPE_MEMBER and info.Members then
			assert(type(value) == "table", ("%s must be a table, got %s."):format("%s", type(value)))

			for _, n in ipairs(info.Members) do
				value[n] = info.StructEnv[n]:Validate(value[n])
			end
		end

		if info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
			assert(type(value) == "table", ("%s must be a table, got %s."):format("%s", type(value)))

			local flag, ret
			local ele = info.ArrayElement

			for i, v in ipairs(value) do
				flag, ret = pcall(ele.Validate, ele, v)

				if flag then
					value[i] = ret
				else
					ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)

					if ret:find("%%s([_%w]+)") then
						ret = ret:gsub("%%s([_%w]+)", "%%s["..i.."]")
					end

					assert(false, ret)
				end
			end
		end

		if type(info.UserValidate) == "function" then
			value = info.UserValidate(value)
		end

		return value
	end

	function Struct2Obj(strt, ...)
		local info = _NSInfo[strt]

		local max = select("#", ...)
		local init = select(1, ...)

		if max == 1 and type(init) == "table" and getmetatable(init) == nil then
			local continue = true

			if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
				if not info.StructEnv[info.Members[1]]:GetObjectType(init) then
					continue = false
				end
			elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
				if not info.ArrayElement:GetObjectType(init) then
					continue = false
				end
			end

			local ok, value = pcall(ValidateStruct, strt, init)

			if ok then
				if info.Method and type(value) == "table" then
					for k, v in pairs(info.Method) do
						value[k] = v
					end
				end

				return value
			elseif not continue then
				if info.SubType == _STRUCT_TYPE_MEMBER then
					value = strtrim(value:match(":%d+:%s*(.-)$") or value)
					value = value:gsub("%%s%.", ""):gsub("%%s", "")

					local args = ""
					for i, n in ipairs(info.Members) do
						if info.StructEnv[n]:Is(nil) and not args:find("%[") then
							n = "["..n
						end
						if i == 1 then
							args = n
						else
							args = args..", "..n
						end
					end
					if args:find("%[") then
						args = args.."]"
					end
					error(("Usage : %s(%s) - %s"):format(tostring(strt), args, value), 3)
				else
					value = strtrim(value:match(":%d+:%s*(.-)$") or value)
					value = value:gsub("%%s%.", ""):gsub("%%s", "")

					error(("Usage : %s(...) - %s"):format(tostring(strt), value), 3)
				end
			end
		end

		if type(info.Constructor) == "function" then
			local ok, ret = pcall(info.Constructor, ...)
			if ok then
				if info.Method and type(ret) == "table" then
					for k, v in pairs(info.Method) do
						ret[k] = v
					end
				end
				return ret
			else
				ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)

				error(ret, 3)
			end
		end

		if info.SubType == _STRUCT_TYPE_MEMBER then
			local ret = {}

			if info.Members then
				for i, n in ipairs(info.Members) do
					ret[n] = select(i, ...)
				end
			end

			local ok, value = pcall(ValidateStruct, strt, ret)

			if ok then
				if info.Method then
					for k, v in pairs(info.Method) do
						value[k] = v
					end
				end

				return value
			else
				value = strtrim(value:match(":%d+:%s*(.-)$") or value)
				value = value:gsub("%%s%.", ""):gsub("%%s", "")

				local args = ""
				for i, n in ipairs(info.Members) do
					if info.StructEnv[n]:Is(nil) and not args:find("%[") then
						n = "["..n
					end
					if i == 1 then
						args = n
					else
						args = args..", "..n
					end
				end
				if args:find("%[") then
					args = args.."]"
				end
				error(("Usage : %s(%s) - %s"):format(tostring(strt), args, value), 3)
			end
		end

		if info.SubType == _STRUCT_TYPE_ARRAY then
			local ret = {}

			for i = 1, select('#', ...) do
				ret[i] = select(i, ...)
			end

			local ok, value = pcall(ValidateStruct, strt, ret)

			if ok then
				if info.Method then
					for k, v in pairs(info.Method) do
						value[k] = v
					end
				end
				return value
			else
				value = strtrim(value:match(":%d+:%s*(.-)$") or value)
				value = value:gsub("%%s%.", ""):gsub("%%s", "")

				error(("Usage : %s(...) - %s"):format(tostring(strt), value), 3)
			end
		end

		-- For custom at last
		if type(info.UserValidate) == "function"  then
			local ok, ret = pcall(info.UserValidate, ...)

			if not ok then
				ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)

				ret = ret:gsub("%%s", "[".. info.Name .."]")

				error(ret, 3)
			end

			return ret
		end

		error(("struct '%s' is abstract."):format(tostring(strt)), 3)
	end

	function BuildStructValidate(strt)
		local info = _NSInfo[strt]

		info.Validate = function ( value )
			local ok, ret = pcall(ValidateStruct, strt, value)

			if not ok then
				ret = strtrim(ret:match(":%d+:%s*(.-)$") or ret)

				ret = ret:gsub("%%s", "[".. info.Name .."]")

				error(ret, 2)
			end

			return ret
		end
	end

	------------------------------------
	--- create a structure
	-- @name struct
	-- @class function
	-- @param name the name of the enum
	-- @usage struct "Point"
	--    x = System.Number
	--    y = System.Number
	-- endstruct "Point"
	------------------------------------
	function struct(name)
		if type(name) ~= "string" or not name:match("^[_%w]+$") then
			error([[Usage: struct "structname"]], 2)
		end
		local fenv = getfenv(2)
		local ns = GetNameSpace4Env(fenv)

		-- Create class or get it
		local strt

		if ns then
			strt = BuildNameSpace(ns, name)

			if _NSInfo[strt] then
				if _NSInfo[strt].Type and _NSInfo[strt].Type ~= TYPE_STRUCT then
					error(("%s is existed as %s, not struct."):format(name, tostring(_NSInfo[strt].Type)), 2)
				end
			end
		else
			strt = fenv[name]

			if not ( strt and _NSInfo[strt] and _NSInfo[strt].NameSpace == nil and _NSInfo[strt].Type == TYPE_STRUCT ) then
				strt = BuildNameSpace(nil, name)
			end
		end

		if not strt then
			error("No struct is created.", 2)
		end

		-- save class to the environment
		rawset(fenv, name, strt)

		-- Build class
		info = _NSInfo[strt]

		-- Check if the struct is final
		if info.IsFinal then
			error("The struct is final, can't be re-defined.", 2)
		end

		info.Type = TYPE_STRUCT
		info.SubType = _STRUCT_TYPE_MEMBER
		info.NameSpace = ns
		info.Members = nil
		info.ArrayElement = nil
		info.UserValidate = nil
		info.Validate = nil
		info.Method = nil
		info.Constructor = nil
		info.Import4Env = nil

		info.StructEnv = setmetatable({
			[OWNER_FIELD] = strt,
			[BASE_ENV_FIELD] = fenv,
		}, _MetaStrtEnv)

		-- Set namespace
		SetNameSpace4Env(info.StructEnv, strt)

		if __Attribute__ then
			__Attribute__._ConsumePreparedAttributes(info.Owner, AttributeTargets.Struct)
		end

		-- Set the environment to class's environment
		setfenv(2, info.StructEnv)
	end

	------------------------------------
	--- import classes from the given name's namespace to the current environment
	-- @name import
	-- @class function
	-- @param name the namespace's name list, using "." to split.
	-- @usage import "System.Widget"
	------------------------------------
	function import_STRT(name)
		if type(name) ~= "string" and not IsNameSpace(name) then
			error([[Usage: import "namespaceA.namespaceB"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]
		local ns

		if type(name) == "string" then
			ns = GetNameSpace(GetDefaultNameSpace(), name)
		elseif IsNameSpace(name) then
			ns = name
		end

		if not ns then
			error(("No namespace is found with name : %s"):format(name), 2)
		end

		info.Import4Env = info.Import4Env or {}

		for _, v in ipairs(info.Import4Env) do
			if v == ns then
				return
			end
		end

		tinsert(info.Import4Env, ns)
	end

	------------------------------------
	--- End the class's definition and restore the environment
	-- @name class
	-- @class function
	-- @param name the name of the class
	-- @usage endclass "Form"
	------------------------------------
	function endstruct(name)
		if type(name) ~= "string" or name:find("%.") then
			error([[Usage: endstruct "structname"]], 2)
		end

		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		if info.Name == name then
			if __Attribute__ then
				__Attribute__._ClearPreparedAttributes()
			end

			setfenv(2, env[BASE_ENV_FIELD])
		else
			error(("%s is not closed."):format(info.Name), 2)
		end
	end

	function structtype(_type_)
		local env = getfenv(2)
		local info = _NSInfo[env[OWNER_FIELD]]

		_type_ = _type_:upper()

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
			info.ArrayElement = nil
		end
	end

	_KeyWord4StrtEnv.struct = struct
	_KeyWord4StrtEnv.structtype = structtype
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
-- System Namespace
------------------------------------------------------
do
	namespace "System"

	------------------------------------------------------
	-- Base structs
	------------------------------------------------------
	struct "Boolean"
		structtype "CUSTOM"

		function Validate(value)
			return value and true or false
		end
	endstruct "Boolean"

	struct "String"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "string" then
				error(("%s must be a string, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "String"

	struct "Number"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "number" then
				error(("%s must be a number, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "Number"

	struct "Function"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "function" then
				error(("%s must be a function, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "Function"

	struct "Table"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "table" then
				error(("%s must be a table, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "Table"

	struct "Userdata"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "userdata" then
				error(("%s must be a userdata, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "Userdata"

	struct "Thread"
		structtype "CUSTOM"

		function Validate(value)
			if type(value) ~= "thread" then
				error(("%s must be a thread, got %s."):format("%s", type(value)))
			end
			return value
		end
	endstruct "Thread"

	struct "Any"
		structtype "CUSTOM"

		function Validate(value)
			return value
		end
	endstruct "Any"

	------------------------------------------------------
	-- System.Type
	------------------------------------------------------
	class "Type"
		doc [======[
			@name Type
			@type class
			@desc The type object used to handle the value's validation
		]======]

		_ALLOW_NIL = "AllowNil"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc [======[
			@name Validate
			@type method
			@desc Used to validate the value
			@format value[, name[, stack]]
			@param value
			@param name the name present the value
			@param stack the stack level, default 1
			@return value
		]======]
		function Validate(self, value, name, stack)
			if value == nil and rawget(self, _ALLOW_NIL) then
				return value
			end

			local flag, msg, info, new

			local index = -1

	        local types

			while self[index] do
				info = _NSInfo[self[index]]

	            new = nil

	            if not info then
	                -- skip
				elseif info.Type == TYPE_CLASS then
					if value and rawget(_NSInfo, value) and _NSInfo[value].Type == TYPE_CLASS and IsChildClass(info.Owner, value) then
						return value
					end

					new = ("%s must be or must be subclass of [class]%s."):format("%s", tostring(info.Owner))
				elseif info.Type == TYPE_INTERFACE then
					if value and rawget(_NSInfo, value) and _NSInfo[value].Type == TYPE_CLASS and IsExtend(info.Owner, value) then
						return value
					end

					new = ("%s must be extended from [interface]%s."):format("%s", tostring(info.Owner))
	            elseif info.Type then
	                if value == info.Owner then
	                    return value
	                else
	                    types = (types or "") .. tostring(info.Owner) .. ", "
	                end
				end

				if new and not msg then
					if self.Name and self.Name ~= "" then
						if new:find("%%s([_%w]+)") then
							msg = new:gsub("%%s", "%%s"..self.Name..".")
						else
							msg = new:gsub("%%s", "%%s"..self.Name)
						end
					else
						msg = new
					end
				end

				index = index - 1
			end

	        if types and types:len() >= 3 and not msg then
	            new = ("%s must be the type in ()."):format("%s", types:sub(1, -3))

	            if self.Name and self.Name ~= "" then
	                if new:find("%%s([_%w]+)") then
	                    msg = new:gsub("%%s", "%%s"..self.Name..".")
	                else
	                    msg = new:gsub("%%s", "%%s"..self.Name)
	                end
	            else
	                msg = new
	            end
	        end

			for _, ns in ipairs(self) do
				info = _NSInfo[ns]

				new = nil

				if not info then
					-- do nothing
				elseif info.Type == TYPE_STRUCT then
					-- Check if the value is an enumeration value of this structure
					flag, new = pcall(ValidateStruct, ns, value)

					if flag then
						return new
					end

					new = strtrim(new:match(":%d+:%s*(.-)$") or new)
				elseif info.Type == TYPE_CLASS then
					-- Check if the value is an instance of this class
					if type(value) == "table" and getmetatable(value) and IsChildClass(ns, getmetatable(value)) then
						return value
					end

					new = ("%s must be an instance of [class]%s."):format("%s", tostring(ns))
				elseif info.Type == TYPE_INTERFACE then
					-- Check if the value is an instance of this interface
					if type(value) == "table" and getmetatable(value) and IsExtend(ns, getmetatable(value)) then
						return value
					end

					new = ("%s must be an instance extended from [interface]%s."):format("%s", tostring(ns))
				elseif info.Type == TYPE_ENUM then
					-- Check if the value is an enumeration value of this enum
					if type(value) == "string" and info.Enum[value:upper()] then
						return info.Enum[value:upper()]
					end

					if info.MaxValue then
						-- Bit flag validation, use MaxValue check to reduce cost
						value = tonumber(value)

						if value then
							if value >= 1 and value <= info.MaxValue then
								return floor(value)
							elseif value == 0 then
								for _, v in pairs(info.Enum) do
									if value == v then
										return v
									end
								end
							end
						end
					else
						for _, v in pairs(info.Enum) do
							if value == v then
								return v
							end
						end
					end

					new = ("%s must be a value of [enum]%s ( %s )."):format("%s", tostring(ns), GetShortEnumInfo(ns))
				end

				if new and not msg then
					if self.Name and self.Name ~= "" then
						if new:find("%%s([_%w]+)") then
							msg = new:gsub("%%s", "%%s"..self.Name..".")
						else
							msg = new:gsub("%%s", "%%s"..self.Name)
						end
					else
						msg = new
					end
				end
			end

			if msg and rawget(self, _ALLOW_NIL) and not msg:match("%(Optional%)$") then
				msg = msg .. "(Optional)"
			end

			if msg then
				if name then
					if msg:find("%%s") then
						msg = msg:gsub("%%s[_%w]*", name)
					end
				end

				error(msg, (stack or 1) + 1)
			end

			return value
		end

		doc [======[
			@name Copy
			@type method
			@desc Copy the type object
			@return the clone
		]======]
		function Copy(self)
			local _type = Type()

			for i, v in pairs(self) do
				_type[i] = v
			end

			return _type
		end

		doc [======[
			@name Is
			@type method
			@desc Check if the type object constains such type
			@param type class | struct | enum | nil
			@param onlyClass true if the type only much class, not class' object
			@return boolean
		]======]
		function Is(self, ns, onlyClass)
			local fenv = getfenv(2)

			if ns == nil then
				return self.AllowNil or false
			end

			if IsNameSpace(ns) then
				if not onlyClass then
					for _, v in ipairs(self) do
						if v == ns then
							return true
						end
					end
				else
					local index = -1

					while self[index] do
						if self[index] == ns then
							return true
						end
						index = index - 1
					end
				end
			end

			return false
		end

		doc [======[
			@name GetObjectType
			@type method
			@desc Get the object type if validated, false if nothing match
			@param value
			@return type struct | enum | class | interface | nil
		]======]
		function GetObjectType(self, value)
			if value == nil and rawget(self, _ALLOW_NIL) then
				return
			end

			local flag, msg, info, new

			local index = -1

			while self[index] do
				info = _NSInfo[self[index]]

	            if not info then
	                -- skip
				elseif info.Type == TYPE_CLASS then
					if value and rawget(_NSInfo, value) and _NSInfo[value].Type == TYPE_CLASS and IsChildClass(info.Owner, value) then
						return info.Owner
					end
				elseif info.Type == TYPE_INTERFACE then
					if value and rawget(_NSInfo, value) and _NSInfo[value].Type == TYPE_CLASS and IsExtend(info.Owner, value) then
						return info.Owner
					end
	            elseif info.Type then
	                if value == info.Owner then
	                    return info.Owner
	                end
				end

				index = index - 1
			end

			for _, ns in ipairs(self) do
				info = _NSInfo[ns]

				new = nil

				if not info then
					-- do nothing
				elseif info.Type == TYPE_CLASS then
					-- Check if the value is an instance of this class
					if type(value) == "table" and getmetatable(value) and IsChildClass(ns, getmetatable(value)) then
						return ns
					end
				elseif info.Type == TYPE_INTERFACE then
					-- Check if the value is an instance of this interface
					if type(value) == "table" and getmetatable(value) and IsExtend(ns, getmetatable(value)) then
						return ns
					end
				elseif info.Type == TYPE_ENUM then
					-- Check if the value is an enumeration value of this enum
					if type(value) == "string" and info.Enum[value:upper()] then
						return ns
					end

					if info.MaxValue then
						-- Bit flag validation, use MaxValue check to reduce cost
						value = tonumber(value)

						if value then
							if value >= 1 and value <= info.MaxValue then
								return ns
							end
						end
					else
						for _, v in pairs(info.Enum) do
							if value == v then
								return ns
							end
						end
					end
				elseif info.Type == TYPE_STRUCT then
					-- Check if the value is an enumeration value of this structure
					flag, new = pcall(ValidateStruct, ns, value)

					if flag then
						return ns
					end
				end
			end

			return false
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------

		------------------------------------------------------
		-- MetaMethod
		------------------------------------------------------
		function __add(v1, v2)
			local ok, _type1, _type2

			ok, _type1 = pcall(BuildType, v1)
			if not ok then
				_type1 = strtrim(_type1:match(":%d+:%s*(.-)$") or _type1)
				error(_type1, 2)
			end

			ok, _type2 = pcall(BuildType, v2)
			if not ok then
				_type2 = strtrim(_type2:match(":%d+:%s*(.-)$") or _type2)
				error(_type2, 2)
			end

			if _type1 and _type2 then
				local _type = Type()

				_type.AllowNil = _type1.AllowNil or _type2.AllowNil

				local tmp = {}

				for _, ns in ipairs(_type1) do
					tinsert(_type, ns)
					tmp[ns] = true
				end
				for _, ns in ipairs(_type2) do
					if not tmp[ns] then
						tinsert(_type, ns)
					end
				end

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

				ok, _type2 = pcall(BuildType, v2, nil, true)
				if not ok then
					_type2 = strtrim(_type2:match(":%d+:%s*(.-)$") or _type2)
					error(_type2, 2)
				end

				return v1 + _type2
			elseif v2 == nil then
				return v1
			else
				error("The operation '-' must be used with class or interface.", 2)
			end
		end

		function __unm(v1)
			error("Can't use unary '-' before a Type", 2)
		end

		function __tostring(self)
			local ret = ""

			for _, tns in ipairs(self) do
				ret = ret .. " + " .. GetFullName4NS(tns)
			end

			local index = -1
			while self[index] do
				ret = ret .. " - " .. GetFullName4NS(self[index])

				index = index - 1
			end

			-- Allow nil
			if self.AllowNil then
				ret = ret .. " + nil"
			end

			if ret:sub(1, 2) == " +" then
				ret = ret:sub(4, -1)
			end

			return ret
		end
	endclass "Type"

	------------------------------------------------------
	-- System.Reflector
	------------------------------------------------------
	interface "Reflector"

		doc [======[
			@name Reflector
			@type interface
			@desc This interface contains much methodes to get the running object-oriented system's informations.
		]======]

		doc [======[
			@name GetCurrentNameSpace
			@type method
			@desc Get the namespace used by the environment
			@param env table
			@param rawOnly boolean, rawget data from the env if true
			@return namespace
		]======]
		function GetCurrentNameSpace(env, rawOnly)
			env = type(env) == "table" and env or getfenv(2)

			return GetNameSpace4Env(env, rawOnly)
		end

		doc [======[
			@name SetCurrentNameSpace
			@type method
			@desc set the namespace used by the environment
			@param ns the namespace that set for the environment
			@param env table
			@return nil
		]======]
		function SetCurrentNameSpace(ns, env)
			env = type(env) == "table" and env or getfenv(2)

			return SetNameSpace4Env(env, ns)
		end

		doc [======[
			@name ForName
			@type method
			@desc Get the namespace for the name
			@param name the namespace's name, split by "."
			@return namespace the namespace
			@usage System.Reflector.ForName("System")
		]======]
		function ForName(name)
			return GetNameSpace(GetDefaultNameSpace(), name)
		end

		doc [======[
			@name GetType
			@type method
			@desc Get the class|enum|struct|interface for the namespace
			@param name the namespace
			@return type
			@usage System.Reflector.GetType("System.Object")
		]======]
		function GetType(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Type
		end

		doc [======[
			@name GetName
			@type method
			@desc Get the name for the namespace
			@param namespace the namespace to query
			@return name
			@usage System.Reflector.GetName(System.Object)
		]======]
		function GetName(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Name
		end

		doc [======[
			@name GetFullName
			@type method
			@desc Get the full name for the namespace
			@param namespace the namespace to query
			@return fullname
			@usage System.Reflector.GetFullName(System.Object)
		]======]
		function GetFullName(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return GetFullName4NS(ns)
		end

		doc [======[
			@name GetSuperClass
			@type method
			@desc Get the superclass for the class
			@param class the class object to query
			@return superclass
			@usage System.Reflector.GetSuperClass(System.Object)
		]======]
		function GetSuperClass(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].SuperClass
		end

		doc [======[
			@name IsNameSpace
			@type method
			@desc Check if the object is a NameSpace
			@param object the object to query
			@return boolean true if the object is a NameSpace
			@usage System.Reflector.IsNameSpace(System.Object)
		]======]
		function IsNameSpace(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and true or false
		end

		doc [======[
			@name IsClass
			@type method
			@desc Check if the namespace is a class
			@param object
			@return boolean true if the object is a class
			@usage System.Reflector.IsClass(System.Object)
		]======]
		function IsClass(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Type == TYPE_CLASS or false
		end

		doc [======[
			@name IsStruct
			@type method
			@desc Check if the namespace is a struct
			@param object
			@return boolean true if the object is a struct
			@usage System.Reflector.IsStruct(System.Object)
		]======]
		function IsStruct(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Type == TYPE_STRUCT or false
		end

		doc [======[
			@name IsEnum
			@type method
			@desc Check if the namespace is an enum
			@param object
			@return boolean true if the object is a enum
			@usage System.Reflector.IsEnum(System.Object)
		]======]
		function IsEnum(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Type == TYPE_ENUM or false
		end

		doc [======[
			@name IsInterface
			@type method
			@desc Check if the namespace is an interface
			@param object
			@return boolean true if the object is an Interface
			@usage System.Reflector.IsInterface(System.IFSocket)
		]======]
		function IsInterface(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].Type == TYPE_INTERFACE or false
		end

		doc [======[
			@name IsFinal
			@type method
			@desc Check if the class|interface is final, can't be re-defined
			@param object
			@return boolean true if the class|interface is final
			@usage System.Reflector.IsFinal(System.Object)
		]======]
		function IsFinal(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].IsFinal or false
		end

		doc [======[
			@name IsNonInheritable
			@type method
			@desc Check if the class|interface is non-inheritable
			@param object
			@return boolean true if the class|interface is non-inheritable
			@usage System.Reflector.IsNonInheritable(System.Object)
		]======]
		function IsNonInheritable(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].NonInheritable or false
		end

		doc [======[
			@name IsNonExpandable
			@type method
			@desc Check if the class|interface is non-expandable
			@param object
			@return boolean true if the class|interface is non-expandable
			@usage System.Reflector.IsNonExpandable(System.Object)
		]======]
		function IsNonExpandable(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			return ns and rawget(_NSInfo, ns) and _NSInfo[ns].NonExpandable or false
		end

		doc [======[
			@name GetSubNamespace
			@type method
			@desc Get the sub namespace of the namespace
			@param namespace
			@return table the sub-namespace list
			@usage System.Reflector.GetSubNamespace(System)
		]======]
		function GetSubNamespace(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and info.SubNS then
				local ret = {}

				for key in pairs(info.SubNS) do
					tinsert(ret, key)
				end

				sort(ret)

				return ret
			end
		end

		doc [======[
			@name GetExtendInterfaces
			@type method
			@desc Get the extend interfaces of the class
			@param class
			@return table the extend interface list
			@usage System.Reflector.GetExtendInterfaces(System.Object)
		]======]
		function GetExtendInterfaces(cls)
			if type(cls) == "string" then cls = ForName(cls) end

			local info = cls and _NSInfo[cls]

			if info.ExtendInterface then
				local ret = {}

				for _, IF in ipairs(info.ExtendInterface) do
					tinsert(ret, IF)
				end

				return ret
			end
		end

		doc [======[
			@name GetAllExtendInterfaces
			@type method
			@desc Get all the extend interfaces of the class
			@param class
			@return table the full extend interface list in the inheritance tree
			@usage System.Reflector.GetAllExtendInterfaces(System.Object)
		]======]
		function GetAllExtendInterfaces(cls)
			if type(cls) == "string" then cls = ForName(cls) end

			local info = cls and _NSInfo[cls]

			if info.Cache4Interface then
				local ret = {}

				for _, IF in ipairs(info.Cache4Interface) do
					tinsert(ret, IF)
				end

				return ret
			end
		end

		doc [======[
			@name GetChildClasses
			@type method
			@desc Get the child classes of the class
			@param class
			@return table the child class list
			@usage System.Reflector.GetChildClasses(System.Object)
		]======]
		function GetChildClasses(cls)
			if type(cls) == "string" then cls = ForName(cls) end

			local info = cls and _NSInfo[cls]

			if info.Type == TYPE_CLASS and info.ChildClass then
				local ret = {}

				for subCls in pairs(info.ChildClass) do
					tinsert(ret, subCls)
				end

				return ret
			end
		end

		doc [======[
			@name GetEvents
			@type method
			@desc Get the events of the class
			@format class|interface[, noSuper]
			@param class|interface the class or interface to query
			@param noSuper no super event handlers
			@return table the event handler list
			@usage System.Reflector.GetEvents(System.Object)
		]======]
		function GetEvents(ns, noSuper)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				local ret = {}

				for i, v in pairs(noSuper and info.Event or info.Cache4Event) do
					if v then
						tinsert(ret, i)
					end
				end

				sort(ret)

				return ret
			end
		end

		doc [======[
			@name GetProperties
			@type method
			@desc Get the properties of the class
			@format class|interface[, noSuper]
			@param class|interface the class or interface to query
			@param noSuper no super properties
			@return table the property list
			@usage System.Reflector.GetProperties(System.Object)
		]======]
		function GetProperties(ns, noSuper)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				local ret = {}

				for i, v in pairs(noSuper and info.Property or info.Cache4Property) do
					if v then
						tinsert(ret, i)
					end
				end

				sort(ret)

				return ret
			end
		end

		doc [======[
			@name GetMethods
			@type method
			@desc Get the methods of the class
			@format class|interface[, noSuper]
			@param class|interface the class or interface to query
			@param noSuper no super methodes
			@return table the method list
			@usage System.Reflector.GetMethods(System.Object)
		]======]
		function GetMethods(ns, noSuper)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				local ret = {}

				for k, v in pairs(noSuper and info.Method or info.Cache4Method) do
					tinsert(ret, k)
				end

				if not noSuper then
					for k, v in pairs(info.Method) do
						if k:match("^_") then
							tinsert(ret, k)
						end
					end
				end

				sort(ret)

				return ret
			end
		end

		doc [======[
			@name GetPropertyType
			@type method
			@desc Get the property type of the class
			@param class|interface
			@param propName the property name
			@return type the property type
			@usage System.Reflector.GetPropertyType(System.Object, "Name")
		]======]
		function GetPropertyType(ns, propName)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local ty = info.Cache4Property[propName].Type

				return ty and ty:Copy()
			end
		end

		doc [======[
			@name HasProperty
			@type method
			@desc whether the property is existed
			@param class|interface
			@param propName
			@return boolean true if the class|interface has the property
			@usage System.Reflector.HasProperty(System.Object, "Name")
		]======]
		function HasProperty(ns, propName)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				return true
			end

			return false
		end

		doc [======[
			@name IsPropertyReadable
			@type method
			@desc whether the property is readable
			@param class|interface
			@param propName
			@return boolean true if the property is readable
			@usage System.Reflector.IsPropertyReadable(System.Object, "Name")
		]======]
		function IsPropertyReadable(ns, propName)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local prop = info.Cache4Property[propName]
				if prop.Get or prop.GetMethod or prop.Field then
					return true
				else
					return false
				end
			end
		end

		doc [======[
			@name IsPropertyWritable
			@type method
			@desc whether the property is writable
			@param class|interface
			@param propName
			@return boolean true if the property is writable
			@usage System.Reflector.IsPropertyWritable(System.Object, "Name")
		]======]
		function IsPropertyWritable(ns, propName)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[propName] then
				local prop = info.Cache4Property[propName]
				if prop.Set or prop.SetMethod or prop.Field then
					return true
				else
					return false
				end
			end
		end

		doc [======[
			@name GetEnums
			@type method
			@desc Get the enums of the enum
			@param enum
			@return table the enum index list
			@usage System.Reflector.GetEnums(System.SampleEnum)
		]======]
		function GetEnums(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and _NSInfo[ns]

			if info and info.Type == TYPE_ENUM then
				if __Attribute__._IsDefined(ns, AttributeTargets.Enum, __Flags__) then
					local tmp = {}
					local zero = nil

					for i, v in pairs(info.Enum) do
						if type(v) == "number" then
							if v > 0 then
								tmp[floor(log(v)/log(2)) + 1] = i
							else
								zero = i
							end
						end
					end

					if zero then
						tinsert(tmp, 1, zero)
					end

					return tmp
				else
					local tmp = {}

					for i in pairs(info.Enum) do
						tinsert(tmp, i)
					end

					sort(tmp)

					return tmp
				end
			end
		end

		doc [======[
			@name ParseEnum
			@type method
			@desc Get the enum index of the enum value
			@param enum
			@param value
			@return index
			@usage System.Reflector.ParseEnum(System.SampleEnum, 1)
		]======]
		function ParseEnum(ns, value)
			if type(ns) == "string" then ns = ForName(ns) end

			if ns and _NSInfo[ns] and _NSInfo[ns].Type == TYPE_ENUM and _NSInfo[ns].Enum then
				if __Attribute__._IsDefined(ns, AttributeTargets.Enum, __Flags__) and type(value) == "number" then
					local ret = {}

					if value == 0 then
						for n, v in pairs(_NSInfo[ns].Enum) do
							if v == value then
								return n
							end
						end
					else
						for n, v in pairs(_NSInfo[ns].Enum) do
							if ValidateFlags(v, value) then
								tinsert(ret, n)
							end
						end
					end

					return unpack(ret)
				else
					for n, v in pairs(_NSInfo[ns].Enum) do
						if v == value then
							return n
						end
					end
				end
			end
		end

		doc [======[
			@name ValidateFlags
			@type method
			@desc  hether the value is contains on the target value
			@param checkValue like 1, 2, 4, 8, ...
			@param targetValue like 3 : (1 + 2)
			@return boolean true if the targetValue contains the checkValue
		]======]
		function ValidateFlags(checkValue, targetValue)
			targetValue = targetValue % (2 * checkValue)
			return (targetValue - targetValue % checkValue) == checkValue
		end

		doc [======[
			@name HasEvent
			@type method
			@desc Check if the class|interface has that event
			@param class|interface
			@param event the event handler name
			@return true if the class|interface has the event
			@usage System.Reflector.HasEvent(Addon, "OnEvent")
		]======]
		function HasEvent(cls, sc)
			if type(cls) == "string" then cls = ForName(cls) end

			local info = _NSInfo[cls]

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) then
				return info.Cache4Event[sc] or false
			end
		end

		doc [======[
			@name GetStructType
			@type method
			@desc Get the type of the struct
			@param struct
			@return string
		]======]
		function GetStructType(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and rawget(_NSInfo, ns)

			if info and info.Type == TYPE_STRUCT then
				return info.SubType
			end
		end

		doc [======[
			@name GetStructArrayElement
			@type method
			@desc Get the array element type of the struct
			@param ns
			@return type the array element's type
		]======]
		function GetStructArrayElement(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and rawget(_NSInfo, ns)

			if info and info.Type == TYPE_STRUCT and info.SubType == _STRUCT_TYPE_ARRAY then
				return info.ArrayElement
			end
		end

		doc [======[
			@name GetStructParts
			@type method
			@desc Get the parts of the struct
			@param struct
			@return table struct part name list
			@usage System.Reflector.GetStructParts(Position)
		]======]
		function GetStructParts(ns)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and rawget(_NSInfo, ns)

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					local tmp = {}

					for _, part in ipairs(info.Members) do
						tinsert(tmp, part)
					end

					return tmp
				elseif info.SubType == _STRUCT_TYPE_ARRAY then
					return { "element" }
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					local tmp = {}

					for key, value in pairs(info.StructEnv) do
						if type(key) == "string" and IsType(value) then
							tinsert(tmp, key)
						end
					end

					sort(tmp)

					return tmp
				end
			end
		end

		doc [======[
			@name GetStructPart
			@type method
			@desc Get the part's type of the struct
			@param struct
			@param part the part's name
			@return type the part's type
			@usage System.Reflector.GetStructPart(Position, "x")
		]======]
		function GetStructPart(ns, part)
			if type(ns) == "string" then ns = ForName(ns) end

			local info = ns and rawget(_NSInfo, ns)

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0  then
					for _, p in ipairs(info.Members) do
						if p == part and IsType(info.StructEnv[part]) then
							return info.StructEnv[part]:Copy()
						end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return info.ArrayElement:Copy()
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					if IsType(info.StructEnv[part]) then
						return info.StructEnv[part]:Copy()
					end
				end
			end
		end

		doc [======[
			@name IsSuperClass
			@type method
			@desc Check if this first arg is a child class of the next arg
			@param childclass
			@param superclass
			@return boolean true if the supeclass is the childclass's super class
			@usage System.Reflector.IsSuperClass(UIObject, Object)
		]======]
		function IsSuperClass(child, super)
			if type(child) == "string" then child = ForName(child) end
			if type(super) == "string" then super = ForName(super) end

			return IsClass(child) and IsClass(super) and IsChildClass(super, child)
		end

		doc [======[
			@name IsExtendedInterface
			@type method
			@desc Check if the class is extended from the interface
			@param class|interface
			@param interface
			@return boolean true if the first arg is extend from the second
			@usage System.Reflector.IsExtendedInterface(UIObject, IFSocket)
		]======]
		function IsExtendedInterface(cls, IF)
			if type(cls) == "string" then cls = ForName(cls) end
			if type(IF) == "string" then IF = ForName(IF) end

			return IsExtend(IF, cls)
		end

		doc [======[
			@name GetObjectClass
			@type method
			@desc Get the class type of this object
			@param object
			@return class the object's class
			@usage System.Reflector.GetObjectClass(obj)
		]======]
		function GetObjectClass(obj)
			return type(obj) == "table" and getmetatable(obj)
		end

		doc [======[
			@name ObjectIsClass
			@type method
			@desc Check if this object is an instance of the class
			@param object
			@param class
			@return true if the object is an instance of the class or it's child class
			@usage System.Reflector.ObjectIsClass(obj, Object)
		]======]
		function ObjectIsClass(obj, cls)
			if type(cls) == "string" then cls = ForName(cls) end
			return (obj and cls and IsChildClass(cls, GetObjectClass(obj))) or false
		end

		doc [======[
			@name ObjectIsInterface
			@type method
			@desc Check if this object is an instance of the interface
			@param object
			@param interface
			@return true if the object's class is extended from the interface
			@usage System.Reflector.ObjectIsInterface(obj, IFSocket)
		]======]
		function ObjectIsInterface(obj, IF)
			if type(IF) == "string" then IF = ForName(IF) end
			return (obj and IF and IsExtend(IF, GetObjectClass(obj))) or false
		end

		doc [======[
			@name FireObjectEvent
			@type method
			@desc Fire an object's event, to trigger the object's event handlers
			@param object the object
			@param event the event name
			@param ... the event's arguments
			@return nil
		]======]
		function FireObjectEvent(obj, sc, ...)
			-- No more check , just fire the event as quick as we can
			local handler = rawget(obj, "__Events")
			handler = handler and handler[sc]
			if handler then return handler(obj, ...) end
		end

		doc [======[
			@name ActiveThread
			@type method
			@desc Active thread mode for special events.
			@param object
			@param ... event handler name list
			@return nil
			@usage System.Reflector.ActiveThread(obj, "OnClick", "OnEnter")
		]======]
		function ActiveThread(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then
						local handler = rawget(obj, "__Events")
						handler = handler and handler[name]

						if handler or not IsThreadActivated(cls, name) then
							obj[name].ThreadActivated = true
						end
					end
				end
			end
		end

		doc [======[
			@name IsThreadActivated
			@type method
			@desc Whether the thread mode is activated for special events.
			@param obect
			@param event
			@return boolean true if the object has active thread mode for the given event.
			@usage System.Reflector.IsThreadActivated(obj, "OnClick")
		]======]
		function IsThreadActivated(obj, sc)
			if IsClass(obj) then
				local evt = _NSInfo[obj].Cache4Event[sc]

				return evt and evt.ThreadActivated or false
			else
				local cls = GetObjectClass(obj)

				if cls and HasEvent(cls, sc) then
					return obj[sc].ThreadActivated or false
				end
			end

			return false
		end

		doc [======[
			@name InactiveThread
			@type method
			@desc Inactive thread mode for special events.
			@param object
			@param ... event name list
			@return nil
			@usage System.Reflector.InactiveThread(obj, "OnClick", "OnEnter")
		]======]
		function InactiveThread(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then
						local handler = rawget(obj, "__Events")
						handler = handler and handler[name]

						if handler or IsThreadActivated(cls, name) then
							obj[name].ThreadActivated = false
						end
					end
				end
			end
		end

		doc [======[
			@name BlockEvent
			@type method
			@desc Block event for object
			@param object
			@param ... the event handler name list
			@return nil
			@usage System.Reflector.BlockEvent(obj, "OnClick", "OnEnter")
		]======]
		function BlockEvent(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then
						obj[name]._Blocked = true
					end
				end
			end
		end

		doc [======[
			@name IsEventBlocked
			@type method
			@desc Whether the event is blocked for object
			@param object
			@param event
			@return boolean true if the event is blocked
			@usage System.Reflector.IsEventBlocked(obj, "OnClick")
		]======]
		function IsEventBlocked(obj, sc)
			local cls = GetObjectClass(obj)
			local name

			if cls and HasEvent(cls, sc) then
				return obj[sc]._Blocked or false
			end

			return false
		end

		doc [======[
			@name UnBlockEvent
			@type method
			@desc Un-Block event for object
			@param object
			@param ... event handler name list
			@return nil
			@usage System.Reflector.UnBlockEvent(obj, "OnClick", "OnEnter")
		]======]
		function UnBlockEvent(obj, ...)
			local cls = GetObjectClass(obj)
			local name

			if cls then
				for i = 1, select('#', ...) do
					name = select(i, ...)

					if HasEvent(cls, name) then
						obj[name]._Blocked = nil
					end
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
					if next(self) then
						return tremove(self)
					else
						return BuildType(nil)
					end
				end
			end,
		})

		doc [======[
			@name Validate
			@type method
			@desc Validating the value to the given type.
			@format type, value, name[, prefix[, stacklevel]]
			@param type such like Object+String+nil
			@param value the test value
			@param name the parameter's name
			@param prefix the prefix string
			@param stacklevel set if not in the main function call, only work when prefix is setted
			@return nil
			@usage System.Reflector.Validate(System.String+nil, "Test")
		]======]
		function Validate(types, value, name, prefix, stacklevel)
			stacklevel = type(stacklevel) == "number" and stacklevel > 0 and stacklevel or 0

			stacklevel = math.floor(stacklevel)

			if type(name) ~= "string" then name = "value" end

			if types == nil then
				return value
			end

			if IsNameSpace(types) then
				local vtype = _Validate_Type()

				vtype.AllowNil = nil
				vtype[1] = types
				vtype.Name = name

				types = vtype
			end

			local ok, _type = pcall(BuildType, types, name)

			if ok then
				if _type then
					ok, value = pcall(_type.Validate, _type, value)

					-- Recycle
					_Validate_Type(types)

					if not ok then
						value = strtrim(value:match(":%d+:%s*(.-)$") or value)

						if value:find("%%s") then
							value = value:gsub("%%s[_%w]*", name)
						end

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

		doc [======[
			@name EnableDocumentSystem
			@type method
			@desc Enable or disbale the document system, only effect later created document
			@param enabled true to enable the document system
			@return nil
			@usage System.Reflector.EnableDocumentSystem(true)
		]======]
		function EnableDocumentSystem(enabled)
			EnableDocument(enabled)
		end

		doc [======[
			@name IsDocumentSystemEnabled
			@type method
			@desc Whether the document system is enabled
			@return boolean
		]======]
		function IsDocumentSystemEnabled()
			return IsDocumentEnabled()
		end

		doc [======[
			@name GetDocument
			@type method
			@desc Get the document settings
			@format namespace, docType, name[, part]
			@param namespace
			@param doctype such as "property"
			@param name the query name
			@param part the part name
			@return Iterator the iterator to get detail
			@usage
				for part, value in System.Reflector.GetDocument(System.Object, "method", "GetClass")
			<br>	do print(part, value)
			<br>end
		]======]
		function GetDocument(ns, doctype, name, part)
			return GetDocumentPart(ns, doctype, name, part)
		end

		doc [======[
			@name HasDocument
			@type method
			@desc Check if has the document
			@param namespace
			@param doctype
			@param name
			@return true if the document is present
		]======]
		function HasDocument(ns, doctype, name)
			return HasDocumentPart(ns, doctype, name)
		end

		doc [======[
			@name Help
			@type method
			@desc Get the document detail
			@format class|interface[, event|property|method, name]
			@format class|interface, name
			@format enum|struct
			@param class|interface|enum|struct
			@param event|property|method
			@param name the name to query
			@return string the detail information
		]======]

		-- The cache for constructor parameters
		local function buildSubNamespace(ns)
			local result = ""

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
					result = result .. "\n\n Sub Enum :"

					for _, sns in ipairs(_Enums) do
						result = result .. "\n    " .. GetName(sns)
					end
				end

				if next(_Structs) then
					result = result .. "\n\n Sub Struct :"

					for _, sns in ipairs(_Structs) do
						result = result .. "\n    " .. GetName(sns)
					end
				end

				if next(_Interfaces) then
					result = result .. "\n\n Sub Interface :"

					for _, sns in ipairs(_Interfaces) do
						result = result .. "\n    " .. GetName(sns)
					end
				end

				if next(_Classes) then
					result = result .. "\n\n Sub Class :"

					for _, sns in ipairs(_Classes) do
						result = result .. "\n    " .. GetName(sns)
					end
				end

				if next(_Namespaces) then
					result = result .. "\n\n Sub NameSpace :"

					for _, sns in ipairs(_Namespaces) do
						result = result .. "\n    " .. GetName(sns)
					end
				end
			end

			CACHE_TABLE(_Enums)
			CACHE_TABLE(_Structs)
			CACHE_TABLE(_Classes)
			CACHE_TABLE(_Interfaces)
			CACHE_TABLE(_Namespaces)

			return result
		end

		function Help(ns, doctype, name)
			if type(ns) == "string" then ns = ForName(ns) end

			if ns and rawget(_NSInfo, ns) then
				local info = _NSInfo[ns]

				if info.Type == TYPE_ENUM then
					-- Enum
					local result = ""
					local value

					if info.IsFinal then
						result = result .. "[__Final__]\n"
					end

					if __Attribute__._IsDefined(ns, AttributeTargets.Enum, __Flags__) then
						result = result .. "[__Flags__]\n"
					end

					result = result .. "[Enum] " .. GetFullName(ns) .. " :"

					for _, enums in ipairs(GetEnums(ns)) do
						value = ns[enums]

						if type(value) == "string" then
							value = ("%q"):format(value)
						else
							value = tostring(value)
						end

						result = result .. "\n    " .. enums .. " = " .. value
					end
					return result
				elseif info.Type == TYPE_STRUCT then
					-- Struct
					local result = ""

					if info.IsFinal then
						result = result .. "[__Final__]\n"
					end

					if info.SubType == _STRUCT_TYPE_ARRAY then
						result = result .. "[__StructType__(StructType.Array)]\n"
					elseif info.SubType == _STRUCT_TYPE_CUSTOM then
						result = result .. "[__StructType__(StructType.Custom)]\n"
					end

					result = result .. "[Struct] " .. GetFullName(ns) .. " :"

					-- SubNameSpace
					result = result .. buildSubNamespace(ns)

					if info.SubType == _STRUCT_TYPE_MEMBER or info.SubType == _STRUCT_TYPE_CUSTOM then
						local parts = GetStructParts(ns)

						if parts and next(parts) then
							result = result .. "\n\n  Field:"

							for _, name in ipairs(parts) do
								result = result .. "\n    " .. name .. " = " .. tostring(info.StructEnv[name])
							end
						end
					elseif info.SubType == _STRUCT_TYPE_ARRAY then
						if info.ArrayElement then
							result = result .. "\n\n  Element :\n    " .. tostring(info.ArrayElement)
						end
					end

					return result
				elseif info.Type == TYPE_INTERFACE or info.Type == TYPE_CLASS then
					-- Interface & Class
					if type(doctype) ~= "string" then
						local result = ""
						local desc

						if info.IsFinal then
							result = result .. "[__Final__]\n"
						end

						if info.NonInheritable then
							result = result .. "[__NonInheritable__]\n"
						end

						if info.NonExpandable then
							result = result .. "[__NonExpandable__]\n"
						end

						if info.Type == TYPE_INTERFACE then
							result = result .. "[Interface] " .. GetFullName(ns) .. " :"

							if HasDocumentPart(ns, "interface", GetName(ns)) then
								desc = GetDocumentPart(ns, "interface", GetName(ns), "desc")
							elseif HasDocumentPart(ns, "default", GetName(ns)) then
								desc = GetDocumentPart(ns, "default", GetName(ns), "desc")
							end
						else
							if __Attribute__._IsDefined(ns, AttributeTargets.Class, __Cache__) then
								result = result .. "[__Cache__]\n"
							end

							if __Attribute__._IsDefined(ns, AttributeTargets.Class, __Unique__) then
								result = result .. "[__Unique__]\n"
							end

							if IsChildClass(__Attribute__, ns) then
								local usage = __Attribute__._GetClassAttribute(ns, __AttributeUsage__)

								if usage then
									result = result .. "[__AttributeUsage__{ "

									result = result .. "AttributeTarget = " .. Serialize(usage.AttributeTarget, AttributeTargets) .. ", "

									result = result .. "Inherited = " .. tostring(usage.Inherited and true or false) .. ", "

									result = result .. "AllowMultiple = " .. tostring(usage.AllowMultiple and true or false) .. ", "

									result = result .. "RunOnce = " .. tostring(usage.RunOnce and true or false)

									result = result .. " }]\n"
								end
							end

							result = result .. "[Class] " .. GetFullName(ns) .. " :"

							if HasDocumentPart(ns, "class", GetName(ns)) then
								desc = GetDocumentPart(ns, "class", GetName(ns), "desc")
							elseif HasDocumentPart(ns, "default", GetName(ns)) then
								desc = GetDocumentPart(ns, "default", GetName(ns), "desc")
							end
						end

						-- Desc
						desc = desc and desc()
						if desc then
							result = result .. "\n\n  Description :\n    " .. desc:gsub("<br>", "\n        "):gsub("  %s+", "\n        "):gsub("\t+", "\n        ")
						end

						-- Inherit
						if info.SuperClass then
							result = result .. "\n\n  Super Class :\n    " .. GetFullName(info.SuperClass)
						end

						-- Extend
						if info.ExtendInterface and next(info.ExtendInterface) then
							result = result .. "\n\n  Extend Interface :"
							for _, IF in ipairs(info.ExtendInterface) do
								result = result .. "\n    " .. GetFullName(IF)
							end
						end

						-- SubNameSpace
						result = result .. buildSubNamespace(ns)

						-- Event
						if next(info.Event) then
							result = result .. "\n\n  Event :"
							for _, evt in ipairs(GetEvents(ns, true)) do
								-- Desc
								desc = HasDocument(ns, "event", evt) and GetDocument(ns, "event", evt, "desc")
								desc = desc and desc()
								if desc then
									desc = " - " .. desc
								else
									desc = ""
								end

								result = result .. "\n    " .. evt .. desc
							end
						end

						-- Property
						if next(info.Property) then
							result = result .. "\n\n  Property :"
							for _, prop in ipairs(GetProperties(ns, true)) do
								-- Desc
								desc = HasDocument(ns, "property", prop) and GetDocument(ns, "property", prop, "desc")
								desc = desc and desc()
								if desc then
									desc = " - " .. desc
								else
									desc = ""
								end

								result = result .. "\n    " .. prop .. desc
							end
						end

						-- Method
						if next(info.Method) then
							result = result .. "\n\n  Method :"
							for _, method in ipairs(GetMethods(ns, true)) do
								-- Desc
								desc = HasDocument(ns, "method", method) and GetDocument(ns, "method", method, "desc")
								desc = desc and desc()
								if desc then
									desc = " - " .. desc
								else
									desc = ""
								end
								result = result .. "\n    " .. method .. desc
							end
						end

						-- Need
						if info.Type == TYPE_INTERFACE then
							desc = GetDocumentPart(ns, "interface", GetName(ns), "overridable")

							if desc then
								result = result .. "\n\n  Overridable :"

								for need, info in desc do
									if info and info:len() > 0 then
										result = result .. "\n    " .. need .. " - " .. info
									else
										result = result .. "\n    " .. need
									end
								end
							end
						end

						-- Constructor
						local isFormat = false

						if info.Type == TYPE_CLASS then
							-- __Arguments__
							local args = __Attribute__._GetConstructorAttribute(ns, __Arguments__)

							if args and #args > 0 then
								result = result .. "\n\n  Init table field :"

								for i = 1, #args do
									result = result .. "\n    " .. args[i].Name

									if args[i].Type then
										result = result .. " = " .. tostring(args[i].Type)
									end

									if args[i].Default then
										result = result .. " (Default : " .. Serialize(args[i].Default, args[i].Type) .. " )"
									end
								end
							end

							while ns do
								isFormat = true

								desc = nil

								if HasDocumentPart(ns, "class", GetName(ns)) then
									desc = GetDocumentPart(ns, "class", GetName(ns), "format")
									if not desc then
										desc = GetDocumentPart(ns, "class", GetName(ns), "param")
										isFormat = false
									end
								elseif HasDocumentPart(ns, "default", GetName(ns)) then
									desc = GetDocumentPart(ns, "default", GetName(ns), "desc")
									if not desc then
										desc = GetDocumentPart(ns, "default", GetName(ns), "param")
										isFormat = false
									end
								end

								if desc then
									-- Constructor
									result = result .. "\n\n  Constructor :"
									if isFormat then
										for fmt in desc do
											result = result .. "\n    " .. GetName(ns) .. "(" .. fmt .. ")"
										end
									else
										result = result .. "\n    " .. GetName(ns) .. "("

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
									desc = GetDocumentPart(ns, "class", GetName(ns), "param") or GetDocumentPart(ns, "default", GetName(ns), "param")
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
							result = "[Interface] " .. GetFullName(ns) .. " - "
						else
							result = "[Class] " .. GetFullName(ns) .. " - "
						end

						if type(name) ~= "string" then
							doctype, name = nil, doctype
						end

						querytype = doctype

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

						doctype = querytype or "default"

						if doctype:match("^%a") then
							result = result .. "[" .. doctype:match("^%a"):upper() .. doctype:sub(2, -1) .. "] " .. name .. " :"
						else
							result = result .. "[" .. doctype .. "] " .. name .. " :"
						end

						local hasDocument = HasDocumentPart(ns, doctype, name)

						-- Desc
						local desc = hasDocument and GetDocumentPart(ns, doctype, name, "desc")
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
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "format")
							if desc then
								result = result .. "\n\n  Format :"
								for fmt in desc do
									result = result .. "\n    " .. "function object:" .. name .. "(" .. fmt .. ")\n        -- Handle the event\n    end"
								end
							else
								result = result .. "\n\n  Format :\n    function object:" .. name .. "("

								desc = hasDocument and GetDocumentPart(ns, doctype, name, "param")

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
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "param")
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

							-- Format
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "format")
							result = result .. "\n\n  Format :"
							if desc then
								for fmt in desc do
									if isGlobal then
										result = result .. "\n    " .. GetName(ns) .. "." .. name .. "(" .. fmt .. ")"
									else
										result = result .. "\n    object:" .. name .. "(" .. fmt .. ")"
									end
								end
							else
								if isGlobal then
									result = result .. "\n    " .. GetName(ns) .. "." .. name .. "("
								else
									result = result .. "\n    object:" .. name .. "("
								end

								desc = hasDocument and GetDocumentPart(ns, doctype, name, "param")

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
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "param")
							if desc then
								result = result .. "\n\n  Parameter :"
								for param, info in desc do
									if info and info:len() > 0 then
										result = result .. "\n    " .. param .. " - " .. info
									else
										result = result .. "\n    " .. param
									end
								end
							else
								-- __Arguments__
								local args = __Attribute__._GetMethodAttribute(ns, name, __Arguments__)

								if args and #args > 0 then
									result = result .. "\n\n  Parameter :"

									for i = 1, #args do
										result = result .. "\n    " .. args[i].Name

										if args[i].Type then
											result = result .. " = " .. tostring(args[i].Type)
										end

										if args[i].Default then
											result = result .. " (Default : " .. Serialize(args[i].Default, args[i].Type) .. " )"
										end
									end
								end
							end

							-- ReturnFormat
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "returnformat")
							if desc then
								result = result .. "\n\n  Return Format :"
								for fmt in desc do
									result = result .. "\n    " .. fmt
								end
							end

							-- Returns
							desc = hasDocument and GetDocumentPart(ns, doctype, name, "return")
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
						desc = hasDocument and GetDocumentPart(ns, doctype, name, "usage")
						if desc then
							result = result .. "\n\n  Usage :"
							for usage in desc do
								result = result .. "\n    " .. usage:gsub("<br>", "\n    ")
							end
						end

						return result
					end
				else
					local result = "[NameSpace] " .. GetFullName(ns) .. " :"
					local desc

					if HasDocumentPart(ns, "namespace", GetName(ns)) then
						desc = GetDocumentPart(ns, "namespace", GetName(ns), "desc")
					elseif HasDocumentPart(ns, "default", GetName(ns)) then
						desc = GetDocumentPart(ns, "default", GetName(ns), "desc")
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

		doc [======[
			@name Serialize
			@type method
			@desc Serialize the data
			@format data[, type]
			@param data the data
			@param type the data's type
			@return string
		]======]
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

					if ns == false then
						return nil
					elseif ns == nil then
						return "nil"
					end
				elseif type(ns) == "string" then
					ns = ForName(ns)
				end
			end

			if ns and rawget(_NSInfo, ns) then
				if Reflector.IsEnum(ns) then
					if __Attribute__._IsDefined(ns, AttributeTargets.Enum, __Flags__) and type(data) == "number" then
						local ret = {Reflector.ParseEnum(ns, data)}

						local result = ""

						for i, str in ipairs(ret) do
							if i > 1 then
								result = result .. " + "
							end
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

		doc [======[
			@name ThreadCall
			@type method
			@desc Call the function in a thread from the thread pool of the system
			@param func the function
			@param ... the parameters
			@return any
		]======]
		function ThreadCall(func, ...)
			return CallThread(func, ...)
		end

		doc [======[
			@name IsEqual
			@type method
			@desc Whether the two objects are objects with same settings
			@param obj1 object, the object used to compare
			@param obj2 object, the object used to compare to
			@return boolean
		]======]
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
			local info = cls and rawget(_NSInfo, cls)

			if info then
				if cls ~= getmetatable(obj2) then return false end

				-- Check properties
				for name, prop in pairs(info.Cache4Property) do
					if prop.Get or prop.GetMethod or prop.Field then
						if not checkEqual(obj1[name], obj2[name], cache) then
							return false
						end
					end
				end
			end

			-- Check fields
			for k, v in pairs(obj1) do
				if not checkEqual(v, rawget(obj2, k), cache) then
					return false
				end
			end

			for k, v in pairs(obj2) do
				if rawget(obj1, k) == nil then
					return false
				end
			end

			return true
		end

		function IsEqual(obj1, obj2)
			local cache = CACHE_TABLE()

			local result = checkEqual(obj1, obj2, cache)

			CACHE_TABLE(cache)

			return result
		end
	endinterface "Reflector"

	------------------------------------------------------
	-- System.Event & EventHandler
	------------------------------------------------------
	class "Event"
		doc [======[
			@name Event
			@type class
			@desc The object event definition
		]======]

		doc [======[
			@name Name
			@type property
			@desc The event's name
		]======]
		property "Name" { Type = String }

		doc [======[
			@name ThreadActivated
			@type property
			@desc Whether the event is thread activated
		]======]
		property "ThreadActivated" { Type = Boolean }

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function Event(self, name)
			self.Name = type(name) == "string" and name or "anonymous"
		end

		------------------------------------------------------
		-- Meta-Method
		------------------------------------------------------
		function __tostring(self)
			return ("%s( %q )"):format(tostring(Event), self.__Name)
		end
	endclass "Event"

	class "EventHandler"
		doc [======[
			@name EventHandler
			@type class
			@desc The object event handler
		]======]

		local function FireOnEventHandlerChanged(self)
			return Reflector.FireObjectEvent(self.Owner, "OnEventHandlerChanged", self.Event.Name)
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc [======[
			@name IsEmpty
			@type method
			@desc Check if the event handler is empty
			@return boolean true if the event handler has no functions
		]======]
		function IsEmpty(self)
			return #self == 0 and self[0] == nil
		end

		doc [======[
			@name Clear
			@type method
			@desc Clear all handlers
			@return nil
		]======]
		function Clear(self)
			local flag = false

			for i = #self, 0, -1 do
				flag = true
				self[i] = nil
			end

			if flag then
				return FireOnEventHandlerChanged(self)
			end
		end

		doc [======[
			@name Copy
			@type method
			@desc Copy handlers from the source event handler
			@param src the event handler source
			@return nil
		]======]
		function Copy(self, src)
			local flag = false

			if Reflector.ObjectIsClass(src, EventHandler) and self.Event == src.Event and self ~= src then
				for i = #self, 0, -1 do
					flag = true
					self[i] = nil
				end

				for i = #src, 0, -1 do
					flag = true
					self[i] = src[i]
				end
			end

			if flag then
				return FireOnEventHandlerChanged(self)
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc [======[
			@name Owner
			@type property
			@desc The owner of the event handler
		]======]
		property "Owner" { Type = Table }

		doc [======[
			@name Event
			@type property
			@desc The event type of the handler
		]======]
		property "Event" { Type = Event }

		doc [======[
			@name Blocked
			@type property
			@desc Whether the event handler is blocked
		]======]
		property "Blocked" { Type = Boolean }

		doc [======[
			@name ThreadActivated
			@type property
			@desc Whether the event handler is thread activated
		]======]
		property "ThreadActivated" { Type = Boolean }

		doc [======[
			@name Handler
			@type property
			@desc description
		]======]
		property "Handler" {
			Get = function(self)
				return self[0]
			end,
			Set = function(self, value)
				if self[0] ~= value then
					self[0] = value
					return FireOnEventHandlerChanged(self)
				end
			end,
			Type = Function + nil,
		}

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
	    function EventHandler(self, evt, owner)
	    	if not Reflector.ObjectIsClass(evt, Event) then
	    		error("Usage : EventHandler(event, owner) - 'event' must be an object of 'System.Event'.")
	    	end

	    	if not Reflector.GetObjectClass(owner) then
	    		error("Usage : EventHandler(event, owner) - 'owner' must be an object.")
	    	end

	    	self.Event = evt
	    	self.Owner = owner

	    	-- Active the thread status based on the attribute setting
	    	if evt.ThreadActivated then
	    		self.ThreadActivated = true
	    	end
	    end

		------------------------------------------------------
		-- Meta-Method
		------------------------------------------------------
		function __add(self, func)
			if type(func) ~= "function" then
				error("Usage: obj.OnXXXX = obj.OnXXXX + func", 2)
			end

			for _, f in ipairs(self) do
				if f == func then
					return self
				end
			end

			tinsert(self, func)

			FireOnEventHandlerChanged(self)

			return self
		end

		function __sub(self, func)
			if type(func) ~= "function" then
				error("Usage: obj.OnXXXX = obj.OnXXXX - func", 2)
			end

			for i, f in ipairs(self) do
				if f == func then
					tremove(self, i)
					FireOnEventHandlerChanged(self)
					break
				end
			end

			return self
		end

		local create = create
		local resume = resume
		local status = status
		local rawget = rawget
		local pcall = pcall
		local ipairs = ipairs
		local errorhandler = errorhandler
		local CallThread = CallThread

		function __call(self, obj, ...)
			-- The event call is so frequent
			-- keep local for optimization
			if self.Blocked then return end

			local owner = self.Owner
			local asParam, useThread, ret

			asParam = (obj ~= owner)
			useThread = self.ThreadActivated

			-- Call the stacked handlers
			for _, handler in ipairs(self) do
				-- Call the handler
				if useThread then
					if asParam then
						ret = CallThread(handler, owner, obj, ...)
					else
						ret = CallThread(handler, obj, ...)
					end
				else
					if asParam then
						ret = handler(owner, obj, ...)
					else
						ret = handler(obj, ...)
					end
				end

				if rawget(owner, "Disposed") then
					-- means it's disposed
					ret = true
				end

				-- Any handler return true means to stop all
				if ret then break end
			end

			-- Call the final handler
			if not ret and self[0] then
				local handler = self[0]

				if useThread then
					if asParam then
						CallThread(handler, owner, obj, ...)
					else
						CallThread(handler, obj, ...)
					end
				else
					if asParam then
						handler(owner, obj, ...)
					else
						handler(obj, ...)
					end
				end
			end
		end

		function __tostring(self)
			return tostring(EventHandler) .. "( " .. tostring(self.Event) .. " )"
		end
	endclass "EventHandler"

	------------------------------------------------------
	-- System.__Attribute__
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
	}

	class "__Attribute__"

		doc [======[
			@name __Attribute__
			@type class
			@desc The __Attribute__ class associates predefined system information or user-defined custom information with a target element.
		]======]

		_PreparedAttributes = {}
		_ThreadPreparedAttributes = _ThreadPreparedAttributes or setmetatable({}, WEAK_KEY)

		-- Since the targets are stable, so a big table is a good storage
		_Attribute4Class = _Attribute4Class or setmetatable({}, WEAK_KEY)
		_Attribute4Constructor = _Attribute4Constructor or setmetatable({}, WEAK_KEY)
		_Attribute4Enum = _Attribute4Enum or setmetatable({}, WEAK_KEY)
		_Attribute4Event = _Attribute4Event or setmetatable({}, WEAK_KEY)
		_Attribute4Interface = _Attribute4Interface or setmetatable({}, WEAK_KEY)
		_Attribute4Method = _Attribute4Method or setmetatable({}, WEAK_KEY)
		_Attribute4Property = _Attribute4Property or setmetatable({}, WEAK_KEY)
		_Attribute4Struct = _Attribute4Struct or setmetatable({}, WEAK_KEY)
		_Attribute4Field = _Attribute4Field or setmetatable({}, WEAK_KEY)

		_AttributeCache = {
			[AttributeTargets.Class] = _Attribute4Class,
			[AttributeTargets.Constructor] = _Attribute4Constructor,
			[AttributeTargets.Enum] = _Attribute4Enum,
			[AttributeTargets.Event] = _Attribute4Event,
			[AttributeTargets.Interface] = _Attribute4Interface,
			[AttributeTargets.Method] = _Attribute4Method,
			[AttributeTargets.Property] = _Attribute4Property,
			[AttributeTargets.Struct] = _Attribute4Struct,
			[AttributeTargets.Field] = _Attribute4Field,
		}

		TYPE_CLASS = TYPE_CLASS
		TYPE_INTERFACE = TYPE_INTERFACE

		-- Recycle the cache for dispose attributes
		_AttributeCache4Dispose = setmetatable({}, {
			__call = function(self, key)
				if key then
					if type(key) == "table" and self[key] then
						for attr in pairs(key) do
							key[attr] = nil
							if not rawget(attr, "Disposed") then
								attr:Dispose()
							end
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

			for i, v in ipairs(prepared) do
				if v == self then
					return
				end
			end

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
				return type(target) == "function"
			elseif targetType == AttributeTargets.Property then
				-- Normally, this only be called by the system
				return type(target) == "table" and type(target.Name) == "string"
			elseif targetType == AttributeTargets.Struct then
				return Reflector.IsStruct(target)
			elseif targetType == AttributeTargets.Field then
				return Reflector.ObjectIsClass(target, Type)
			end
		end

		local function ValidateUsable(config, attr, skipMulti)
			if getmetatable(config) then
				if Reflector.IsEqual(config, attr) then
					return false
				end

				if not skipMulti and getmetatable(config) == getmetatable(attr) then
					local usage = _GetCustomAttribute(getmetatable(config), AttributeTargets.Class, __AttributeUsage__)

					if not usage or not usage.AllowMultiple then
						return false
					end
				end
			else
				for _, v in ipairs(config) do
					if not ValidateUsable(v, attr, skipMulti) then
						return false
					end
				end
			end

			return true
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		--[======[
			@name _ApplyAttributes
			@type method
			@desc Apply the attributes for the target
			@format target, targetType[, superTarget, owner, name]
			@param target class | event | method | property | struct | interface | enum | field
			@param targetType System.AttributeTargets
			@param superTarget the super target the contains several attributes to be inherited
			@param owner the class|interface|struct object, the owner of the target
			@param name the target's name
			@return target
		]======]
		local function _ApplyAttributes(target, targetType, owner, name, start)
			-- Apply the attributes
			local config = _AttributeCache[targetType][target]
			local usage

			if config then
				local ok, ret, arg1, arg2, arg3, arg4

				-- Some target can't be send to the attribute's ApplyAttribute directly
				if targetType == AttributeTargets.Event then
					arg1 = target.Name
					arg2 = targetType
					arg3 = owner
				elseif targetType == AttributeTargets.Method then
					arg1 = target
					arg2 = targetType
					arg3 = owner
					arg4 = name
				elseif targetType == AttributeTargets.Property then
					arg1 = target.Name
					arg2 = targetType
					arg3 = owner
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
						usage = _GetCustomAttribute(getmetatable(config), AttributeTargets.Class, __AttributeUsage__)

						if usage and not usage.Inherited and usage.RunOnce then
							_AttributeCache[targetType][target] = nil

							config:Dispose()
						end

						if targetType == AttributeTargets.Method then
							-- The method may be wrapped in the apply operation
							if ret then
								target = ret
							end
						end
					end
				else
					start = start or 1

					for i = #config, start, -1 do
						ok, ret = pcall(config[i].ApplyAttribute, config[i], arg1, arg2, arg3, arg4)

						if not ok then
							errorhandler(ret)

							tremove(config, i)
						else
							usage = _GetCustomAttribute(getmetatable(config[i]), AttributeTargets.Class, __AttributeUsage__)

							if usage and not usage.Inherited and usage.RunOnce then
								config[i]:Dispose()
								tremove(config, i)
							end

							if targetType == AttributeTargets.Method then
								if ret then
									target = ret
									arg1 = ret
								end
							end
						end
					end

					if #config == 0 then
						_AttributeCache[targetType][target] = nil
					elseif #config == 1 then
						_AttributeCache[targetType][target] = config[1]
					end
				end
			end

			return target
		end

		doc [======[
			@name _ClearPreparedAttributes
			@type method
			@desc Clear the prepared attributes
			@return nil
		]======]
		function _ClearPreparedAttributes(noDispose)
			local thread = running()

			if thread then
				if _ThreadPreparedAttributes[thread] then
					if not noDispose then
						for _, attr in ipairs(_ThreadPreparedAttributes[thread]) do
							attr:Dispose()
						end
					end
					wipe(_ThreadPreparedAttributes[thread])
				end
			else
				if not noDispose then
					for _, attr in ipairs(_PreparedAttributes) do
						attr:Dispose()
					end
				end
				wipe(_PreparedAttributes)
			end
		end

		doc [======[
			@name _ConsumePreparedAttributes
			@type method
			@desc Set the prepared attributes for target
			@format target, targetType[, superTarget[, owner, name]]
			@param target class | event | method | property | struct | interface | enum
			@param targetType System.AttributeTargets
			@param superTarget the super target the contains several attributes to be inherited
			@param owner the class|interface object, the owner of the target
			@param name the target's name
			@return target
		]======]
		function _ConsumePreparedAttributes(target, targetType, superTarget, owner, name)
			if not _AttributeCache[targetType] then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'targetType' is invalid.", 2)
			elseif not ValidateTargetType(target, targetType) then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'target' is invalid.", 2)
			elseif superTarget and not ValidateTargetType(superTarget, targetType) then
				error("Usage : __Attribute__._ConsumePreparedAttributes(target, targetType[, superTarget[, owner, name]]) - 'superTarget' is invalid.", 2)
			end

			-- Consume the prepared Attributes
			local prepared
			local thread = running()

			if thread then
				prepared = _ThreadPreparedAttributes[thread]
			else
				prepared = _PreparedAttributes
			end

			-- Filter with the usage
			if prepared and #prepared > 0 then
				local cls, usage
				local noUseAttr = _AttributeCache4Dispose()
				local usableAttr = _AttributeCache4Dispose()

				for i = 1, #prepared do
					cls = getmetatable(prepared[i])
					usage = _GetCustomAttribute(cls, AttributeTargets.Class, __AttributeUsage__)

					if usage and usage.AttributeTarget > 0 and not Reflector.ValidateFlags(targetType, usage.AttributeTarget) then
						errorhandler("Can't apply the " .. tostring(cls) .. " attribute to the " .. ParseTarget(target, targetType, owner, name))
					elseif ValidateUsable(usableAttr, prepared[i]) then
						usableAttr[prepared[i]] = true
						tinsert(usableAttr, prepared[i])
					else
						errorhandler("Can't apply the " .. tostring(cls) .. " attribute for multi-times.")
					end
				end

				for i = #prepared, 1, -1 do
					if not usableAttr[prepared[i]] then
						noUseAttr[prepared[i]] = true
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
							if not ValidateUsable(prepared, config) then
								_AttributeCache[targetType][target] = nil
							end
						else
							for i = #config, 1, -1 do
								if not ValidateUsable(prepared, config[i]) then
									tremove(config, i)
								end
							end

							if #config == 0 then
								_AttributeCache[targetType][target] = nil
							end
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

							if ValidateUsable(prepared, config) then
								tinsert(prepared, config)
							end
						end
					else
						for _, attr in ipairs(config) do
							usage = _GetCustomAttribute(getmetatable(attr), AttributeTargets.Class, __AttributeUsage__)

							if not usage or usage.Inherited then
								prepared = prepared or {}

								if ValidateUsable(prepared, attr) then
									tinsert(prepared, attr)
								end
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

					if getmetatable(config) then
						config = { config }
					end

					start = #config + 1

					for _, attr in ipairs(prepared) do
						tinsert(config, attr)
					end

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

		doc [======[
			@name _CloneAttributes
			@type method
			@desc Clone the attributes
			@param source the source
			@param target the target
			@param targetType System.AttributeTargets
			@param owner the class|interface object, the owner of the target
			@param name the target's name
			@return target
		]======]
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
							if removeSource then
								_AttributeCache[targetType][source] = nil
							end

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

						for i = 1, #config do
							if ValidateUsable(attrs, config[i]) then
								tinsert(usableAttr, config[i])
							end
						end

						if #usableAttr == 0 then
							if removeSource then
								_AttributeCache[targetType][source] = nil
							end

							_AttributeCache4Dispose(usableAttr)

							return target
						end

						if getmetatable(attrs) then
							attrs = { attrs }
							_AttributeCache[targetType][target] = attrs
						end

						start = #attrs + 1

						for i = 1, #usableAttr do
							tinsert(attrs, usableAttr[i])
						end

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

				if removeSource then
					_AttributeCache[targetType][source] = nil
				end
			end

			return target
		end

		doc [======[
			@name _IsDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class | event | method | property | struct | interface | enum
			@param targetType System.AttributeTargets
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsDefined(target, targetType, type)
			local config = _AttributeCache[targetType][target]

			if not config then
				return false
			elseif getmetatable(config) then
				return getmetatable(config) == type
			else
				for _, attr in ipairs(config) do
					if getmetatable(attr) == type then
						return true
					end
				end
				return false
			end
		end

		doc [======[
			@name _IsClassAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsClassAttributeDefined(target, type)
			if Reflector.IsClass(target) then
				return _IsDefined(target, AttributeTargets.Class, type)
			end
		end

		doc [======[
			@name _IsConstructorAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsConstructorAttributeDefined(target, type)
			if Reflector.IsClass(target) then
				return _IsDefined(target, AttributeTargets.Constructor, type)
			end
		end

		doc [======[
			@name _IsEnumAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target enum
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsEnumAttributeDefined(target, type)
			if Reflector.IsEnum(target) then
				return _IsDefined(target, AttributeTargets.Enum, type)
			end
		end

		doc [======[
			@name _IsEventAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class | interface
			@param event the event's name
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsEventAttributeDefined(target, event, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Event[event] then
				return _IsDefined(info.Cache4Event[event], AttributeTargets.Event, type)
			end
		end

		doc [======[
			@name _IsInterfaceAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target interface
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsInterfaceAttributeDefined(target, type)
			if Reflector.IsInterface(target) then
				return _IsDefined(target, AttributeTargets.Interface, type)
			end
		end

		doc [======[
			@name _IsMethodAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class | interface
			@param method the method's name
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsMethodAttributeDefined(target, method, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Method[method] then
				return _IsDefined(info.Cache4Method[method], AttributeTargets.Method, type)
			elseif type(target) == "function" then
				return _IsDefined(target, AttributeTargets.Method, method)
			end
		end

		doc [======[
			@name _IsPropertyAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target class | interface
			@param property the property's name
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsPropertyAttributeDefined(target, prop, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[prop] then
				return _IsDefined(info.Cache4Property[prop], AttributeTargets.Property, type)
			end
		end

		doc [======[
			@name _IsStructAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target struct
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsStructAttributeDefined(target, type)
			if Reflector.IsStruct(target) then
				return _IsDefined(target, AttributeTargets.Struct, type)
			end
		end

		doc [======[
			@name _IsFieldAttributeDefined
			@type method
			@desc Check whether the target contains such type attribute
			@param target struct
			@param field the field's name
			@param type the attribute class type
			@return boolean true if the target contains attribute with the type
		]======]
		function _IsFieldAttributeDefined(target, field, type)
			local info = rawget(_NSInfo, target)

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					for _, part in ipairs(info.Members) do
						if part == field then
							return _IsDefined(info.StructEnv[field], AttributeTargets.Field, type)
						end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return _IsDefined(info.ArrayElement, AttributeTargets.Field, type)
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					return _IsDefined(info.StructEnv[field], AttributeTargets.Field, type)
				end
			end

			return false
		end

		doc [======[
			@name _GetCustomAttribute
			@type method
			@desc Return the attributes of the given type for the target
			@param target class | event | method | property | struct | interface | enum
			@param targetType System.AttributeTargets
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetCustomAttribute(target, targetType, type)
			local config = _AttributeCache[targetType][target]

			if not config then
				return
			elseif getmetatable(config) then
				return getmetatable(config) == type and config or nil
			else
				local cache = _AttributeCache4Dispose()

				for _, attr in ipairs(config) do
					if getmetatable(attr) == type then
						tinsert(cache, attr)
					end
				end

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

		doc [======[
			@name _GetClassAttribute
			@type method
			@desc Return the attributes of the given type for the class
			@param target class
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetClassAttribute(target, type)
			if Reflector.IsClass(target) then
				return _GetCustomAttribute(target, AttributeTargets.Class, type)
			end
		end

		doc [======[
			@name _GetConstructorAttribute
			@type method
			@desc Return the attributes of the given type for the class's constructor
			@param target class
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetConstructorAttribute(target, type)
			if Reflector.IsClass(target) then
				return _GetCustomAttribute(target, AttributeTargets.Constructor, type)
			end
		end

		doc [======[
			@name _GetEnumAttribute
			@type method
			@desc Return the attributes of the given type for the enum
			@param target enum
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetEnumAttribute(target, type)
			if Reflector.IsEnum(target) then
				return _GetCustomAttribute(target, AttributeTargets.Enum, type)
			end
		end

		doc [======[
			@name _GetEventAttribute
			@type method
			@desc Return the attributes of the given type for the class|interface's event
			@param target class|interface
			@param event the event's name
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetEventAttribute(target, event, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Event[event] then
				return _GetCustomAttribute(info.Cache4Event[event], AttributeTargets.Event, type)
			end
		end

		doc [======[
			@name _GetInterfaceAttribute
			@type method
			@desc Return the attributes of the given type for the interface
			@param target interface
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetInterfaceAttribute(target, type)
			if Reflector.IsInterface(target) then
				return _GetCustomAttribute(target, AttributeTargets.Interface, type)
			end
		end

		doc [======[
			@name _GetMethodAttribute
			@type method
			@desc Return the attributes of the given type for the class|interface's method
			@format target, method, type
			@format method, type
			@param target class|interface
			@param method the method's name(with target) or the method itself(without target)
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetMethodAttribute(target, method, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Method[method] then
				return _GetCustomAttribute(info.Cache4Method[method], AttributeTargets.Method, type)
			elseif type(target) == "function" then
				return _GetCustomAttribute(target, AttributeTargets.Method, method)
			end
		end

		doc [======[
			@name _GetPropertyAttribute
			@type method
			@desc Return the attributes of the given type for the class|interface's property
			@param target class|interface
			@param prop the property's name
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetPropertyAttribute(target, prop, type)
			local info = rawget(_NSInfo, target)

			if info and (info.Type == TYPE_CLASS or info.Type == TYPE_INTERFACE) and info.Cache4Property[prop] then
				return _GetCustomAttribute(info.Cache4Property[prop], AttributeTargets.Property, type)
			end
		end

		doc [======[
			@name _GetStructAttribute
			@type method
			@desc Return the attributes of the given type for the struct
			@param target struct
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetStructAttribute(target, type)
			if Reflector.IsStruct(target) then
				return _GetCustomAttribute(target, AttributeTargets.Struct, type)
			end
		end

		doc [======[
			@name _GetFieldAttribute
			@type method
			@desc Return the attributes of the given type for the struct's field
			@param target struct
			@param field the field's name
			@param type the attribute class type
			@return ... the attribute objects
		]======]
		function _GetFieldAttribute(target, field, type)
			local info = rawget(_NSInfo, target)

			if info and info.Type == TYPE_STRUCT then
				if info.SubType == _STRUCT_TYPE_MEMBER and info.Members and #info.Members > 0 then
					for _, part in ipairs(info.Members) do
						if part == field then
							return _GetCustomAttribute(info.StructEnv[field], AttributeTargets.Field, type)
						end
					end
				elseif info.SubType == _STRUCT_TYPE_ARRAY and info.ArrayElement then
					return _GetCustomAttribute(info.ArrayElement, AttributeTargets.Field, type)
				elseif info.SubType == _STRUCT_TYPE_CUSTOM then
					return _GetCustomAttribute(info.StructEnv[field], AttributeTargets.Field, type)
				end
			end
		end

		doc [======[
			@name ApplyAttribute
			@type method
			@desc Apply the attribute to the target, overridable
			@param target the attribute's target
			@param targetType System.AttributeTargets
			@return nil
		]======]
		function ApplyAttribute(self, target, targetType)
			-- Pass
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Attribute__(self)
			SendToPrepared(self)
		end

		function __call(self)
			SendToPrepared(self)
		end
	endclass "__Attribute__"

	class "__Unique__"
		inherit "__Attribute__"

		local _UniqueObj

		doc [======[
			@name __Unique__
			@type class
			@desc Mark the class will only create one unique object, and can't be disposed, also the class can't be inherited
		]======]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsClass(target) then
				_NSInfo[target].NonInheritable = true
			end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Unique__(self)
			_UniqueObj = self
		end

		function __exist()
			if _UniqueObj then
				_UniqueObj()
			end

			return _UniqueObj
		end
	endclass "__Unique__"

	class "__Flags__"
		inherit "__Attribute__"

		local _UniqueObj

		doc [======[
			@name __Flags__
			@type class
			@desc Indicates that an enumeration can be treated as a bit field; that is, a set of flags.
		]======]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsEnum(target) then
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
						if enums[k] == 0 then
							enums[k] = -1
						end
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

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Flags__(self)
			_UniqueObj = self
		end

		function __exist()
			if _UniqueObj then
				_UniqueObj()
			end
			return _UniqueObj
		end
	endclass "__Flags__"

	class "__AttributeUsage__"
		inherit "__Attribute__"

		doc [======[
			@name __AttributeUsage__
			@type class
			@desc Specifies the usage of another attribute class.
		]======]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc [======[
			@name AttributeTarget
			@type property
			@desc The attribute target type, default AttributeTargets.All
		]======]
		property "AttributeTarget" { Default = AttributeTargets.All, Type = AttributeTargets }

		doc [======[
			@name Inherited
			@type property
			@desc Whether your attribute can be inherited by classes that are derived from the classes to which your attribute is applied. Default true
		]======]
		property "Inherited" { Default = true, Type = Boolean }

		doc [======[
			@name AllowMultiple
			@type property
			@desc whether multiple instances of your attribute can exist on an element. default false
		]======]
		property "AllowMultiple" { Type = Boolean }

		doc [======[
			@name RunOnce
			@type property
			@desc Whether the property only apply once, when the Inherited is false, and the RunOnce is true, the attribute will be removed after apply operation
		]======]
		property "RunOnce" { Type = Boolean }
	endclass "__AttributeUsage__"

	class "__Final__"
		inherit "__Attribute__"

		local _UniqueObj

		doc [======[
			@name __Final__
			@type class
			@desc Mark the class|interface|struct|enum to be final, and can't be re-defined again
		]======]

		function ApplyAttribute(self, target, targetType)
			if rawget(_NSInfo, target) then
				_NSInfo[target].IsFinal = true
			end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __Final__(self)
			_UniqueObj = self
		end

		function __exist()
			if _UniqueObj then
				_UniqueObj()
			end
			return _UniqueObj
		end
	endclass "__Final__"

	class "__NonInheritable__"
		inherit "__Attribute__"

		local _UniqueObj

		doc [======[
			@name __NonInheritable__
			@type class
			@desc Mark the class can't be inherited
		]======]

		function ApplyAttribute(self, target, targetType)
			if Reflector.IsClass(target) or Reflector.IsInterface(target) then
				_NSInfo[target].NonInheritable = true
			end
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function __NonInheritable__(self)
			_UniqueObj = self
		end

		function __exist()
			if _UniqueObj then
				_UniqueObj()
			end
			return _UniqueObj
		end
	endclass "__NonInheritable__"

	-- Apply Attribute to the previous definitions, since I can't use them before definition
	do
		------------------------------------------------------
		-- For Attribute system
		------------------------------------------------------
		local objFinal = __Final__()
		local objNonInheritable = __NonInheritable__()
		__Attribute__._ClearPreparedAttributes()

		------------------------------------------------------
		-- For structs
		------------------------------------------------------
		_KeyWord4StrtEnv.structtype = nil

		objFinal:ApplyAttribute(Boolean, AttributeTargets.Struct)
		objFinal:ApplyAttribute(String, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Number, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Function, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Table, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Userdata, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Thread, AttributeTargets.Struct)
		objFinal:ApplyAttribute(Any, AttributeTargets.Struct)

		-- System.AttributeTargets
		__Flags__()
		__Attribute__._ConsumePreparedAttributes(AttributeTargets, AttributeTargets.Enum)
		objFinal:ApplyAttribute(AttributeTargets, AttributeTargets.Enum)

		-- System.__Attribute__
		__AttributeUsage__{AttributeTarget = AttributeTargets.All}
		__Attribute__._ConsumePreparedAttributes(__Attribute__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__Attribute__, AttributeTargets.Class)

		-- System.__Unique__
		__Unique__()
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false}
		__Attribute__._ConsumePreparedAttributes(__Unique__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__Unique__, AttributeTargets.Class)

		-- System.__Flags__
		__Unique__()
		__AttributeUsage__{AttributeTarget = AttributeTargets.Enum, Inherited = false}
		__Attribute__._ConsumePreparedAttributes(__Flags__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__Flags__, AttributeTargets.Class)

		-- System.__AttributeUsage__
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class, Inherited = false}
		__Attribute__._ConsumePreparedAttributes(__AttributeUsage__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__AttributeUsage__, AttributeTargets.Class)
		objNonInheritable:ApplyAttribute(__AttributeUsage__, AttributeTargets.Class)

		-- System.__Final__
		__Unique__()
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class + AttributeTargets.Interface + AttributeTargets.Struct + AttributeTargets.Enum, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__Final__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__Final__, AttributeTargets.Class)

		-- System.__NonInheritable__
		__Unique__()
		__AttributeUsage__{AttributeTarget = AttributeTargets.Class + AttributeTargets.Interface, Inherited = false, RunOnce = true}
		__Attribute__._ConsumePreparedAttributes(__NonInheritable__, AttributeTargets.Class)
		objFinal:ApplyAttribute(__NonInheritable__, AttributeTargets.Class)

		------------------------------------------------------
		-- For other classes
		------------------------------------------------------
		-- System.Type
		__Final__()
		__NonInheritable__()
		__Attribute__._ConsumePreparedAttributes(Type, AttributeTargets.Class)

		-- System.Reflector
		__Final__()
		__NonInheritable__()
		__Attribute__._ConsumePreparedAttributes(Reflector, AttributeTargets.Interface)

		-- System.Event
		__Final__()
		__NonInheritable__()
		__Attribute__._ConsumePreparedAttributes(Event, AttributeTargets.Class)

		-- System.EventHandler
		__Final__()
		__NonInheritable__()
		__Attribute__._ConsumePreparedAttributes(EventHandler, AttributeTargets.Class)
	end

	-- More usable attributes
	__AttributeUsage__{AttributeTarget = AttributeTargets.Event + AttributeTargets.Method, RunOnce = true}
	__Final__()
	__Unique__()
	class "__Thread__"
		inherit "__Attribute__"
		doc [======[
			@name __Thread__
			@type class
			@desc Whether the event is thread activated by defalut, or wrap the method as coroutine
		]======]

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			local CallThread = CallThread

			if targetType == AttributeTargets.Method then
				if type(target) == "function" then
					-- Wrap the target method
					return function (...)
						return CallThread(target, ...)
					end
				elseif Reflector.ObjectIsClass(target, __Arguments__.FixedMethod) then
					local func = target.Method

					target.Method = function (...)
						return CallThread(func, ...)
					end
				end
			elseif targetType == AttributeTargets.Event then
				_NSInfo[owner].Event[target].ThreadActivated = true
			end
		end
	endclass "__Thread__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Class}
	__Final__()
	__Unique__()
	class "__Cache__"
		inherit "__Attribute__"
		doc [======[
			@name __Cache__
			@type class
			@desc Mark the class so its objects will cache any methods they accessed, mark the method so the objects will cache the method when they are created, if using on an interface, all object methods defined in it would be marked with __Cache__ attribute .
		]======]
	endclass "__Cache__"

	__Final__()
	struct "Argument"
		Name = String + nil
		Type = Any + nil
		Default = Any + nil
		IsList = Boolean + nil

		function Validate(value)
			value.Type = value.Type and BuildType(value.Type, "Type") or nil

			if value.Type and value.Default ~= nil then
				if value.Type:GetObjectType(value.Default) == false then
					value.Default = nil
				end
			end

			return value
		end
	endstruct "Argument"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Method + AttributeTargets.Constructor, RunOnce = true }
	__Final__()
	__Unique__()
	class "__Arguments__"
		inherit "__Attribute__"

		doc [======[
			@name __Arguments__
			@type class
			@desc The argument definitions of the target method or class's constructor
		]======]

		class "FixedMethod"
			doc [======[
				@name FixedMethod
				@type class
				@desc Used to control method with fixed arguments
			]======]

			-- Reduce cache table cost
			local function keepArgs(...)
				local flag = yield( running() )

				while flag do
					flag = yield( ... )
				end

				return ...
			end

			------------------------------------------------------
			-- Event
			------------------------------------------------------

			------------------------------------------------------
			-- Method
			------------------------------------------------------
			doc [======[
				@name MatchArgs
				@type method
				@desc Whether the fixed method can handler the arguments
				@param ...
				@return boolean
			]======]
			function MatchArgs(self, ...)
				local base = self.HasSelf and 1 or 0
				local count = select('#', ...) - base
				local argsCount = #self

				-- Empty methods won't accept any arguments
				if argsCount == 0 then
					if count > 0 then
						return false
					else
						return true
					end
				end

				-- Check argument settings
				if count >= self.MinArgs and count <= self.MaxArgs then
					local cache = CACHE_TABLE()

					-- Cache first
					for i = 1, count do
						cache[i] = select(i + base, ...)
					end

					-- required
					for i = 1, self.MinArgs do
						local arg = self[i]
						local value = cache[i]
						local ok

						if value == nil then
							-- No check
							if arg.Default ~= nil then
								value = arg.Default
							else
								CACHE_TABLE(cache)

								return false
							end
						elseif arg.Type then
							-- Validate the value
							ok, value = pcall(arg.Type.Validate, arg.Type, value)

							if not ok then
								CACHE_TABLE(cache)

								return false
							end
						end

						cache[i] = value
					end

					-- optional
					for i = self.MinArgs + 1, count do
						local arg = self[i] or self[argsCount]
						local value = cache[i]
						local ok

						if value == nil then
							-- No check
							if arg.Default ~= nil then
								value = arg.Default
							end
						elseif arg.Type then
							-- Validate the value
							ok, value = pcall(arg.Type.Validate, arg.Type, value)

							if not ok then
								CACHE_TABLE(cache)

								return false
							end
						end

						cache[i] = value
					end

					-- Keep arguments in thread, so cache can be recycled
					self.Thread = CallThread(keepArgs, unpack(cache, 1, count))

					CACHE_TABLE(cache)

					return true
				end

				return false
			end

			doc [======[
				@name MatchInitTable
				@type method
				@desc Whether the fixed method can handler the init table
				@param init
				@return boolean
			]======]
			function MatchInitTable(self, init)

			end

			doc [======[
				@name GetUsage
				@type method
				@desc Get the usage of the fixed method
				@return string
			]======]
			function GetUsage(self)
				if self.__Usage then return self.__Usage end

				-- Generate usage message
				local usage = CACHE_TABLE()
				local targetType = self.TargetType
				local name = self.Name
				local owner = self.Owner

				if targetType == AttributeTargets.Method then
					if name:match("^_") or ( Reflector.IsInterface(owner) and Reflector.IsNonInheritable(owner) ) then
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

					if i > 1 then
						tinsert(usage, ", ")
					end

					-- [name As type = default]
					if arg.Name then
						str = str .. arg.Name

						if arg.Type then
							str = str .. " As "
						end
					end

					if arg.Type then
						str = str .. tostring(arg.Type)
					end

					if arg.Default ~= nil then
						local serialize = Reflector.Serialize(arg.Default, arg.Type)

						if serialize then
							str = str .. " = " .. serialize
						end
					end

					if not arg.Type or arg.Type:Is(nil) then
						str = "[" .. str .. "]"
					end

					tinsert(usage, str)
				end

				tinset(usage, " )")

				self.__Usage = tblconcat(usage, "")

				CACHE_TABLE(usage)

				return self.__Usage
			end

			------------------------------------------------------
			-- Property
			------------------------------------------------------
			doc [======[
				@name Next
				@type property
				@desc The next fixed method
			]======]
			property "Next" { Type = FixedMethod + Function + nil }

			doc [======[
				@name Usage
				@type property
				@desc The usage of the fixed method
			]======]
			property "Usage" { }

			------------------------------------------------------
			-- Constructor
			------------------------------------------------------

			------------------------------------------------------
			-- Meta-methods
			------------------------------------------------------
			function __call(self, ...)
				-- Constructor can't be called
				if self.TargetType == AttributeTargets.Constructor then return end

				-- Clear the thread
				self.Thread = nil

				-- Validation self once, maybe no need to waste time
				if true and self.HasSelf then
					local value = select(1, ...)
					local owner = self.Owner

					if not value or
						( Reflector.IsInterface(owner) and not Reflector.ObjectIsInterface(value, owner) ) or
						( Reflector.IsClass(owner) and not Reflector.ObjectIsClass(value, owner)) or
						( Reflector.IsStruct(owner) and not pcall(owner.Validate, value)) then

						error(self.Usage, 2)
					end
				end

				if MatchArgs(self, ...) then
					if self.Thread then
						return self.Method( resume(self.Thread, false) )
					else
						return self.Method( ... )
					end
				end

				-- Remove argument container
				if self.Thread then
					resume(self.Thread, false)
					self.Thread = nil
				end

				if self.Next then
					return self.Next( ... )
				elseif self.HasSelf then
					-- Check super for object method
					local info = _NSInfo[self.Owner]
					local name = self.Name

					local handler = info.SuperClass and _NSInfo[info.SuperClass].Cache4Method[name]

					if not handler then
						if info.ExtendInterface then
							for _, IF in ipairs(info.ExtendInterface) do
								handler = _NSInfo[IF].Cache4Method[name]

								if handler then
									break
								end
							end
						end
					end

					if handler then
						-- Keep link for a quick inheritance
						self.Next = handler

						return handler( ... )
					end
				end

				return error(self.Usage, 2)
			end

			function __tostring(self)
				return GetUsage(self)
			end
		endclass "FixedMethod"

		_Validate_Header = [[
			return function (self, %s, ...)
				local ok, value, objArg
				local index = 0

		]]

		_Validate_Body = [[
				index = index + 1
				objArg = self[index]
				if objArg then
					if arg@ == nil and objArg.Default ~= nil then
						arg@ = objArg.Default
					end

					if objArg.Type then
						ok, value = pcall(objArg.Type.Validate, objArg.Type, arg@)

						if not ok then
							value = value:match(":%d+:%s*(.-)$") or value

							if value:find("%%s") then
								value = value:gsub("%%s[_%w]*", objArg.Name)
							end

							error(self.Usage .. value, 3)
						else
							arg@ = value
						end
					end
				end

		]]

		_Validate_Tail = [[
				return %s, ...
			end
		]]

		_Error_Header = [[Usage : __Arguments__{ arg1[, arg2[, ...] ] } : ]]
		_Error_NotArgument = [[arg%d must be System.Argument]]
		_Error_NotOptional = [[arg%d must also be optional]]
		_Error_NotList = [[arg%d can't be a list]]

		local function buildValidate(count)
			local args = ""

			for i = 1, count do
				if i > 1 then
					args = args .. ", arg" .. i
				else
					args = "arg1"
				end
			end

			local func = _Validate_Header:format(args)

			for i = 1, count do
				func = func .. _Validate_Body:gsub("@", tostring(i))
			end

			func = func .. _Validate_Tail:format(args)

			func = func:gsub("\n%s+", "\n"):gsub("^%s+", "")

			return func
		end

		_ValidateArgumentsCache = setmetatable({}, {__index = function(self, key)
			if type(key) == "number" and key >= 1 then
				key = floor(key)

				rawset(self, key, loadstring(buildValidate(key))())
				return rawget(self, key)
			end
		end})

		_ValidateArgumentsCache[0] = function (self, ...)
			local ret = {...}
			local max = #self
			local ok, value

			for i = 1, max do
				local arg = self[i]

				if i < max or not arg.IsList then
					if ret[i] == nil and arg.Default ~= nil then
						ret[i] = arg.Default
					end

					if arg.Type then
						ok, value = pcall(arg.Type.Validate, arg.Type, ret[i])

						if not ok then
							value = strtrim(value:match(":%d+:%s*(.-)$") or value)

							if value:find("%%s") then
								value = value:gsub("%%s[_%w]*", arg.Name)
							end

							error(self.Usage .. value, 3)
						elseif ret[i] ~= nil then
							ret[i] = value
						end
					end
				else
					if arg.Type then
						for j = i, #ret do
							ok, value = pcall(arg.Type.Validate, arg.Type, ret[j])

							if not ok then
								value = strtrim(value:match(":%d+:%s*(.-)$") or value)

								if value:find("%%s") then
									value = value:gsub("%%s[_%w]*", "...")
								end

								error(self.Usage .. value, 3)
							elseif ret[j] ~= nil then
								ret[j] = value
							end
						end
					end
				end
			end

			return unpack(ret)
		end

		local function ValidateArgument(self, i)
			local isLast = i == #self

			local flag, arg = pcall( Argument.Validate, self[i] )

			if flag then
				-- Init table need name to match
				if not arg.Name then self.NoInitTable = true end

				-- Check optional args
				if not arg.Type or arg.Type:Is(nil) then
					if not self.MinArgs then
						self.MinArgs = i - 1
					end
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
								self.NoInitTable = true
							end

							-- Just big enough
							self.MaxArgs = 9999

							arg.Name = "..."
						end
					else
						error(_Error_Header .. _Error_NotList:format(i))
					end
				end
			else
				error(_Error_Header .. _Error_NotArgument:format(i))
			end
		end

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		function ApplyAttribute(self, target, targetType, owner, name)
			-- Self validation once
			for i = 1, #self do
				ValidateArgument(self, i)
			end

			self.Owner = owner
			self.TargetType = targetType
			self.Name = name

			if targetType == AttributeTargets.Method then
				self.NoInitTable = true

				if name:match("^_") or ( Reflector.IsInterface(owner) and Reflector.IsNonInheritable(owner) ) then
					self.HasSelf = false
				else
					self.HasSelf = true
				end
			else
				self.HasSelf = true
			end

			-- Quick match
			if not self.MinArgs then self.MinArgs = #self end
			if not self.MaxArgs then self.MaxArgs = #self end

			-- Save self to fixedmethod object
			local fixedObj = FixedMethod()

			for k, v in pairs(self) do
				fixedObj[k] = v
			end

			fixedObj.Method = target

			wipe(self)

			return fixedObj
		end

		------------------------------------------------------
		-- Meta-methods
		------------------------------------------------------
		function __call(self)
			wipe(self)

			return Super.__call(self)
		end
	endclass "__Arguments__"

	enum "StructType" {
		"Member",
		"Array",
		"Custom"
	}

	__AttributeUsage__{AttributeTarget = AttributeTargets.Struct, Inherited = false, RunOnce = true}
	__Final__()
	__NonInheritable__()
	class "__StructType__"
		inherit "__Attribute__"

		doc [======[
			@name __StructType__
			@type class
			@desc Mark the struct's type, default 'Member'
		]======]

		_STRUCT_TYPE_MEMBER = _STRUCT_TYPE_MEMBER
		_STRUCT_TYPE_ARRAY = _STRUCT_TYPE_ARRAY
		_STRUCT_TYPE_CUSTOM = _STRUCT_TYPE_CUSTOM

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
		doc [======[
			@name Type
			@type property
			@desc The struct's type
		]======]
		property "Type" {
			Field = "__Type",
			Type = StructType,
		}

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		__Arguments__{ Argument{ Name = "Type", Type = StructType, Default = StructType.Member } }
		function __StructType__(self, type)
			self.__Type = type
		end
	endclass "__StructType__"

	__AttributeUsage__{AttributeTarget = AttributeTargets.Interface + AttributeTargets.Class, RunOnce = true}
	__Final__()
	__Unique__()
	class "__NonExpandable__"
		inherit "__Attribute__"
		doc [======[
			@name __NonExpandable__
			@type class
			@desc Mark the class|interface can't receive functions as new methods like :
				System.Object.Print = function(self) print(self) end, give all object of System.Object a new method.
				The cost should be expensive, use it carefully.
		]======]

		function ApplyAttribute(self, target, targetType)
			if rawget(_NSInfo, target) then
				_NSInfo[target].NonExpandable = true
			end
		end
	endclass "__NonExpandable__"

	------------------------------------------------------
	-- System.Object
	------------------------------------------------------
	__Final__()
	class "Object"

		doc [======[
			@name Object
			@type class
			@desc The root class of other classes. Object class contains several methodes for common use.
		]======]

		------------------------------------------------------
		-- Event
		------------------------------------------------------
		doc [======[
			@name OnEventHandlerChanged
			@type event
			@desc Fired when an event's handler is changed
			@param name the changed event handler's event name
		]======]
		event "OnEventHandlerChanged"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc [======[
			@name HasEvent
			@type method
			@desc Check if the event type is supported by the object
			@param name the event's name
			@return boolean true if the object has that event type
		]======]
		function HasEvent(self, name)
			if type(name) ~= "string" then
				error(("Usage : object:HasEvent(name) : 'name' - string expected, got %s."):format(type(name)), 2)
			end
			return Reflector.HasEvent(Reflector.GetObjectClass(self), name) or false
		end

		doc [======[
			@name GetClass
			@type method
			@desc Get the class type of the object
			@return class the object's class
		]======]
		function GetClass(self)
			return Reflector.GetObjectClass(self)
		end

		doc [======[
			@name IsClass
			@type method
			@desc Check if the object is an instance of the class
			@param class
			@return boolean true if the object is an instance of the class
		]======]
		function IsClass(self, cls)
			return Reflector.ObjectIsClass(self, cls)
		end

		doc [======[
			@name IsInterface
			@type method
			@desc Check if the object is extend from the interface
			@param interface
			@return boolean true if the object is extend from the interface
		]======]
		function IsInterface(self, IF)
			return Reflector.ObjectIsInterface(self, IF)
		end

		doc [======[
			@name Fire
			@type method
			@desc Fire an object's event, to trigger the object's event handlers
			@param event the event name
			@param ... the event's arguments
			@return nil
		]======]
		local rawget = rawget
		function Fire(self, sc, ...)
			-- No more check , just fire the event as quick as we can
			local handler = rawget(self, "__Events")
			handler = handler and handler[sc]
			return handler and handler(self, ...)
		end

		doc [======[
			@name ActiveThread
			@type method
			@desc Active the thread mode for special events
			@format event[, ...]
			@param event the event name
			@param ... other event's name list
			@return nil
		]======]
		function ActiveThread(self, ...)
			return Reflector.ActiveThread(self, ...)
		end

		doc [======[
			@name IsThreadActivated
			@type method
			@desc Check if the thread mode is actived for the event
			@param event the event's name
			@return boolean true if the event is in thread mode
		]======]
		function IsThreadActivated(self, sc)
			return Reflector.IsThreadActivated(self, sc)
		end

		doc [======[
			@name InactiveThread
			@type method
			@desc Turn off the thread mode for the events
			@format event[, ...]
			@param event the event's name
			@param ... other event's name list
			@return nil
		]======]
		function InactiveThread(self, ...)
			return Reflector.InactiveThread(self, ...)
		end

		doc [======[
			@name BlockEvent
			@type method
			@desc Block some events for the object
			@format event[, ...]
			@param event the event's name
			@param ... other event's name list
			@return nil
		]======]
		function BlockEvent(self, ...)
			return Reflector.BlockEvent(self, ...)
		end

		doc [======[
			@name IsEventBlocked
			@type method
			@desc Check if the event is blocked for the object
			@param event the event's name
			@return boolean true if th event is blocked
		]======]
		function IsEventBlocked(self, sc)
			return Reflector.IsEventBlocked(self, sc)
		end

		doc [======[
			@name UnBlockEvent
			@type method
			@desc Un-Block some events for the object
			@format event[, ...]
			@param event the event's name
			@param ... other event's name list
			@return nil
		]======]
		function UnBlockEvent(self, ...)
			return Reflector.UnBlockEvent(self, ...)
		end

		doc [======[
			@name ThreadCall
			@type method
			@desc Call method or function as a thread
			@param methodname|function
			@param ... the arguments
			@return nil
		]======]
		function ThreadCall(self, method, ...)
			if type(method) == "string" then
				method = self[method]
			end

			if type(method) == "function" then
				return CallThread(method, self, ...)
			end
		end

		------------------------------------------------------
		-- Meta-methods
		------------------------------------------------------
		--[[function __tostring(self)
			return "[Object]" .. tostring(getmetatable(self)) .. "()"
		end--]]
	endclass "Object"

	------------------------------------------------------
	-- System.Module
	------------------------------------------------------
	__Final__()
	class "Module"
		inherit "Object"

		doc [======[
			@name Module
			@type class
			@desc Used to create an hierarchical environment with class system settings, like : Module "Root.ModuleA" "v72"
		]======]

		_Module = _Module or {}
		_ModuleInfo = _ModuleInfo or setmetatable({}, WEAK_KEY)

		_ModuleEnv = _ModuleEnv or {}

		_ModuleEnv.class = class
		_ModuleEnv.enum = enum
		_ModuleEnv.namespace = namespace
		_ModuleEnv.struct = struct
		_ModuleEnv.interface = interface
		_ModuleEnv.import = function(name)
			local ns = name

			if type(name) == "string" then
				ns = Reflector.ForName(name)

				if not ns then
					error(("no namespace is found with name : %s"):format(name), 2)
				end
			end

			if not Reflector.IsNameSpace(ns) then
				error([[Usage: import "namespaceA.namespaceB"]], 2)
			end

			local env = getfenv(2)

			local info = _ModuleInfo[env]

			if not info then
				error("can't use import here.", 2)
			end

			info.Import = info.Import or {}

			for _, v in ipairs(info.Import) do
				if v == ns then
					return
				end
			end

			tinsert(info.Import, ns)
		end

		------------------------------------------------------
		-- Event
		------------------------------------------------------
		doc [======[
			@name OnDispose
			@type event
			@desc Fired when the module is disposed
		]======]
		event "OnDispose"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		doc [======[
			@name ValidateVersion
			@type method
			@desc Return true if the version is greater than the current version of the module
			@param version
			@return boolean true if the version is a validated version
		]======]
		function ValidateVersion(self, version)
			local info = _ModuleInfo[self]

			if not info then
				error("The module is disposed", 2)
			end

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

		doc [======[
			@name GetModule
			@type method
			@desc Get the child-module with the name
			@param name string, the child-module's name
			@return System.Module the child-module
		]======]
		function GetModule(self, name)
			if type(name) ~= "string" or strtrim(name) == "" then
				return
			end

			local mdl = self

			for sub in name:gmatch("[_%w]+") do
				mdl =  _ModuleInfo[mdl] and _ModuleInfo[mdl].Modules and _ModuleInfo[mdl].Modules[sub]

				if not mdl then return end
			end

			if mdl == self then return end

			return mdl
		end

		doc [======[
			@name GetModules
			@type method
			@desc Get all child-modules of the module
			@return table the list of the the child-modules
		]======]
		function GetModules(self)
			if _ModuleInfo[self] and _ModuleInfo[self].Modules then
				local lst = {}

				for _, mdl in pairs(_ModuleInfo[self].Modules) do
					tinsert(lst, mdl)
				end

				return lst
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		doc [======[
			@name _M
			@type property
			@desc The module itself
		]======]
		property "_M" {
			Get = function(self)
				return self
			end,
		}

		doc [======[
			@name _Name
			@type property
			@desc The module's name
		]======]
		property "_Name" {
			Get = function(self)
				return _ModuleInfo[self].Name
			end,
		}

		doc [======[
			@name _Parent
			@type property
			@desc The module's parent module
		]======]
		property "_Parent" {
			Get = function(self)
				return _ModuleInfo[self].Parent
			end,
		}

		doc [======[
			@name _Version
			@type property
			@desc The module's version
		]======]
		property "_Version" {
			Get = function(self)
				return _ModuleInfo[self].Version
			end,
		}

		------------------------------------------------------
		-- Dispose
		------------------------------------------------------
		function Dispose(self)
			local info = _ModuleInfo[self]

			if info then
				-- Clear child modules
				if info.Modules then
					for name, mdl in pairs(info.Modules) do
						mdl:Dispose()
					end

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

			if not Reflector.ObjectIsClass(parent, Module) then
				parent = nil
			end

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
			if Reflector.ObjectIsClass(parent, Module) then
				mdl = parent
			end

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
			if _ModuleEnv[key] then
				return _ModuleEnv[key]
			end

			-- Check self's namespace
			local ns = Reflector.GetCurrentNameSpace(self, true)
			local parent = _ModuleInfo[self].Parent

			while not ns and parent do
				ns = Reflector.GetCurrentNameSpace(parent, true)
				parent = _ModuleInfo[parent].Parent
			end

			if ns and Reflector.GetName(ns) then
				if key == Reflector.GetName(ns) then
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
					if key == Reflector.GetName(ns) then
						rawset(self, key, ns)
						return rawget(self, key)
					elseif ns[key] then
						rawset(self, key, ns[key])
						return rawget(self, key)
					end
				end
			end

			-- Check base namespace
			if Reflector.ForName(key) then
				rawset(self, key, Reflector.ForName(key))
				return rawget(self, key)
			end

			if info.Parent then
				local value = info.Parent[key]

				if value ~= nil then
					rawset(self, key, value)
				end

				return value
			else
				if key ~= "_G" and type(key) == "string" and key:find("^_") then
					return
				end

				local value = _G[key]

				if value ~= nil then
					rawset(self, key, value)
				end

				return value
			end
		end

		function __newindex(self, key, value)
			if _ModuleEnv[key] then
				error(("%s is a keyword."):format(key), 2)
			end

			rawset(self, key, value)
		end

		function __call(self, version, depth)
			depth = type(depth) == "number" and depth > 0 and depth or 1

			local info = _ModuleInfo[self]

			if not info then
				error("The module is disposed", 2)
			end

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
	-- Keep the root so can't be disposed
	System = Reflector.ForName("System")

	function import_install(name, all)
		local ns = Reflector.ForName(name)
		local env = getfenv(2)

		if ns and env then
			env[Reflector.GetName(ns)] = ns

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
