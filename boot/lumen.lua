delimiters = {[";"] = true, ["("] = true, ["\n"] = true, [")"] = true}
whitespace = {["\t"] = true, ["\n"] = true, [" "] = true}
function make_stream(str)
  return({len = length(str), string = str, pos = 0})
end
function peek_char(s)
  if (s.pos < s.len) then
    return(char(s.string, s.pos))
  end
end
function read_char(s)
  local c = peek_char(s)
  if c then
    s.pos = (s.pos + 1)
    return(c)
  end
end
function skip_non_code(s)
  while true do
    local c = peek_char(s)
    if nil63(c) then
      break
    elseif whitespace[c] then
      read_char(s)
    elseif (c == ";") then
      while (c and (not (c == "\n"))) do
        c = read_char(s)
      end
      skip_non_code(s)
    else
      break
    end
  end
end
read_table = {}
eof = {}
function key63(atom)
  return((string63(atom) and (length(atom) > 1) and (char(atom, (length(atom) - 1)) == ":")))
end
function flag63(atom)
  return((string63(atom) and (length(atom) > 1) and (char(atom, 0) == ":")))
end
read_table[""] = function (s)
  local str = ""
  local dot63 = false
  while true do
    local c = peek_char(s)
    if (c and ((not whitespace[c]) and (not delimiters[c]))) then
      if (c == ".") then
        dot63 = true
      end
      str = (str .. c)
      read_char(s)
    else
      break
    end
  end
  local n = parse_number(str)
  if is63(n) then
    return(n)
  elseif (str == "true") then
    return(true)
  elseif (str == "false") then
    return(false)
  elseif (str == "_") then
    return(make_id())
  elseif dot63 then
    return(reduce(function (a, b)
      return({"get", b, {"quote", a}})
    end, reverse(split(str, "."))))
  else
    return(str)
  end
end
read_table["("] = function (s)
  read_char(s)
  local l = {}
  while true do
    skip_non_code(s)
    local c = peek_char(s)
    if (c and (not (c == ")"))) then
      local x = read(s)
      if key63(x) then
        local k = sub(x, 0, (length(x) - 1))
        local v = read(s)
        l[k] = v
      elseif flag63(x) then
        l[sub(x, 1)] = true
      else
        add(l, x)
      end
    elseif c then
      read_char(s)
      break
    else
      error(("Expected ) at " .. s.pos))
    end
  end
  return(l)
end
read_table[")"] = function (s)
  error(("Unexpected ) at " .. s.pos))
end
read_table["\""] = function (s)
  read_char(s)
  local str = "\""
  while true do
    local c = peek_char(s)
    if (c and (not (c == "\""))) then
      if (c == "\\") then
        str = (str .. read_char(s))
      end
      str = (str .. read_char(s))
    elseif c then
      read_char(s)
      break
    else
      error(("Expected \" at " .. s.pos))
    end
  end
  return((str .. "\""))
end
read_table["|"] = function (s)
  read_char(s)
  local str = "|"
  while true do
    local c = peek_char(s)
    if (c and (not (c == "|"))) then
      str = (str .. read_char(s))
    elseif c then
      read_char(s)
      break
    else
      error(("Expected | at " .. s.pos))
    end
  end
  return((str .. "|"))
end
read_table["'"] = function (s)
  read_char(s)
  return({"quote", read(s)})
end
read_table["`"] = function (s)
  read_char(s)
  return({"quasiquote", read(s)})
end
read_table[","] = function (s)
  read_char(s)
  if (peek_char(s) == "@") then
    read_char(s)
    return({"unquote-splicing", read(s)})
  else
    return({"unquote", read(s)})
  end
end
function read(s)
  skip_non_code(s)
  local c = peek_char(s)
  if is63(c) then
    return(((read_table[c] or read_table[""]))(s))
  else
    return(eof)
  end
end
function read_all(s)
  local l = {}
  while true do
    local form = read(s)
    if (form == eof) then
      break
    end
    add(l, form)
  end
  return(l)
end
function read_from_string(str)
  return(read(make_stream(str)))
end
function setenv(k, ...)
  local keys = unstash({...})
  local _g9 = sub(keys, 0)
  if string63(k) then
    local frame = last(environment)
    local x = (frame[k] or {})
    local k1 = nil
    local _g10 = _g9
    for k1 in next, _g10 do
      if (not number63(k1)) then
        local v = _g10[k1]
        x[k1] = v
      end
    end
    x.module = current_module
    frame[k] = x
  end
end
function getenv(k)
  if string63(k) then
    return(find(function (e)
      return(e[k])
    end, reverse(environment)))
  end
end
function macro_function(k)
  local b = getenv(k)
  return((b and b.macro))
end
function macro63(k)
  return(is63(macro_function(k)))
end
function special63(k)
  local b = getenv(k)
  return((b and is63(b.special)))
end
function special_form63(form)
  return((list63(form) and special63(hd(form))))
end
function symbol_expansion(k)
  local b = getenv(k)
  return((b and b.symbol))
end
function symbol63(k)
  return(is63(symbol_expansion(k)))
end
function variable63(k)
  local b = last(environment)[k]
  return((b and is63(b.variable)))
end
function bound63(x)
  return((macro63(x) or special63(x) or symbol63(x) or variable63(x)))
end
function escape(str)
  local str1 = "\""
  local i = 0
  while (i < length(str)) do
    local c = char(str, i)
    local c1 = (function ()
      if (c == "\n") then
        return("\\n")
      elseif (c == "\"") then
        return("\\\"")
      elseif (c == "\\") then
        return("\\\\")
      else
        return(c)
      end
    end)()
    str1 = (str1 .. c1)
    i = (i + 1)
  end
  return((str1 .. "\""))
end
function quoted(form)
  if string63(form) then
    return(escape(form))
  elseif atom63(form) then
    return(form)
  else
    return(join({"list"}, map42(quoted, form)))
  end
end
function stash(args)
  if keys63(args) then
    local p = {_stash = true}
    local k = nil
    local _g62 = args
    for k in next, _g62 do
      if (not number63(k)) then
        local v = _g62[k]
        p[k] = v
      end
    end
    return(join(args, {p}))
  else
    return(args)
  end
end
function stash42(args)
  if keys63(args) then
    local l = {"%object", "_stash", true}
    local k = nil
    local _g63 = args
    for k in next, _g63 do
      if (not number63(k)) then
        local v = _g63[k]
        add(l, k)
        add(l, v)
      end
    end
    return(join(args, {l}))
  else
    return(args)
  end
end
function unstash(args)
  if empty63(args) then
    return({})
  else
    local l = last(args)
    if (table63(l) and l._stash) then
      local args1 = sub(args, 0, (length(args) - 1))
      local k = nil
      local _g64 = l
      for k in next, _g64 do
        if (not number63(k)) then
          local v = _g64[k]
          if (k ~= "_stash") then
            args1[k] = v
          end
        end
      end
      return(args1)
    else
      return(args)
    end
  end
end
function bind_arguments(args, body)
  local args1 = {}
  local rest = function ()
    if (target == "js") then
      return({"unstash", {"sublist", "arguments", length(args1)}})
    else
      add(args1, "|...|")
      return({"unstash", {"list", "|...|"}})
    end
  end
  if atom63(args) then
    return({args1, {join({"let", {args, rest()}}, body)}})
  else
    local bs = {}
    local r = (args.rest or (keys63(args) and make_id()))
    local _g66 = 0
    local _g65 = args
    while (_g66 < length(_g65)) do
      local arg = _g65[(_g66 + 1)]
      if atom63(arg) then
        add(args1, arg)
      elseif (list63(arg) or keys63(arg)) then
        local v = make_id()
        add(args1, v)
        bs = join(bs, {arg, v})
      end
      _g66 = (_g66 + 1)
    end
    if r then
      bs = join(bs, {r, rest()})
    end
    if keys63(args) then
      bs = join(bs, {sub(args, length(args)), r})
    end
    if empty63(bs) then
      return({args1, body})
    else
      return({args1, {join({"let", bs}, body)}})
    end
  end
end
function bind(lh, rh)
  if (composite63(lh) and list63(rh)) then
    local id = make_id()
    return(join({{id, rh}}, bind(lh, id)))
  elseif atom63(lh) then
    return({{lh, rh}})
  else
    local bs = {}
    local r = lh.rest
    local i = 0
    local _g67 = lh
    while (i < length(_g67)) do
      local x = _g67[(i + 1)]
      bs = join(bs, bind(x, {"at", rh, i}))
      i = (i + 1)
    end
    if r then
      bs = join(bs, bind(r, {"sub", rh, length(lh)}))
    end
    local k = nil
    local _g68 = lh
    for k in next, _g68 do
      if (not number63(k)) then
        local v = _g68[k]
        if (v == true) then
          v = k
        end
        if (k ~= "rest") then
          bs = join(bs, bind(v, {"get", rh, {"quote", k}}))
        end
      end
    end
    return(bs)
  end
end
function message_handler(msg)
  local i = search(msg, ": ")
  return(sub(msg, (i + 2)))
end
function quoting63(depth)
  return(number63(depth))
end
function quasiquoting63(depth)
  return((quoting63(depth) and (depth > 0)))
end
function can_unquote63(depth)
  return((quoting63(depth) and (depth == 1)))
end
function quasisplice63(x, depth)
  return((list63(x) and can_unquote63(depth) and (hd(x) == "unquote-splicing")))
end
function macroexpand(form)
  if symbol63(form) then
    return(macroexpand(symbol_expansion(form)))
  elseif atom63(form) then
    return(form)
  else
    local x = hd(form)
    if (x == "%for") then
      local _g6 = form[1]
      local _g69 = form[2]
      local t = _g69[1]
      local k = _g69[2]
      local body = sub(form, 2)
      return(join({"%for", {macroexpand(t), macroexpand(k)}}, macroexpand(body)))
    elseif (x == "%function") then
      local _g7 = form[1]
      local args = form[2]
      local _g70 = sub(form, 2)
      add(environment, {})
      local _g72 = (function ()
        local _g74 = 0
        local _g73 = args
        while (_g74 < length(_g73)) do
          local _g71 = _g73[(_g74 + 1)]
          setenv(_g71, {_stash = true, variable = true})
          _g74 = (_g74 + 1)
        end
        return(join({"%function", map42(macroexpand, args)}, macroexpand(_g70)))
      end)()
      drop(environment)
      return(_g72)
    elseif ((x == "%local-function") or (x == "%global-function")) then
      local _g8 = form[1]
      local name = form[2]
      local _g75 = form[3]
      local _g76 = sub(form, 3)
      add(environment, {})
      local _g78 = (function ()
        local _g80 = 0
        local _g79 = _g75
        while (_g80 < length(_g79)) do
          local _g77 = _g79[(_g80 + 1)]
          setenv(_g77, {_stash = true, variable = true})
          _g80 = (_g80 + 1)
        end
        return(join({x, name, map42(macroexpand, _g75)}, macroexpand(_g76)))
      end)()
      drop(environment)
      return(_g78)
    elseif macro63(x) then
      local b = getenv(x)
      return(macroexpand(apply(b.macro, tl(form))))
    else
      return(map42(macroexpand, form))
    end
  end
end
function quasiexpand(form, depth)
  if quasiquoting63(depth) then
    if atom63(form) then
      return({"quote", form})
    elseif (can_unquote63(depth) and (hd(form) == "unquote")) then
      return(quasiexpand(form[2]))
    elseif ((hd(form) == "unquote") or (hd(form) == "unquote-splicing")) then
      return(quasiquote_list(form, (depth - 1)))
    elseif (hd(form) == "quasiquote") then
      return(quasiquote_list(form, (depth + 1)))
    else
      return(quasiquote_list(form, depth))
    end
  elseif atom63(form) then
    return(form)
  elseif (hd(form) == "quote") then
    return(form)
  elseif (hd(form) == "quasiquote") then
    return(quasiexpand(form[2], 1))
  else
    return(map42(function (x)
      return(quasiexpand(x, depth))
    end, form))
  end
end
function quasiquote_list(form, depth)
  local xs = {{"list"}}
  local k = nil
  local _g81 = form
  for k in next, _g81 do
    if (not number63(k)) then
      local v = _g81[k]
      local v = (function ()
        if quasisplice63(v, depth) then
          return(quasiexpand(v[2]))
        else
          return(quasiexpand(v, depth))
        end
      end)()
      last(xs)[k] = v
    end
  end
  local _g83 = 0
  local _g82 = form
  while (_g83 < length(_g82)) do
    local x = _g82[(_g83 + 1)]
    if quasisplice63(x, depth) then
      local x = quasiexpand(x[2])
      add(xs, x)
      add(xs, {"list"})
    else
      add(last(xs), quasiexpand(x, depth))
    end
    _g83 = (_g83 + 1)
  end
  if (length(xs) == 1) then
    return(hd(xs))
  else
    return(reduce(function (a, b)
      return({"join", a, b})
    end, keep(function (x)
      return(((length(x) > 1) or (not (hd(x) == "list")) or keys63(x)))
    end, xs)))
  end
end
target = "lua"
function length(x)
  return(#x)
end
function empty63(x)
  return((length(x) == 0))
end
function substring(str, from, upto)
  return((string.sub)(str, (from + 1), upto))
end
function sublist(l, from, upto)
  local i = (from or 0)
  local j = 0
  local _g84 = (upto or length(l))
  local l2 = {}
  while (i < _g84) do
    l2[(j + 1)] = l[(i + 1)]
    i = (i + 1)
    j = (j + 1)
  end
  return(l2)
end
function sub(x, from, upto)
  local _g85 = (from or 0)
  if string63(x) then
    return(substring(x, _g85, upto))
  else
    local l = sublist(x, _g85, upto)
    local k = nil
    local _g86 = x
    for k in next, _g86 do
      if (not number63(k)) then
        local v = _g86[k]
        l[k] = v
      end
    end
    return(l)
  end
end
function inner(x)
  return(sub(x, 1, (length(x) - 1)))
end
function hd(l)
  return(l[1])
end
function tl(l)
  return(sub(l, 1))
end
function add(l, x)
  return((table.insert)(l, x))
end
function drop(l)
  return((table.remove)(l))
end
function last(l)
  return(l[((length(l) - 1) + 1)])
end
function reverse(l)
  local l1 = {}
  local i = (length(l) - 1)
  while (i >= 0) do
    add(l1, l[(i + 1)])
    i = (i - 1)
  end
  return(l1)
end
function join(l1, l2)
  if nil63(l1) then
    return(l2)
  elseif nil63(l2) then
    return(l1)
  else
    local l = {}
    local skip63 = false
    if (not skip63) then
      local i = 0
      local len = length(l1)
      while (i < len) do
        l[(i + 1)] = l1[(i + 1)]
        i = (i + 1)
      end
      while (i < (len + length(l2))) do
        l[(i + 1)] = l2[((i - len) + 1)]
        i = (i + 1)
      end
    end
    local k = nil
    local _g87 = l1
    for k in next, _g87 do
      if (not number63(k)) then
        local v = _g87[k]
        l[k] = v
      end
    end
    local _g89 = nil
    local _g88 = l2
    for _g89 in next, _g88 do
      if (not number63(_g89)) then
        local v = _g88[_g89]
        l[_g89] = v
      end
    end
    return(l)
  end
end
function reduce(f, x)
  if empty63(x) then
    return(x)
  elseif (length(x) == 1) then
    return(hd(x))
  else
    return(f(hd(x), reduce(f, tl(x))))
  end
end
function keep(f, l)
  local l1 = {}
  local _g91 = 0
  local _g90 = l
  while (_g91 < length(_g90)) do
    local x = _g90[(_g91 + 1)]
    if f(x) then
      add(l1, x)
    end
    _g91 = (_g91 + 1)
  end
  return(l1)
end
function find(f, l)
  local _g93 = 0
  local _g92 = l
  while (_g93 < length(_g92)) do
    local x = _g92[(_g93 + 1)]
    local x = f(x)
    if x then
      return(x)
    end
    _g93 = (_g93 + 1)
  end
end
function pairwise(l)
  local i = 0
  local l1 = {}
  while (i < length(l)) do
    add(l1, {l[(i + 1)], l[((i + 1) + 1)]})
    i = (i + 2)
  end
  return(l1)
end
function iterate(f, count)
  local i = 0
  while (i < count) do
    f(i)
    i = (i + 1)
  end
end
function replicate(n, x)
  local l = {}
  iterate(function ()
    return(add(l, x))
  end, n)
  return(l)
end
function splice(x)
  return({_splice = x})
end
function splice63(x)
  if table63(x) then
    return(x._splice)
  end
end
function map(f, l)
  local l1 = {}
  local _g103 = 0
  local _g102 = l
  while (_g103 < length(_g102)) do
    local x = _g102[(_g103 + 1)]
    local x1 = f(x)
    local s = splice63(x1)
    if list63(s) then
      l1 = join(l1, s)
    elseif is63(s) then
      add(l1, s)
    elseif is63(x1) then
      add(l1, x1)
    end
    _g103 = (_g103 + 1)
  end
  return(l1)
end
function map42(f, t)
  local l = map(f, t)
  local k = nil
  local _g104 = t
  for k in next, _g104 do
    if (not number63(k)) then
      local v = _g104[k]
      local x = f(v)
      if is63(x) then
        l[k] = x
      end
    end
  end
  return(l)
end
function mapt(f, t)
  local t1 = {}
  local k = nil
  local _g105 = t
  for k in next, _g105 do
    if (not number63(k)) then
      local v = _g105[k]
      local x = f(k, v)
      if is63(x) then
        t1[k] = x
      end
    end
  end
  return(t1)
end
function mapo(f, t)
  local o = {}
  local k = nil
  local _g106 = t
  for k in next, _g106 do
    if (not number63(k)) then
      local v = _g106[k]
      local x = f(k, v)
      if is63(x) then
        add(o, k)
        add(o, x)
      end
    end
  end
  return(o)
end
function keys63(t)
  local k63 = false
  local k = nil
  local _g107 = t
  for k in next, _g107 do
    if (not number63(k)) then
      local v = _g107[k]
      k63 = true
      break
    end
  end
  return(k63)
end
function extend(t, ...)
  local xs = unstash({...})
  local _g108 = sub(xs, 0)
  return(join(t, _g108))
end
function exclude(t, ...)
  local keys = unstash({...})
  local _g109 = sub(keys, 0)
  local t1 = sublist(t)
  local k = nil
  local _g110 = t
  for k in next, _g110 do
    if (not number63(k)) then
      local v = _g110[k]
      if (not _g109[k]) then
        t1[k] = v
      end
    end
  end
  return(t1)
end
function char(str, n)
  return(sub(str, n, (n + 1)))
end
function code(str, n)
  return((string.byte)(str, (function ()
    if n then
      return((n + 1))
    end
  end)()))
end
function search(str, pattern, start)
  local _g111 = (function ()
    if start then
      return((start + 1))
    end
  end)()
  local i = (string.find)(str, pattern, start, true)
  return((i and (i - 1)))
end
function split(str, sep)
  if ((str == "") or (sep == "")) then
    return({})
  else
    local strs = {}
    while true do
      local i = search(str, sep)
      if nil63(i) then
        break
      else
        add(strs, sub(str, 0, i))
        str = sub(str, (i + 1))
      end
    end
    add(strs, str)
    return(strs)
  end
end
function cat(...)
  local xs = unstash({...})
  local _g112 = sub(xs, 0)
  if empty63(_g112) then
    return("")
  else
    return(reduce(function (a, b)
      return((a .. b))
    end, _g112))
  end
end
function _43(...)
  local xs = unstash({...})
  local _g115 = sub(xs, 0)
  return(reduce(function (a, b)
    return((a + b))
  end, _g115))
end
function _(...)
  local xs = unstash({...})
  local _g116 = sub(xs, 0)
  return(reduce(function (a, b)
    return((b - a))
  end, reverse(_g116)))
end
function _42(...)
  local xs = unstash({...})
  local _g117 = sub(xs, 0)
  return(reduce(function (a, b)
    return((a * b))
  end, _g117))
end
function _47(...)
  local xs = unstash({...})
  local _g118 = sub(xs, 0)
  return(reduce(function (a, b)
    return((b / a))
  end, reverse(_g118)))
end
function _37(...)
  local xs = unstash({...})
  local _g119 = sub(xs, 0)
  return(reduce(function (a, b)
    return((b % a))
  end, reverse(_g119)))
end
function _62(a, b)
  return((a > b))
end
function _60(a, b)
  return((a < b))
end
function _61(a, b)
  return((a == b))
end
function _6261(a, b)
  return((a >= b))
end
function _6061(a, b)
  return((a <= b))
end
function read_file(path)
  local f = (io.open)(path)
  return((f.read)(f, "*a"))
end
function write_file(path, data)
  local f = (io.open)(path, "w")
  return((f.write)(f, data))
end
function write(x)
  return((io.write)(x))
end
function exit(code)
  return((os.exit)(code))
end
function nil63(x)
  return((x == nil))
end
function is63(x)
  return((not nil63(x)))
end
function string63(x)
  return((type(x) == "string"))
end
function string_literal63(x)
  return((string63(x) and (char(x, 0) == "\"")))
end
function id_literal63(x)
  return((string63(x) and (char(x, 0) == "|")))
end
function number63(x)
  return((type(x) == "number"))
end
function boolean63(x)
  return((type(x) == "boolean"))
end
function function63(x)
  return((type(x) == "function"))
end
function composite63(x)
  return((type(x) == "table"))
end
function atom63(x)
  return((not composite63(x)))
end
function table63(x)
  return((composite63(x) and nil63(hd(x))))
end
function list63(x)
  return((composite63(x) and is63(hd(x))))
end
function parse_number(str)
  return(tonumber(str))
end
function to_string(x)
  if nil63(x) then
    return("nil")
  elseif boolean63(x) then
    if x then
      return("true")
    else
      return("false")
    end
  elseif function63(x) then
    return("#<function>")
  elseif atom63(x) then
    return((x .. ""))
  else
    local str = "("
    local x1 = sub(x)
    local k = nil
    local _g120 = x
    for k in next, _g120 do
      if (not number63(k)) then
        local v = _g120[k]
        add(x1, (k .. ":"))
        add(x1, v)
      end
    end
    local i = 0
    local _g121 = x1
    while (i < length(_g121)) do
      local y = _g121[(i + 1)]
      str = (str .. to_string(y))
      if (i < (length(x1) - 1)) then
        str = (str .. " ")
      end
      i = (i + 1)
    end
    return((str .. ")"))
  end
end
function apply(f, args)
  local _g122 = stash(args)
  return(f(unpack(_g122)))
end
id_count = 0
function make_id()
  id_count = (id_count + 1)
  return(("_g" .. id_count))
end
infix = {lua = {["~="] = true, ["="] = "==", ["cat"] = "..", ["or"] = true, ["and"] = true}, common = {["*"] = true, ["+"] = true, ["<"] = true, ["-"] = true, [">"] = true, ["/"] = true, ["%"] = true, ["<="] = true, [">="] = true}, js = {["~="] = "!=", ["="] = "===", ["cat"] = "+", ["or"] = "||", ["and"] = "&&"}}
function getop(op)
  local op1 = (infix.common[op] or infix[target][op])
  if (op1 == true) then
    return(op)
  else
    return(op1)
  end
end
function infix63(form)
  return((list63(form) and is63(getop(hd(form)))))
end
indent_level = 0
function indentation()
  return(apply(cat, replicate(indent_level, "  ")))
end
function compile_args(args)
  local str = "("
  local i = 0
  local _g125 = args
  while (i < length(_g125)) do
    local arg = _g125[(i + 1)]
    str = (str .. compile(arg))
    if (i < (length(args) - 1)) then
      str = (str .. ", ")
    end
    i = (i + 1)
  end
  return((str .. ")"))
end
function compile_body(forms, ...)
  local _g126 = unstash({...})
  local tail63 = _g126["tail?"]
  local str = ""
  local i = 0
  local _g127 = forms
  while (i < length(_g127)) do
    local x = _g127[(i + 1)]
    local t63 = (tail63 and (i == (length(forms) - 1)))
    str = (str .. compile(x, {_stash = true, ["tail?"] = t63, ["stmt?"] = true}))
    i = (i + 1)
  end
  return(str)
end
function numeric63(n)
  return(((n > 47) and (n < 58)))
end
function valid_char63(n)
  return((numeric63(n) or ((n > 64) and (n < 91)) or ((n > 96) and (n < 123)) or (n == 95)))
end
function valid_id63(id)
  if empty63(id) then
    return(false)
  elseif special63(id) then
    return(false)
  elseif getop(id) then
    return(false)
  else
    local i = 0
    while (i < length(id)) do
      local n = code(id, i)
      local valid63 = valid_char63(n)
      if ((not valid63) or ((i == 0) and numeric63(n))) then
        return(false)
      end
      i = (i + 1)
    end
    return(true)
  end
end
function compile_id(id)
  local id1 = ""
  local i = 0
  while (i < length(id)) do
    local c = char(id, i)
    local n = code(c)
    local c1 = (function ()
      if (c == "-") then
        return("_")
      elseif valid_char63(n) then
        return(c)
      elseif (i == 0) then
        return(("_" .. n))
      else
        return(n)
      end
    end)()
    id1 = (id1 .. c1)
    i = (i + 1)
  end
  return(id1)
end
function compile_atom(x)
  if ((x == "nil") and (target == "lua")) then
    return(x)
  elseif (x == "nil") then
    return("undefined")
  elseif id_literal63(x) then
    return(inner(x))
  elseif string_literal63(x) then
    return(x)
  elseif string63(x) then
    return(compile_id(x))
  elseif boolean63(x) then
    if x then
      return("true")
    else
      return("false")
    end
  elseif number63(x) then
    return((x .. ""))
  else
    error("Unrecognized atom")
  end
end
function compile_call(form)
  if empty63(form) then
    return(compile_special({"%array"}))
  else
    local f = hd(form)
    local f1 = compile(f)
    local args = compile_args(stash42(tl(form)))
    if list63(f) then
      return(("(" .. f1 .. ")" .. args))
    elseif string63(f) then
      return((f1 .. args))
    else
      error("Invalid function call")
    end
  end
end
function compile_infix(_g128)
  local op = _g128[1]
  local args = sub(_g128, 1)
  local str = "("
  local op = getop(op)
  local i = 0
  local _g129 = args
  while (i < length(_g129)) do
    local arg = _g129[(i + 1)]
    if ((op == "-") and (length(args) == 1)) then
      str = (str .. op .. compile(arg))
    else
      str = (str .. compile(arg))
      if (i < (length(args) - 1)) then
        str = (str .. " " .. op .. " ")
      end
    end
    i = (i + 1)
  end
  return((str .. ")"))
end
function compile_branch(condition, body, first63, last63, tail63)
  local cond1 = compile(condition)
  local _g130 = (function ()
    indent_level = (indent_level + 1)
    local _g131 = compile(body, {_stash = true, ["tail?"] = tail63, ["stmt?"] = true})
    indent_level = (indent_level - 1)
    return(_g131)
  end)()
  local ind = indentation()
  local tr = (function ()
    if (last63 and (target == "lua")) then
      return((ind .. "end\n"))
    elseif last63 then
      return("\n")
    else
      return("")
    end
  end)()
  if (first63 and (target == "js")) then
    return((ind .. "if (" .. cond1 .. ") {\n" .. _g130 .. ind .. "}" .. tr))
  elseif first63 then
    return((ind .. "if " .. cond1 .. " then\n" .. _g130 .. tr))
  elseif (nil63(condition) and (target == "js")) then
    return((" else {\n" .. _g130 .. ind .. "}\n"))
  elseif nil63(condition) then
    return((ind .. "else\n" .. _g130 .. tr))
  elseif (target == "js") then
    return((" else if (" .. cond1 .. ") {\n" .. _g130 .. ind .. "}" .. tr))
  else
    return((ind .. "elseif " .. cond1 .. " then\n" .. _g130 .. tr))
  end
end
function compile_function(args, body, ...)
  local _g132 = unstash({...})
  local prefix = _g132.prefix
  local name = _g132.name
  local id = (function ()
    if name then
      return(compile(name))
    else
      return("")
    end
  end)()
  local prefix = (prefix or "")
  local args = compile_args(args)
  local body = (function ()
    indent_level = (indent_level + 1)
    local _g133 = compile_body(body, {_stash = true, ["tail?"] = true})
    indent_level = (indent_level - 1)
    return(_g133)
  end)()
  local ind = indentation()
  local tr = (function ()
    if name then
      return("end\n")
    else
      return("end")
    end
  end)()
  if (target == "js") then
    return(("function " .. id .. args .. " {\n" .. body .. ind .. "}"))
  else
    return((prefix .. "function " .. id .. args .. "\n" .. body .. ind .. tr))
  end
end
function terminator(stmt63)
  if (not stmt63) then
    return("")
  elseif (target == "js") then
    return(";\n")
  else
    return("\n")
  end
end
function compile_special(form, stmt63, tail63)
  local _g134 = getenv(hd(form))
  local special = _g134.special
  local self_tr63 = _g134.tr
  local stmt = _g134.stmt
  if ((not stmt63) and stmt) then
    return(compile({{"%function", {}, form}}, {_stash = true, ["tail?"] = tail63}))
  else
    local tr = terminator((stmt63 and (not self_tr63)))
    return((special(tl(form), tail63) .. tr))
  end
end
function can_return63(form)
  return(((not special_form63(form)) or (not getenv(hd(form)).stmt)))
end
function compile(form, ...)
  local _g178 = unstash({...})
  local tail63 = _g178["tail?"]
  local stmt63 = _g178["stmt?"]
  if (tail63 and can_return63(form)) then
    form = {"return", form}
  end
  if nil63(form) then
    return("")
  elseif special_form63(form) then
    return(compile_special(form, stmt63, tail63))
  else
    local tr = terminator(stmt63)
    local ind = (function ()
      if stmt63 then
        return(indentation())
      else
        return("")
      end
    end)()
    local form = (function ()
      if atom63(form) then
        return(compile_atom(form))
      elseif infix63(form) then
        return(compile_infix(form))
      else
        return(compile_call(form))
      end
    end)()
    return((ind .. form .. tr))
  end
end
function compile_toplevel(form)
  return(compile(macroexpand(form), {_stash = true, ["stmt?"] = true}))
end
function compile_file(file)
  local str = read_file(file)
  local body = read_all(make_stream(str))
  local form = join({"do"}, body)
  return(compile_toplevel(form))
end
compiler_output = nil
compilation_level = nil
function compile_module(spec)
  compilation_level = 0
  compiler_output = ""
  return(load_module(spec))
end
run_result = nil
function run(x)
  local f = load((compile("run-result") .. "=" .. x))
  if f then
    f()
    return(run_result)
  else
    local f,e = load(x)
    if f then
      return(f())
    else
      error((e .. " in " .. x))
    end
  end
end
function eval(form)
  local previous = target
  target = "lua"
  local str = compile(macroexpand(form))
  target = previous
  return(run(str))
end
current_module = nil
function initial_environment()
  return({{["define-module"] = getenv("define-module")}})
end
function module_key(spec)
  if atom63(spec) then
    return(to_string(spec))
  else
    error("Unsupported module specification")
  end
end
function module(spec)
  return(modules[module_key(spec)])
end
function module_path(spec)
  return((module_key(spec) .. ".l"))
end
function load_module(spec)
  if nil63(module(spec)) then
    _37compile_module(spec)
  elseif (compilation_level == 0) then
    compilation_level = (compilation_level + 1)
    _37compile_module(spec)
    compilation_level = (compilation_level - 1)
  end
  return(open_module(spec))
end
function _37compile_module(spec)
  local path = module_path(spec)
  local mod0 = current_module
  local env0 = environment
  local k = module_key(spec)
  current_module = spec
  environment = initial_environment()
  local compiled = compile_file(path)
  local m = module(spec)
  local toplevel = hd(environment)
  current_module = mod0
  environment = env0
  local name = nil
  local _g186 = toplevel
  for name in next, _g186 do
    if (not number63(name)) then
      local binding = _g186[name]
      if (binding.export and (binding.module == k)) then
        m.toplevel[name] = binding
      end
    end
  end
  if number63(compilation_level) then
    compiler_output = (compiler_output .. compiled)
  else
    return(run(compiled))
  end
end
function open_module(spec)
  local m = module(spec)
  local frame = last(environment)
  local k = nil
  local _g187 = m.toplevel
  for k in next, _g187 do
    if (not number63(k)) then
      local v = _g187[k]
      frame[k] = v
    end
  end
end
function in_module(spec)
  load_module(spec)
  local m = module(spec)
  return(map(open_module, m.import))
end
function quote_binding(b)
  b = extend(b, {_stash = true, module = {"quote", b.module}})
  if is63(b.symbol) then
    return(extend(b, {_stash = true, symbol = {"quote", b.symbol}}))
  elseif (b.macro and b.form) then
    return(exclude(extend(b, {_stash = true, macro = b.form}), {_stash = true, form = true}))
  elseif (b.special and b.form) then
    return(exclude(extend(b, {_stash = true, special = b.form}), {_stash = true, form = true}))
  elseif is63(b.variable) then
    return(b)
  end
end
function quote_frame(t)
  return(join({"%object"}, mapo(function (_g124, b)
    return(join({"table"}, quote_binding(b)))
  end, t)))
end
function quote_environment(env)
  return(join({"list"}, map(quote_frame, env)))
end
function quote_module(m)
  local _g188 = {"table"}
  _g188.toplevel = quote_frame(m.toplevel)
  _g188.import = quoted(m.import)
  return(_g188)
end
function quote_modules()
  return(join({"table"}, map42(quote_module, modules)))
end
modules = {compiler = {toplevel = {["define-module"] = {export = true, module = "compiler", macro = function (spec, ...)
  local body = unstash({...})
  local _g189 = sub(body, 0)
  local exp = _g189.export
  local imp = _g189.import
  map(load_module, imp)
  modules[module_key(spec)] = {toplevel = {}, import = imp, export = {}}
  local _g191 = 0
  local _g190 = (exp or {})
  while (_g191 < length(_g190)) do
    local k = _g190[(_g191 + 1)]
    setenv(k, {_stash = true, export = true})
    _g191 = (_g191 + 1)
  end
end}, ["%local-function"] = {export = true, module = "compiler", special = function (_g192)
  local name = _g192[1]
  local args = _g192[2]
  local body = sub(_g192, 2)
  return(compile_function(args, body, {_stash = true, prefix = "local ", name = name}))
end, stmt = true, tr = true}, ["compile-toplevel"] = {variable = true, module = "compiler", export = true}, ["if"] = {export = true, module = "compiler", special = function (form, tail63)
  local str = ""
  local i = 0
  local _g193 = form
  while (i < length(_g193)) do
    local condition = _g193[(i + 1)]
    local last63 = (i >= (length(form) - 2))
    local else63 = (i == (length(form) - 1))
    local first63 = (i == 0)
    local body = form[((i + 1) + 1)]
    if else63 then
      body = condition
      condition = nil
    end
    str = (str .. compile_branch(condition, body, first63, last63, tail63))
    i = (i + 1)
    i = (i + 1)
  end
  return(str)
end, stmt = true, tr = true}, ["break"] = {export = true, module = "compiler", stmt = true, special = function (_g123)
  return((indentation() .. "break"))
end}, ["initial-environment"] = {variable = true, module = "compiler", export = true}, ["current-module"] = {variable = true, module = "compiler", export = true}, eval = {variable = true, module = "compiler", export = true}, ["return"] = {export = true, module = "compiler", stmt = true, special = function (_g194)
  local x = _g194[1]
  local x = (function ()
    if nil63(x) then
      return("return")
    else
      return(compile_call({"return", x}))
    end
  end)()
  return((indentation() .. x))
end}, ["set"] = {export = true, module = "compiler", stmt = true, special = function (_g195)
  local lh = _g195[1]
  local rh = _g195[2]
  if nil63(rh) then
    error("Missing right-hand side in assignment")
  end
  return((indentation() .. compile(lh) .. " = " .. compile(rh)))
end}, ["do"] = {export = true, module = "compiler", special = function (forms, tail63)
  return(compile_body(forms, {_stash = true, ["tail?"] = tail63}))
end, stmt = true, tr = true}, ["open-m0dule"] = {variable = true, module = "compiler", export = true}, ["%array"] = {special = function (forms)
  local open = (function ()
    if (target == "lua") then
      return("{")
    else
      return("[")
    end
  end)()
  local close = (function ()
    if (target == "lua") then
      return("}")
    else
      return("]")
    end
  end)()
  local str = ""
  local i = 0
  local _g196 = forms
  while (i < length(_g196)) do
    local x = _g196[(i + 1)]
    str = (str .. compile(x))
    if (i < (length(forms) - 1)) then
      str = (str .. ", ")
    end
    i = (i + 1)
  end
  return((open .. str .. close))
end, module = "compiler", export = true}, ["%try"] = {export = true, module = "compiler", special = function (forms)
  local ind = indentation()
  local body = (function ()
    indent_level = (indent_level + 1)
    local _g197 = compile_body(forms, {_stash = true, ["tail?"] = true})
    indent_level = (indent_level - 1)
    return(_g197)
  end)()
  local e = make_id()
  local handler = {"return", {"%array", false, e}}
  local h = (function ()
    indent_level = (indent_level + 1)
    local _g198 = compile(handler, {_stash = true, ["stmt?"] = true})
    indent_level = (indent_level - 1)
    return(_g198)
  end)()
  return((ind .. "try {\n" .. body .. ind .. "}\n" .. ind .. "catch (" .. e .. ") {\n" .. h .. ind .. "}\n"))
end, stmt = true, tr = true}, ["load-module"] = {variable = true, module = "compiler", export = true}, ["while"] = {export = true, module = "compiler", special = function (_g199)
  local condition = _g199[1]
  local body = sub(_g199, 1)
  local condition = compile(condition)
  local body = (function ()
    indent_level = (indent_level + 1)
    local _g200 = compile_body(body)
    indent_level = (indent_level - 1)
    return(_g200)
  end)()
  local ind = indentation()
  if (target == "js") then
    return((ind .. "while (" .. condition .. ") {\n" .. body .. ind .. "}\n"))
  else
    return((ind .. "while " .. condition .. " do\n" .. body .. ind .. "end\n"))
  end
end, stmt = true, tr = true}, ["compiler-output"] = {variable = true, module = "compiler", export = true}, ["%local"] = {export = true, module = "compiler", stmt = true, special = function (_g201)
  local name = _g201[1]
  local value = _g201[2]
  local id = compile(name)
  local value = compile(value)
  local keyword = (function ()
    if (target == "js") then
      return("var ")
    else
      return("local ")
    end
  end)()
  local ind = indentation()
  return((ind .. keyword .. id .. " = " .. value))
end}, ["quote-modules"] = {variable = true, module = "compiler", export = true}, ["compile-module"] = {variable = true, module = "compiler", export = true}, ["open-module"] = {variable = true, module = "compiler", export = true}, ["get"] = {special = function (_g202)
  local t = _g202[1]
  local k = _g202[2]
  local t = compile(t)
  local k1 = compile(k)
  if ((target == "lua") and (char(t, 0) == "{")) then
    t = ("(" .. t .. ")")
  end
  if (string_literal63(k) and valid_id63(inner(k))) then
    return((t .. "." .. inner(k)))
  else
    return((t .. "[" .. k1 .. "]"))
  end
end, module = "compiler", export = true}, compile = {variable = true, module = "compiler", export = true}, ["quote-m0dules"] = {variable = true, module = "compiler", export = true}, ["quote-environment"] = {variable = true, module = "compiler", export = true}, ["%function"] = {special = function (_g203)
  local args = _g203[1]
  local body = sub(_g203, 1)
  return(compile_function(args, body))
end, module = "compiler", export = true}, ["%global-function"] = {export = true, module = "compiler", special = function (_g204)
  local name = _g204[1]
  local args = _g204[2]
  local body = sub(_g204, 2)
  if (target == "lua") then
    return(compile_function(args, body, {_stash = true, name = name}))
  else
    return(compile({"set", name, join({"%function", args}, body)}, {_stash = true, ["stmt?"] = true}))
  end
end, stmt = true, tr = true}, ["in-module"] = {variable = true, module = "compiler", export = true}, ["%for"] = {export = true, module = "compiler", special = function (_g205)
  local _g206 = _g205[1]
  local t = _g206[1]
  local k = _g206[2]
  local body = sub(_g205, 1)
  local t = compile(t)
  local ind = indentation()
  local body = (function ()
    indent_level = (indent_level + 1)
    local _g207 = compile_body(body)
    indent_level = (indent_level - 1)
    return(_g207)
  end)()
  if (target == "lua") then
    return((ind .. "for " .. k .. " in next, " .. t .. " do\n" .. body .. ind .. "end\n"))
  else
    return((ind .. "for (" .. k .. " in " .. t .. ") {\n" .. body .. ind .. "}\n"))
  end
end, stmt = true, tr = true}, ["error"] = {export = true, module = "compiler", stmt = true, special = function (_g208)
  local x = _g208[1]
  local e = (function ()
    if (target == "js") then
      return(("throw " .. compile(x)))
    else
      return(compile_call({"error", x}))
    end
  end)()
  return((indentation() .. e))
end}, ["not"] = {special = function (_g209)
  local x = _g209[1]
  local x = compile(x)
  local open = (function ()
    if (target == "js") then
      return("!(")
    else
      return("(not ")
    end
  end)()
  return((open .. x .. ")"))
end, module = "compiler", export = true}, ["with-indent"] = {export = true, module = "compiler", macro = function (form)
  local result = make_id()
  return({"do", {"inc", "indent-level"}, {"let", {result, form}, {"dec", "indent-level"}, result}})
end}, ["%object"] = {special = function (forms)
  local str = "{"
  local sep = (function ()
    if (target == "lua") then
      return(" = ")
    else
      return(": ")
    end
  end)()
  local pairs = pairwise(forms)
  local i = 0
  local _g210 = pairs
  while (i < length(_g210)) do
    local _g211 = _g210[(i + 1)]
    local k = _g211[1]
    local v = _g211[2]
    if (not string63(k)) then
      error(("Illegal key: " .. to_string(k)))
    end
    local v = compile(v)
    local k = (function ()
      if valid_id63(k) then
        return(k)
      elseif ((target == "js") and string_literal63(k)) then
        return(k)
      elseif (target == "js") then
        return(quoted(k))
      elseif string_literal63(k) then
        return(("[" .. k .. "]"))
      else
        return(("[" .. quoted(k) .. "]"))
      end
    end)()
    str = (str .. k .. sep .. v)
    if (i < (length(pairs) - 1)) then
      str = (str .. ", ")
    end
    i = (i + 1)
  end
  return((str .. "}"))
end, module = "compiler", export = true}}, import = {"reader", "lib", "compiler"}}, boot = {toplevel = {}, import = {"lib", "compiler"}}, lib = {toplevel = {["*"] = {variable = true, module = "lib", export = true}, ["+"] = {variable = true, module = "lib", export = true}, ["define-symbol"] = {export = true, module = "lib", macro = function (name, expansion)
  setenv(name, {_stash = true, symbol = expansion})
  return(nil)
end}, ["-"] = {variable = true, module = "lib", export = true}, iterate = {variable = true, module = "lib", export = true}, reverse = {variable = true, module = "lib", export = true}, ["join!"] = {export = true, module = "lib", macro = function (a, ...)
  local bs = unstash({...})
  local _g212 = sub(bs, 0)
  return({"set", a, join({"join*", a}, _g212)})
end}, across = {export = true, module = "lib", macro = function (_g213, ...)
  local l = _g213[1]
  local v = _g213[2]
  local i = _g213[3]
  local start = _g213[4]
  local body = unstash({...})
  local _g214 = sub(body, 0)
  local l1 = make_id()
  i = (i or make_id())
  start = (start or 0)
  return({"let", {i, start, l1, l}, {"while", {"<", i, {"length", l1}}, join({"let", {v, {"at", l1, i}}}, join(_g214, {{"inc", i}}))}})
end}, ["composite?"] = {variable = true, module = "lib", export = true}, exclude = {variable = true, module = "lib", export = true}, ["%"] = {variable = true, module = "lib", export = true}, ["let-macro"] = {export = true, module = "lib", macro = function (definitions, ...)
  local body = unstash({...})
  local _g215 = sub(body, 0)
  add(environment, {})
  local _g216 = (function ()
    map(function (m)
      return(macroexpand(join({"define-macro"}, m)))
    end, definitions)
    return(join({"do"}, macroexpand(_g215)))
  end)()
  drop(environment)
  return(_g216)
end}, tl = {variable = true, module = "lib", export = true}, at = {export = true, module = "lib", macro = function (l, i)
  if ((target == "lua") and number63(i)) then
    i = (i + 1)
  elseif (target == "lua") then
    i = {"+", i, 1}
  end
  return({"get", l, i})
end}, ["table?"] = {variable = true, module = "lib", export = true}, pairwise = {variable = true, module = "lib", export = true}, [">="] = {variable = true, module = "lib", export = true}, print = {variable = true, module = "lib", export = true}, ["make-id"] = {variable = true, module = "lib", export = true}, find = {variable = true, module = "lib", export = true}, ["is?"] = {variable = true, module = "lib", export = true}, ["special-form?"] = {variable = true, module = "lib", export = true}, mapt = {variable = true, module = "lib", export = true}, ["define-local"] = {export = true, module = "lib", macro = function (name, x, ...)
  local body = unstash({...})
  local _g217 = sub(body, 0)
  setenv(name, {_stash = true, variable = true})
  if (not empty63(_g217)) then
    local _g218 = bind_arguments(x, _g217)
    local args = _g218[1]
    local _g219 = _g218[2]
    return(join({"%local-function", name, args}, _g219))
  else
    return({"%local", name, x})
  end
end}, let = {export = true, module = "lib", macro = function (bindings, ...)
  local body = unstash({...})
  local _g220 = sub(body, 0)
  local i = 0
  local renames = {}
  local locals = {}
  map(function (_g221)
    local lh = _g221[1]
    local rh = _g221[2]
    local _g223 = 0
    local _g222 = bind(lh, rh)
    while (_g223 < length(_g222)) do
      local _g224 = _g222[(_g223 + 1)]
      local id = _g224[1]
      local val = _g224[2]
      if bound63(id) then
        local rename = make_id()
        add(renames, id)
        add(renames, rename)
        id = rename
      else
        setenv(id, {_stash = true, variable = true})
      end
      add(locals, {"%local", id, val})
      _g223 = (_g223 + 1)
    end
  end, pairwise(bindings))
  return(join({"do"}, join(locals, {join({"let-symbol", renames}, _g220)})))
end}, ["define-global"] = {export = true, module = "lib", macro = function (name, x, ...)
  local body = unstash({...})
  local _g225 = sub(body, 0)
  setenv(name, {_stash = true, variable = true})
  if (not empty63(_g225)) then
    local _g226 = bind_arguments(x, _g225)
    local args = _g226[1]
    local _g227 = _g226[2]
    return(join({"%global-function", name, args}, _g227))
  else
    return({"set", name, x})
  end
end}, split = {variable = true, module = "lib", export = true}, ["write-file"] = {variable = true, module = "lib", export = true}, type = {variable = true, module = "lib", export = true}, ["set-of"] = {export = true, module = "lib", macro = function (...)
  local elements = unstash({...})
  local l = {}
  local _g229 = 0
  local _g228 = elements
  while (_g229 < length(_g228)) do
    local e = _g228[(_g229 + 1)]
    l[e] = true
    _g229 = (_g229 + 1)
  end
  return(join({"table"}, l))
end}, reduce = {variable = true, module = "lib", export = true}, splice = {variable = true, module = "lib", export = true}, ["atom?"] = {variable = true, module = "lib", export = true}, exit = {variable = true, module = "lib", export = true}, replicate = {variable = true, module = "lib", export = true}, inc = {export = true, module = "lib", macro = function (n, by)
  return({"set", n, {"+", n, (by or 1)}})
end}, ["special?"] = {variable = true, module = "lib", export = true}, ["let-symbol"] = {export = true, module = "lib", macro = function (expansions, ...)
  local body = unstash({...})
  local _g230 = sub(body, 0)
  add(environment, {})
  local _g231 = (function ()
    map(function (_g232)
      local name = _g232[1]
      local exp = _g232[2]
      return(macroexpand({"define-symbol", name, exp}))
    end, pairwise(expansions))
    return(join({"do"}, macroexpand(_g230)))
  end)()
  drop(environment)
  return(_g231)
end}, ["join*"] = {export = true, module = "lib", macro = function (...)
  local xs = unstash({...})
  return(reduce(function (a, b)
    return({"join", a, b})
  end, xs))
end}, ["read-file"] = {variable = true, module = "lib", export = true}, ["number?"] = {variable = true, module = "lib", export = true}, quoted = {variable = true, module = "lib", export = true}, ["keys?"] = {variable = true, module = "lib", export = true}, ["cat!"] = {export = true, module = "lib", macro = function (a, ...)
  local bs = unstash({...})
  local _g233 = sub(bs, 0)
  return({"set", a, join({"cat", a}, _g233)})
end}, list = {export = true, module = "lib", macro = function (...)
  local body = unstash({...})
  local l = join({"%array"}, body)
  if (not keys63(body)) then
    return(l)
  else
    local id = make_id()
    local init = {}
    local k = nil
    local _g234 = body
    for k in next, _g234 do
      if (not number63(k)) then
        local v = _g234[k]
        add(init, {"set", {"get", id, {"quote", k}}, v})
      end
    end
    return(join({"let", {id, l}}, join(init, {id})))
  end
end}, add = {variable = true, module = "lib", export = true}, ["id-literal?"] = {variable = true, module = "lib", export = true}, ["with-bindings"] = {export = true, module = "lib", macro = function (_g235, ...)
  local names = _g235[1]
  local body = unstash({...})
  local _g236 = sub(body, 0)
  local x = make_id()
  return(join({"with-frame", {"across", {names, x}, (function ()
    local _g237 = {"setenv", x}
    _g237.variable = true
    return(_g237)
  end)()}}, _g236))
end}, ["function?"] = {variable = true, module = "lib", export = true}, dec = {export = true, module = "lib", macro = function (n, by)
  return({"set", n, {"-", n, (by or 1)}})
end}, apply = {variable = true, module = "lib", export = true}, macroexpand = {variable = true, module = "lib", export = true}, ["string-literal?"] = {variable = true, module = "lib", export = true}, table = {export = true, module = "lib", macro = function (...)
  local body = unstash({...})
  return(join({"%object"}, mapo(function (_g5, x)
    return(x)
  end, body)))
end}, pr = {export = true, module = "lib", macro = function (...)
  local xs = unstash({...})
  local xs = map(function (x)
    return(splice({{"to-string", x}, "\" \""}))
  end, xs)
  return({"print", join({"cat"}, xs)})
end}, ["with-frame"] = {export = true, module = "lib", macro = function (...)
  local body = unstash({...})
  local x = make_id()
  return({"do", {"add", "environment", {"table"}}, {"let", {x, join({"do"}, body)}, {"drop", "environment"}, x}})
end}, ["cat"] = {variable = true, module = "lib", export = true}, ["define-special"] = {export = true, module = "lib", macro = function (name, args, ...)
  local body = unstash({...})
  local _g238 = sub(body, 0)
  local form = join({"fn", args}, _g238)
  local keys = sub(_g238, length(_g238))
  eval(join((function ()
    local _g239 = {"setenv", {"quote", name}}
    _g239.special = form
    _g239.form = {"quote", form}
    return(_g239)
  end)(), keys))
  return(nil)
end}, keep = {variable = true, module = "lib", export = true}, extend = {variable = true, module = "lib", export = true}, quasiquote = {export = true, module = "lib", macro = function (form)
  return(quasiexpand(form, 1))
end}, mapo = {variable = true, module = "lib", export = true}, ["parse-number"] = {variable = true, module = "lib", export = true}, last = {variable = true, module = "lib", export = true}, length = {variable = true, module = "lib", export = true}, inner = {variable = true, module = "lib", export = true}, drop = {variable = true, module = "lib", export = true}, language = {export = true, module = "lib", macro = function ()
  return({"quote", target})
end}, sub = {variable = true, module = "lib", export = true}, ["list*"] = {export = true, module = "lib", macro = function (...)
  local xs = unstash({...})
  if empty63(xs) then
    return({})
  else
    local l = {}
    local i = 0
    local _g240 = xs
    while (i < length(_g240)) do
      local x = _g240[(i + 1)]
      if (i == (length(xs) - 1)) then
        l = {"join", join({"list"}, l), x}
      else
        add(l, x)
      end
      i = (i + 1)
    end
    return(l)
  end
end}, setenv = {variable = true, module = "lib", export = true}, target = {export = true, module = "lib", macro = function (...)
  local clauses = unstash({...})
  return(clauses[target])
end, variable = true}, search = {variable = true, module = "lib", export = true}, ["stash*"] = {variable = true, module = "lib", export = true}, ["string?"] = {variable = true, module = "lib", export = true}, ["list?"] = {variable = true, module = "lib", export = true}, ["%export"] = {}, ["empty?"] = {variable = true, module = "lib", export = true}, char = {variable = true, module = "lib", export = true}, ["to-string"] = {variable = true, module = "lib", export = true}, quote = {export = true, module = "lib", macro = function (form)
  return(quoted(form))
end}, ["map*"] = {variable = true, module = "lib", export = true}, getenv = {variable = true, module = "lib", export = true}, code = {variable = true, module = "lib", export = true}, unstash = {variable = true, module = "lib", export = true}, map = {variable = true, module = "lib", export = true}, write = {variable = true, module = "lib", export = true}, ["<"] = {variable = true, module = "lib", export = true}, ["="] = {variable = true, module = "lib", export = true}, [">"] = {variable = true, module = "lib", export = true}, define = {export = true, module = "lib", macro = function (name, x, ...)
  local body = unstash({...})
  local _g241 = sub(body, 0)
  setenv(name, {_stash = true, variable = true})
  return(join({"define-global", name, x}, _g241))
end}, ["nil?"] = {variable = true, module = "lib", export = true}, ["define-macro"] = {export = true, module = "lib", macro = function (name, args, ...)
  local body = unstash({...})
  local _g242 = sub(body, 0)
  local form = join({"fn", args}, _g242)
  eval((function ()
    local _g243 = {"setenv", {"quote", name}}
    _g243.macro = form
    _g243.form = {"quote", form}
    return(_g243)
  end)())
  return(nil)
end}, fn = {export = true, module = "lib", macro = function (args, ...)
  local body = unstash({...})
  local _g244 = sub(body, 0)
  local _g245 = bind_arguments(args, _g244)
  local args = _g245[1]
  local _g246 = _g245[2]
  return(join({"%function", args}, _g246))
end}, join = {variable = true, module = "lib", export = true}, ["<="] = {variable = true, module = "lib", export = true}, hd = {variable = true, module = "lib", export = true}, ["boolean?"] = {variable = true, module = "lib", export = true}, each = {export = true, module = "lib", macro = function (_g247, ...)
  local t = _g247[1]
  local k = _g247[2]
  local v = _g247[3]
  local body = unstash({...})
  local _g248 = sub(body, 0)
  local t1 = make_id()
  return({"let", {k, "nil", t1, t}, {"%for", {t1, k}, {"if", (function ()
    local _g249 = {"target"}
    _g249.lua = {"not", {"number?", k}}
    _g249.js = {"isNaN", {"parseInt", k}}
    return(_g249)
  end)(), join({"let", {v, {"get", t1, k}}}, _g248)}}})
end}, guard = {export = true, module = "lib", macro = function (expr)
  if (target == "js") then
    return({{"fn", {}, {"%try", {"list", true, expr}}}})
  else
    local e = make_id()
    local x = make_id()
    local ex = ("|" .. e .. "," .. x .. "|")
    return({"let", {ex, {"xpcall", {"fn", {}, expr}, "message-handler"}}, {"list", e, x}})
  end
end}, ["/"] = {variable = true, module = "lib", export = true}}, import = {"lib", "compiler"}}, reader = {toplevel = {["define-reader"] = {macro = function (_g250, ...)
  local char = _g250[1]
  local stream = _g250[2]
  local body = unstash({...})
  local _g251 = sub(body, 0)
  return({"set", {"get", "read-table", char}, join({"fn", {stream}}, _g251)})
end, module = "reader", export = true}, read = {variable = true, module = "reader", export = true}, ["make-stream"] = {variable = true, module = "reader", export = true}, ["read-all"] = {variable = true, module = "reader", export = true}, ["read-from-string"] = {variable = true, module = "reader", export = true}}, import = {"lib", "compiler"}}}
environment = {{["define-module"] = {export = true, module = "compiler", macro = function (spec, ...)
  local body = unstash({...})
  local _g252 = sub(body, 0)
  local exp = _g252.export
  local imp = _g252.import
  map(load_module, imp)
  modules[module_key(spec)] = {toplevel = {}, import = imp, export = {}}
  local _g254 = 0
  local _g253 = (exp or {})
  while (_g254 < length(_g253)) do
    local k = _g253[(_g254 + 1)]
    setenv(k, {_stash = true, export = true})
    _g254 = (_g254 + 1)
  end
end}}}
function rep(str)
  local _g255 = (function ()
    local _g256,_g257 = xpcall(function ()
      return(eval(read_from_string(str)))
    end, message_handler)
    return({_g256, _g257})
  end)()
  local _g1 = _g255[1]
  local x = _g255[2]
  if is63(x) then
    return(print((to_string(x) .. " ")))
  end
end
function repl()
  local step = function (str)
    rep(str)
    return(write("> "))
  end
  write("> ")
  while true do
    local str = (io.read)()
    if str then
      step(str)
    else
      break
    end
  end
end
function usage()
  print((to_string("usage: lumen [options] <module>") .. " "))
  print((to_string("options:") .. " "))
  print((to_string("  -o <output>\tOutput file") .. " "))
  print((to_string("  -t <target>\tTarget language (default: lua)") .. " "))
  print((to_string("  -e <expr>\tExpression to evaluate") .. " "))
  return(exit())
end
function main()
  local args = arg
  if ((hd(args) == "-h") or (hd(args) == "--help")) then
    usage()
  end
  local spec = nil
  local output = nil
  local target1 = nil
  local expr = nil
  local i = 0
  local _g258 = args
  while (i < length(_g258)) do
    local arg = _g258[(i + 1)]
    if ((arg == "-o") or (arg == "-t") or (arg == "-e")) then
      if (i == (length(args) - 1)) then
        print((to_string("missing argument for") .. " " .. to_string(arg) .. " "))
      else
        i = (i + 1)
        local val = args[(i + 1)]
        if (arg == "-o") then
          output = val
        elseif (arg == "-t") then
          target1 = val
        elseif (arg == "-e") then
          expr = val
        end
      end
    elseif (nil63(spec) and ("-" ~= char(arg, 0))) then
      spec = arg
    end
    i = (i + 1)
  end
  if output then
    if target1 then
      target = target1
    end
    compile_module(spec)
    return(write_file(output, compiler_output))
  else
    local spec = (spec or "main")
    in_module(spec)
    if expr then
      return(rep(expr))
    else
      return(repl())
    end
  end
end
main()
