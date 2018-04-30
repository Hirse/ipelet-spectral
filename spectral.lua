----------------------------------------------------------------------
-- Spectral Drawing Ipelet
----------------------------------------------------------------------

-- luacheck: globals label about methods
-- luacheck: globals ipe ipeui

label = "Spectral"

about = [[
Auto-layout an existing graph using eigenvectors.
]]

----------------------------------------------------------------------

--- Get the center of a bounding box.
-- @param box The bounding box of an object
-- @return The center as vector
local function boxcenter(box)
   return (box:bottomLeft() + box:topRight()) * 0.5
end

--- Find the vertex belonging to an edge.
-- @param m        The matrix of the edge
-- @param vertices The list of vertices to search
-- @param curve    The curve of the shape
-- @param head     Whether the vertex is at the head or tail of the edge
-- @return The vertex or null
local function find_vertex(m, vertices, curve, head)
   local v = curve[#curve]
   v = v[#v]
   if head then
      v = curve[1][1]
   end
   v = m * v
   for i = 1, #vertices do
      if vertices[i].bbox:contains(v) then
         return vertices[i]
      end
   end
   return nil
end

--- Create lists of vertices and edges in the current selection.
-- @param model The Ipe model
-- @return List of vertices and list of edges
local function collect_graph(model)
   local p = model:page()
   local vertices = {}
   local edges = {}
   for i, obj, sel, _ in p:objects() do
      if sel and (obj:type() == "group" or obj:type() == "reference" or obj:type() == "text") then
         local name = "v" .. i
         local bbox = p:bbox(i)
         bbox:add(bbox:bottomLeft() - ipe.Vector(5, 5))
         bbox:add(bbox:topRight() + ipe.Vector(5, 5))
         local pos = boxcenter(bbox)
         vertices[#vertices + 1] = {obj = i, name = name, bbox = bbox, pos = pos, index = #vertices + 1}
      end
   end
   for i, obj, sel, _ in p:objects() do
      if sel and obj:type() == "path" then
         local shape = obj:shape()
         local m = obj:matrix()
         if #shape == 1 and shape[1].type == "curve" and shape[1].closed == false then
            local head = find_vertex(m, vertices, shape[1], true)
            local tail = find_vertex(m, vertices, shape[1], false)
            if head and tail then
               edges[#edges + 1] = {head = head, tail = tail, obj = i}
            end
         end
      end
   end
   return vertices, edges
end

--- Get a graph matrix for the current selection.
-- @param model The Ipe model
-- @param type  The type of matrix; one of "laplacian", "adjacency", or "degree"
-- @return The matrix
local function get_matrix(model, type)
   local vertices, edges = collect_graph(model)
   local matrix = {}

   local vertexMap = {}
   for i, v in ipairs(vertices) do
      vertexMap[v.name] = i
      matrix[i] = {}
      for j, _ in ipairs(vertices) do
         matrix[i][j] = 0
      end
   end

   for _, e in ipairs(edges) do
      local headIndex = vertexMap[e.head.name]
      local tailIndex = vertexMap[e.tail.name]
      if type == "laplacian" or type == "degree" then
         matrix[headIndex][headIndex] = matrix[headIndex][headIndex] + 1
         matrix[tailIndex][tailIndex] = matrix[tailIndex][tailIndex] + 1
      end
      if type == "adjacency" then
         matrix[headIndex][tailIndex] = 1
         matrix[tailIndex][headIndex] = 1
      end
      if type == "laplacian" then
         matrix[headIndex][tailIndex] = -1
         matrix[tailIndex][headIndex] = -1
      end
   end

   return matrix
end

--- Show a given matrix in an Ipe dialog for reading and copying.
-- @param model  The Ipe model to access the dialog API
-- @param matrix The filled matrix to show
-- @param name   The name of the matrix as Dialog title
local function show_matrix(model, matrix, name)
   if #matrix == 0 then
      model:warning("Missing Selection")
      return
   end

   local d = ipeui.Dialog(model.ui:win(), name)
   local matlab_matrix = "["
   d:add("opening", "label", {label = string.sub(name, 1, 1) .. " = ("}, math.ceil(#matrix / 2), 1)
   for i, row in ipairs(matrix) do
      for j, cell in ipairs(row) do
         d:add("cell" .. i .. j, "label", {label = cell}, i, j + 1)
         matlab_matrix = matlab_matrix .. " " .. cell
      end
      matlab_matrix = matlab_matrix .. ";"
   end
   matlab_matrix = matlab_matrix .. "]"
   d:add("closing", "label", {label = ")"}, math.ceil(#matrix / 2), #matrix + 2)
   d:add("matlab", "text", {read_only = true}, #matrix + 2, 1, 1, #matrix + 2)
   d:set("matlab", matlab_matrix)
   d:addButton("close", "&Close", "accept")
   if not d:execute() then
      return
   end
end

--- Show the laplacian matrix in an Ipe dialog for reading and copying.
-- @param model The Ipe model to access the dialog API
local function show_laplacian_matrix(model)
   local matrix = get_matrix(model, "laplacian")
   show_matrix(model, matrix, "Laplacian Matrix")
end

--- Show the degree matrix in an Ipe dialog for reading and copying.
-- @param model The Ipe model to access the dialog API
local function show_degree_matrix(model)
   local matrix = get_matrix(model, "degree")
   show_matrix(model, matrix, "Degree Matrix")
end

--- Show the adjacency matrix in an Ipe dialog for reading and copying.
-- @param model The Ipe model to access the dialog API
local function show_adjacency_matrix(model)
   local matrix = get_matrix(model, "adjacency")
   show_matrix(model, matrix, "Adjacency matrix")
end

--- Apply a set of changes to the current document.
-- @param t   The transaction of changes including objects and transition values
-- @param doc The current Ipe document
local function apply_graphdrawing(t, doc)
   local max_x_value = -math.huge
   local min_x_value = math.huge
   for _, x in ipairs(t.ex) do
      if x > max_x_value then
         max_x_value = x
      end
      if x < min_x_value then
         min_x_value = x
      end
   end
   local x_step = (t.selection_bbox:right() - t.selection_bbox:left()) / (max_x_value - min_x_value)
   local x_base = t.selection_bbox:right() - (max_x_value * x_step)

   local max_y_value = -math.huge
   local min_y_value = math.huge
   for _, y in ipairs(t.ey) do
      if y > max_y_value then
         max_y_value = y
      end
      if y < min_y_value then
         min_y_value = y
      end
   end
   local y_step = (t.selection_bbox:top() - t.selection_bbox:bottom()) / (max_y_value - min_y_value)
   local y_base = t.selection_bbox:top() - (max_y_value * y_step)

   local p = doc[t.pno]

   for i, v in ipairs(t.vertices) do
      local box = p:bbox(v.obj)
      local vx = x_base + x_step * t.ex[i] - box:left()
      local vy = y_base + y_step * t.ey[i] - box:top()
      p:transform(v.obj, ipe.Translation(ipe.Vector(vx, vy)))
   end

   for _, e in ipairs(t.edges) do
      local head_x = x_base + x_step * t.ex[e.head.index]
      local head_y = y_base + y_step * t.ey[e.head.index]
      local tail_x = x_base + x_step * t.ex[e.tail.index]
      local tail_y = y_base + y_step * t.ey[e.tail.index]
      p[e.obj]:setShape(
         {
            {
               type = "curve",
               closed = false,
               {
                  type = "segment",
                  ipe.Vector(head_x, head_y),
                  ipe.Vector(tail_x, tail_y)
               }
            }
         }
      )
      p[e.obj]:setMatrix(ipe.Matrix())
   end
end

--- Layout the selected nodes and edges.
-- @param model The Ipe model
local function spectral_layout(model)
   local vertices, edges = collect_graph(model)
   local d = ipeui.Dialog(model.ui:win(), "Enter Eigenvectors")
   d:add("x", "label", {label = "x"}, 1, 1)
   d:add("y", "label", {label = "y"}, 1, 2)
   for i, _ in ipairs(vertices) do
      d:add("x" .. i, "input", {}, i + 1, 1)
      d:add("y" .. i, "input", {}, i + 1, 2)
   end
   d:addButton("ok", "&OK", "accept")
   d:addButton("cancel", "&Cancel", "reject")
   if not d:execute() then
      return
   end
   local ex = {}
   for i, _ in ipairs(vertices) do
      ex[i] = tonumber(d:get("x" .. i))
   end
   local ey = {}
   for i, _ in ipairs(vertices) do
      ey[i] = tonumber(d:get("y" .. i))
   end

   local p = model:page()
   local box = ipe.Rect()
   for i, obj, sel, _ in p:objects() do
      if sel and (obj:type() == "group" or obj:type() == "reference" or obj:type() == "text") then
         local bbox = p:bbox(i)
         box:add(bbox:bottomLeft())
         box:add(bbox:topRight())
      end
   end

   local t = {
      label = "Spectral Layout",
      pno = model.pno,
      model = model,
      vertices = vertices,
      edges = edges,
      ex = ex,
      ey = ey,
      selection_bbox = box,
      original = p:clone(),
      undo = _G.revertOriginal,
      redo = apply_graphdrawing
   }
   model:register(t)
end

----------------------------------------------------------------------

methods = {
   {label = "Show Laplacian Matrix", run = show_laplacian_matrix},
   {label = "Show Degree Matrix", run = show_degree_matrix},
   {label = "Show Adjacency Matrix", run = show_adjacency_matrix},
   {label = "Spectral Layout", run = spectral_layout}
}
