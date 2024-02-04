local sampev = require('lib.samp.events')
local mad = require('MoonAdditions')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require('inicfg')
local directIni = 'CarColor.ini'
local ini = inicfg.load(inicfg.load({
	main = {
		rainbowcolor = false,
		color = 0xFFFFFFFF,
		changecolor = false,
		speed = 1,
	},
}, directIni))
inicfg.save(ini, directIni)

local renderWindow = imgui.new.bool(false)
local rainbowcolor = imgui.new.bool(ini.main.rainbowcolor)
local speed = imgui.new.int(ini.main.speed)
local color = imgui.new.float[4](1, 1, 1, 1)
local changecolor = imgui.new.bool(ini.main.changecolor)
local displaycomponents = imgui.new.bool(false)
local exception = {}
local font = renderCreateFont('Arial', 7, 5)
imgui.OnInitialize(function()
	local carcolor = imgui.ColorConvertU32ToFloat4(ini.main.color)
	color = imgui.new.float[4](carcolor.x,carcolor.y,carcolor.z,carcolor.w)
	imgui.GetIO().IniFilename = nil
	imgui.DarkTheme()
end)
local newFrame = imgui.OnFrame(
	function() return renderWindow[0] end,
	function(player)
		local resX, resY = getScreenResolution()
		local sizeX, sizeY = 355, 400
		imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
		if imgui.Begin('Car Color', renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
			if imgui.BeginChild('##main', imgui.ImVec2(-1, -1), true) then
				if imgui.CustomCheckbox(u8('Изменение цвета'), changecolor) then
					ini.main.changecolor = changecolor[0]
					inicfg.save(ini, directIni)
				end
				if imgui.ColorEdit4(u8('Цвет'), color, imgui.ColorEditFlags.AlphaBar) then
					if isCharInAnyCar(1) and changecolor[0] then
						local car = storeCarCharIsInNoSave(1)
						change_vehicle_color(car, function (mat)
							mat:set_color(color[0]*255, color[1]*255, color[2]*255, color[3]*255)
						end)
					end
					ini.main.color = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color[0], color[1], color[2], color[3]))
					inicfg.save(ini, directIni)
				end
				if imgui.CustomCheckbox(u8('Радужный режим'), rainbowcolor) then
					ini.main.rainbowcolor = rainbowcolor[0]
					inicfg.save(ini, directIni)
				end
				if imgui.SliderInt(u8('Скорость'), speed, 1, 10) then
					ini.main.speed = speed[0]
					inicfg.save(ini, directIni)
				end
                imgui.CustomCheckbox(u8('Отображение компонентов'), displaycomponents)
                imgui.CenterText(u8('Исключения'))
                imgui.SameLine(250)
                if imgui.Button(u8('Сохранить'), imgui.ImVec2(75, 25)) then
                    SaveException()
                end
                if isCharInAnyCar(1) then
                    local car = storeCarCharIsInNoSave(1)
                    local components = mad.get_all_vehicle_components(car)
                    for i, comp in ipairs(components) do
                        imgui.Text('ID: '..i..', NAME: '..comp.name)
                        imgui.SameLine(250)
                        local result, found = findtable(exception, i)
                        if result then
                            if imgui.Button(u8('Удалить##'..i), imgui.ImVec2(75, 25)) then
                                table.remove(exception, found)
                            end
                        else
                            if imgui.Button(u8('Добавить##'..i), imgui.ImVec2(75, 25)) then
                                table.insert(exception, i)
                            end
                        end
                    end
                end
				imgui.EndChild()
			end
			imgui.End()
		end
	end
)

function main()
	while not isSampAvailable() do wait(0) end
    LoadException()
	sampRegisterChatCommand('carcolor', function()
		renderWindow[0] = not renderWindow[0]
	end)
	while true do
		wait(0)
		if isCharInAnyCar(1) then
            local car = storeCarCharIsInNoSave(1)
            if rainbowcolor[0] and changecolor[0] then
                local r,g,b,a = rainbow(speed[0], 255, 0)
                change_vehicle_color(car, function (mat)
                    mat:set_color(r,g,b,a)
                end)
            end
            if displaycomponents[0] then
				local components = mad.get_all_vehicle_components(car)
				for i, comp in ipairs(components) do
					draw_component(comp, i)
				end
            end
		end
	end
end
function sampev.onSendEnterVehicle(vehicleId, passenger)
	if not passenger then
		lua_thread.create(function ()
			while not isCharInAnyCar(1) do wait(0) end
			local car = storeCarCharIsInNoSave(1)
			change_vehicle_color(car, function (mat)
				mat:set_color(color[0]*255, color[1]*255, color[2]*255, color[3]*255)
			end)
		end)
	end
end
function findtable(tbl, find)
    for k, v in pairs(tbl) do
        if v == find then
            return true, k
        end
    end
    return false
end
function change_vehicle_color(car, func)
    local components = mad.get_all_vehicle_components(car)
    for i, comp in ipairs(components) do
        if not findtable(exception, i) then
            for _, obj in ipairs(comp:get_objects()) do
                for _, mat in ipairs(obj:get_materials()) do
                    func(mat)
                end
            end
        end
    end
end
function SaveException()
    local file = io.open(getWorkingDirectory()..'\\config\\CarColorException.dat', 'w')
    if file then
        file:write(table.concat(exception, '\n'))
        file:close()
    end
end
function LoadException()
    if doesFileExist(getWorkingDirectory()..'\\config\\CarColorException.dat') then
        for line in io.lines(getWorkingDirectory()..'\\config\\CarColorException.dat') do
            if #line > 0 then
                table.insert(exception, tonumber(line))
            end
        end
    end
end
function rainbow(speed, alpha, offset)
    local clock = os.clock() + offset
    local r = math.floor(math.sin(clock * speed) * 127 + 128)
    local g = math.floor(math.sin(clock * speed + 2) * 127 + 128)
    local b = math.floor(math.sin(clock * speed + 4) * 127 + 128)
    return r,g,b,alpha
end
function imgui.DarkTheme()
    imgui.SwitchContext()
    --==[ STYLE ]==--
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10

    --==[ BORDER ]==--
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1

    --==[ ROUNDING ]==--
    imgui.GetStyle().WindowRounding = 5
    imgui.GetStyle().ChildRounding = 5
    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().PopupRounding = 5
    imgui.GetStyle().ScrollbarRounding = 5
    imgui.GetStyle().GrabRounding = 5
    imgui.GetStyle().TabRounding = 5

    --==[ ALIGN ]==--
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    
    --==[ COLORS ]==--
    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.50)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end
function imgui.CustomCheckbox(str_id, bool, a_speed)
    local p         = imgui.GetCursorScreenPos()
    local DL        = imgui.GetWindowDrawList()

    local label     = str_id:gsub('##.+', '') or ""
    local h         = imgui.GetTextLineHeightWithSpacing() + 2
    local speed     = a_speed or 0.1

    local function bringVec2To(from, to, start_time, duration)
        local timer = os.clock() - start_time
        if timer >= 0.00 and timer <= duration then
            local count = timer / (duration / 100)
            return imgui.ImVec2(
                from.x + (count * (to.x - from.x) / 100),
                from.y + (count * (to.y - from.y) / 100)
            ), true
        end
        return (timer > duration) and to or from, false
    end
    local function bringVec4To(from, to, start_time, duration)
        local timer = os.clock() - start_time
        if timer >= 0.00 and timer <= duration then
            local count = timer / (duration / 100)
            return imgui.ImVec4(
                from.x + (count * (to.x - from.x) / 100),
                from.y + (count * (to.y - from.y) / 100),
                from.z + (count * (to.z - from.z) / 100),
                from.w + (count * (to.w - from.w) / 100)
            ), true
        end
        return (timer > duration) and to or from, false
    end

    local c = {
        {0.18536826495, 0.42833250947},
        {0.44109925858, 0.70010380622},
        {0.38825341901, 0.70010380622},
        {0.81248970176, 0.28238693976},
    }

    if UI_CUSTOM_CHECKBOX == nil then UI_CUSTOM_CHECKBOX = {} end
    if UI_CUSTOM_CHECKBOX[str_id] == nil then
        UI_CUSTOM_CHECKBOX[str_id] = {
            lines = {
                {
                    from = imgui.ImVec2(0, 0),
                    to = imgui.ImVec2(h*c[1][1], h*c[1][2]),
                    start = 0,
                    anim = false,
                },
                {
                    from = imgui.ImVec2(0, 0),
                    to = bool[0] and imgui.ImVec2(h*c[2][1], h*c[2][2]) or imgui.ImVec2(h*c[1][1], h*c[1][2]),
                    start = 0,
                    anim = false,
                },
                {
                    from = imgui.ImVec2(0, 0),
                    to = imgui.ImVec2(h*c[3][1], h*c[3][2]),
                    start = 0,
                    anim = false,
                },
                {     
                    from = imgui.ImVec2(0, 0),   
                    to = bool[0] and imgui.ImVec2(h*c[4][1], h*c[4][2]) or imgui.ImVec2(h*c[3][1], h*c[3][2]),
                    start = 0,
                    anim = false,
                },
            },
            hovered = false,
            h_start = 0,
        }
    end

    local pool = UI_CUSTOM_CHECKBOX[str_id]

    imgui.BeginGroup()
        imgui.InvisibleButton(str_id, imgui.ImVec2(h, h))
        imgui.SameLine()
        local pp = imgui.GetCursorPos()
        imgui.SetCursorPos(imgui.ImVec2(pp.x, pp.y + h/2 - imgui.CalcTextSize(label).y/2))
        imgui.Text(label)
    imgui.EndGroup()

    local clicked = imgui.IsItemClicked()
    if pool.hovered ~= imgui.IsItemHovered() then
        pool.hovered = imgui.IsItemHovered()
        local timer = os.clock() - pool.h_start
        if timer <= speed and timer >= 0 then
            pool.h_start = os.clock() - (speed - timer)
        else
            pool.h_start = os.clock()
        end
    end

    if clicked then
        local isAnim = false

        for i = 1, 4 do
            if pool.lines[i].anim then
                isAnim = true
            end
        end

        if not isAnim then
            bool[0] = not bool[0]

            pool.lines[1].from = imgui.ImVec2(h*c[1][1], h*c[1][2])
            pool.lines[1].to = bool[0] and imgui.ImVec2(h*c[1][1], h*c[1][2]) or imgui.ImVec2(h*c[2][1], h*c[2][2])
            pool.lines[1].start = bool[0] and 0 or os.clock()

            pool.lines[2].from = bool[0] and imgui.ImVec2(h*c[1][1], h*c[1][2]) or imgui.ImVec2(h*c[2][1], h*c[2][2])
            pool.lines[2].to = bool[0] and imgui.ImVec2(h*c[2][1], h*c[2][2]) or imgui.ImVec2(h*c[2][1], h*c[2][2])
            pool.lines[2].start = bool[0] and os.clock() or 0

            pool.lines[3].from = imgui.ImVec2(h*c[3][1], h*c[3][2])
            pool.lines[3].to = bool[0] and imgui.ImVec2(h*c[3][1], h*c[3][2]) or imgui.ImVec2(h*c[4][1], h*c[4][2])
            pool.lines[3].start = bool[0] and 0 or os.clock() + speed

            pool.lines[4].from = bool[0] and imgui.ImVec2(h*c[3][1], h*c[3][2]) or imgui.ImVec2(h*c[4][1], h*c[4][2])
            pool.lines[4].to = imgui.ImVec2(h*c[4][1], h*c[4][2]) or imgui.ImVec2(h*c[4][1], h*c[4][2])
            pool.lines[4].start = bool[0] and os.clock() + speed or 0
        end
    end

    local pos = {}

    for i = 1, 4 do
        pos[i], pool.lines[i].anim = bringVec2To(
            p + pool.lines[i].from,
            p + pool.lines[i].to,
            pool.lines[i].start,
            speed
        )
    end

    local color = imgui.GetStyle().Colors[imgui.Col.Text]
    local c = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
    local colorHovered = bringVec4To(
        pool.hovered and imgui.ImVec4(c.x, c.y, c.z, 0) or imgui.ImVec4(c.x, c.y, c.z, 0.2),
        pool.hovered and imgui.ImVec4(c.x, c.y, c.z, 0.2) or imgui.ImVec4(c.x, c.y, c.z, 0),
        pool.h_start,
        speed
    )

    DL:AddRectFilled(p, imgui.ImVec2(p.x + h, p.y + h), imgui.GetColorU32Vec4(colorHovered), h/15, 15)
    DL:AddRect(p, imgui.ImVec2(p.x + h, p.y + h), imgui.GetColorU32Vec4(color), h/15, 15, 1.5)
    DL:AddLine(pos[1], pos[2], imgui.GetColorU32Vec4(color), h/10)
    DL:AddLine(pos[3], pos[4], imgui.GetColorU32Vec4(color), h/10)
    
    return clicked
end
function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end
function draw_component(component, id)
	local x, y, z = component.matrix.pos:get()
	local sx, sy = convert3DCoordsToScreen(x, y, z)
	renderFontDrawText(font, string.format('Component #%d: %s', id, component.name), sx, sy, -1)
	sx = sx + 4
end