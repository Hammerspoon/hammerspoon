--[=====================================================================[
v0.7 Copyright © 2013-2014 Gavin Kistner <!@phrogz.net>; MIT Licensed
See http://github.com/Phrogz/SLAXML for details.
--]=====================================================================]
local SLAXML = {
	VERSION = "0.7",
	_call = {
		pi = function(target,content)
			print(string.format("<?%s %s?>",target,content))
		end,
		comment = function(content)
			print(string.format("<!-- %s -->",content))
		end,
		startElement = function(name,nsURI,nsPrefix)
			                 io.write("<")
			if nsPrefix then io.write(nsPrefix,":") end
			                 io.write(name)
			if nsURI    then io.write(" (ns='",nsURI,"')") end
			                 print(">")
		end,
		attribute = function(name,value,nsURI,nsPrefix)
			                 io.write('  ')
			if nsPrefix then io.write(nsPrefix,":") end
			                 io.write(name,'=',string.format('%q',value))
			if nsURI    then io.write(" (ns='",nsURI,"')") end
			                 io.write("\n")
		end,
		text = function(text)
			print(string.format("  text: %q",text))
		end,
		closeElement = function(name,nsURI,nsPrefix)
			print(string.format("</%s>",name))
		end,
	}
}

function SLAXML:parser(callbacks)
	return { _call=callbacks or self._call, parse=SLAXML.parse }
end

function SLAXML:parse(xml,options)
	if not options then options = { stripWhitespace=false } end

	-- Cache references for maximum speed
	local find, sub, gsub, char, push, pop, concat = string.find, string.sub, string.gsub, string.char, table.insert, table.remove, table.concat
	local first, last, match1, match2, match3, pos2, nsURI
	local unpack = unpack or table.unpack
	local pos = 1
	local state = "text"
	local textStart = 1
	local currentElement={}
	local currentAttributes={}
	local currentAttributeCt -- manually track length since the table is re-used
	local nsStack = {}
	local anyElement = false

	local utf8markers = { {0x7FF,192}, {0xFFFF,224}, {0x1FFFFF,240} }
	local function utf8(decimal) -- convert unicode code point to utf-8 encoded character string
		if decimal<128 then return char(decimal) end
		local charbytes = {}
		for bytes,vals in ipairs(utf8markers) do
			if decimal<=vals[1] then
				for b=bytes+1,2,-1 do
					local mod = decimal%64
					decimal = (decimal-mod)/64
					charbytes[b] = char(128+mod)
				end
				charbytes[1] = char(vals[2]+decimal)
				return concat(charbytes)
			end
		end
	end
	local entityMap  = { ["lt"]="<", ["gt"]=">", ["amp"]="&", ["quot"]='"', ["apos"]="'" }
	local entitySwap = function(orig,n,s) return entityMap[s] or n=="#" and utf8(tonumber('0'..s)) or orig end  
	local function unescape(str) return gsub( str, '(&(#?)([%d%a]+);)', entitySwap ) end

	local function finishText()
		if first>textStart and self._call.text then
			local text = sub(xml,textStart,first-1)
			if options.stripWhitespace then
				text = gsub(text,'^%s+','')
				text = gsub(text,'%s+$','')
				if #text==0 then text=nil end
			end
			if text then self._call.text(unescape(text)) end
		end
	end

	local function findPI()
		first, last, match1, match2 = find( xml, '^<%?([:%a_][:%w_.-]*) ?(.-)%?>', pos )
		if first then
			finishText()
			if self._call.pi then self._call.pi(match1,match2) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function findComment()
		first, last, match1 = find( xml, '^<!%-%-(.-)%-%->', pos )
		if first then
			finishText()
			if self._call.comment then self._call.comment(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function nsForPrefix(prefix)
		if prefix=='xml' then return 'http://www.w3.org/XML/1998/namespace' end -- http://www.w3.org/TR/xml-names/#ns-decl
		for i=#nsStack,1,-1 do if nsStack[i][prefix] then return nsStack[i][prefix] end end
		error(("Cannot find namespace for prefix %s"):format(prefix))
	end

	local function startElement()
		anyElement = true
		first, last, match1 = find( xml, '^<([%a_][%w_.-]*)', pos )
		if first then
			currentElement[2] = nil -- reset the nsURI, since this table is re-used
			currentElement[3] = nil -- reset the nsPrefix, since this table is re-used
			finishText()
			pos = last+1
			first,last,match2 = find(xml, '^:([%a_][%w_.-]*)', pos )
			if first then
				currentElement[1] = match2
				currentElement[3] = match1 -- Save the prefix for later resolution
				match1 = match2
				pos = last+1
			else
				currentElement[1] = match1
				for i=#nsStack,1,-1 do if nsStack[i]['!'] then currentElement[2] = nsStack[i]['!']; break end end
			end
			currentAttributeCt = 0
			push(nsStack,{})
			return true
		end
	end

	local function findAttribute()
		first, last, match1 = find( xml, '^%s+([:%a_][:%w_.-]*)%s*=%s*', pos )
		if first then
			pos2 = last+1
			first, last, match2 = find( xml, '^"([^<"]*)"', pos2 ) -- FIXME: disallow non-entity ampersands
			if first then
				pos = last+1
				match2 = unescape(match2)
			else
				first, last, match2 = find( xml, "^'([^<']*)'", pos2 ) -- FIXME: disallow non-entity ampersands
				if first then
					pos = last+1
					match2 = unescape(match2)
				end
			end
		end
		if match1 and match2 then
			local currentAttribute = {match1,match2}
			local prefix,name = string.match(match1,'^([^:]+):([^:]+)$')
			if prefix then
				if prefix=='xmlns' then
					nsStack[#nsStack][name] = match2
				else
					currentAttribute[1] = name
					currentAttribute[4] = prefix
				end
			else
				if match1=='xmlns' then
					nsStack[#nsStack]['!'] = match2
					currentElement[2]      = match2
				end
			end
			currentAttributeCt = currentAttributeCt + 1
			currentAttributes[currentAttributeCt] = currentAttribute
			return true
		end
	end

	local function findCDATA()
		first, last, match1 = find( xml, '^<!%[CDATA%[(.-)%]%]>', pos )
		if first then
			finishText()
			if self._call.text then self._call.text(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function closeElement()
		first, last, match1 = find( xml, '^%s*(/?)>', pos )
		if first then
			state = "text"
			pos = last+1
			textStart = pos

			-- Resolve namespace prefixes AFTER all new/redefined prefixes have been parsed
			if currentElement[3] then currentElement[2] = nsForPrefix(currentElement[3])    end
			if self._call.startElement then self._call.startElement(unpack(currentElement)) end
			if self._call.attribute then
				for i=1,currentAttributeCt do
					if currentAttributes[i][4] then currentAttributes[i][3] = nsForPrefix(currentAttributes[i][4]) end
					self._call.attribute(unpack(currentAttributes[i]))
				end
			end

			if match1=="/" then
				pop(nsStack)
				if self._call.closeElement then self._call.closeElement(unpack(currentElement)) end
			end
			return true
		end
	end

	local function findElementClose()
		first, last, match1, match2 = find( xml, '^</([%a_][%w_.-]*)%s*>', pos )
		if first then
			nsURI = nil
			for i=#nsStack,1,-1 do if nsStack[i]['!'] then nsURI = nsStack[i]['!']; break end end
		else
			first, last, match2, match1 = find( xml, '^</([%a_][%w_.-]*):([%a_][%w_.-]*)%s*>', pos )
			if first then nsURI = nsForPrefix(match2) end
		end
		if first then
			finishText()
			if self._call.closeElement then self._call.closeElement(match1,nsURI) end
			pos = last+1
			textStart = pos
			pop(nsStack)
			return true
		end
	end

	while pos<#xml do
		if state=="text" then
			if not (findPI() or findComment() or findCDATA() or findElementClose()) then		
				if startElement() then
					state = "attributes"
				else
					first, last = find( xml, '^[^<]+', pos )
					pos = (first and last or pos) + 1
				end
			end
		elseif state=="attributes" then
			if not findAttribute() then
				if not closeElement() then
					error("Was in an element and couldn't find attributes or the close.")
				end
			end
		end
	end

	if not anyElement then error("Parsing did not discover any elements") end
	if #nsStack > 0 then error("Parsing ended with unclosed elements") end
end

return SLAXML
