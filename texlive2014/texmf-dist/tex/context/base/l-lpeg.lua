if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- lpeg 12 vs lpeg 10: slower compilation, similar parsing speed (i need to check
-- if i can use new features like capture / 2 and .B (at first sight the xml
-- parser is some 5% slower)

-- a new lpeg fails on a #(1-P(":")) test and really needs a + P(-1)

-- move utf    -> l-unicode
-- move string -> l-string or keep it here

lpeg = require("lpeg")

-- The latest lpeg doesn't have print any more, and even the new ones are not
-- available by default (only when debug mode is enabled), which is a pitty as
-- as it helps nailign down bottlenecks. Performance seems comparable: some 10%
-- slower pattern compilation, same parsing speed, although,
--
-- local p = lpeg.C(lpeg.P(1)^0 * lpeg.P(-1))
-- local a = string.rep("123",100)
-- lpeg.match(p,a)
--
-- seems slower and is also still suboptimal (i.e. a match that runs from begin
-- to end, one of the cases where string matchers win).

if not lpeg.print then function lpeg.print(...) print(lpeg.pcode(...)) end end

-- tracing (only used when we encounter a problem in integration of lpeg in luatex)

-- some code will move to unicode and string

-- local lpmatch = lpeg.match
-- local lpprint = lpeg.print
-- local lpp     = lpeg.P
-- local lpr     = lpeg.R
-- local lps     = lpeg.S
-- local lpc     = lpeg.C
-- local lpb     = lpeg.B
-- local lpv     = lpeg.V
-- local lpcf    = lpeg.Cf
-- local lpcb    = lpeg.Cb
-- local lpcg    = lpeg.Cg
-- local lpct    = lpeg.Ct
-- local lpcs    = lpeg.Cs
-- local lpcc    = lpeg.Cc
-- local lpcmt   = lpeg.Cmt
-- local lpcarg  = lpeg.Carg

-- function lpeg.match(l,...) print("LPEG MATCH") lpprint(l) return lpmatch(l,...) end

-- function lpeg.P    (l) local p = lpp   (l) print("LPEG P =")    lpprint(l) return p end
-- function lpeg.R    (l) local p = lpr   (l) print("LPEG R =")    lpprint(l) return p end
-- function lpeg.S    (l) local p = lps   (l) print("LPEG S =")    lpprint(l) return p end
-- function lpeg.C    (l) local p = lpc   (l) print("LPEG C =")    lpprint(l) return p end
-- function lpeg.B    (l) local p = lpb   (l) print("LPEG B =")    lpprint(l) return p end
-- function lpeg.V    (l) local p = lpv   (l) print("LPEG V =")    lpprint(l) return p end
-- function lpeg.Cf   (l) local p = lpcf  (l) print("LPEG Cf =")   lpprint(l) return p end
-- function lpeg.Cb   (l) local p = lpcb  (l) print("LPEG Cb =")   lpprint(l) return p end
-- function lpeg.Cg   (l) local p = lpcg  (l) print("LPEG Cg =")   lpprint(l) return p end
-- function lpeg.Ct   (l) local p = lpct  (l) print("LPEG Ct =")   lpprint(l) return p end
-- function lpeg.Cs   (l) local p = lpcs  (l) print("LPEG Cs =")   lpprint(l) return p end
-- function lpeg.Cc   (l) local p = lpcc  (l) print("LPEG Cc =")   lpprint(l) return p end
-- function lpeg.Cmt  (l) local p = lpcmt (l) print("LPEG Cmt =")  lpprint(l) return p end
-- function lpeg.Carg (l) local p = lpcarg(l) print("LPEG Carg =") lpprint(l) return p end

local type, next, tostring = type, next, tostring
local byte, char, gmatch, format = string.byte, string.char, string.gmatch, string.format
----- mod, div = math.mod, math.div
local floor = math.floor

local P, R, S, V, Ct, C, Cs, Cc, Cp, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Cp, lpeg.Cmt
local lpegtype, lpegmatch, lpegprint = lpeg.type, lpeg.match, lpeg.print

-- let's start with an inspector:

if setinspector then
    setinspector(function(v) if lpegtype(v) then lpegprint(v) return true end end)
end

-- Beware, we predefine a bunch of patterns here and one reason for doing so
-- is that we get consistent behaviour in some of the visualizers.

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local anything         = P(1)
local endofstring      = P(-1)
local alwaysmatched    = P(true)

patterns.anything      = anything
patterns.endofstring   = endofstring
patterns.beginofstring = alwaysmatched
patterns.alwaysmatched = alwaysmatched

local sign             = S('+-')
local zero             = P('0')
local digit            = R('09')
local octdigit         = R("07")
local lowercase        = R("az")
local uppercase        = R("AZ")
local underscore       = P("_")
local hexdigit         = digit + lowercase + uppercase
local cr, lf, crlf     = P("\r"), P("\n"), P("\r\n")
----- newline          = crlf + S("\r\n") -- cr + lf
local newline          = P("\r") * (P("\n") + P(true)) + P("\n")
local escaped          = P("\\") * anything
local squote           = P("'")
local dquote           = P('"')
local space            = P(" ")
local period           = P(".")
local comma            = P(",")

local utfbom_32_be     = P('\000\000\254\255') -- 00 00 FE FF
local utfbom_32_le     = P('\255\254\000\000') -- FF FE 00 00
local utfbom_16_be     = P('\254\255')         -- FE FF
local utfbom_16_le     = P('\255\254')         -- FF FE
local utfbom_8         = P('\239\187\191')     -- EF BB BF
local utfbom           = utfbom_32_be + utfbom_32_le
                       + utfbom_16_be + utfbom_16_le
                       + utfbom_8
local utftype          = utfbom_32_be * Cc("utf-32-be") + utfbom_32_le  * Cc("utf-32-le")
                       + utfbom_16_be * Cc("utf-16-be") + utfbom_16_le  * Cc("utf-16-le")
                       + utfbom_8     * Cc("utf-8")     + alwaysmatched * Cc("utf-8") -- assume utf8
local utfstricttype    = utfbom_32_be * Cc("utf-32-be") + utfbom_32_le  * Cc("utf-32-le")
                       + utfbom_16_be * Cc("utf-16-be") + utfbom_16_le  * Cc("utf-16-le")
                       + utfbom_8     * Cc("utf-8")
local utfoffset        = utfbom_32_be * Cc(4) + utfbom_32_le * Cc(4)
                       + utfbom_16_be * Cc(2) + utfbom_16_le * Cc(2)
                       + utfbom_8     * Cc(3) + Cc(0)

local utf8next         = R("\128\191")

patterns.utfbom_32_be  = utfbom_32_be
patterns.utfbom_32_le  = utfbom_32_le
patterns.utfbom_16_be  = utfbom_16_be
patterns.utfbom_16_le  = utfbom_16_le
patterns.utfbom_8      = utfbom_8

patterns.utf_16_be_nl  = P("\000\r\000\n") + P("\000\r") + P("\000\n") -- P("\000\r") * (P("\000\n") + P(true)) + P("\000\n")
patterns.utf_16_le_nl  = P("\r\000\n\000") + P("\r\000") + P("\n\000") -- P("\r\000") * (P("\n\000") + P(true)) + P("\n\000")

patterns.utf8one       = R("\000\127")
patterns.utf8two       = R("\194\223") * utf8next
patterns.utf8three     = R("\224\239") * utf8next * utf8next
patterns.utf8four      = R("\240\244") * utf8next * utf8next * utf8next
patterns.utfbom        = utfbom
patterns.utftype       = utftype
patterns.utfstricttype = utfstricttype
patterns.utfoffset     = utfoffset

local utf8char         = patterns.utf8one + patterns.utf8two + patterns.utf8three + patterns.utf8four
local validutf8char    = utf8char^0 * endofstring * Cc(true) + Cc(false)

local utf8character    = P(1) * R("\128\191")^0 -- unchecked but fast

patterns.utf8          = utf8char
patterns.utf8char      = utf8char
patterns.utf8character = utf8character -- this one can be used in most cases so we might use that one
patterns.validutf8     = validutf8char
patterns.validutf8char = validutf8char

local eol              = S("\n\r")
local spacer           = S(" \t\f\v")  -- + char(0xc2, 0xa0) if we want utf (cf mail roberto)
local whitespace       = eol + spacer
local nonspacer        = 1 - spacer
local nonwhitespace    = 1 - whitespace

patterns.eol           = eol
patterns.spacer        = spacer
patterns.whitespace    = whitespace
patterns.nonspacer     = nonspacer
patterns.nonwhitespace = nonwhitespace

local stripper         = spacer    ^0 * C((spacer    ^0 * nonspacer    ^1)^0)     -- from example by roberto
local fullstripper     = whitespace^0 * C((whitespace^0 * nonwhitespace^1)^0)

----- collapser        = Cs(spacer^0/"" * ((spacer^1 * endofstring / "") + (spacer^1/" ") + P(1))^0)
local collapser        = Cs(spacer^0/"" * nonspacer^0 * ((spacer^0/" " * nonspacer^1)^0))

patterns.stripper      = stripper
patterns.fullstripper  = fullstripper
patterns.collapser     = collapser

patterns.lowercase     = lowercase
patterns.uppercase     = uppercase
patterns.letter        = patterns.lowercase + patterns.uppercase
patterns.space         = space
patterns.tab           = P("\t")
patterns.spaceortab    = patterns.space + patterns.tab
patterns.newline       = newline
patterns.emptyline     = newline^1
patterns.equal         = P("=")
patterns.comma         = comma
patterns.commaspacer   = comma * spacer^0
patterns.period        = period
patterns.colon         = P(":")
patterns.semicolon     = P(";")
patterns.underscore    = underscore
patterns.escaped       = escaped
patterns.squote        = squote
patterns.dquote        = dquote
patterns.nosquote      = (escaped + (1-squote))^0
patterns.nodquote      = (escaped + (1-dquote))^0
patterns.unsingle      = (squote/"") * patterns.nosquote * (squote/"") -- will change to C in the middle
patterns.undouble      = (dquote/"") * patterns.nodquote * (dquote/"") -- will change to C in the middle
patterns.unquoted      = patterns.undouble + patterns.unsingle -- more often undouble
patterns.unspacer      = ((patterns.spacer^1)/"")^0

patterns.singlequoted  = squote * patterns.nosquote * squote
patterns.doublequoted  = dquote * patterns.nodquote * dquote
patterns.quoted        = patterns.doublequoted + patterns.singlequoted

patterns.digit         = digit
patterns.octdigit      = octdigit
patterns.hexdigit      = hexdigit
patterns.sign          = sign
patterns.cardinal      = digit^1
patterns.integer       = sign^-1 * digit^1
patterns.unsigned      = digit^0 * period * digit^1
patterns.float         = sign^-1 * patterns.unsigned
patterns.cunsigned     = digit^0 * comma * digit^1
patterns.cfloat        = sign^-1 * patterns.cunsigned
patterns.number        = patterns.float + patterns.integer
patterns.cnumber       = patterns.cfloat + patterns.integer
patterns.oct           = zero * octdigit^1
patterns.octal         = patterns.oct
patterns.HEX           = zero * P("X") * (digit+uppercase)^1
patterns.hex           = zero * P("x") * (digit+lowercase)^1
patterns.hexadecimal   = zero * S("xX") * hexdigit^1

patterns.hexafloat     = sign^-1
                       * zero * S("xX")
                       * (hexdigit^0 * period * hexdigit^1 + hexdigit^1 * period * hexdigit^0 + hexdigit^1)
                       * (S("pP") * sign^-1 * hexdigit^1)^-1
patterns.decafloat     = sign^-1
                       * (digit^0 * period * digit^1 + digit^1 * period * digit^0 + digit^1)
                       *  S("eE") * sign^-1 * digit^1

patterns.propername    = (uppercase + lowercase + underscore) * (uppercase + lowercase + underscore + digit)^0 * endofstring

patterns.somecontent   = (anything - newline - space)^1 -- (utf8char - newline - space)^1
patterns.beginline     = #(1-newline)

patterns.longtostring  = Cs(whitespace^0/"" * ((patterns.quoted + nonwhitespace^1 + whitespace^1/"" * (P(-1) + Cc(" ")))^0))

local function anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * V(1) }
end

lpeg.anywhere = anywhere

function lpeg.instringchecker(p)
    p = anywhere(p)
    return function(str)
        return lpegmatch(p,str) and true or false
    end
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

function lpeg.tsplitter(pattern, action)
    return Ct((((1-P(pattern))^1)/action+1)^0)
end

-- probleem: separator can be lpeg and that does not hash too well, but
-- it's quite okay as the key is then not garbage collected

local splitters_s, splitters_m, splitters_t = { }, { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        local other = C((1 - separator)^0)
        if single then
            local any = anything
            splitter = other * (separator * C(any^0) + "") -- ?
            splitters_s[separator] = splitter
        else
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

local function tsplitat(separator)
    local splitter = splitters_t[separator]
    if not splitter then
        splitter = Ct(splitat(separator))
        splitters_t[separator] = splitter
    end
    return splitter
end

lpeg.splitat  = splitat
lpeg.tsplitat = tsplitat

function string.splitup(str,separator)
    if not separator then
        separator = ","
    end
    return lpegmatch(splitters_m[separator] or splitat(separator),str)
end

-- local p = splitat("->",false)  print(lpegmatch(p,"oeps->what->more"))  -- oeps what more
-- local p = splitat("->",true)   print(lpegmatch(p,"oeps->what->more"))  -- oeps what->more
-- local p = splitat("->",false)  print(lpegmatch(p,"oeps"))              -- oeps
-- local p = splitat("->",true)   print(lpegmatch(p,"oeps"))              -- oeps

local cache = { }

function lpeg.split(separator,str)
    local c = cache[separator]
    if not c then
        c = tsplitat(separator)
        cache[separator] = c
    end
    return lpegmatch(c,str)
end

function string.split(str,separator)
    if separator then
        local c = cache[separator]
        if not c then
            c = tsplitat(separator)
            cache[separator] = c
        end
        return lpegmatch(c,str)
    else
        return { str }
    end
end

local spacing  = patterns.spacer^0 * newline -- sort of strip
local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

patterns.textline = content

local linesplitter = tsplitat(newline)

patterns.linesplitter = linesplitter

function string.splitlines(str)
    return lpegmatch(linesplitter,str)
end

-- lpeg.splitters = cache -- no longer public

local cache = { }

function lpeg.checkedsplit(separator,str)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return lpegmatch(c,str)
end

function string.checkedsplit(str,separator)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return lpegmatch(c,str)
end

-- from roberto's site:

local function f2(s) local c1, c2         = byte(s,1,2) return   c1 * 64 + c2                       -    12416 end
local function f3(s) local c1, c2, c3     = byte(s,1,3) return  (c1 * 64 + c2) * 64 + c3            -   925824 end
local function f4(s) local c1, c2, c3, c4 = byte(s,1,4) return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168 end

local utf8byte = patterns.utf8one/byte + patterns.utf8two/f2 + patterns.utf8three/f3 + patterns.utf8four/f4

patterns.utf8byte = utf8byte

--~ local str = " a b c d "

--~ local s = lpeg.stripper(lpeg.R("az"))   print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.keeper(lpeg.R("az"))     print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.stripper("ab")           print("["..lpegmatch(s,str).."]")
--~ local s = lpeg.keeper("ab")             print("["..lpegmatch(s,str).."]")

local cache = { }

function lpeg.stripper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs(((S(str)^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs(((str^1)/"" + 1)^0)
    end
end

local cache = { }

function lpeg.keeper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs((((1-S(str))^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs((((1-str)^1)/"" + 1)^0)
    end
end

function lpeg.frontstripper(str) -- or pattern (yet undocumented)
    return (P(str) + P(true)) * Cs(anything^0)
end

function lpeg.endstripper(str) -- or pattern (yet undocumented)
    return Cs((1 - P(str) * endofstring)^0)
end

-- Just for fun I looked at the used bytecode and
-- p = (p and p + pp) or pp gets one more (testset).

-- todo: cache when string

function lpeg.replacer(one,two,makefunction,isutf) -- in principle we should sort the keys
    local pattern
    local u = isutf and utf8char or 1
    if type(one) == "table" then
        local no = #one
        local p = P(false)
        if no == 0 then
            for k, v in next, one do
                p = p + P(k) / v
            end
            pattern = Cs((p + u)^0)
        elseif no == 1 then
            local o = one[1]
            one, two = P(o[1]), o[2]
         -- pattern = Cs(((1-one)^1 + one/two)^0)
            pattern = Cs((one/two + u)^0)
        else
            for i=1,no do
                local o = one[i]
                p = p + P(o[1]) / o[2]
            end
            pattern = Cs((p + u)^0)
        end
    else
        pattern = Cs((P(one)/(two or "") + u)^0)
    end
    if makefunction then
        return function(str)
            return lpegmatch(pattern,str)
        end
    else
        return pattern
    end
end

-- local pattern1 = P(1-P(pattern))^0 * P(pattern)   : test for not nil
-- local pattern2 = (P(pattern) * Cc(true) + P(1))^0 : test for true (could be faster, but not much)

function lpeg.finder(lst,makefunction,isutf) -- beware: slower than find with 'patternless finds'
    local pattern
    if type(lst) == "table" then
        pattern = P(false)
        if #lst == 0 then
            for k, v in next, lst do
                pattern = pattern + P(k) -- ignore key, so we can use a replacer table
            end
        else
            for i=1,#lst do
                pattern = pattern + P(lst[i])
            end
        end
    else
        pattern = P(lst)
    end
    if isutf then
--         pattern = ((utf8char or 1)-pattern)^0 * pattern
        pattern = ((utf8char or 1)-pattern)^0 * pattern
    else
        pattern = (1-pattern)^0 * pattern
    end
    if makefunction then
        return function(str)
            return lpegmatch(pattern,str)
        end
    else
        return pattern
    end
end

-- print(lpeg.match(lpeg.replacer("e","a"),"test test"))
-- print(lpeg.match(lpeg.replacer{{"e","a"}},"test test"))
-- print(lpeg.match(lpeg.replacer({ e = "a", t = "x" }),"test test"))

local splitters_f, splitters_s = { }, { }

function lpeg.firstofsplit(separator) -- always return value
    local splitter = splitters_f[separator]
    if not splitter then
        local pattern = P(separator)
        splitter = C((1 - pattern)^0)
        splitters_f[separator] = splitter
    end
    return splitter
end

function lpeg.secondofsplit(separator) -- nil if not split
    local splitter = splitters_s[separator]
    if not splitter then
        local pattern = P(separator)
        splitter = (1 - pattern)^0 * pattern * C(anything^0)
        splitters_s[separator] = splitter
    end
    return splitter
end

local splitters_s, splitters_p = { }, { }

function lpeg.beforesuffix(separator) -- nil if nothing but empty is ok
    local splitter = splitters_s[separator]
    if not splitter then
        local pattern = P(separator)
        splitter = C((1 - pattern)^0) * pattern * endofstring
        splitters_s[separator] = splitter
    end
    return splitter
end

function lpeg.afterprefix(separator) -- nil if nothing but empty is ok
    local splitter = splitters_p[separator]
    if not splitter then
        local pattern = P(separator)
        splitter = pattern * C(anything^0)
        splitters_p[separator] = splitter
    end
    return splitter
end

function lpeg.balancer(left,right)
    left, right = P(left), P(right)
    return P { left * ((1 - left - right) + V(1))^0 * right }
end

-- print(1,lpegmatch(lpeg.firstofsplit(":"),"bc:de"))
-- print(2,lpegmatch(lpeg.firstofsplit(":"),":de")) -- empty
-- print(3,lpegmatch(lpeg.firstofsplit(":"),"bc"))
-- print(4,lpegmatch(lpeg.secondofsplit(":"),"bc:de"))
-- print(5,lpegmatch(lpeg.secondofsplit(":"),"bc:")) -- empty
-- print(6,lpegmatch(lpeg.secondofsplit(":",""),"bc"))
-- print(7,lpegmatch(lpeg.secondofsplit(":"),"bc"))
-- print(9,lpegmatch(lpeg.secondofsplit(":","123"),"bc"))

-- -- slower:
--
-- function lpeg.counter(pattern)
--     local n, pattern = 0, (lpeg.P(pattern)/function() n = n + 1 end  + lpeg.anything)^0
--     return function(str) n = 0 ; lpegmatch(pattern,str) ; return n end
-- end

local nany = utf8char/""

function lpeg.counter(pattern)
    pattern = Cs((P(pattern)/" " + nany)^0)
    return function(str)
        return #lpegmatch(pattern,str)
    end
end

-- utf extensies

utf = utf or (unicode and unicode.utf8) or { }

local utfcharacters = utf and utf.characters or string.utfcharacters
local utfgmatch     = utf and utf.gmatch
local utfchar       = utf and utf.char

lpeg.UP = lpeg.P

if utfcharacters then

    function lpeg.US(str)
        local p = P(false)
        for uc in utfcharacters(str) do
            p = p + P(uc)
        end
        return p
    end


elseif utfgmatch then

    function lpeg.US(str)
        local p = P(false)
        for uc in utfgmatch(str,".") do
            p = p + P(uc)
        end
        return p
    end

else

    function lpeg.US(str)
        local p = P(false)
        local f = function(uc)
            p = p + P(uc)
        end
        lpegmatch((utf8char/f)^0,str)
        return p
    end

end

local range = utf8byte * utf8byte + Cc(false) -- utf8byte is already a capture

function lpeg.UR(str,more)
    local first, last
    if type(str) == "number" then
        first = str
        last = more or first
    else
        first, last = lpegmatch(range,str)
        if not last then
            return P(str)
        end
    end
    if first == last then
        return P(str)
    elseif utfchar and (last - first < 8) then -- a somewhat arbitrary criterium
        local p = P(false)
        for i=first,last do
            p = p + P(utfchar(i))
        end
        return p -- nil when invalid range
    else
        local f = function(b)
            return b >= first and b <= last
        end
        -- tricky, these nested captures
        return utf8byte / f -- nil when invalid range
    end
end

-- print(lpeg.match(lpeg.Cs((C(lpeg.UR("αω"))/{ ["χ"] = "OEPS" })^0),"αωχαω"))

-- lpeg.print(lpeg.R("ab","cd","gh"))
-- lpeg.print(lpeg.P("a","b","c"))
-- lpeg.print(lpeg.S("a","b","c"))

-- print(lpeg.count("äáàa",lpeg.P("á") + lpeg.P("à")))
-- print(lpeg.count("äáàa",lpeg.UP("áà")))
-- print(lpeg.count("äáàa",lpeg.US("àá")))
-- print(lpeg.count("äáàa",lpeg.UR("aá")))
-- print(lpeg.count("äáàa",lpeg.UR("àá")))
-- print(lpeg.count("äáàa",lpeg.UR(0x0000,0xFFFF)))

function lpeg.is_lpeg(p)
    return p and lpegtype(p) == "pattern"
end

function lpeg.oneof(list,...) -- lpeg.oneof("elseif","else","if","then") -- assume proper order
    if type(list) ~= "table" then
        list = { list, ... }
    end
 -- table.sort(list) -- longest match first
    local p = P(list[1])
    for l=2,#list do
        p = p + P(list[l])
    end
    return p
end

-- For the moment here, but it might move to utilities. Beware, we need to
-- have the longest keyword first, so 'aaa' comes beforte 'aa' which is why we
-- loop back from the end cq. prepend.

local sort = table.sort

local function copyindexed(old)
    local new = { }
    for i=1,#old do
        new[i] = old
    end
    return new
end

local function sortedkeys(tab)
    local keys, s = { }, 0
    for key,_ in next, tab do
        s = s + 1
        keys[s] = key
    end
    sort(keys)
    return keys
end

function lpeg.append(list,pp,delayed,checked)
    local p = pp
    if #list > 0 then
        local keys = copyindexed(list)
        sort(keys)
        for i=#keys,1,-1 do
            local k = keys[i]
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
    elseif delayed then -- hm, it looks like the lpeg parser resolves anyway
        local keys = sortedkeys(list)
        if p then
            for i=1,#keys,1 do
                local k = keys[i]
                local v = list[k]
                p = P(k)/list + p
            end
        else
            for i=1,#keys do
                local k = keys[i]
                local v = list[k]
                if p then
                    p = P(k) + p
                else
                    p = P(k)
                end
            end
            if p then
                p = p / list
            end
        end
    elseif checked then
        -- problem: substitution gives a capture
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                if k == v then
                    p = P(k) + p
                else
                    p = P(k)/v + p
                end
            else
                if k == v then
                    p = P(k)
                else
                    p = P(k)/v
                end
            end
        end
    else
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                p = P(k)/v + p
            else
                p = P(k)/v
            end
        end
    end
    return p
end

-- inspect(lpeg.append({ a = "1", aa = "1", aaa = "1" } ,nil,true))
-- inspect(lpeg.append({ ["degree celsius"] = "1", celsius = "1", degree = "1" } ,nil,true))

-- function lpeg.exact_match(words,case_insensitive)
--     local pattern = concat(words)
--     if case_insensitive then
--         local pattern = S(upper(characters)) + S(lower(characters))
--         local list = { }
--         for i=1,#words do
--             list[lower(words[i])] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[lower(s)] and i
--         end)
--     else
--         local pattern = S(concat(words))
--         local list = { }
--         for i=1,#words do
--             list[words[i]] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[s] and i
--         end)
--     end
-- end

-- experiment:

local function make(t)
    local p
    local keys = sortedkeys(t)
    for i=1,#keys do
        local k = keys[i]
        local v = t[k]
        if not p then
            if next(v) then
                p = P(k) * make(v)
            else
                p = P(k)
            end
        else
            if next(v) then
                p = p + P(k) * make(v)
            else
                p = p + P(k)
            end
        end
    end
    return p
end

function lpeg.utfchartabletopattern(list) -- goes to util-lpg
    local tree = { }
    for i=1,#list do
        local t = tree
        for c in gmatch(list[i],".") do
            if not t[c] then
                t[c] = { }
            end
            t = t[c]
        end
    end
    return make(tree)
end

-- inspect ( lpeg.utfchartabletopattern {
--     utfchar(0x00A0), -- nbsp
--     utfchar(0x2000), -- enquad
--     utfchar(0x2001), -- emquad
--     utfchar(0x2002), -- enspace
--     utfchar(0x2003), -- emspace
--     utfchar(0x2004), -- threeperemspace
--     utfchar(0x2005), -- fourperemspace
--     utfchar(0x2006), -- sixperemspace
--     utfchar(0x2007), -- figurespace
--     utfchar(0x2008), -- punctuationspace
--     utfchar(0x2009), -- breakablethinspace
--     utfchar(0x200A), -- hairspace
--     utfchar(0x200B), -- zerowidthspace
--     utfchar(0x202F), -- narrownobreakspace
--     utfchar(0x205F), -- math thinspace
-- } )

-- a few handy ones:
--
-- faster than find(str,"[\n\r]") when match and # > 7 and always faster when # > 3

patterns.containseol = lpeg.finder(eol) -- (1-eol)^0 * eol

-- The next pattern^n variant is based on an approach suggested
-- by Roberto: constructing a big repetition in chunks.
--
-- Being sparse is not needed, and only complicate matters and
-- the number of redundant entries is not that large.

local function nextstep(n,step,result)
    local m = n % step      -- mod(n,step)
    local d = floor(n/step) -- div(n,step)
    if d > 0 then
        local v = V(tostring(step))
        local s = result.start
        for i=1,d do
            if s then
                s = v * s
            else
                s = v
            end
        end
        result.start = s
    end
    if step > 1 and result.start then
        local v = V(tostring(step/2))
        result[tostring(step)] = v * v
    end
    if step > 0 then
        return nextstep(m,step/2,result)
    else
        return result
    end
end

function lpeg.times(pattern,n)
    return P(nextstep(n,2^16,{ "start", ["1"] = pattern }))
end

-- local p = lpeg.Cs((1 - lpeg.times(lpeg.P("AB"),25))^1)
-- local s = "12" .. string.rep("AB",20) .. "34" .. string.rep("AB",30) .. "56"
-- inspect(p)
-- print(lpeg.match(p,s))

-- moved here (before util-str)

----- digit         = R("09")
----- period        = P(".")
----- zero          = P("0")
local trailingzeros = zero^0 * -digit -- suggested by Roberto R
local case_1        = period * trailingzeros / ""
local case_2        = period * (digit - trailingzeros)^1 * (trailingzeros / "")
local number        = digit^1 * (case_1 + case_2)
local stripper      = Cs((number + 1)^0)

lpeg.patterns.stripzeros = stripper

-- local sample = "bla 11.00 bla 11 bla 0.1100 bla 1.00100 bla 0.00 bla 0.001 bla 1.1100 bla 0.100100100 bla 0.00100100100"
-- collectgarbage("collect")
-- str = string.rep(sample,10000)
-- local ts = os.clock()
-- lpegmatch(stripper,str)
-- print(#str, os.clock()-ts, lpegmatch(stripper,sample))

