local M = {}

local Super			= require 'Super'

local Util			= require 'Util'
-- TODO add default patterns
local Patterns		= require 'Patterns'

local Arc			= require 'Arc'
local Dial			= require 'Dial'
local Poly			= require 'Poly'
local Bar			= require 'Bar'
local Text			= require 'Text'
local CriticalText	= require 'CriticalText'
local TextColumn 	= require 'TextColumn'
local Table 		= require 'Table'
local Plot			= require 'Plot'
local LabelPlot		= require 'LabelPlot'
local Image			= require 'Image'
local ScaledImage	= require 'ScaledImage'

local __cairo_new_path 				= cairo_new_path
local __cairo_rectangle				= cairo_rectangle
local __cairo_copy_path				= cairo_copy_path
local __cairo_set_font_face 		= cairo_set_font_face
local __cairo_set_font_size 		= cairo_set_font_size
local __cairo_font_extents  		= cairo_font_extents
local __cairo_toy_font_face_create 	= cairo_toy_font_face_create

local __unpack		= table.unpack
local __math_atan2	= math.atan2
local __math_sin	= math.sin
local __math_cos	= math.cos
local __math_ceil	= math.ceil
local __math_log	= math.log
local __math_rad	= math.rad

-- dummy drawing surface
local _cs_ = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1366, 768)
local CR_DUMMY = cairo_create(_cs_)
cairo_surface_destroy(_cs_)
_cs_ = nil

--Box(x, y, [width], [height])

local BOX_WIDTH = 0
local BOX_HEIGHT = 0

local Box = function(arg)

	local width = arg.width or BOX_WIDTH
	local height = arg.height or BOX_HEIGHT

	local obj = {
		x 			= arg.x,
		y 			= arg.y,
		width		= width,
		height 		= height,
		right_x 	= width + arg.x,
		bottom_y 	= height + arg.y
	}

	return obj
end

--Arc(x, y, radius, [thickness], [theta0], [theta1], [arc_pattern], [cap])

local ARC_CAP = CAIRO_LINE_CAP_BUTT
local ARC_THICKNESS = 2
local ARC_THETA0 = 0
local ARC_THETA1 = 360
local ARC_PATTERN = Patterns.DARK_GREY

local initArc = function(arg)

	local x				= arg.x
	local y				= arg.y
	local radius		= arg.radius
	local thickness		= arg.thickness or ARC_THICKNESS

	local obj = {
		x = x,
		y = y,
		thickness = thickness,
		cap = arg.cap or ARC_CAP,
		path = Arc.create_path(CR_DUMMY, x, y, radius, __math_rad(arg.theta0 or ARC_THETA0),
			__math_rad(arg.theta1 or ARC_THETA1)),
		source = Super.Pattern{
			pattern = arg.arc_pattern or ARC_PATTERN,
			p1 = {x = x, y = y},
			p2 = {x = x, y = y},
			r1 = radius - thickness * 0.5,
			r2 = radius + thickness * 0.5
		}
	}

	return obj
end

--[[
Dial([x], [y], radius, [thickness], [theta0], [theta1], [arc_pattern], [cap],
	[dial_pattern], [critical_pattern], [critical_limit])
]]

local DIAL_THICKNESS = 4
local DIAL_THETA0 = 90
local DIAL_THETA1 = 360
local DIAL_ARC_PATTERN = Patterns.GREY_ROUNDED
local DIAL_DIAL_PATTERN = Patterns.BLUE_ROUNDED
local DIAL_CRITICAL_PATTERN = Patterns.RED_ROUNDED
local DIAL_CRITICAL_LIMIT = '>80'

local initDial = function(arg)

	local x			= arg.x
	local y			= arg.y
	local radius	= arg.radius
	local thickness	= arg.thickness	or DIAL_THICKNESS
	local theta0	= arg.theta0	or DIAL_THETA0
	local theta1	= arg.theta1	or DIAL_THETA1

	local obj = initArc{
		x 			= x,
		y 			= y,
		radius 		= radius,
		thickness 	= thickness,
		theta0 		= theta0,
		theta1 		= theta1,
		arc_pattern = arg.arc_pattern or DIAL_ARC_PATTERN,
		cap			= arg.cap
	}

	local inner_radius = radius - thickness * 0.5
	local outer_radius = radius + thickness * 0.5

	obj.indicator_source = Super.Pattern{
		pattern = arg.dial_pattern or DIAL_DIAL_PATTERN,
		p1 		= {x = x, y = y},
		p2 		= {x = x, y = y},
		r1 		= inner_radius,
		r2 		= outer_radius
	}

	obj.critical = Super.Critical{
		critical_pattern 	= arg.critical_pattern or DIAL_CRITICAL_PATTERN,
		critical_limit 		= arg.critical_limit or DIAL_CRITICAL_LIMIT,
		p1 					= {x = x, y = y},
		p2 					= {x = x, y = y},
		r1 					= inner_radius,
		r2 					= outer_radius
	}

	theta0 = __math_rad(theta0)
	theta1 = __math_rad(theta1)

	obj._make_dial_path = Util.memoize(
		function(percent)
			obj.dial_angle = (1 - percent) * theta0 + percent * theta1
			return Arc.create_path(CR_DUMMY, x, y, radius, theta0, obj.dial_angle)
		end
	)

	Dial.set(obj, 0)

	return obj
end

--[[
Dial([x], [y], inner_radius, outer_radius, spacing, num_dials, [theta0], [theta1],
	[arc_pattern], [cap], [dial_pattern], [critical_pattern], [critical_limit])
]]
local initCompoundDial = function(arg)

	local inner_radius		= arg.inner_radius
	local outer_radius		= arg.outer_radius
	local spacing			= arg.spacing
	local num_dials			= arg.num_dials

	local side_length = outer_radius * 2

	local obj = {
		width = side_length,
		height = side_length,
		num_dials = num_dials,
		dials = {}
	}

	local thickness = ((outer_radius - inner_radius) - (num_dials - 1) * spacing) /	num_dials

	for i = 1, obj.num_dials do
		local r = inner_radius + thickness * 0.5 + (i - 1) * (spacing + thickness)
		obj.dials[i] = initDial{
			x 					= arg.x,
			y 					= arg.y,
			radius 				= r,
			thickness 			= thickness,
			theta0 				= arg.theta0,
			theta1 				= arg.theta1,
			arc_pattern 		= arg.arc_pattern,
			dial_pattern 		= arg.dial_pattern,
			critical_pattern 	= arg.critical_pattern,
			critical_limit 		= arg.critical_limit,
			cap					= arg.cap
		}
	end
	
	return obj
end

--Poly([thickness], [line_pattern], [cap], [join], [closed], ... points)

local POLY_THICKNESS = 1
local POLY_CAP = CAIRO_LINE_CAP_BUTT
local POLY_JOIN = CAIRO_LINE_JOIN_MITER
local POLY_LINE_PATTERN = Patterns.MID_GREY

local initPoly = function(arg)

	local obj = {
		thickness = arg.thickness or POLY_THICKNESS,
		cap = arg.cap or POLY_CAP,
		join = arg.join or POLY_JOIN,
		points = {}
	}

	local points = {}
	
	for i = 1, #arg do points[i] = arg[i] end
	
	obj.path = Poly.create_path(CR_DUMMY, arg.closed, __unpack(points))

	obj.source = Super.Pattern{
		pattern = line_pattern or POLY_LINE_PATTERN,
		p1 		= points[1],
		p2 		= points[#points]
	}

	return obj
end

--Line(p1, p2, [thickness], [line_pattern], [cap])

local LINE_THICKNESS = 1
local LINE_PATTERN = Patterns.DARK_GREY
local LINE_CAP = CAIRO_LINE_CAP_BUTT

local initLine = function(arg)

	local p1			= arg.p1
	local p2			= arg.p2
	local thickness		= arg.thickness		or LINE_THICKNESS
	local line_pattern	= arg.line_pattern	or LINE_PATTERN
	local cap			= arg.cap			or LINE_CAP

	local obj = initPoly{
		thickness 		= thickness,
		line_pattern 	= line_pattern,
		cap 			= cap,
		p1,
		p2
	}

	return obj
end

--[[
Bar(p1, p2, [thickness], [line_pattern], [indicator_pattern], [critical_pattern],
	[critical_limit], [cap])
]]

local BAR_THICKNESS = 10
local BAR_CRITICAL_LIMIT = '>80'
local BAR_CAP = CAIRO_LINE_CAP_BUTT
local BAR_LINE_PATTERN = Patterns.GREY_ROUNDED
local BAR_INDICATOR_PATTERN = Patterns.BLUE_ROUNDED
local BAR_CRITICAL_PATTERN = Patterns.RED_ROUNDED

local initBar = function(arg)

	local p1		= arg.p1
	local p2		= arg.p2
	local thickness	= arg.thickness	or BAR_THICKNESS

	local obj = initLine{
		p1 				= p1,
		p2 				= p2,
		thickness 		= thickness,
		line_pattern 	= line_pattern,
		cap 			= arg.cap or BAR_CAP
	}

	local p1_x = p1.x
	local p1_y = p1.y
	local p2_x = p2.x
	local p2_y = p2.y

	local theta = __math_atan2(p2_y - p1_y, p2_x - p1_x)
	local delta_x = 0.5 * thickness * __math_sin(theta) --and yes, these are actually flipped
	local delta_y = 0.5 * thickness * __math_cos(theta)
	local p1_pattern = {x = p1_x + delta_x, y = p1_y + delta_y}
	local p2_pattern = {x = p1_x - delta_x, y = p1_y - delta_y}

	--override pattern from superclasses
	obj.source = Super.Pattern{
		pattern = arg.line_pattern or BAR_LINE_PATTERN,
		p1 		= p1_pattern,
		p2 		= p2_pattern
	}

	obj.indicator_source = Super.Pattern{
		pattern = arg.indicator_pattern or BAR_INDICATOR_PATTERN,
		p1 		= p1_pattern,
		p2 		= p2_pattern
	}

	obj.critical = Super.Critical{
		critical_pattern 	= arg.critical_pattern or BAR_CRITICAL_PATTERN,
		critical_limit 		= arg.critical_limit or BAR_CRITICAL_LIMIT,
		p1 					= p1_pattern,
		p2 					= p2_pattern
	}

	obj.midpoint = {}
	
	obj._make_bar_path = Util.memoize(
		function(percent)
			local mp = obj.midpoint
			mp.x = (p2_x - p1_x) * percent + p1_x
			mp.y = (p2_y - p1_y) * percent + p1_y
			return Poly.create_path(CR_DUMMY, nil, p1, mp)
		end
	)

	Bar.set(obj, 0)

	return obj
end

--[[
CompoundBar([x], [y], width, [length], [spacing], [num_bars], [line_pattern],
	[indicator_pattern], [critical_pattern], [critical_limit], [cap], [is_vertical])
]]
local initCompoundBar = function(arg)

	local x					= arg.x
	local y					= arg.y
	local thickness			= arg.thickness
	local length			= arg.length
	local spacing			= arg.spacing
	local num_bars			= arg.num_bars
	local is_vertical		= arg.is_vertical

	local width = is_vertical and spacing * (num_bars -1) or length
	local height = is_vertical and length or spacing * (num_bars -1)

	local obj = Box{
		x 		= x,
		y 		= y,
		width 	= width,
		height 	= height
	}

	obj.bars = {
		n = num_bars
	}

	for i = 1, num_bars do
		local p1, p2
		local var_dim = spacing * (i - 1)
		
		if is_vertical then
			var_dim = x + var_dim
			p1 = {x = var_dim, y = y}
			p2 = {x = var_dim, y = obj.bottom_y}
		else
			var_dim = y + var_dim
			p1 = {x = x, y = var_dim}
			p2 = {x = obj.right_x, y = var_dim}
		end
		
		obj.bars[i] = initBar{
			x 					= x,
			y 					= y,
			p1 					= p1,
			p2 					= p2,
			thickness 			= arg.thickness,
			line_pattern 		= arg.line_pattern,
			indicator_pattern 	= arg.indicator_pattern,
			critical_pattern 	= arg.critical_pattern,
			critical_limit 		= arg.critical_limit,
			cap 				= arg.cap
		}
	end

	return obj
end

--Rect(x, y, [width], [height], [thickness], [join], [line_pattern])

local RECT_LINE_PATTERN = Patterns.MID_GREY
local RECT_LINE_THICKNESS = 1
local RECT_LINE_JOIN = CAIRO_LINE_JOIN_MITER

local RECT_CREATE_PATH = function(x, y, w, h)
	__cairo_new_path(CR_DUMMY)
	__cairo_rectangle(CR_DUMMY, x, y, w, h)
	return __cairo_copy_path(CR_DUMMY)
end

local initRect = function(arg)

	local x				= arg.x
	local y				= arg.y
	local width			= arg.width
	local height		= arg.height

	local obj = Box{
		x = x,
		y = y,
		width = width,
		height = height
	}

	obj.path = RECT_CREATE_PATH(x, y, width, height)
	
	obj.thickness = arg.thickness or RECT_LINE_THICKNESS
	obj.join = arg.join or RECT_LINE_JOIN

	obj.source = Super.Pattern{
		pattern = arg.line_pattern	or RECT_LINE_PATTERN,
		{x = x, y = y},
		{x = x, y = y + height}
	}

	return obj
end

--FillRect(x, y, [width], [height], [thickness], [join], [line_pattern], [fill_pattern])
local initFillRect = function(arg)

	local x				= arg.x
	local y				= arg.y
	local width			= arg.width
	local height		= arg.height

	local obj = initRect{
		x 				= x,
		y 				= y,
		width 			= width,
		height 			= height,
		join 			= arg.join,
		thickness		= arg.thickness,
		line_pattern 	= arg.line_pattern
	}
	obj.fill_source = Super.Pattern{
		pattern = arg.fill_pattern,
		p1 		= {x = x, y = y},
		p2 		= {x = x, y = y + height}
	}

	return obj
end

--Image([path], x, y)

local initImage = function(arg)

	local path	= arg.path
	local x		= arg.x
	local y		= arg.y

	local obj = {x = x,	y = y}

	local width, height

	if path then Image.update(obj, path) end

	obj.width = width or 0
	obj.height = height or 0
	obj.path = path

	return obj
end

--ScaledImage([path], x, y, [width], [height])

local initScaledImage = function(arg)

	local path	= arg.path
	local x		= arg.x
	local y		= arg.y

	local obj = Box{x = x, y = y}

	local img_width
	local img_height

	if path then ScaledImage.update(obj, path) end

	obj.width = arg.width or 0
	obj.height = arg.height or 0

	return obj
end

--[[
Text(x, y, [text], [font_size], [x_align], [y_align], [text_color], [font], [slant],
	[weight], [append_front], [append_end])
]]

local TEXT_STRING = '<null>'
local TEXT_FONT_SIZE = 13
local TEXT_X_ALIGN = 'left'
local TEXT_Y_ALIGN = 'center'
local TEXT_FONT = 'Neuropolitical'
local TEXT_FONT_SLANT = CAIRO_FONT_SLANT_NORMAL
local TEXT_FONT_WEIGHT = CAIRO_FONT_WEIGHT_NORMAL
local TEXT_COLOR = Patterns.LIGHT_GREY

local fe = cairo_font_extents_t:create()
tolua.takeownership(fe)

local initText = function(arg)

	local font_size = arg.font_size	or TEXT_FONT_SIZE

	local font_face = __cairo_toy_font_face_create(
		arg.font or TEXT_FONT,
		arg.slant or TEXT_FONT_SLANT,
		arg.weight or TEXT_FONT_WEIGHT
	)
	local source = Super.Pattern{
		pattern = arg.text_color or TEXT_COLOR
	}

	__cairo_set_font_size(CR_DUMMY, font_size)
	__cairo_set_font_face(CR_DUMMY, font_face)
	__cairo_font_extents(CR_DUMMY, fe)

	local delta_y
	local y_align = arg.y_align or TEXT_Y_ALIGN

	if		y_align == 'bottom' then delta_y = -fe.descent
	elseif 	y_align == 'top'	then delta_y = fe.height
	elseif 	y_align == 'center' then delta_y = 0.92 * fe.height * 0.5 - fe.descent
	end

	local obj = {
		x = arg.x,
		y = arg.y + delta_y,
		x_ref = arg.x,
		y_ref = arg.y + delta_y,
		delta_y = delta_y,
		height = fe.ascent,
		font_size = font_size,
		x_align = arg.x_align or TEXT_X_ALIGN,
		y_align = y_align,
		font_face = font_face,
		source = source,
		current_source = source, --hack to integrate critical
		append_front = arg.append_front,
		append_end = arg.append_end
	}

	Text.set(obj, CR_DUMMY, (arg.text or TEXT_STRING))

	return obj
end

--[[
CriticalText(x, y, [text], [font_size], [x_align], [y_align], [text_color], [font],
	[slant], [weight], [append_front], [append_end], [critical_color], [critical_limit])
]]

local CRITICALTEXT_COLOR = Patterns.BLUE
local CRITICALTEXT_CRITICAL_COLOR = Patterns.RED

local initCriticalText = function(arg)

	local obj = initText{
		x 			 = arg.x,
		y 			 = arg.y,
		text 		 = arg.text,
		font_size 	 = arg.font_size,
		x_align 	 = arg.x_align,
		y_align 	 = arg.y_align,
		text_color	 = arg.text_color or CRITICALTEXT_COLOR,
		font 		 = arg.font,
		slant 		 = arg.slant,
		weight 		 = arg.weight,
		append_front = arg.append_front,
		append_end 	 = arg.append_end
	}

	obj.critical = Super.Critical{
		critical_color 	= arg.critical_color or CRITICALTEXT_CRITICAL_COLOR,
		critical_limit	= arg.critical_limit
	}

	CriticalText.set(obj, CR_DUMMY, '0')

	return obj
end

--[[
TextColumn(x, y, [spacing], [max_length], [font_size], [x_align], [y_align],
	[text_color], [font], [slant], [weight], [append_front], [append_end],
	[num_rows], ... text list)
]]

local TEXTCOLUMN_SPACING = 20
local TEXTCOLUMN_NUM_ROWS = 1

local initTextColumn = function(arg)

	local obj = {
		rows = {
			n = (#arg == 0) and (arg.num_rows or TEXTCOLUMN_NUM_ROWS) or #arg
		},
		spacing = arg.spacing or TEXTCOLUMN_SPACING,
		max_length = arg.max_length
	}

	for i = 1, obj.rows.n do
		obj.rows[i] = initText{
			x 				= arg.x,
			y 				= arg.y + obj.spacing * (i - 1),
			font_size 		= arg.font_size,
			x_align 		= arg.x_align,
			y_align 		= arg.y_align,
			text_color 		= arg.text_color,
			font 			= arg.font,
			slant 			= arg.slant,
			weight 			= arg.weight,
			append_front 	= arg.append_front,
			append_end 		= arg.append_end
		}
		TextColumn.set(obj, CR_DUMMY, i, (#arg == 0) and 'row'..i or arg[i])
	end

	return obj
end

--[[
Table(x, y, width, height, [num_rows], [max_length], [line_pattern],
	[body_color], [header_color], [separator_pattern], ... header list)
]]

local TABLE_FONT = "Neuropolitical"

local TABLE_HEADER_FONT_SIZE = 11
local TABLE_HEADER_FONT_SLANT = CAIRO_FONT_SLANT_NORMAL
local TABLE_HEADER_FONT_WEIGHT = CAIRO_FONT_WEIGHT_NORMAL

local TABLE_BODY_FONT_SIZE = 11
local TABLE_BODY_FONT_SLANT = CAIRO_FONT_SLANT_NORMAL
local TABLE_BODY_FONT_WEIGHT = CAIRO_FONT_WEIGHT_NORMAL

local TABLE_X_ALIGN = 'center'
local TABLE_Y_ALIGN = 'center'

local TABLE_JOIN = CAIRO_LINE_JOIN_MITER

local TABLE_TOP_PAD = 15
local TABLE_BOTTOM_PAD = 15
local TABLE_LEFT_PAD = 5
local TABLE_RIGHT_PAD = 5
local TABLE_HEADER_PAD_FACTOR = 1.25

local TABLE_SEPARATOR_THICKNESS = 1
local TABLE_SEPARATOR_CAP = CAIRO_LINE_CAP_BUTT

local TABLE_NUM_ROWS = 5
local TABLE_MAX_LENGTH = 8
local TABLE_HEADER_COLOR = Patterns.BLUE
local TABLE_BODY_COLOR = Patterns.LIGHT_GREY
local TABLE_LINE_PATTERN = Patterns.DARK_GREY
local TABLE_SEPARATOR_PATTERN = Patterns.DARK_GREY

local initTable = function(arg)

	local x					= arg.x
	local y					= arg.y
	local width				= arg.width
	local height			= arg.height
	local num_rows			= arg.num_rows or TABLE_NUM_ROWS

	local obj = initRect{
		x 				= x + 0.5,
		y 				= y + 0.5,
		width 			= width,
		height 			= height,
		join 			= TABLE_JOIN,
		line_pattern 	= arg.line_pattern or TABLE_LINE_PATTERN
	}
		
	obj.table = Box{
		x 		= x + TABLE_LEFT_PAD,
		y 		= y + TABLE_TOP_PAD,
		width 	= width - TABLE_LEFT_PAD - TABLE_RIGHT_PAD,
		height 	= height - TABLE_TOP_PAD - TABLE_BOTTOM_PAD
	}

	local tbl = obj.table
	tbl.num_rows = num_rows
	tbl.num_columns = #arg

	tbl.columns = {}
	
	local column_width = tbl.width / tbl.num_columns
	local spacing = tbl.height / (TABLE_HEADER_PAD_FACTOR + tbl.num_rows - 1)

	for i = 1, tbl.num_columns do
		local column_x = tbl.x + column_width * (i - 0.5)

		tbl.columns[i] = initTextColumn{
			x 			= column_x,
			y 			= tbl.y + spacing * TABLE_HEADER_PAD_FACTOR,
			spacing 	= spacing,
			max_length 	= arg.max_length or TABLE_MAX_LENGTH,
			font_size 	= TABLE_BODY_FONT_SIZE,
			x_align 	= TABLE_X_ALIGN,
			y_align 	= TABLE_Y_ALIGN,
			text_color 	= arg.body_color or TABLE_BODY_COLOR,
			font 		= TABLE_FONT,
			slant 		= TABLE_BODY_FONT_SLANT,
			slant 		= TABLE_BODY_FONT_WEIGHT,
			num_rows 	= num_rows
		}
		tbl.columns[i].header = initText{
			x 			= column_x,
			y 			= tbl.y,
			text 		= arg[i],
			font_size 	= TABLE_HEADER_FONT_SIZE,
			x_align 	= TABLE_X_ALIGN,
			y_align 	= TABLE_Y_ALIGN,
			text_color 	= arg.header_color or TABLE_HEADER_COLOR,
			font 		= TABLE_FONT,
			slant 		= TABLE_HEADER_FONT_SLANT,
			weight 		= TABLE_HEADER_FONT_WEIGHT
		}
	end

	tbl.separators = {
		n = tbl.num_columns - 1
	}

	for i = 1, tbl.separators.n do
		local sep_x = tbl.x + column_width * i
		tbl.separators[i] = initLine{
			thickness 		= TABLE_SEPARATOR_THICKNESS,
			line_pattern 	= arg.separator_pattern or TABLE_SEPARATOR_PATTERN,
			cap 			= TABLE_SEPARATOR_CAP,
			p1 				= {x = sep_x, y = tbl.y},
			p2 				= {x = sep_x, y = tbl.bottom_y}
		}
	end

	return obj
end


--[[
Plot([x], [y], width, height, [seconds], [num_x_intrvl], [num_y_intrvl],
	[outline_pattern], [intrvl_pattern], [data_pattern])

where data_pattern is a table of form {line_pattern, fill_pattern} where
either can be nil to omit
]]

local PLOT_SECONDS = 90
local PLOT_NUM_X_INTERVAL = 9
local PLOT_NUM_Y_INTERVAL = 4
local PLOT_OUTLINE_PATTERN = Patterns.DARK_GREY
local PLOT_INTRVL_PATTERN = Patterns.DARK_GREY
local DATA_PATTERN = {Patterns.PLOT_LINE_BLUE, Patterns.PLOT_FILL_BLUE}

local initPlot = function(arg)

	local x					= arg.x
	local y					= arg.y
	local width				= arg.width
	local height			= arg.height
	
	local obj = Box{
		x = x,
		y = y,
		width = width,
		height = height
	}

	local p1 = {x = x, 			y = y}
	local p2 = {x = x + width, 	y = y}

	--allocate outline objects
	obj.outline = {
		source = Super.Pattern{
			pattern = arg.outline_pattern or PLOT_OUTLINE_PATTERN,
			p1 = p1,
			p2 = p2
		},
	}

	obj.intrvls = {
		source = Super.Pattern{
			pattern = arg.intrvl_pattern or PLOT_INTRVL_PATTERN,
			p1 = p1,
			p2 = p2
		},
		x = {
			n = arg.num_x_intrvl or PLOT_NUM_X_INTERVAL
		},
		y = {
			n = arg.num_y_intrvl or PLOT_NUM_Y_INTERVAL
		},
		
	}
	
	local seconds = arg.seconds or PLOT_SECONDS

	local _create_data_pattern = function(data_pattern)
	   local line_pattern = data_pattern[1]
	   local fill_pattern = data_pattern[2]
	   return {
		  line_source = line_pattern and Super.Pattern{
			 pattern = line_pattern,
			 p1 = p1,
			 p2 = p2
													  },
		  fill_source = fill_pattern and Super.Pattern{
			 pattern = fill_pattern,
			 p1 = p1,
			 p2 = p2,
													  },
	   }
	end

	obj.data = {seconds = seconds, num_points = seconds * _G_INIT_DATA_.UPDATE_INTERVAL}
	if #arg == 0 then
	   obj.data[1] = _create_data_pattern(DATA_PATTERN)
	else
	   for i = 1, #arg do
		  obj.data[i] = _create_data_pattern(arg[i])
	   end
	end
	
	Plot.position_x_intrvls(obj, CR_DUMMY)
	Plot.position_y_intrvls(obj, CR_DUMMY)
	Plot.position_graph_outline(obj, CR_DUMMY)

	return obj
end

--[[
LabelPlot(x, y, width, height, [seconds], [x_label_func], [y_label_func],
	[num_x_intrvl], [num_y_intrvl], [outline_pattern], [intrvl_pattern],
	[data_line_pattern], [data_fill_pattern], [label_color])
]]

local LABELPLOT_LABEL_SIZE = 8
local LABELPLOT_LABEL_FONT = "Neuropolitical"
local LABELPLOT_LABEL_SLANT = CAIRO_FONT_SLANT_NORMAL
local LABELPLOT_LABEL_WEIGHT = CAIRO_FONT_WEIGHT_NORMAL
local LABELPLOT_LABEL_COLOR = Patterns.MID_GREY
local LABELPLOT_SECONDS = 90
local LABELPLOT_NUM_X_INTERVAL = 9
local LABELPLOT_NUM_Y_INTERVAL = 4

-- TODO make patterns a variable argument which specifies the number of input values
local initLabelPlot = function(arg)

	local x					= arg.x
	local y					= arg.y
	local width				= arg.width
	local height			= arg.height
	local seconds			= arg.seconds			or LABELPLOT_SECONDS
	local x_label_func		= arg.x_label_func
	local y_label_func		= arg.y_label_func
	local num_x_intrvl		= arg.num_x_intrvl		or LABELPLOT_NUM_X_INTERVAL
	local num_y_intrvl		= arg.num_y_intrvl		or LABELPLOT_NUM_Y_INTERVAL
	local label_color		= arg.label_color		or LABELPLOT_LABEL_COLOR
	local x_input_factor	= arg.x_input_factor
	local y_input_factor	= arg.y_input_factor
	
	local obj = Box{
		x = x,
		y = y,
		width = width,
		height = height
	}

	obj.plot = initPlot{
		x 					= x,
		y 					= y,
		width 				= width,
		height 				= height,
		seconds 			= seconds,
		num_x_intrvl 		= num_x_intrvl,
		num_y_intrvl 		= num_y_intrvl,
		outline_pattern 	= arg.outline_pattern,
		intrvl_pattern 		= arg.intrvl_pattern,
		__unpack(arg)
	}

	obj.labels = {
		x = {
			n = num_x_intrvl + 1
		},
		y = {
			n = num_y_intrvl + 1
		}
	}

	--x labels
	local labels_x = obj.labels.x
	
	labels_x._func = x_label_func or function(fraction)
		return Util.round_to_string((1-fraction) * seconds)..'s'
	end

	for i = 1, labels_x.n do
		labels_x[i] = initText{
			x			= 0,
			y 			= obj.bottom_y,
			font_size 	= LABELPLOT_LABEL_SIZE,
			x_align 	= 'center',
			y_align 	= 'bottom',
			text_color 	= label_color
		}
	end

	LabelPlot.populate_x_labels(obj, CR_DUMMY, x_input_factor)

	--y labels
	local labels_y = obj.labels.y
	
	labels_y._func = y_label_func or function(fraction)
		return Util.round_to_string(fraction * 100)..'%'
	end

	for i = 1, labels_y.n do
		labels_y[i] = initText{	
			x 			= x,
			y			= 0,
			font_size 	= LABELPLOT_LABEL_SIZE,
			x_align 	= 'left',
			y_align 	= 'center',
			text_color 	= label_color,
		}
	end
	
	LabelPlot.populate_y_labels(obj, CR_DUMMY, y_input_factor)

	LabelPlot.position_x_intrvls(obj.plot, CR_DUMMY)
	LabelPlot.position_y_intrvls(obj.plot, CR_DUMMY)
	
	LabelPlot.position_graph_outline(obj.plot, CR_DUMMY)

	LabelPlot.position_x_labels(obj)
	LabelPlot.position_y_labels(obj)

	return obj
end

--[[
ScalePlot(x, y, width, height, [seconds], [x_label_func], [y_label_func],
	[scale_function], [num_x_intrvl], [num_y_intrvl], [outline_pattern], [intrvl_pattern],
	[data_line_pattern], [data_fill_pattern], [label_color])
]]

local SCALEPLOT_THRESHOLD = 0.9	--trip point to go to next scale domain
local SCALEPLOT_BASE = 2			--base for log scale
local SCALEPLOT_INITIAL = 1		--initial scale domain value

local SCALEPLOT_Y_LABEL_FUNCTION = function(kilobytes)
	local new_unit = Util.get_unit_base_K(kilobytes)
	local converted_bytes = Util.convert_bytes(kilobytes, 'KiB', new_unit)
	local precision = 0
	if converted_bytes < 10 then precision = 1 end
	
	return Util.round_to_string(converted_bytes, precision)..' '..new_unit..'/s'
end

-- TODO make patterns a variable argument which specifies the number of input values
local initScalePlot = function(arg)

	local base = arg.scaleplot_base or SCALEPLOT_BASE
	local initial = arg.scaleplot_initial or SCALEPLOT_INITIAL

	local obj = initLabelPlot{
		x 					= arg.x,
		y 					= arg.y,
		width 				= arg.width,
		height 				= arg.height,
		seconds 			= arg.seconds,
		x_label_func 		= arg.x_label_func,
		y_label_func 		= arg.y_label_func or SCALEPLOT_Y_LABEL_FUNCTION,
		num_x_intrvl 		= arg.num_x_intrvl,
		num_y_intrvl 		= arg.num_y_intrvl,
		outline_pattern 	= arg.outline_pattern,
		intrvl_pattern 		= arg.intrvl_pattern,
		label_color 		= arg.label_color,
		y_input_factor		= base ^ initial,
		__unpack(arg)
	}
	
	obj.scale = {
		_func = function(x)
			local threshold = arg.scaleplot_threshold or SCALEPLOT_THRESHOLD
			
			local domain = 1
			if x > 0 then
				domain = __math_ceil(__math_log(x / threshold) / __math_log(base) - initial + 1)
			end

			if domain < 1 then domain = 1 end
			return domain, base ^ -(initial + domain - 1)
		end,
		factor = 0.5,
		domain = 1,
		timers = {}
	}

	obj.scale.previous_domain, obj.scale.previous_factor = obj.scale._func(0)

	return obj
end

--Header(x, y, width, header)

local HEADER_HEIGHT = 45
local HEADER_FONT_SIZE = 15
local HEADER_FONT_SLANT = CAIRO_FONT_SLANT_NORMAL
local HEADER_FONT_WEIGHT = CAIRO_FONT_WEIGHT_BOLD
local HEADER_X_ALIGN = 'left'
local HEADER_Y_ALIGN = 'top'
local HEADER_COLOR = Patterns.WHITE
local HEADER_UNDERLINE_OFFSET = -20
local HEADER_UNDERLINE_THICKNESS = 3
local HEADER_UNDERLINE_COLOR = Patterns.WHITE
local HEADER_UNDERLINE_CAP = CAIRO_LINE_CAP_ROUND

local initHeader = function(arg)

	local x 		= arg.x
	local y 		= arg.y
	local width 	= arg.width

	local bottom_y = y + HEADER_HEIGHT
	local underline_y = bottom_y + HEADER_UNDERLINE_OFFSET

	local obj = {
		text = initText{
			x 			= x,
			y 			= y,
			text 		= arg.header,
			font_size 	= HEADER_FONT_SIZE,
			x_align 	= HEADER_X_ALIGN,
			y_align 	= HEADER_Y_ALIGN,
			text_color 	= HEADER_COLOR,
			slant 		= HEADER_FONT_SLANT,
			weight 		= HEADER_FONT_WEIGHT
		},
		bottom_y = bottom_y,
		underline = initLine{
			p1 				= {x = x, y = underline_y},
			p2 				= {x = x + width, y = underline_y},
			thickness 		= HEADER_UNDERLINE_THICKNESS,
			line_pattern 	= HEADER_UNDERLINE_COLOR,
			cap 			= HEADER_UNDERLINE_CAP
		}
	}

	return obj
end

--Panel{x, y, width, height}

local PANEL_LINE_PATTERN = Patterns.DARK_GREY
local PANEL_FILL_PATTERN = Patterns.TRANSPARENT_BLACK

local initPanel = function(arg)

	local obj = initFillRect{
		x 				= arg.x + 0.5,
		y 				= arg.y + 0.5,
		width 			= arg.width,
		height 			= arg.height,
		line_pattern 	= PANEL_LINE_PATTERN,
		fill_pattern 	= PANEL_FILL_PATTERN,
	}

	return obj
end

M.Arc = initArc
M.Dial = initDial
M.CompoundDial = initCompoundDial
M.Poly = initPoly
M.Line = initLine
M.Bar = initBar
M.CompoundBar = initCompoundBar
M.Rect = initRect
M.FillRect = initFillRect
M.Image = initImage
M.ScaledImage = initScaledImage
M.Text = initText
M.CriticalText = initCriticalText
M.TextColumn = initTextColumn
M.Table = initTable
M.Plot = initPlot
M.LabelPlot = initLabelPlot
M.ScalePlot = initScalePlot
M.Header = initHeader
M.Panel = initPanel

M = Util.set_finalizer(M, function()
	print('Cleaning up Widget.lua')
	cairo_destroy(CR_DUMMY)
end)

return M
