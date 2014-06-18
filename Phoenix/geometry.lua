local geometry = {}

function geometry.rectmidpoint(r)
  local x, y = __api.geometry_rectmidpoint(r.x, r.y, r.w, r.h)
  return {x = x, y = y}
end

function geometry.rectintersection(r1, r2)
  local x, y, w, h = __api.geometry_rectintersection(r1.x, r1.y, r1.w, r1.h, r2.x, r2.y, r2.w, r2.h)
  return {x = x, y = y, w = w, h = h}
end

return geometry
