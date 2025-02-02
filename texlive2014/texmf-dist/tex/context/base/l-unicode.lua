if not modules then modules = { } end modules ['l-unicode'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- in lua 5.3:

-- utf8.char(···)         : concatinated
-- utf8.charpatt          : "[\0-\x7F\xC2-\xF4][\x80-\xBF]*"
-- utf8.codes(s)          : for p, c in utf8.codes(s) do body end
-- utf8.codepoint(s [, i [, j]])
-- utf8.len(s [, i])
-- utf8.offset(s, n [, i])

-- todo: utf.sub replacement (used in syst-aux)
-- we put these in the utf namespace:

utf = utf or (unicode and unicode.utf8) or { }

utf.characters = utf.characters or string.utfcharacters
utf.values     = utf.values     or string.utfvalues

-- string.utfvalues
-- string.utfcharacters
-- string.characters
-- string.characterpairs
-- string.bytes
-- string.bytepairs

local type = type
local char, byte, format, sub, gmatch = string.char, string.byte, string.format, string.sub, string.gmatch
local concat = table.concat
local P, C, R, Cs, Ct, Cmt, Cc, Carg, Cp = lpeg.P, lpeg.C, lpeg.R, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Carg, lpeg.Cp
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local bytepairs     = string.bytepairs

local finder        = lpeg.finder
local replacer      = lpeg.replacer

local utfvalues     = utf.values
local utfgmatch     = utf.gmatch -- not always present

local p_utftype       = patterns.utftype
local p_utfstricttype = patterns.utfstricttype
local p_utfoffset     = patterns.utfoffset
local p_utf8char      = patterns.utf8char
local p_utf8byte      = patterns.utf8byte
local p_utfbom        = patterns.utfbom
local p_newline       = patterns.newline
local p_whitespace    = patterns.whitespace

if not unicode then

    unicode = { utf = utf } -- for a while

end

if not utf.char then

    local floor, char = math.floor, string.char

    function utf.char(n)
        if n < 0x80 then
            -- 0aaaaaaa : 0x80
            return char(n)
        elseif n < 0x800 then
            -- 110bbbaa : 0xC0 : n >> 6
            -- 10aaaaaa : 0x80 : n & 0x3F
            return char(
                0xC0 + floor(n/0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x10000 then
            -- 1110bbbb : 0xE0 :  n >> 12
            -- 10bbbbaa : 0x80 : (n >>  6) & 0x3F
            -- 10aaaaaa : 0x80 :  n        & 0x3F
            return char(
                0xE0 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x200000 then
            -- 11110ccc : 0xF0 :  n >> 18
            -- 10ccbbbb : 0x80 : (n >> 12) & 0x3F
            -- 10bbbbaa : 0x80 : (n >>  6) & 0x3F
            -- 10aaaaaa : 0x80 :  n        & 0x3F
            -- dddd     : ccccc - 1
            return char(
                0xF0 +  floor(n/0x40000),
                0x80 + (floor(n/0x1000) % 0x40),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        else
            return ""
        end
    end

end

if not utf.byte then

    local utf8byte = patterns.utf8byte

    function utf.byte(c)
        return lpegmatch(utf8byte,c)
    end

end

local utfchar, utfbyte = utf.char, utf.byte

-- As we want to get rid of the (unmaintained) utf library we implement our own
-- variants (in due time an independent module):

function utf.filetype(data)
    return data and lpegmatch(p_utftype,data) or "unknown"
end

local toentities = Cs (
    (
        patterns.utf8one
            + (
                patterns.utf8two
              + patterns.utf8three
              + patterns.utf8four
            ) / function(s) local b = utfbyte(s) if b < 127 then return s else return format("&#%X;",b) end end
    )^0
)

patterns.toentities = toentities

function utf.toentities(str)
    return lpegmatch(toentities,str)
end

-- local utfchr = { } -- 60K -> 2.638 M extra mem but currently not called that often (on latin)
--
-- setmetatable(utfchr, { __index = function(t,k) local v = utfchar(k) t[k] = v return v end } )
--
-- collectgarbage("collect")
-- local u = collectgarbage("count")*1024
-- local t = os.clock()
-- for i=1,1000 do
--     for i=1,600 do
--         local a = utfchr[i]
--     end
-- end
-- print(os.clock()-t,collectgarbage("count")*1024-u)

-- collectgarbage("collect")
-- local t = os.clock()
-- for i=1,1000 do
--     for i=1,600 do
--         local a = utfchar(i)
--     end
-- end
-- print(os.clock()-t,collectgarbage("count")*1024-u)

-- local byte = string.byte
-- local utfchar = utf.char

local one  = P(1)
local two  = C(1) * C(1)
local four = C(R(utfchar(0xD8),utfchar(0xFF))) * C(1) * C(1) * C(1)

-- actually one of them is already utf ... sort of useless this one

-- function utf.char(n)
--     if n < 0x80 then
--         return char(n)
--     elseif n < 0x800 then
--         return char(
--             0xC0 + floor(n/0x40),
--             0x80 + (n % 0x40)
--         )
--     elseif n < 0x10000 then
--         return char(
--             0xE0 + floor(n/0x1000),
--             0x80 + (floor(n/0x40) % 0x40),
--             0x80 + (n % 0x40)
--         )
--     elseif n < 0x40000 then
--         return char(
--             0xF0 + floor(n/0x40000),
--             0x80 + floor(n/0x1000),
--             0x80 + (floor(n/0x40) % 0x40),
--             0x80 + (n % 0x40)
--         )
--     else
--      -- return char(
--      --     0xF1 + floor(n/0x1000000),
--      --     0x80 + floor(n/0x40000),
--      --     0x80 + floor(n/0x1000),
--      --     0x80 + (floor(n/0x40) % 0x40),
--      --     0x80 + (n % 0x40)
--      -- )
--         return "?"
--     end
-- end
--
-- merge into:

local pattern = P("\254\255") * Cs( (
                    four  / function(a,b,c,d)
                                local ab = 0xFF * byte(a) + byte(b)
                                local cd = 0xFF * byte(c) + byte(d)
                                return utfchar((ab-0xD800)*0x400 + (cd-0xDC00) + 0x10000)
                            end
                  + two   / function(a,b)
                                return utfchar(byte(a)*256 + byte(b))
                            end
                  + one
                )^1 )
              + P("\255\254") * Cs( (
                    four  / function(b,a,d,c)
                                local ab = 0xFF * byte(a) + byte(b)
                                local cd = 0xFF * byte(c) + byte(d)
                                return utfchar((ab-0xD800)*0x400 + (cd-0xDC00) + 0x10000)
                            end
                  + two   / function(b,a)
                                return utfchar(byte(a)*256 + byte(b))
                            end
                  + one
                )^1 )

function string.toutf(s) -- in string namespace
    return lpegmatch(pattern,s) or s -- todo: utf32
end

local validatedutf = Cs (
    (
        patterns.utf8one
      + patterns.utf8two
      + patterns.utf8three
      + patterns.utf8four
      + P(1) / "�"
    )^0
)

patterns.validatedutf = validatedutf

function utf.is_valid(str)
    return type(str) == "string" and lpegmatch(validatedutf,str) or false
end

if not utf.len then

    -- -- alternative 1: 0.77
    --
    -- local utfcharcounter = utfbom^-1 * Cs((p_utf8char/'!')^0)
    --
    -- function utf.len(str)
    --     return #lpegmatch(utfcharcounter,str or "")
    -- end
    --
    -- -- alternative 2: 1.70
    --
    -- local n = 0
    --
    -- local utfcharcounter = utfbom^-1 * (p_utf8char/function() n = n + 1 end)^0 -- slow
    --
    -- function utf.length(str)
    --     n = 0
    --     lpegmatch(utfcharcounter,str or "")
    --     return n
    -- end
    --
    -- -- alternative 3: 0.24 (native unicode.utf8.len: 0.047)

    -- local n = 0
    --
    -- -- local utfcharcounter = lpeg.patterns.utfbom^-1 * P ( ( Cp() * (
    -- --     patterns.utf8one  ^1 * Cc(1)
    -- --   + patterns.utf8two  ^1 * Cc(2)
    -- --   + patterns.utf8three^1 * Cc(3)
    -- --   + patterns.utf8four ^1 * Cc(4) ) * Cp() / function(f,d,t) n = n + (t - f)/d end
    -- --  )^0 ) -- just as many captures as below
    --
    -- -- local utfcharcounter = lpeg.patterns.utfbom^-1 * P ( (
    -- --     (Cmt(patterns.utf8one  ^1,function(_,_,s) n = n + #s   return true end))
    -- --   + (Cmt(patterns.utf8two  ^1,function(_,_,s) n = n + #s/2 return true end))
    -- --   + (Cmt(patterns.utf8three^1,function(_,_,s) n = n + #s/3 return true end))
    -- --   + (Cmt(patterns.utf8four ^1,function(_,_,s) n = n + #s/4 return true end))
    -- -- )^0 ) -- not interesting as it creates strings but sometimes faster
    --
    -- -- The best so far:
    --
    -- local utfcharcounter = utfbom^-1 * P ( (
    --     Cp() * (patterns.utf8one  )^1 * Cp() / function(f,t) n = n +  t - f    end
    --   + Cp() * (patterns.utf8two  )^1 * Cp() / function(f,t) n = n + (t - f)/2 end
    --   + Cp() * (patterns.utf8three)^1 * Cp() / function(f,t) n = n + (t - f)/3 end
    --   + Cp() * (patterns.utf8four )^1 * Cp() / function(f,t) n = n + (t - f)/4 end
    -- )^0 )

    -- function utf.len(str)
    --     n = 0
    --     lpegmatch(utfcharcounter,str or "")
    --     return n
    -- end

    local n, f = 0, 1

    local utfcharcounter = patterns.utfbom^-1 * Cmt (
        Cc(1) * patterns.utf8one  ^1
      + Cc(2) * patterns.utf8two  ^1
      + Cc(3) * patterns.utf8three^1
      + Cc(4) * patterns.utf8four ^1,
        function(_,t,d) -- due to Cc no string captures, so faster
            n = n + (t - f)/d
            f = t
            return true
        end
    )^0

    function utf.len(str)
        n, f = 0, 1
        lpegmatch(utfcharcounter,str or "")
        return n
    end

    -- -- these are quite a bit slower:

    -- utfcharcounter = utfbom^-1 * (Cmt(P(1) * R("\128\191")^0, function() n = n + 1 return true end))^0 -- 50+ times slower
    -- utfcharcounter = utfbom^-1 * (Cmt(P(1), function() n = n + 1 return true end) * R("\128\191")^0)^0 -- 50- times slower

end

utf.length = utf.len

if not utf.sub then

    -- inefficient as lpeg just copies ^n

    -- local function sub(str,start,stop)
    --     local pattern = p_utf8char^-(start-1) * C(p_utf8char^-(stop-start+1))
    --     inspect(pattern)
    --     return lpegmatch(pattern,str) or ""
    -- end

    -- local b, e, n, first, last = 0, 0, 0, 0, 0
    --
    -- local function slide(s,p)
    --     n = n + 1
    --     if n == first then
    --         b = p
    --         if not last then
    --             return nil
    --         end
    --     end
    --     if n == last then
    --         e = p
    --         return nil
    --     else
    --         return p
    --     end
    -- end
    --
    -- local pattern = Cmt(p_utf8char,slide)^0
    --
    -- function utf.sub(str,start,stop) -- todo: from the end
    --     if not start then
    --         return str
    --     end
    --     b, e, n, first, last = 0, 0, 0, start, stop
    --     lpegmatch(pattern,str)
    --     if not stop then
    --         return sub(str,b)
    --     else
    --         return sub(str,b,e-1)
    --     end
    -- end

    -- print(utf.sub("Hans Hagen is my name"))
    -- print(utf.sub("Hans Hagen is my name",5))
    -- print(utf.sub("Hans Hagen is my name",5,10))

    local utflength = utf.length

    -- also negative indices, upto 10 times slower than a c variant

    local b, e, n, first, last = 0, 0, 0, 0, 0

    local function slide_zero(s,p)
        n = n + 1
        if n >= last then
            e = p - 1
        else
            return p
        end
    end

    local function slide_one(s,p)
        n = n + 1
        if n == first then
            b = p
        end
        if n >= last then
            e = p - 1
        else
            return p
        end
    end

    local function slide_two(s,p)
        n = n + 1
        if n == first then
            b = p
        else
            return true
        end
    end

    local pattern_zero = Cmt(p_utf8char,slide_zero)^0
    local pattern_one  = Cmt(p_utf8char,slide_one )^0
    local pattern_two  = Cmt(p_utf8char,slide_two )^0

    function utf.sub(str,start,stop)
        if not start then
            return str
        end
        if start == 0 then
            start = 1
        end
        if not stop then
            if start < 0 then
                local l = utflength(str) -- we can inline this function if needed
                start = l + start
            else
                start = start - 1
            end
            b, n, first = 0, 0, start
            lpegmatch(pattern_two,str)
            if n >= first then
                return sub(str,b)
            else
                return ""
            end
        end
        if start < 0 or stop < 0 then
            local l = utf.length(str)
            if start < 0 then
                start = l + start
                if start <= 0 then
                    start = 1
                else
                    start = start + 1
                end
            end
            if stop < 0 then
                stop = l + stop
                if stop == 0 then
                    stop = 1
                else
                    stop = stop + 1
                end
            end
        end
        if start > stop then
            return ""
        elseif start > 1 then
            b, e, n, first, last = 0, 0, 0, start - 1, stop
            lpegmatch(pattern_one,str)
            if n >= first and e == 0 then
                e = #str
            end
            return sub(str,b,e)
        else
            b, e, n, last = 1, 0, 0, stop
            lpegmatch(pattern_zero,str)
            if e == 0 then
                e = #str
            end
            return sub(str,b,e)
        end
    end

    -- local n = 100000
    -- local str = string.rep("123456àáâãäå",100)
    --
    -- for i=-15,15,1 do
    --     for j=-15,15,1 do
    --         if utf.xsub(str,i,j) ~= utf.sub(str,i,j) then
    --             print("error",i,j,"l>"..utf.xsub(str,i,j),"s>"..utf.sub(str,i,j))
    --         end
    --     end
    --     if utf.xsub(str,i) ~= utf.sub(str,i) then
    --         print("error",i,"l>"..utf.xsub(str,i),"s>"..utf.sub(str,i))
    --     end
    -- end

    -- print(" 1, 7",utf.xsub(str, 1, 7),utf.sub(str, 1, 7))
    -- print(" 0, 7",utf.xsub(str, 0, 7),utf.sub(str, 0, 7))
    -- print(" 0, 9",utf.xsub(str, 0, 9),utf.sub(str, 0, 9))
    -- print(" 4   ",utf.xsub(str, 4   ),utf.sub(str, 4   ))
    -- print(" 0   ",utf.xsub(str, 0   ),utf.sub(str, 0   ))
    -- print(" 0, 0",utf.xsub(str, 0, 0),utf.sub(str, 0, 0))
    -- print(" 4, 4",utf.xsub(str, 4, 4),utf.sub(str, 4, 4))
    -- print(" 4, 0",utf.xsub(str, 4, 0),utf.sub(str, 4, 0))
    -- print("-3, 0",utf.xsub(str,-3, 0),utf.sub(str,-3, 0))
    -- print(" 0,-3",utf.xsub(str, 0,-3),utf.sub(str, 0,-3))
    -- print(" 5,-3",utf.xsub(str,-5,-3),utf.sub(str,-5,-3))
    -- print("-3   ",utf.xsub(str,-3   ),utf.sub(str,-3   ))

end

-- a replacement for simple gsubs:

function utf.remapper(mapping)
    local pattern = Cs((p_utf8char/mapping)^0)
    return function(str)
        if not str or str == "" then
            return ""
        else
            return lpegmatch(pattern,str)
        end
    end, pattern
end

-- local remap = utf.remapper { a = 'd', b = "c", c = "b", d = "a" }
-- print(remap("abcd 1234 abcd"))

--

function utf.replacer(t) -- no precheck, always string builder
    local r = replacer(t,false,false,true)
    return function(str)
        return lpegmatch(r,str)
    end
end

function utf.subtituter(t) -- with precheck and no building if no match
    local f = finder  (t)
    local r = replacer(t,false,false,true)
    return function(str)
        local i = lpegmatch(f,str)
        if not i then
            return str
        elseif i > #str then
            return str
        else
         -- return sub(str,1,i-2) .. lpegmatch(r,str,i-1) -- slower
            return lpegmatch(r,str)
        end
    end
end

-- inspect(utf.split("a b c d"))
-- inspect(utf.split("a b c d",true))

local utflinesplitter     = p_utfbom^-1 * lpeg.tsplitat(p_newline)
local utfcharsplitter_ows = p_utfbom^-1 * Ct(C(p_utf8char)^0)
local utfcharsplitter_iws = p_utfbom^-1 * Ct((p_whitespace^1 + C(p_utf8char))^0)
local utfcharsplitter_raw = Ct(C(p_utf8char)^0)

patterns.utflinesplitter  = utflinesplitter

function utf.splitlines(str)
    return lpegmatch(utflinesplitter,str or "")
end

function utf.split(str,ignorewhitespace) -- new
    if ignorewhitespace then
        return lpegmatch(utfcharsplitter_iws,str or "")
    else
        return lpegmatch(utfcharsplitter_ows,str or "")
    end
end

function utf.totable(str) -- keeps bom
    return lpegmatch(utfcharsplitter_raw,str)
end

-- 0  EF BB BF      UTF-8
-- 1  FF FE         UTF-16-little-endian
-- 2  FE FF         UTF-16-big-endian
-- 3  FF FE 00 00   UTF-32-little-endian
-- 4  00 00 FE FF   UTF-32-big-endian
--
-- \000 fails in <= 5.0 but is valid in >=5.1 where %z is depricated

-- utf.name = {
--     [0] = 'utf-8',
--     [1] = 'utf-16-le',
--     [2] = 'utf-16-be',
--     [3] = 'utf-32-le',
--     [4] = 'utf-32-be'
-- }
--
-- function utf.magic(f)
--     local str = f:read(4)
--     if not str then
--         f:seek('set')
--         return 0
--  -- elseif find(str,"^%z%z\254\255") then            -- depricated
--  -- elseif find(str,"^\000\000\254\255") then        -- not permitted and bugged
--     elseif find(str,"\000\000\254\255",1,true) then  -- seems to work okay (TH)
--         return 4
--  -- elseif find(str,"^\255\254%z%z") then            -- depricated
--  -- elseif find(str,"^\255\254\000\000") then        -- not permitted and bugged
--     elseif find(str,"\255\254\000\000",1,true) then  -- seems to work okay (TH)
--         return 3
--     elseif find(str,"^\254\255") then
--         f:seek('set',2)
--         return 2
--     elseif find(str,"^\255\254") then
--         f:seek('set',2)
--         return 1
--     elseif find(str,"^\239\187\191") then
--         f:seek('set',3)
--         return 0
--     else
--         f:seek('set')
--         return 0
--     end
-- end

function utf.magic(f) -- not used
    local str = f:read(4) or ""
    local off = lpegmatch(p_utfoffset,str)
    if off < 4 then
        f:seek('set',off)
    end
    return lpegmatch(p_utftype,str)
end

local utf16_to_utf8_be, utf16_to_utf8_le
local utf32_to_utf8_be, utf32_to_utf8_le

local utf_16_be_linesplitter = patterns.utfbom_16_be^-1 * lpeg.tsplitat(patterns.utf_16_be_nl)
local utf_16_le_linesplitter = patterns.utfbom_16_le^-1 * lpeg.tsplitat(patterns.utf_16_le_nl)

-- we have three possibilities:

-- bytepairs: 0.048
-- gmatch   : 0.069
-- lpeg     : 0.089 (match time captures)

if bytepairs then

    -- with a little bit more code we could include the linesplitter

    utf16_to_utf8_be = function(t)
        if type(t) == "string" then
            t = lpegmatch(utf_16_be_linesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, 0
            for left, right in bytepairs(t[i]) do
                if right then
                    local now = 256*left + right
                    if more > 0 then
                        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                        more = 0
                        r = r + 1
                        result[r] = utfchar(now)
                    elseif now >= 0xD800 and now <= 0xDBFF then
                        more = now
                    else
                        r = r + 1
                        result[r] = utfchar(now)
                    end
                end
            end
            t[i] = concat(result,"",1,r) -- we reused tmp, hence t
        end
        return t
    end

    utf16_to_utf8_le = function(t)
        if type(t) == "string" then
            t = lpegmatch(utf_16_le_linesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, 0
            for left, right in bytepairs(t[i]) do
                if right then
                    local now = 256*right + left
                    if more > 0 then
                        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                        more = 0
                        r = r + 1
                        result[r] = utfchar(now)
                    elseif now >= 0xD800 and now <= 0xDBFF then
                        more = now
                    else
                        r = r + 1
                        result[r] = utfchar(now)
                    end
                end
            end
            t[i] = concat(result,"",1,r) -- we reused tmp, hence t
        end
        return t
    end

    utf32_to_utf8_be = function(t)
        if type(t) == "string" then
            t = lpegmatch(utflinesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, -1
            for a,b in bytepairs(t[i]) do
                if a and b then
                    if more < 0 then
                        more = 256*256*256*a + 256*256*b
                    else
                        r = r + 1
                        result[t] = utfchar(more + 256*a + b)
                        more = -1
                    end
                else
                    break
                end
            end
            t[i] = concat(result,"",1,r)
        end
        return t
    end

    utf32_to_utf8_le = function(t)
        if type(t) == "string" then
            t = lpegmatch(utflinesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, -1
            for a,b in bytepairs(t[i]) do
                if a and b then
                    if more < 0 then
                        more = 256*b + a
                    else
                        r = r + 1
                        result[t] = utfchar(more + 256*256*256*b + 256*256*a)
                        more = -1
                    end
                else
                    break
                end
            end
            t[i] = concat(result,"",1,r)
        end
        return t
    end

else

    utf16_to_utf8_be = function(t)
        if type(t) == "string" then
            t = lpegmatch(utf_16_be_linesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, 0
            for left, right in gmatch(t[i],"(.)(.)") do
                if left == "\000" then -- experiment
                    r = r + 1
                    result[r] = utfchar(byte(right))
                elseif right then
                    local now = 256*byte(left) + byte(right)
                    if more > 0 then
                        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                        more = 0
                        r = r + 1
                        result[r] = utfchar(now)
                    elseif now >= 0xD800 and now <= 0xDBFF then
                        more = now
                    else
                        r = r + 1
                        result[r] = utfchar(now)
                    end
                end
            end
            t[i] = concat(result,"",1,r) -- we reused tmp, hence t
        end
        return t
    end

    utf16_to_utf8_le = function(t)
        if type(t) == "string" then
            t = lpegmatch(utf_16_le_linesplitter,t)
        end
        local result = { } -- we reuse result
        for i=1,#t do
            local r, more = 0, 0
            for left, right in gmatch(t[i],"(.)(.)") do
                if right == "\000" then
                    r = r + 1
                    result[r] = utfchar(byte(left))
                elseif right then
                    local now = 256*byte(right) + byte(left)
                    if more > 0 then
                        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                        more = 0
                        r = r + 1
                        result[r] = utfchar(now)
                    elseif now >= 0xD800 and now <= 0xDBFF then
                        more = now
                    else
                        r = r + 1
                        result[r] = utfchar(now)
                    end
                end
            end
            t[i] = concat(result,"",1,r) -- we reused tmp, hence t
        end
        return t
    end

    utf32_to_utf8_le = function() return { } end -- never used anyway
    utf32_to_utf8_be = function() return { } end -- never used anyway

    -- the next one is slighty slower

    -- local result, lines, r, more = { }, { }, 0, 0
    --
    -- local simple = Cmt(
    --     C(1) * C(1), function(str,p,left,right)
    --         local now = 256*byte(left) + byte(right)
    --         if more > 0 then
    --             now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
    --             more = 0
    --             r = r + 1
    --             result[r] = utfchar(now)
    --         elseif now >= 0xD800 and now <= 0xDBFF then
    --             more = now
    --         else
    --             r = r + 1
    --             result[r] = utfchar(now)
    --         end
    --         return p
    --    end
    -- )
    --
    -- local complex = Cmt(
    --     C(1) * C(1), function(str,p,left,right)
    --         local now = 256*byte(left) + byte(right)
    --         if more > 0 then
    --             now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
    --             more = 0
    --             r = r + 1
    --             result[r] = utfchar(now)
    --         elseif now >= 0xD800 and now <= 0xDBFF then
    --             more = now
    --         else
    --             r = r + 1
    --             result[r] = utfchar(now)
    --         end
    --         return p
    --    end
    -- )
    --
    -- local lineend = Cmt (
    --     patterns.utf_16_be_nl, function(str,p)
    --         lines[#lines+1] = concat(result,"",1,r)
    --         r, more = 0, 0
    --         return p
    --     end
    -- )
    --
    -- local be_1 = patterns.utfbom_16_be^-1 * (simple + complex)^0
    -- local be_2 = patterns.utfbom_16_be^-1 * (lineend + simple + complex)^0
    --
    -- utf16_to_utf8_be = function(t)
    --     if type(t) == "string" then
    --         local s = t
    --         lines, r, more = { }, 0, 0
    --         lpegmatch(be_2,s)
    --         if r > 0 then
    --             lines[#lines+1] = concat(result,"",1,r)
    --         end
    --         result = { }
    --         return lines
    --     else
    --         for i=1,#t do
    --             r, more = 0, 0
    --             lpegmatch(be_1,t[i])
    --             t[i] = concat(result,"",1,r)
    --         end
    --         result = { }
    --         return t
    --     end
    -- end

end

utf.utf16_to_utf8_le = utf16_to_utf8_le
utf.utf16_to_utf8_be = utf16_to_utf8_be
utf.utf32_to_utf8_le = utf32_to_utf8_le
utf.utf32_to_utf8_be = utf32_to_utf8_be

function utf.utf8_to_utf8(t)
    return type(t) == "string" and lpegmatch(utflinesplitter,t) or t
end

function utf.utf16_to_utf8(t,endian)
    return endian and utf16_to_utf8_be(t) or utf16_to_utf8_le(t) or t
end

function utf.utf32_to_utf8(t,endian)
    return endian and utf32_to_utf8_be(t) or utf32_to_utf8_le(t) or t
end

local function little(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b%256,b/256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1%256,b1/256,b2%256,b2/256)
    end
end

local function big(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b/256,b%256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1/256,b1%256,b2/256,b2%256)
    end
end

-- function utf.utf8_to_utf16(str,littleendian)
--     if littleendian then
--         return char(255,254) .. utfgsub(str,".",little)
--     else
--         return char(254,255) .. utfgsub(str,".",big)
--     end
-- end

local _, l_remap = utf.remapper(little)
local _, b_remap = utf.remapper(big)

function utf.utf8_to_utf16_be(str,nobom)
    if nobom then
        return lpegmatch(b_remap,str)
    else
        return char(254,255) .. lpegmatch(b_remap,str)
    end
end

function utf.utf8_to_utf16_le(str,nobom)
    if nobom then
        return lpegmatch(l_remap,str)
    else
        return char(255,254) .. lpegmatch(l_remap,str)
    end
end

function utf.utf8_to_utf16(str,littleendian,nobom)
    if littleendian then
        return utf.utf8_to_utf16_le(str,nobom)
    else
        return utf.utf8_to_utf16_be(str,nobom)
    end
end

-- function utf.tocodes(str,separator) -- can be sped up with an lpeg
--     local t, n = { }, 0
--     for u in utfvalues(str) do
--         n = n + 1
--         t[n] = format("0x%04X",u)
--     end
--     return concat(t,separator or " ")
-- end

local pattern = Cs (
    (p_utf8byte           / function(unicode          ) return format(  "0x%04X",          unicode) end) *
    (p_utf8byte * Carg(1) / function(unicode,separator) return format("%s0x%04X",separator,unicode) end)^0
)

function utf.tocodes(str,separator)
    return lpegmatch(pattern,str,1,separator or " ")
end

function utf.ustring(s)
    return format("U+%05X",type(s) == "number" and s or utfbyte(s))
end

function utf.xstring(s)
    return format("0x%05X",type(s) == "number" and s or utfbyte(s))
end

function utf.toeight(str)
    if not str then
        return nil
    end
    local utftype = lpegmatch(p_utfstricttype,str)
    if utftype == "utf-8" then
        return sub(str,4)
    elseif utftype == "utf-16-le" then
        return utf16_to_utf8_le(str)
    elseif utftype == "utf-16-be" then
        return utf16_to_utf8_ne(str)
    else
        return str
    end
end

--

local p_nany = p_utf8char / ""

if utfgmatch then

    function utf.count(str,what)
        if type(what) == "string" then
            local n = 0
            for _ in utfgmatch(str,what) do
                n = n + 1
            end
            return n
        else -- 4 times slower but still faster than / function
            return #lpegmatch(Cs((P(what)/" " + p_nany)^0),str)
        end
    end

else

    local cache = { }

    function utf.count(str,what)
        if type(what) == "string" then
            local p = cache[what]
            if not p then
                p = Cs((P(what)/" " + p_nany)^0)
                cache[p] = p
            end
            return #lpegmatch(p,str)
        else -- 4 times slower but still faster than / function
            return #lpegmatch(Cs((P(what)/" " + p_nany)^0),str)
        end
    end

end

-- maybe also register as string.utf*


if not utf.characters then

    -- New: this gmatch hack is taken from the Lua 5.2 book. It's about two times slower
    -- than the built-in string.utfcharacters.

    function utf.characters(str)
        return gmatch(str,".[\128-\191]*")
    end

    string.utfcharacters = utf.characters

end

if not utf.values then

    -- So, a logical next step is to check for the values variant. It over five times
    -- slower than the built-in string.utfvalues. I optimized it a bit for n=0,1.

    ----- wrap, yield, gmatch = coroutine.wrap, coroutine.yield, string.gmatch
    local find =  string.find

    local dummy = function()
        -- we share this one
    end

    -- function utf.values(str)
    --     local n = #str
    --     if n == 0 then
    --         return wrap(dummy)
    --     elseif n == 1 then
    --         return wrap(function() yield(utfbyte(str)) end)
    --     else
    --         return wrap(function() for s in gmatch(str,".[\128-\191]*") do
    --             yield(utfbyte(s))
    --         end end)
    --     end
    -- end
    --
    -- faster:

    function utf.values(str)
        local n = #str
        if n == 0 then
            return dummy
        elseif n == 1 then
            return function() return utfbyte(str) end
        else
            local p = 1
         -- local n = #str
            return function()
             -- if p <= n then -- slower than the last find
                    local b, e = find(str,".[\128-\191]*",p)
                    if b then
                        p = e + 1
                        return utfbyte(sub(str,b,e))
                    end
             -- end
            end
        end
    end

    -- slower:
    --
    -- local pattern = C(patterns.utf8character) * Cp()
    -- ----- pattern = patterns.utf8character/utfbyte * Cp()
    -- ----- pattern = patterns.utf8byte * Cp()
    --
    -- function utf.values(str) -- one of the cases where a find is faster than an lpeg
    --     local n = #str
    --     if n == 0 then
    --         return dummy
    --     elseif n == 1 then
    --         return function() return utfbyte(str) end
    --     else
    --         local p = 1
    --         return function()
    --             local s, e = lpegmatch(pattern,str,p)
    --             if e then
    --                 p = e
    --                 return utfbyte(s)
    --              -- return s
    --             end
    --         end
    --     end
    -- end

    string.utfvalues = utf.values

end

function utf.chrlen(u) -- u is number
    return
        (u < 0x80 and 1) or
        (u < 0xE0 and 2) or
        (u < 0xF0 and 3) or
        (u < 0xF8 and 4) or
        (u < 0xFC and 5) or
        (u < 0xFE and 6) or 0
end
