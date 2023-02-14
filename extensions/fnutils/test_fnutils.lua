function test_reduce()
  local reduce = hs.fnutils.reduce

  assert(reduce({}, function(x, y) return x + y end) == nil)
  assert(reduce({}, function(x, y) return x + y end, 10) == 10)
  assert(reduce({1}, function(x, y) return x + y end) == 1)
  assert(reduce({1}, function(x, y) return x + y end, 10) == 11)
  assert(reduce({1, 2}, function(x, y) return x + y end) == 3)
  assert(reduce({1, 2}, function(x, y) return x + y end, 10) == 13)
end
