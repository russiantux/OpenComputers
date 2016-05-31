-- package.loaded.MineOSCore = nil
-- _G.MineOSCore = nil

-- Адаптивная загрузка необходимых библиотек и компонентов
local libraries = {
	buffer = "doubleBuffering",
	MineOSCore = "MineOSCore",
	component = "component",
	computer = "computer",
	event = "event",
	fs = "filesystem",
	files = "files",
	context = "context",
	unicode = "unicode",
	archive = "archive",
	serialization = "serialization",
	GUI = "GUI",
}

local components = {
	["gpu"] = "gpu",
}

for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end
for comp in pairs(components) do if not _G[comp] then _G[comp] = _G.component[components[comp]] end end
libraries, components = nil, nil

------------------------------------------------------------------------------------------------------------------

local colors = {
	topBar = 0xdddddd,
	main = 0xffffff,
	leftBar = 0xeeeeee,
	leftBarTransparency = 35,
	leftBarSelection = ecs.colors.blue,
	leftBarSelectionText = 0xFFFFFF,
	closes = {close = ecs.colors.red, hide = ecs.colors.orange, full = ecs.colors.green},
	topText = 0x262626,
	topButtons = 0xffffff,
	topButtonsText = 0x262626,
	leftBarHeader = 0x000000,
	leftBarList = 0x444444,
	selection = 0x555555,
	mainScrollBarPipe = 0x999999,
}

local pathToComputerIcon = "MineOS/System/OS/Icons/Computer.pic"
local pathToConfig = "MineOS/System/Finder/Config.cfg"
local lang = files.loadTableFromFile("MineOS/System/OS/Languages/" .. _G.OSSettings.language .. ".lang")

local workPathHistory = {}
local currentWorkPathHistoryElement = 1

local oldPixelsOfFullScreen, isFullScreen
local scrollSpeed = 2
local searchBarText

local currentNetworkAddress
local port = 322
local disks = {}
local network = {}
local sizes = {}
local fileList = {}
local config = {}
local obj = {}
local sortingMethods = {[0] = lang.sortByTypeShort, [1] = lang.sortByNameShort, [2] = lang.sortByDateShort, [lang.sortByTypeShort] = 0, [lang.sortByNameShort] = 1, [lang.sortByDateShort] = 2}

------------------------------------------------------------------------------------------------------------------

--Сохраняем все настроечки вот тут вот
local function saveConfig()
	files.saveTableToFile(pathToConfig, config)
end

--Загрузка конфига
local function loadConfig()
	if fs.exists(pathToConfig) then
		config = files.loadTableFromFile(pathToConfig)
	else
		config.favourites = {
			{name = "Root", path = ""},
			{name = "System", path = "MineOS/System/"},
			{name = "Libraries", path = "lib/"},
			{name = "Scripts", path = "bin/"},
			{name = "Desktop", path = "MineOS/Desktop/"},
			{name = "Applications", path = "MineOS/Applications/"},
			{name = "Pictures", path = "MineOS/Pictures/"},
		}
		config.showFileFormat = false
		config.showSystemFiles = false
		config.showHiddenFiles = false
		config.currentSortingMethod = 0
		saveConfig()
	end
end

--Создание дисков для лефтбара
local function createDisks()
	disks = {}
	local HDDs = ecs.getHDDs()
	for proxy, path in fs.mounts() do
		for i = 1, #HDDs do
			if proxy.address == HDDs[i].address and path ~= "/" then
				table.insert(disks, {path = path, name = unicode.sub(path, 2, -1)})
			end
		end
	end
	-- for proxy, path in fs.mounts() do
	-- 	if path ~= "/" then
	-- 		table.insert(disks, {path = path, name = path})
	-- 	end
	-- end
end

--Получить файловый список
local function getFileList()
	fileList = ecs.getFileList(workPathHistory[currentWorkPathHistoryElement])
	fileList = ecs.sortFiles(workPathHistory[currentWorkPathHistoryElement], fileList, config.currentSortingMethod, config.showHiddenFiles)
	if searchBarText then fileList = ecs.searchInArray(fileList, searchBarText) end
end

--Перейти в какую-то папку
local function changePath(path)
	for i = currentWorkPathHistoryElement, #workPathHistory do
		table.remove(workPathHistory, currentWorkPathHistoryElement + 1)
	end
	
	sizes.yFileList = sizes.yFileListStartPoint
	searchBarText = nil

	table.insert(workPathHistory, path)	
	currentWorkPathHistoryElement = #workPathHistory

	getFileList()
end

--Считаем размеры всего
local function calculateSizes()
	sizes.xSpaceBetweenIcons, sizes.ySpaceBetweenIcons = 2, 1
	sizes.finderWidth, sizes.finderHeight = math.floor(buffer.screen.width * 0.585), math.floor(buffer.screen.height * 0.52)
	sizes.leftBarWidth = math.floor(sizes.finderWidth * 0.22)
	sizes.topBarHeight = 3
	sizes.mainWidth, sizes.mainHeight = sizes.finderWidth - sizes.leftBarWidth - 1, sizes.finderHeight - sizes.topBarHeight - 1
	sizes.xFinder, sizes.yFinder = math.floor(buffer.screen.width / 2 - sizes.finderWidth / 2), math.floor(buffer.screen.height / 2 - sizes.finderHeight / 2)
	sizes.xFinderEnd, sizes.yFinderEnd = sizes.xFinder + sizes.finderWidth - 1, sizes.yFinder + sizes.finderHeight - 1
	sizes.xMain, sizes.yMain = sizes.xFinder + sizes.leftBarWidth, sizes.yFinder + sizes.topBarHeight
	sizes.xCountOfIcons, sizes.yCountOfIcons, sizes.totalCountOfIcons = MineOSCore.getParametersForDrawingIcons(sizes.mainWidth - 4, sizes.mainHeight, sizes.xSpaceBetweenIcons, sizes.ySpaceBetweenIcons)
	sizes.yFileListStartPoint = sizes.yMain + 1
	sizes.yFileList = sizes.yFileListStartPoint
	sizes.iconTotalHeight = MineOSCore.iconHeight + sizes.ySpaceBetweenIcons
	sizes.searchBarWidth = math.floor(sizes.finderWidth * 0.21)
	sizes.xSearchBar = sizes.xFinderEnd - sizes.searchBarWidth - 1
	obj.mainZone = GUI.object(sizes.xMain, sizes.yMain, sizes.mainWidth, sizes.mainHeight)
end

--Рисем цветные кружочки слева вверху
local function drawCloses()
	local x, y = sizes.xFinder + 1, sizes.yFinder
	local symbol = "●"
	obj.close = GUI.button(x, y, 1, 1, colors.topBar, colors.closes.close, colors.topBar, 0x000000, symbol)
	obj.hide = GUI.button(obj.close.x + obj.close.width + 1, y, 1, 1, colors.topBar, colors.closes.hide, colors.topBar, 0x000000, symbol)
	obj.full = GUI.button(obj.hide.x + obj.hide.width + 1, y, 1, 1, colors.topBar, colors.closes.full, colors.topBar, 0x000000, symbol)
end

local function drawSearchBar(justDrawNotEvent)
	local y = sizes.yFinder + 1
	local textColor = searchBarText and 0x262626 or 0xBBBBBB
	obj.search = GUI.object(sizes.xSearchBar, y, sizes.searchBarWidth, 1)
	buffer.square(sizes.xSearchBar, y, sizes.searchBarWidth, 1, 0xFFFFFF, textColor, " ")
	return GUI.input(sizes.xSearchBar + 1, y, sizes.searchBarWidth - 2, textColor, searchBarText or lang.search, {justDrawNotEvent = justDrawNotEvent})
end

local function drawTopBar()
	buffer.square(sizes.xFinder, sizes.yFinder, sizes.finderWidth, sizes.topBarHeight, colors.topBar)
	drawCloses()
	local x, y = sizes.xFinder + 2, sizes.yFinder + 1
	obj.historyBack = GUI.button(x, y, 3, 1, 0xffffff, 0x262626, 0xAAAAAA, 0x000000, "<"); x = x + obj.historyBack.width + 1
	obj.historyBack.colors.disabled.button, obj.historyBack.colors.disabled.text = 0xFFFFFF, 0xdddddd
	if currentWorkPathHistoryElement == 1 then obj.historyBack.disabled = true; obj.historyBack:draw() end
	obj.historyForward = GUI.button(x, y, 3, 1, 0xffffff, 0x262626, 0xAAAAAA, 0x000000, ">"); x = x + obj.historyForward.width + 2
	obj.historyForward.colors.disabled.button, obj.historyForward.colors.disabled.text = 0xFFFFFF, 0xdddddd
	if currentWorkPathHistoryElement == #workPathHistory then obj.historyForward.disabled = true; obj.historyForward:draw() end

	local cyka = {
		{objName = "sortingMethod", text = sortingMethods[config.currentSortingMethod], active = false},
		{objName = "showFormat", text = lang.showFileFormatShort, active = config.showFileFormat},
		{objName = "showHidden", text = lang.showHiddenFilesShort, active = config.showHiddenFiles},
	}
	for i = 1, #cyka do
		obj[cyka[i].objName] = GUI.adaptiveButton(x, y, 1, 0, 0xFFFFFF, 0x262626, 0x262626, 0xFFFFFF, cyka[i].text)
		if cyka[i].active then obj[cyka[i].objName]:draw(true) end
		x = x + obj[cyka[i].objName].width + 1
	end

	drawSearchBar(true)
end

local function drawAndHiglightPath(y, arrayElement)
	-- GUI.error(workPathHistory[currentWorkPathHistoryElement] .. " - " .. tostring(arrayElement.path))
	local pathAreEquals = workPathHistory[currentWorkPathHistoryElement] == arrayElement.path
	if pathAreEquals then buffer.square(sizes.xFinder, y, sizes.leftBarWidth, 1, colors.leftBarSelection, colors.leftBarSelectionText, " ") end
	buffer.text(sizes.xFinder + 2, y, pathAreEquals and colors.leftBarSelectionText or colors.leftBarList, unicode.sub(arrayElement.name, 1, sizes.leftBarWidth - 4))
	local object = GUI.object(sizes.xFinder, y, sizes.leftBarWidth, 1)
	object.path = arrayElement.path
	table.insert(obj.leftBarItems, object)
end

local function drawLeftBar()
	obj.leftBarItems = {}
	obj.network = {}
	buffer.setDrawLimit(sizes.xFinder, sizes.yMain, sizes.leftBarWidth, sizes.mainHeight + 1)
	buffer.paste(1, 1, oldPixelsOfFullScreen)
	buffer.square(sizes.xFinder, sizes.yMain, sizes.leftBarWidth, sizes.mainHeight + 1, colors.leftBar, 0x000000, " ", colors.leftBarTransparency)

	local x, y = sizes.xFinder + 1, sizes.yMain
	--Фаворитсы
	if #config.favourites > 0 then
		buffer.text(x, y, colors.leftBarHeader, lang.favourites); y = y + 1
		for i = 1, #config.favourites do
			drawAndHiglightPath(y, config.favourites[i])
			y = y + 1
		end
		y = y + 1
	end
	--Сеть
	if (function() local count = 0; for key in pairs(network) do count = count + 1 end; return count end)() > 0 then
		buffer.text(x, y, colors.leftBarHeader, lang.network); y = y + 1
		for address in pairs(network) do
			buffer.text(sizes.xFinder + 2, y, colors.leftBarList, unicode.sub(address, 1, sizes.leftBarWidth - 4))
			obj.network[address] = GUI.object(sizes.xFinder + 2, y, sizes.leftBarWidth, 1)
			y = y + 1
		end
		y = y + 1
	end
	--Диски
	buffer.text(x, y, colors.leftBarHeader, lang.disks); y = y + 1
	for i = 1, #disks do
		drawAndHiglightPath(y, disks[i])
		y = y + 1
	end

	buffer.resetDrawLimit()
end

local function clearMainZone()
	buffer.square(sizes.xMain, sizes.yMain, sizes.mainWidth + 1, sizes.mainHeight + 1, colors.main)
end

local function drawNetwork()
	local x, y = math.floor(sizes.xMain + sizes.mainWidth / 2 - 4), math.floor(sizes.yMain + sizes.mainHeight / 2 - 4)
	local buttonWidth = 22

	buffer.image(x, y, image.load(pathToComputerIcon)); y = y + 5
	local text = ecs.stringLimit("end", currentNetworkAddress, sizes.mainWidth - 4)
	buffer.text(math.floor(sizes.xMain + sizes.mainWidth / 2 - unicode.len(text) / 2), y, 0xAAAAAA, text); y = y + 2
	x = math.floor(sizes.xMain + sizes.mainWidth / 2 - buttonWidth / 2)
	obj.networkFile = GUI.button(x, y, buttonWidth, 1, 0xdddddd, 0x262626, 0x262626, 0xEEEEEE, lang.sendFile); y = y + 2
	obj.networkMessage = GUI.button(x, y, buttonWidth, 1, 0xdddddd, 0x262626, 0x262626, 0xEEEEEE, lang.sendMessage); y = y + 2
end

local function drawFiles()
	--Ебашим раб стол
	buffer.setDrawLimit(sizes.xMain, sizes.yMain, sizes.mainWidth, sizes.mainHeight)
	local differenceByPixels = sizes.yFileListStartPoint - sizes.yFileList
	local differenceByIcons = math.floor(differenceByPixels / sizes.iconTotalHeight)
	sizes.fromIcon = differenceByIcons < 2 and 1 or math.floor((differenceByIcons - 1) * sizes.xCountOfIcons) + 1
	local finalY = differenceByIcons < 2 and sizes.yFileList or sizes.yFileList + math.floor((differenceByIcons - 1) * sizes.iconTotalHeight)
	local finalTotalCountOfIcons = sizes.totalCountOfIcons + 2 * sizes.xCountOfIcons
	obj.DesktopIcons = MineOSCore.drawIconField(sizes.xMain + 2, finalY, sizes.xCountOfIcons, sizes.yCountOfIcons, sizes.fromIcon, finalTotalCountOfIcons, sizes.xSpaceBetweenIcons, sizes.ySpaceBetweenIcons, workPathHistory[currentWorkPathHistoryElement], fileList, config.showFileFormat, 0x262626)
	buffer.resetDrawLimit()
	--Ебашим скроллбар
	buffer.scrollBar(sizes.xFinderEnd, sizes.yMain, 1, sizes.mainHeight, #fileList, sizes.fromIcon, 0xCCCCCC, 0x666666)
end

local function drawMain(cyka)
	clearMainZone()
	if cyka then drawNetwork() else drawFiles() end
end

--Рисуем нижнюю полосочку с путем
local function drawBottomBar()
	--Подложка
	buffer.square(sizes.xMain, sizes.yFinderEnd, sizes.mainWidth + 1, 1, colors.leftBar, 0xffffff, " ")
	--Создаем переменную строки истории
	local historyString = workPathHistory[currentWorkPathHistoryElement]
	if historyString == "" or historyString == "/" then
		historyString = "Root"
	else
		historyString = string.gsub(historyString, "/", " ► ")
		if unicode.sub(historyString, -3, -1) == " ► " then
			historyString = "Root ► " .. unicode.sub(historyString, 1, -4)
		end
	end
	--Рисуем ее
	buffer.text(sizes.xMain + 1, sizes.yFinderEnd, colors.topText, ecs.stringLimit("start", historyString, sizes.mainWidth - 2))
end

local function drawAll(force)
	drawTopBar()
	drawLeftBar()
	drawBottomBar()
	drawMain()
	buffer.draw(force)
end

local function getListAndDrawAll()
	-- ecs.error("ДА ЕБАНА")
	getFileList()
	drawAll()
end

local function fullRefresh()
	getFileList()
	buffer.paste(1, 1, oldPixelsOfFullScreen)
	drawAll(true)
end

local function openModem()
	if component.isAvailable("modem") then component.modem.open(port) end
end

local function sendPersonalInfo()
	if component.isAvailable("modem") then component.modem.broadcast(port, "addMeToList") end
end

local function sendMessageOrFileWindow(text1, text2)
	return ecs.universalWindow("auto", "auto", 36, 0x262626, true,
		{"EmptyLine"},
		{"CenterText", ecs.colors.orange, text1},
		{"EmptyLine"},
		{"Input", 0xFFFFFF, ecs.colors.orange, text2},
		{"EmptyLine"},
		{"Button", {ecs.colors.orange, 0xffffff, "OK"}, {0x999999, 0xffffff, lang.cancel}}
	)
end

local function sendFile(path, address)
	--Отправляем сообщение о том, что мы собираемся отправить файл
	component.modem.send(address, port, "FILESTARTED", fs.name(path))
	local maxPacketSize = component.modem.maxPacketSize() - 32
	local file = io.open(path, "rb")
	local fileSize = fs.size(path)
	local percent = 0
	local sendedBytes = 0
	local dataToSend

	while true do
		dataToSend = file:read(maxPacketSize)
		if dataToSend then
			component.modem.send(address, port, "FILESEND", dataToSend, percent)
			sendedBytes = sendedBytes + maxPacketSize
			percent = math.floor(sendedBytes / fileSize * 100)
		else
			break
		end
	end

	file:close()
	component.modem.send(address, port, "FILESENDEND")
	GUI.error(lang.fileSuccessfullySent)
end

----------------------------------------------------------------------------------------------------------------------------------

local args = {...}
-- buffer.start()
-- buffer.clear(0xFF6666)

oldPixelsOfFullScreen = buffer.copy(1, 1, buffer.screen.width, buffer.screen.height)
MineOSCore.setLocalization(lang)
MineOSCore.loadIcons()
calculateSizes()
loadConfig()
createDisks()
changePath(args[1] == "open" and (args[2] or "") or "")
drawAll()
openModem()
sendPersonalInfo()

while true do
	local eventData = {event.pull()}
	if eventData[1] == "touch" then
		local clickedAtEmptyArea = true

		if clickedAtEmptyArea then
			if obj.networkMessage and obj.networkMessage:isClicked(eventData[3], eventData[4]) then
				obj.networkMessage:press(0.2)
				local data = sendMessageOrFileWindow(lang.sendMessage, lang.messageText)
				if data[2] == "OK" then
					component.modem.send(currentNetworkAddress, port, "hereIsMessage", data[1])
				end
				clickedAtEmptyArea = false
			elseif obj.networkFile and obj.networkFile:isClicked(eventData[3], eventData[4]) then
				obj.networkFile:press(0.2)
				local data = sendMessageOrFileWindow(lang.sendFile, lang.pathToFile)
				if data[2] == "OK" then
					if fs.exists(data[1]) then
						sendFile(data[1], currentNetworkAddress)
					else
						GUI.error("Файл не существует")
					end
				end
				clickedAtEmptyArea = false
			elseif obj.historyBack:isClicked(eventData[3], eventData[4]) then
				obj.historyBack:press(0.2)
				currentWorkPathHistoryElement = currentWorkPathHistoryElement - 1
				getListAndDrawAll()
				clickedAtEmptyArea = false
			elseif obj.historyForward:isClicked(eventData[3], eventData[4]) then
				obj.historyForward:press(0.2)
				currentWorkPathHistoryElement = currentWorkPathHistoryElement + 1
				getListAndDrawAll()
				clickedAtEmptyArea = false
			elseif obj.search:isClicked(eventData[3], eventData[4]) then
				searchBarText = ""
				searchBarText = drawSearchBar(false)
				if searchBarText == "" then searchBarText = nil end
				sizes.yFileList = sizes.yFileListStartPoint
				getListAndDrawAll()
				clickedAtEmptyArea = false
			elseif obj.close:isClicked(eventData[3], eventData[4]) then
				obj.close:press(0.2)
				clickedAtEmptyArea = false
				return
			elseif obj.showFormat:isClicked(eventData[3], eventData[4]) then
				config.showFileFormat = not config.showFileFormat
				saveConfig()
				getListAndDrawAll()
				clickedAtEmptyArea = false
			elseif obj.showHidden:isClicked(eventData[3], eventData[4]) then
				config.showHiddenFiles = not config.showHiddenFiles
				saveConfig()
				getListAndDrawAll()
				clickedAtEmptyArea = false
			elseif obj.sortingMethod:isClicked(eventData[3], eventData[4]) then
				obj.sortingMethod:press(0.2)
				local data = ecs.universalWindow("auto", "auto", 36, 0x262626, true,
					{"EmptyLine"},
					{"CenterText", ecs.colors.orange, lang.sortingMethod},
					{"EmptyLine"},
					{"Selector", 0xFFFFFF, ecs.colors.orange, lang.sortByTypeShort, lang.sortByNameShort, lang.sortByDateShort},
					{"EmptyLine"},
					{"Button", {ecs.colors.orange, 0xffffff, "OK"}, {0x999999, 0xffffff, lang.cancel}}
				)
				if data[2] == "OK" then
					config.currentSortingMethod = sortingMethods[data[1]]
					saveConfig()
					getListAndDrawAll()
				end
				clickedAtEmptyArea = false
			end
		end

		if clickedAtEmptyArea then
			for _, item in pairs(obj.leftBarItems) do
				if item:isClicked(eventData[3], eventData[4]) then
					changePath(item.path)
					drawAll()
					clickedAtEmptyArea = false
					break
				end
			end
		end

		if clickedAtEmptyArea then
			for address, item in pairs(obj.network) do
				if item:isClicked(eventData[3], eventData[4]) then
					currentNetworkAddress = address
					drawMain(true)
					buffer.draw()
					obj.DesktopIcons = nil
					clickedAtEmptyArea = false
					break
				end
			end
		end

		if clickedAtEmptyArea and obj.DesktopIcons then
			for _, icon in pairs(obj.DesktopIcons) do
				if icon:isClicked(eventData[3], eventData[4]) then
					buffer.setDrawLimit(sizes.xMain, sizes.yMain, sizes.mainWidth, sizes.mainHeight)
					if MineOSCore.iconClick(icon, eventData, colors.selection, nil, 0xFFFFFF, 0.2, config.showFileFormat, {method = getListAndDrawAll, arguments = {}}, {method = fullRefresh, arguments = {}}, {method = changePath, arguments = {icon.path}}) then return end
					buffer.resetDrawLimit()
					clickedAtEmptyArea = false
					break
				end
			end
		end

		if clickedAtEmptyArea and obj.DesktopIcons and obj.mainZone:isClicked(eventData[3], eventData[4]) then
			MineOSCore.emptyZoneClick(eventData, workPathHistory[currentWorkPathHistoryElement], {method = getListAndDrawAll, arguments = {}})
		end
	elseif eventData[1] == "scroll" then
		if obj.mainZone:isClicked(eventData[3], eventData[4]) then
			if eventData[5] == 1 then
				if sizes.yFileList < sizes.yFileListStartPoint then
					sizes.yFileList = sizes.yFileList + scrollSpeed
					drawMain(); buffer.draw()
				end
			else
				if sizes.fromIcon < #fileList - sizes.xCountOfIcons then
					sizes.yFileList = sizes.yFileList - scrollSpeed
					drawMain(); buffer.draw()
				end
			end
		end
	elseif eventData[1] == "modem_message" then
		local localAddress, remoteAddress, remotePort, distance, message1, message2 = eventData[2], eventData[3], eventData[4], eventData[5], eventData[6], eventData[7]
		local truncatedRemoteAddress = unicode.sub(remoteAddress, 1, 5)
		if remotePort == port then
			if message1 == "addMeToList" and not network[remoteAddress] then
				network[remoteAddress] = true
				sendPersonalInfo()
				drawAll()
			elseif message1 == "hereIsMessage" then
				GUI.error(message2, {title = {color = 0xFFDB40, text = lang.gotMessageFrom .. truncatedRemoteAddress}})
			elseif message1 == "FILESTARTED" then
				_G.finderFileReceiver = io.open("MineOS/System/Finder/tempFile.lua", "wb")
			elseif message1 == "FILESEND" then
				_G.finderFileReceiver:write(message2)
			elseif message1 == "FILESENDEND" then
				_G.finderFileReceiver:close()
				local data = sendMessageOrFileWindow(lang.gotFileFrom .. truncatedRemoteAddress, lang.pathToSave)
				if data[2] == "OK" and data[1] ~= "" then fs.rename("MineOS/System/Finder/tempFile.lua", data[1]); getListAndDrawAll() end
			end
		end
	end
end







