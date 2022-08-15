C = {}

function C:new()
  o = {c=1}
  self.__index = self
  return setmetatable(o, self)
end

function C:print()
  print('c = ', self.c)
end

D = C:new()

function D:new()
  o = {}
  C.new(o)
  print('D:new: o.c', o.c)
  o.d = 2
  self.__index = self
  return setmetatable(o, self)
end

function D:print()
  C.print(self)
  print('d = ', self.d)
end

d = d:new()
d:print()

