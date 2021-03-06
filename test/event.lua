local event = require "coutil.event"
local await = event.await
local awaitall = event.awaitall
local awaitany = event.awaitany
local awaiteach = event.awaiteach
local emitall = event.emitall
local emitone = event.emitone
local pending = event.pending

newtest "pending" -----------------------------------------------------------------

do case "garbage collection"
	garbage.e = {}
	assert(pending(garbage.e) == false)

	done()
end

do case "value types"
	for _, e in ipairs(types) do
		assert(pending(e) == false)

		local a = 0
		spawn(function ()
			await(e)
			assert(pending(e) == false)
			a = 1
		end)
		assert(a == 0) -- await suspended the coroutine

		assert(pending(e) == true)
		assert(a == 0) -- still haven't executed

		assert(emitall(e) == true)

		assert(pending(e) == false)
	end

	assert(pending() == false)
	assert(pending(nil) == false)

	done()
end

newtest "emitall" --------------------------------------------------------------

do case "garbage collection"
	garbage.e = {}
	emitall(garbage.e)

	done()
end

do case "value types"
	for _, e in ipairs(types) do
		assert(emitall(e) == false)
	end

	assert(emitall() == false)
	assert(emitall(nil) == false)

	done()
end

do case "event emission"
	for _, e in ipairs(types) do
		local count = 3
		local done = {}
		for i = 1, count do
			done[i] = 0
			spawn(function ()
				await(e)
				done[i] = 1
			end)
			assert(done[i] == 0) -- await suspended the coroutine
		end

		assert(emitall(e) == true)
		for i = 1, count do
			assert(done[i] == 1) -- await returned
		end

		assert(emitall(e) == false)
	end

	done()
end

newtest "emitone" --------------------------------------------------------------

do case "garbage collection"
	garbage.e = {}
	emitone(garbage.e)

	done()
end

do case "value types"
	for _, e in ipairs(types) do
		assert(emitone(e) == false)
	end

	assert(emitone() == false)
	assert(emitone(nil) == false)

	done()
end

do case "event emission"
	for _, e in ipairs(types) do
		local count = 3
		local done = {}
		for i = 1, count do
			done[i] = 0
			spawn(function ()
				await(e)
				done[i] = 1
			end)
			assert(done[i] == 0) -- await suspended the coroutine
		end

		for i = 1, count do
			assert(emitone(e) == true)
			for j = 1, count do
				assert(done[j] == (j <= i and 1 or 0))
			end
		end

		assert(emitone(e) == false)
	end

	done()
end

newtest "await" ----------------------------------------------------------------

do case "error messages"
	asserterr("table index is nil", pspawn(await))
	asserterr("table index is nil", pspawn(await, nil))
	asserterr("unable to yield", pcall(await, "e"))
	assert(emitall("e") == false)

	done()
end

do case "garbage collection"
	garbage.e = {}
	spawn(await, garbage.e)

	done()
end

do case "value types"
	for _, e in ipairs(types) do
		local a = 0
		spawn(function ()
			await(e)
			assert(emitall(e) == false)
			a = 1
		end)
		assert(a == 0) -- await suspended the coroutine

		assert(emitall(e) == true)
		assert(a == 1) -- await returned

		assert(emitall(e) == false)
	end

	done()
end

do case "extra values"
	local e = "event"

	local a1, a2, a3
	spawn(function ()
		a1, a2, a3 = await(e)
	end)
	local b1, b2, b3
	spawn(function ()
		b1, b2, b3 = await(e)
	end)
	local c1, c2, c3
	spawn(function ()
		c1, c2, c3 = await(e)
	end)

	local t1,t2,t3 = {},{},{}
	assert(emitall(e, t1,t2,t3) == true)
	assert(a1 == t1)
	assert(a2 == t2)
	assert(a3 == t3)
	assert(b1 == t1)
	assert(b2 == t2)
	assert(b3 == t3)
	assert(c1 == t1)
	assert(c2 == t2)
	assert(c3 == t3)

	done()
end

do case "resume order"
	local e = "event"
	local order = counter()
	local max = 16

	local list = {}
	for i = 1, max do
		spawn(function ()
			await(e)
			list[i] = order()
		end)
		assert(list[i] == nil)
	end

	assert(emitall(e) == true)
	assert(#list == max)
	for i, order in ipairs(list) do
		assert(i == order)
	end

	done()
end

do case "nested emission"
	local e = "event"
	local t1,t2,t3 = {},{},{}

	local a1,a2,a3
	spawn(function ()
		a1 = await(e)
		a2 = emitall(e, t2)
		a3 = await(e)
	end)

	local b1,b2
	spawn(function ()
		b1 = await(e)
		b2 = emitall(e, t3)
		coroutine.yield()
		b1,b2,b3 = nil
	end)

	assert(emitall(e, t1) == true)
	assert(a1 == t1)
	assert(a2 == false) -- emit from first coroutine resumes no coroutines
	assert(a3 == t3)
	assert(b1 == t1)
	assert(b2 == true) -- emit from second coroutine resumes the first one

	assert(emitall(e, {}) == false)
	assert(b1 == t1)
	assert(b2 == true)

	done()
end

newtest "awaitall" -------------------------------------------------------------

do case "error messages"
	asserterr("unable to yield", pcall(awaitall, 1,2,3))
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	done()
end

do case "garbage collection"
	garbage.e1,garbage.e2,garbage.e3 = {},{},{}

	spawn(awaitall, garbage.e1)
	spawn(awaitall, garbage.e1,garbage.e2)
	spawn(awaitall, garbage.e1,garbage.e2,garbage.e3)

	done()
end

do case "value types"
	local a = 0
	spawn(function ()
		awaitall(table.unpack(types))
		a = 1
	end)

	for _, e in ipairs(types) do
		assert(a == 0)
		assert(pending(e) == true)
		assert(a == 0)
		assert(emitall(e) == true)
	end
	assert(a == 1)

	for _, e in ipairs(types) do
		assert(emitall(e) == false)
	end

	done()
end

do case "ignore duplications"
	local a
	spawn(function ()
		awaitall(1,2,3,2,3)
		a = 1
	end)
	assert(a == nil)
	assert(emitall(1) == true)
	assert(emitall(2) == true)
	assert(emitall(3) == true)
	assert(a == 1)
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	done()
end

do case "ignore 'nil's"
	local a
	spawn(function ()
		awaitall(nil)
		a = 1
		awaitall(1,2,nil,3)
		a = 2
		awaitall(1,2,3,nil)
		a = 3
		awaitall(nil,1,2,3)
		a = 4
		awaitall(nil,1,nil,2,3,nil)
		a = 5
	end)
	assert(a == 1)
	for i = 2, 5 do
		assert(emitall(1) == true)
		assert(emitall(2) == true)
		assert(emitall(3) == true)
		assert(a == i)
	end

	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)
	assert(emitall(nil) == false)

	done()
end

do case "different sets"
	local e1,e2,e3 = {},{},{}

	local a
	spawn(function ()
		a = 1
		awaitall(e1,e2,e3)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		a = 2
		awaitall(e1)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		a = 3
		coroutine.yield()
		a = 4
	end)
	assert(a == 1)

	local b
	spawn(function ()
		awaitall() -- no effect
		b = 1
		awaitall(e2)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		b = 2
		awaitall(e1,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		b = 3
		coroutine.yield()
		b = 4
	end)
	assert(b == 1)

	assert(emitall(e1) == true)
	assert(a == 1)
	assert(b == 1)
	assert(emitall(e1) == false)
	assert(a == 1)
	assert(b == 1)

	assert(emitall(e2) == true)
	assert(a == 1)
	assert(b == 2)
	assert(emitall(e2) == false)
	assert(a == 1)
	assert(b == 2)

	assert(emitall(e3) == true)
	assert(a == 2)
	assert(b == 2)
	assert(emitall(e3) == false)
	assert(a == 2)
	assert(b == 2)

	assert(emitall(e1) == true)
	assert(a == 3)
	assert(b == 3)
	assert(emitall(e1) == false)
	assert(a == 3)
	assert(b == 3)
	assert(emitall(e2) == false)
	assert(a == 3)
	assert(b == 3)
	assert(emitall(e3) == false)
	assert(a == 3)
	assert(b == 3)

	done()
end

do case "resume order"
	local es = { {},{},{} }
	local order = counter()
	local max = 16

	local list = {}
	for i = 1, max do
		spawn(function ()
			awaitall(table.unpack(es, 1, 1+(i-1)%3))
			list[i] = order()
		end)
		assert(list[i] == nil)
	end

	assert(emitall(es[3]) == true)
	assert(#list == 0)
	assert(emitall(es[2]) == true)
	assert(#list == 0)
	assert(emitall(es[1]) == true)
	assert(#list == max)
	for i, order in ipairs(list) do
		assert(i == order)
	end

	done()
end

do case "nested emission"
	local e1,e2,e3 = {},{},{}
	local order = counter()
	local function step(list) list[#list+1] = order() end
	local a = {}
	local b = {}

	spawn(function ()
		awaitall(e1,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(a) -- a[1] = 1
		awaitall(e1,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == true) -- emits to other (awaiting: e2')
		assert(#b == 1 and b[1] == 2)
		step(a) -- a[2] = 3
		awaitall(e1,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(a) -- a[3] = 5
		coroutine.yield()
		step(a)
	end)

	spawn(function ()
		awaitall(e1)
		assert(emitall(e1) == false)
		assert(emitall(e2) == true) -- emits to other (awaiting: e3)
		assert(#a == 0)
		assert(emitall(e3) == true) -- resumes other (awaiting: e1,e2,e3)
		assert(#a == 1 and a[1] == 1)
		assert(emitall(e1) == true) -- emits to other (awaiting: e2,e3)
		assert(#a == 1 and a[1] == 1)
		assert(emitall(e3) == true) -- emits to other (awaiting: e2)
		assert(#a == 1 and a[1] == 1)
		step(b) -- b[1] = 2
		awaitall(e2,e3)
		assert(emitall(e1) == true) -- emits to other (awaiting: e2,e3)
		assert(#a == 2 and a[2] == 3)
		assert(emitall(e2) == true) -- emits to other (awaiting: e3)
		assert(#a == 2 and a[2] == 3)
		step(b) -- b[2] = 4
		awaitall(e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(b) -- b[3] = 6
		coroutine.yield()
		step(b)
	end)

	assert(emitall(e1) == true)
	assert(#a == 1 and a[1] == 1) -- awaiting: e2
	assert(#b == 1 and b[1] == 2) -- awaiting: e2,e3

	assert(emitall(e2) == true)
	assert(#a == 2 and a[2] == 3) -- awaiting: e3
	assert(#b == 2 and b[2] == 4) -- awaiting: e3

	assert(emitall(e3) == true)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)

	assert(emitall(e1) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)
	assert(emitall(e2) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)
	assert(emitall(e3) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)

	done()
end

newtest "awaitany" -------------------------------------------------------------

do case "error messages"
	asserterr("value expected", pspawn(awaitany))
	asserterr("value expected", pspawn(awaitany, nil))
	asserterr("value expected", pspawn(awaitany, nil,nil))
	asserterr("unable to yield", pcall(awaitany, 1,2,3))
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	done()
end

do case "garbage collection"
	garbage.e1,garbage.e2,garbage.e3 = {},{},{}

	spawn(awaitany, garbage.e1)
	spawn(awaitany, garbage.e1,garbage.e2)
	spawn(awaitany, garbage.e1,garbage.e2,garbage.e3)

	done()
end

do case "value types"
	for _, e in ipairs(types) do
		local a = 0
		spawn(function ()
			awaitany(table.unpack(types))
			a = 1
		end)
		assert(a == 0)

		for _, e in ipairs(types) do
			assert(pending(e) == true)
			assert(a == 0)
		end

		assert(emitall(e) == true)
		assert(a == 1)

		for _, e in ipairs(types) do
			assert(emitall(e) == false)
		end

	end

	done()
end

do case "ignore duplications"
	local a
	spawn(function ()
		awaitany(1,2,3,1,2)
		a = 1
	end)
	assert(a == nil)
	assert(emitall(2) == true)
	assert(a == 1)
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	done()
end

do case "ignore 'nil's"
	local a
	spawn(function ()
		awaitany(1,2,nil,3)
		a = 1
		awaitany(1,2,3,nil)
		a = 2
		awaitany(nil,1,2,3)
		a = 3
		awaitany(nil,1,nil,2,3,nil)
		a = 4
	end)
	for i = 1, 4 do
		assert(emitall(2) == true)
		assert(a == i)
	end

	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)
	assert(emitall(nil) == false)

	done()
end

do case "different sets"
	local e0,e1,e2,e3 = {},{},{},{}

	local ae,a1,a2,a3 = e0
	spawn(function ()
		ae,a1,a2,a3 = awaitany(e0,e1,e2,e3)
		ae,a1,a2,a3 = awaitany(e0,e1,e2,e3)
		ae,a1,a2,a3 = awaitany(e0,e1,e2,e3)
		coroutine.yield()
		ae = nil
	end)

	local be,b1,b2,b3 = e0
	spawn(function ()
		be,b1,b2,b3 = awaitany(e1)
		be,b1,b2,b3 = awaitany(e2,e3)
		be,b1,b2,b3 = awaitany(e0,e1,e2)
		coroutine.yield()
		be = nil
	end)

	local t1,t2,t3 = {},{},{}
	assert(emitall(e1, t1,t2,t3) == true)
	assert(ae == e1)
	assert(be == e1)
	assert(a1 == t1)
	assert(a2 == t2)
	assert(a3 == t3)
	assert(b1 == t1)
	assert(b2 == t2)
	assert(b3 == t3)

	local t1,t2,t3 = {},{},{}
	assert(emitall(e2, t1,t2,t3) == true)
	assert(ae == e2)
	assert(be == e2)
	assert(a1 == t1)
	assert(a2 == t2)
	assert(a3 == t3)
	assert(b1 == t1)
	assert(b2 == t2)
	assert(b3 == t3)

	local t1,t2,t3 = {},{},{}
	assert(emitall(e3, t1,t2,t3) == true)
	assert(ae == e3)
	assert(be == e2)
	assert(a1 == t1)
	assert(a2 == t2)
	assert(a3 == t3)

	assert(emitall(e3) == false)
	assert(ae == e3)
	assert(be == e2)

	e0,e1,e2,be = nil
	done()
end

do case "resume order"
	local es = { {},{},{} }
	local max = 16

	local list
	for i = 1, max do
		spawn(function ()
			awaitany(table.unpack(es, 1, 1+(i-1)%3))
			list[#list+1] = i
		end)
	end

	list = {}
	assert(emitall(es[3]) == true)
	assert(#list == max//3)
	for i = 1, #list do assert(list[i] == i*3) end

	list = {}
	assert(emitall(es[2]) == true)
	assert(#list == max//3)
	for i = 1, #list do assert(list[i] == i*3-1) end

	list = {}
	assert(emitall(es[1]) == true)
	assert(#list == max//3+max%3)
	for i = 1, #list do assert(list[i] == i*3-2) end

	assert(emitall(es[1]) == false)
	assert(emitall(es[2]) == false)
	assert(emitall(es[3]) == false)

	done()
end

do case "nested emission"
	local e1,e2,e3 = {},{},{}
	local order = counter()
	local function step(list) list[#list+1] = order() end
	local a = {}
	local b = {}

	spawn(function ()
		assert(awaitany(e1,e2,e3) == e1) -- this time this is resumed first
		assert(emitall(e1) == false) -- other is awaiting: e1'|e2|e3
		assert(#b == 0)
		assert(emitall(e2) == true) -- resumes other (awaiting: e1|e2|e3)
		assert(#b == 1 and b[1] == 1)
		assert(emitall(e1) == true) -- resumes other (awaiting: e1|e2|e3)
		assert(#b == 2 and b[2] == 2)
		step(a) -- a[1] = 3

		assert(awaitany(e1,e2,e3) == e1) -- this time this is resumed last
		assert(#b == 3 and b[3] == 4)
		assert(emitall(e1) == true) -- resumes other (awaiting: e1|e2|e3)
		assert(#b == 4 and b[4] == 5)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(a) -- a[2] = 6

		coroutine.yield()
		step(a)
	end)

	spawn(function ()
		assert(awaitany(e1,e2,e3) == e2) -- emitted from the other coroutine
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(b) -- b[1] = 1
		assert(awaitany(e1,e2,e3) == e1) -- emitted from the other coroutine
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(b) -- b[2] = 2

		assert(awaitany(e1,e2,e3) == e1) -- this time this is resumed first
		assert(emitall(e1) == false) -- other is awaiting: e1'|e2|e3
		step(b) -- b[3] = 4
		assert(awaitany(e1,e2,e3) == e1)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		step(b) -- b[4] = 5

		coroutine.yield()
		step(b)
	end)

	assert(emitall(e1) == true)
	assert(#a == 1 and a[1] == 3)
	assert(#b == 2 and b[2] == 2)

	assert(emitall(e1) == true)
	assert(#a == 2 and a[2] == 6)
	assert(#b == 4 and b[4] == 5)

	assert(emitall(e1) == false)
	assert(#a == 2 and a[2] == 6)
	assert(#b == 4 and b[4] == 5)
	assert(emitall(e2) == false)
	assert(#a == 2 and a[2] == 6)
	assert(#b == 4 and b[4] == 5)
	assert(emitall(e3) == false)
	assert(#a == 2 and a[2] == 6)
	assert(#b == 4 and b[4] == 5)

	done()
end

newtest "awaiteach" ------------------------------------------------------------

local function newcb()
	local seq = {n=0}
	return seq, function (e, t1,t2,t3)
		seq.n = seq.n+1
		seq[seq.n] = { event=e, t1,t2,t3 }
	end
end

local function assertseq(seq, t, ...)
	local count = select("#", ...)
	assert(seq.n == count)
	for index = 1, count do
		local e = select(index, ...)
		assert(seq[index].event == e)
		assert(seq[index][1] == t[e][1])
		assert(seq[index][2] == t[e][2])
		assert(seq[index][3] == t[e][3])
	end
end

do case "error messages"
	asserterr("unable to yield", pcall(awaiteach, print, 1,2,3))
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	local a
	spawn(function ()
		asserterr("attempt to call a nil value", pcall(awaiteach, nil, 1,2,3))
		a = 1
	end)
	assert(emitall(1) == true)
	assert(a == 1)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	done()
end

do case "garbage collection"
	garbage.f = function () end
	garbage.e1,garbage.e2,garbage.e3 = {},{},{}

	spawn(awaiteach, f, garbage.e1)
	spawn(awaiteach, f, garbage.e1,garbage.e2)
	spawn(awaiteach, f, garbage.e1,garbage.e2,garbage.e3)

	done()
end

do case "value types"
	local seq, cb = newcb()

	local a = 0
	spawn(function ()
		awaiteach(cb, table.unpack(types))
		a = 1
	end)

	for i, e in ipairs(types) do
		assert(a == 0)
		assert(seq[i] == nil)
		assert(pending(e) == true)
		assert(a == 0)
		assert(seq[i] == nil)
		assert(emitall(e) == true)
		assert(seq[i].event == e)
	end
	assert(a == 1)
	assert(seq.n == #types)

	for _, e in ipairs(types) do
		assert(emitall(e) == false)
	end

	done()
end

do case "ignore duplications"
	local t = {{},{},{}}
	local seq, cb = newcb()

	local a
	spawn(function ()
		awaiteach(cb, 1,2,3,2,3)
		a = 1
	end)
	assert(a == nil)
	assert(emitall(1) == true)
	assertseq(seq, t, 1)
	assert(emitall(2) == true)
	assertseq(seq, t, 1,2)
	assert(emitall(3) == true)
	assertseq(seq, t, 1,2,3)
	assert(a == 1)
	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)
	assertseq(seq, t, 1,2,3)

	done()
end

do case "ignore 'nil's"
	local t = {{},{},{}}
	local seq, cb = newcb()

	local a
	spawn(function ()
		awaiteach(cb, nil)
		a = 1
		awaiteach(cb, 1,2,nil,3)
		a = 2
		awaiteach(cb, 1,2,3,nil)
		a = 3
		awaiteach(cb, nil,1,2,3)
		a = 4
		awaiteach(cb, nil,1,nil,2,3,nil)
		a = 5
	end)
	assert(a == 1)
	for i = 2, 5 do
		seq.n = 0
		seq[1] = nil
		seq[2] = nil
		seq[3] = nil
		assert(emitall(1) == true)
		assertseq(seq, t, 1)
		assert(emitall(2) == true)
		assertseq(seq, t, 1,2)
		assert(emitall(3) == true)
		assertseq(seq, t, 1,2,3)
		assert(a == i)
	end

	assert(emitall(1) == false)
	assert(emitall(2) == false)
	assert(emitall(3) == false)
	assert(emitall(nil) == false)
	assertseq(seq, t, 1,2,3)

	done()
end

do case "different sets"
	local e1,e2,e3 = {},{},{}
	local t = {
		[e1] = { {},{},{} },
		[e2] = { {},{},{} },
		[e3] = { {},{},{} },
	}

	local aseq, acb = newcb()
	local bseq, bcb = newcb()

	local a
	spawn(function ()
		a = 1
		awaiteach(acb, e1,e2,e3)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		a = 2
		awaiteach(acb, e1)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		a = 3
		coroutine.yield()
		a = 4
	end)
	assert(a == 1)

	local b
	spawn(function ()
		awaiteach(bcb) -- no effect
		b = 1
		awaiteach(bcb, e2)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		b = 2
		awaiteach(bcb, e1,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		b = 3
		coroutine.yield()
		b = 4
	end)
	assert(b == 1)

	assert(emitall(e1, table.unpack(t[e1])) == true)
	assert(a == 1)
	assert(b == 1)
	assertseq(aseq, t, e1)
	assertseq(bseq, t)
	assert(emitall(e1, {},{},{}) == false)
	assert(a == 1)
	assert(b == 1)
	assertseq(aseq, t, e1)
	assertseq(bseq, t)

	assert(emitall(e2, table.unpack(t[e2])) == true)
	assert(a == 1)
	assert(b == 2)
	assertseq(aseq, t, e1,e2)
	assertseq(bseq, t, e2)
	assert(emitall(e2, {},{},{}) == false)
	assert(a == 1)
	assert(b == 2)
	assertseq(aseq, t, e1,e2)
	assertseq(bseq, t, e2)

	assert(emitall(e3, table.unpack(t[e3])) == true)
	assert(a == 2)
	assert(b == 2)
	assertseq(aseq, t, e1,e2,e3)
	assertseq(bseq, t, e2,e3)
	assert(emitall(e3, {},{},{}) == false)
	assert(a == 2)
	assert(b == 2)
	assertseq(aseq, t, e1,e2,e3)
	assertseq(bseq, t, e2,e3)

	assert(emitall(e1, table.unpack(t[e1])) == true)
	assert(a == 3)
	assert(b == 3)
	assertseq(aseq, t, e1,e2,e3,e1)
	assertseq(bseq, t, e2,e3,e1)
	assert(emitall(e1, {},{},{}) == false)
	assert(a == 3)
	assert(b == 3)
	assertseq(aseq, t, e1,e2,e3,e1)
	assertseq(bseq, t, e2,e3,e1)
	assert(emitall(e2, {},{},{}) == false)
	assert(a == 3)
	assert(b == 3)
	assertseq(aseq, t, e1,e2,e3,e1)
	assertseq(bseq, t, e2,e3,e1)
	assert(emitall(e3, {},{},{}) == false)
	assert(a == 3)
	assert(b == 3)
	assertseq(aseq, t, e1,e2,e3,e1)
	assertseq(bseq, t, e2,e3,e1)

	done()
end

do case "resume order"
	local e1,e2,e3 = {},{},{}
	local t = {
		[e1] = {},
		[e2] = {},
		[e3] = {},
	}
	local es = { e1,e2,e3 }
	local order = counter()
	local max = 15

	local list = {}
	local seqof = {}
	for i = 1, max do
		local cb
		seqof[i], cb = newcb()
		spawn(function ()
			awaiteach(cb, table.unpack(es, 1, 1+(i-1)%3))
			list[i] = order()
		end)
		assert(list[i] == nil)
	end

	assert(emitall(e3) == true)
	assert(#list == 0)
	for i = 3, max, 3 do
		assertseq(seqof[i], t, e3)
	end
	assert(emitall(es[2]) == true)
	assert(#list == 0)
	for i = 2, max, 3 do
		assertseq(seqof[i+0], t, e2)
		assertseq(seqof[i+1], t, e3,e2)
	end
	assert(emitall(es[1]) == true)
	assert(#list == max)
	for i = 1, max, 3 do
		assertseq(seqof[i+0], t, e1)
		assertseq(seqof[i+1], t, e2,e1)
		assertseq(seqof[i+2], t, e3,e2,e1)
	end
	for i, order in ipairs(list) do
		assert(i == order)
	end

	done()
end

do case "nested emission"
	local e1,e2,e3 = {},{},{}
	local t = {
		[e1] = {},
		[e2] = {},
		[e3] = {},
	}

	local aseq, acb = newcb()
	local bseq, bcb = newcb()

	local order = counter()
	local function step(list) list[#list+1] = order() end
	local a = {}
	local b = {}

	spawn(function ()
		awaiteach(acb, e1,e2,e3)
		assertseq(aseq, t, e1,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		assertseq(aseq, t, e1,e2,e3)
 		step(a) -- a[1] = 1

		awaiteach(acb, e1,e2,e3)
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == true) -- emits to other (awaiting: e2')
		assertseq(bseq, t, e1,e3)
		assert(#b == 1 and b[1] == 2) -- other was not resumed
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2) -- callback was not called
		step(a) -- a[2] = 3

		awaiteach(acb, e1,e2,e3)
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2,e1,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2,e1,e2,e3) -- callback was not called

		step(a) -- a[3] = 5
		coroutine.yield()
		step(a)
	end)

	spawn(function ()
		awaiteach(bcb, e1)
		assertseq(aseq, t, e1)
		assertseq(bseq, t, e1)
		assert(emitall(e1) == false)
		assert(emitall(e2) == true) -- emits to other (awaiting: e3)
		assertseq(aseq, t, e1,e2)
		assert(#a == 0) -- other was not resumed
		assert(emitall(e3) == true) -- resumes other (awaiting: e1,e2,e3)
		assert(#a == 1 and a[1] == 1) -- other was not resumed
		assert(emitall(e1) == true) -- emits to other (awaiting: e2,e3)
		assertseq(aseq, t, e1,e2,e3,e1)
		assert(emitall(e3) == true) -- emits to other (awaiting: e2)
		assertseq(aseq, t, e1,e2,e3,e1,e3)
		assert(#a == 1 and a[1] == 1) -- other was not resumed
		assertseq(bseq, t, e1) -- callback was not called
		step(b) -- b[1] = 2

		awaiteach(bcb, e2,e3)
		assertseq(bseq, t, e1,e3,e2)
		assert(emitall(e1) == true) -- emits to other (awaiting: e2,e3)
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2,e1)
		assert(emitall(e2) == true) -- emits to other (awaiting: e3)
		assertseq(aseq, t, e1,e2,e3,e1,e3,e2,e1,e2)
		assert(#a == 2 and a[2] == 3) -- other was not resumed
		assertseq(bseq, t, e1,e3,e2) -- callback was not called
		step(b) -- b[2] = 4

		awaiteach(bcb, e3)
		assertseq(bseq, t, e1,e3,e2,e3)
		assert(emitall(e1) == false)
		assert(emitall(e2) == false)
		assert(emitall(e3) == false)
		assertseq(bseq, t, e1,e3,e2,e3) -- callback was not called
		step(b) -- b[3] = 6

		coroutine.yield()
		step(b)
	end)

	assert(emitall(e1) == true)
	assert(#a == 1 and a[1] == 1) -- awaiting: e2
	assert(#b == 1 and b[1] == 2) -- awaiting: e2,e3

	assert(emitall(e2) == true)
	assert(#a == 2 and a[2] == 3) -- awaiting: e3
	assert(#b == 2 and b[2] == 4) -- awaiting: e3

	assert(emitall(e3) == true)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)

	assert(emitall(e1) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)
	assert(emitall(e2) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)
	assert(emitall(e3) == false)
	assert(#a == 3 and a[3] == 5)
	assert(#b == 3 and b[3] == 6)
	assertseq(aseq, t, e1,e2,e3,e1,e3,e2,e1,e2,e3) -- callback was not called
	assertseq(bseq, t, e1,e3,e2,e3) -- callback was not called

	done()
end

do case "cancelation"
	local a
	spawn(function ()
		local function oops() error("oops!") end
		asserterr("oops!", pcall(awaiteach, oops, 1,2,3))
		a = 1
	end)
	assert(emitall(1) == true)
	assert(a == 1)
	assert(emitall(2) == false)
	assert(emitall(3) == false)

	local a
	spawn(function ()
		local t1,t2,t3 = {},{},{}
		local function is2(e)
			if e == 2 then
				return t1,t2,t3
			end
		end
		local r1,r2,r3 = awaiteach(is2, 1,2,3)
		assert(r1 == t1)
		assert(r2 == t2)
		assert(r3 == t3)
		a = 1
	end)
	assert(emitall(1) == true)
	assert(a == nil)
	assert(emitall(2) == true)
	assert(a == 1)
	assert(emitall(3) == false)

	done()
end
