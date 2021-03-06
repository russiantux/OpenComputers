
----------------------------------------- Libraries -----------------------------------------

require("advancedLua")
local computer = require("computer")
local keyboard = require("keyboard")
local buffer = require("doubleBuffering")
local unicode = require("unicode")
local event = require("event")
local fs = require("filesystem")
local image = require("image")

----------------------------------------- Constants -----------------------------------------

local GUI = {}

GUI.alignment = {
	horizontal = enum(
		"left",
		"center",
		"right"
	),
	vertical = enum(
		"top",
		"center",
		"bottom"
	)
}

GUI.directions = enum(
	"horizontal",
	"vertical"
)

GUI.sizePolicies = enum(
	"percentage",
	"absolute"
)

GUI.dropDownMenuElementTypes = enum(
	"default",
	"separator"
)

GUI.colors = {
	disabled = {
		background = 0x888888,
		text = 0xAAAAAA
	},
	contextMenu = {
		separator = 0xAAAAAA,
		default = {
			background = 0xFFFFFF,
			text = 0x2D2D2D
		},
		disabled = {
			text = 0xAAAAAA
		},
		pressed = {
			background = 0x3366CC,
			text = 0xFFFFFF
		},
		transparency = {
			background = 20,
			shadow = 50
		}
	},
	windows = {
		title = {
			background = 0xEEEEEE,
			text = 0x3C3C3C
		},
		backgroundPanel = 0xFFFFFF,
		tabBar = {
			default = {
				background = 0xDDDDDD,
				text = 0x3C3C3C
			},
			selected = {
				background = 0xCCCCCC,
				text = 0x3C3C3C
			}
		}
	}
}

----------------------------------------- Interface objects -----------------------------------------

local function callMethod(method, ...)
	if method then method(...) end
end

function GUI.point(x, y)
	return { x = x, y = y }
end

function GUI.rectangle(x, y, width, height)
	return { x = x, y = y, width = width, height = height}
end

-- Universal method to check if object was clicked by following coordinates
local function isObjectClicked(object, x, y)
	return
		x >= object.x and
		y >= object.y and
		x <= object.x + object.width - 1 and
		y <= object.y + object.height - 1 and
		not object.disabled and
		not object.hidden
end

-- Main reactangle object to use in everything
function GUI.object(x, y, width, height)
	local rectangle = GUI.rectangle(x, y, width, height)
	rectangle.isClicked = isObjectClicked
	return rectangle
end

----------------------------------------- Object alignment -----------------------------------------

-- Set children alignment in parent object
function GUI.setAlignment(object, horizontalAlignment, verticalAlignment)
	object.alignment = {
		horizontal = horizontalAlignment,
		vertical = verticalAlignment
	}
	return object
end

-- Get subObject position inside of parent object
function GUI.getAlignmentCoordinates(object, subObject)
	local x, y
	if object.alignment.horizontal == GUI.alignment.horizontal.left then
		x = object.x
	elseif object.alignment.horizontal == GUI.alignment.horizontal.center then
		x = math.floor(object.x + object.width / 2 - subObject.width / 2)
	elseif object.alignment.horizontal == GUI.alignment.horizontal.right then
		x = object.x + object.width - subObject.width
	else
		error("Unknown horizontal alignment: " .. tostring(object.alignment.horizontal))
	end

	if object.alignment.vertical == GUI.alignment.vertical.top then
		y = object.y
	elseif object.alignment.vertical == GUI.alignment.vertical.center then
		y = math.floor(object.y + object.height / 2 - subObject.height / 2)
	elseif object.alignment.vertical == GUI.alignment.vertical.bottom then
		y = object.y + object.height - subObject.height
	else
		error("Unknown vertical alignment: " .. tostring(object.alignment.vertical))
	end

	return x, y
end

-- Get object position based on it's alignment and margin in parent object
function GUI.getMarginCoordinates(object)
	local x, y = object.x, object.y

	if object.alignment.horizontal == GUI.alignment.horizontal.left then
		x = x + object.margin.horizontal
	elseif object.alignment.horizontal == GUI.alignment.horizontal.right then
		x = x - object.margin.horizontal
	end

	if object.alignment.vertical == GUI.alignment.vertical.top then
		y = y + object.margin.vertical
	elseif object.alignment.vertical == GUI.alignment.vertical.bottom then
		y = y - object.margin.vertical
	end

	return x, y
end

----------------------------------------- Containers -----------------------------------------

local function checkObjectParentExists(object)
	if not object.parent then error("Object doesn't have a parent container") end
end

local function containerObjectIndexOf(object)
	checkObjectParentExists(object)
	for objectIndex = 1, #object.parent.children do
		if object.parent.children[objectIndex] == object then
			return objectIndex
		end
	end
end

-- Move container's object "closer" to our eyes
local function containerObjectMoveForward(object)
	local objectIndex = object:indexOf()
	if objectIndex < #object.parent.children then
		object.parent.children[index], object.parent.children[index + 1] = swap(object.parent.children[index], object.parent.children[index + 1])
	end
	return object
end

-- Move container's object "more far out" of our eyes
local function containerObjectMoveBackward(object)
	local objectIndex = object:indexOf()
	if objectIndex > 1 then
		object.parent.children[objectIndex], object.parent.children[objectIndex - 1] = swap(object.parent.children[objectIndex], object.parent.children[objectIndex - 1])
	end
	return object
end

-- Move container's object to front of all objects
local function containerObjectMoveToFront(object)
	local objectIndex = object:indexOf()
	table.insert(object.parent.children, object)
	table.remove(object.parent.children, objectIndex)
	return object
end

-- Move container's object to back of all objects
local function containerObjectMoveToBack(object)
	local objectIndex = object:indexOf()
	table.insert(object.parent.children, 1, object)
	table.remove(object.parent.children, objectIndex + 1)
	return object
end

local function containerGetFirstParent(object)
	if object.parent then
		local currentParent = object.parent
		while currentParent.parent do
			currentParent = currentParent.parent
		end
		return currentParent
	else
		error("Object doesn't have any parents")
	end
end

local function selfDelete(object)
	table.remove(object.parent.children, containerObjectIndexOf(object))
end

-- Add any object as children to parent container
function GUI.addChildToContainer(container, object, atIndex)
	object.indexOf = containerObjectIndexOf
	object.moveToFront = containerObjectMoveToFront
	object.moveToBack = containerObjectMoveToBack
	object.moveForward = containerObjectMoveForward
	object.moveBackward = containerObjectMoveBackward
	object.getFirstParent = containerGetFirstParent
	object.delete = selfDelete
	object.localPosition = {x = object.x, y = object.y}
	object.parent = container

	table.insert(container.children, object)
	
	return object
end

-- Delete every container's children object
local function deleteContainersContent(container, from, to)
	from = from or 1
	for objectIndex = from, to or #container.children do
		table.remove(container.children, from)
	end
end

local function getRectangleIntersection(R1X1, R1Y1, R1X2, R1Y2, R2X1, R2Y1, R2X2, R2Y2)
	if R2X1 <= R1X2 and R2Y1 <= R2Y2 and R2X2 >= R1X1 and R2Y2 >= R1Y1 then
		return
			math.max(R2X1, R1X1),
			math.max(R2Y1, R1Y1),
			math.min(R2X2, R1X2),
			math.min(R2Y2, R1Y2)
	end
end

-- Recursively draw container's content including all children container's content
function GUI.drawContainerContent(container)
	local R1X1, R1Y1, R1X2, R1Y2 = buffer.getDrawLimit()
	local x1, y1, x2, y2 = getRectangleIntersection(R1X1, R1Y1, R1X2, R1Y2, container.x, container.y, container.x + container.width - 1, container.y + container.height - 1)

	if x1 then
		buffer.setDrawLimit(x1, y1, x2, y2)
		
		for objectIndex = 1, #container.children do
			if not container.children[objectIndex].hidden then
				container.children[objectIndex].x, container.children[objectIndex].y = container.children[objectIndex].localPosition.x + container.x - 1, container.children[objectIndex].localPosition.y + container.y - 1
				container.children[objectIndex]:draw()
			end
		end

		buffer.setDrawLimit(R1X1, R1Y1, R1X2, R1Y2)
	end

	return container
end

local function handleContainer(isScreenEvent, mainContainer, currentContainer, eventData, x1, y1, x2, y2)
	local breakRecursion = false
	
	if not isScreenEvent or x1 and eventData[3] >= x1 and eventData[4] >= y1 and eventData[3] <= x2 and eventData[4] <= y2 then
		for i = #currentContainer.children, 1, -1 do
			if not currentContainer.children[i].hidden then
				if currentContainer.children[i].children then
					if handleContainer(isScreenEvent, mainContainer, currentContainer.children[i], eventData, getRectangleIntersection(
						x1, y1, x2, y2,
						currentContainer.children[i].x,
						currentContainer.children[i].y,
						currentContainer.children[i].x + currentContainer.children[i].width - 1,
						currentContainer.children[i].y + currentContainer.children[i].height - 1
					)) then
						breakRecursion = true
						break
					end
				else
					if isScreenEvent then
						if currentContainer.children[i]:isClicked(eventData[3], eventData[4]) then
							callMethod(currentContainer.children[i].eventHandler, mainContainer, currentContainer.children[i], eventData)
							breakRecursion = true
							break
						end
					else
						callMethod(currentContainer.children[i].eventHandler, mainContainer, currentContainer.children[i], eventData)
					end
				end
			end
		end

		-- if isScreenEvent then
		-- 	if currentContainer.eventHandler then
		-- 		currentContainer.eventHandler(mainContainer, currentContainer, eventData)
		-- 		breakRecursion = true
		-- 	end
		-- else
			callMethod(currentContainer.eventHandler, mainContainer, currentContainer, eventData)
		-- end
	end

	if breakRecursion then
		return true
	end
end

local function containerHandleEventData(mainContainer, eventData)
	handleContainer(eventData[1] == "touch" or eventData[1] == "drag" or eventData[1] == "drop" or eventData[1] == "scroll", mainContainer, mainContainer, eventData, mainContainer.x, mainContainer.y, mainContainer.x + mainContainer.width - 1, mainContainer.y + mainContainer.height - 1)
end

local function containerStartEventHandling(container, pullTime)
	while true do
		containerHandleEventData(container, {event.pull(pullTime)})
		if container.dataToReturn then
			return table.unpack(container.dataToReturn)
		end
	end
end

local function containerReturnData(container, ...)
	container.dataToReturn = {...}
	computer.pushSignal("containerAction")
end

local function containerStopEventHandling(container)
	containerReturnData(container, nil)
end

-- Universal container to store any other objects like buttons, labels, etc
function GUI.container(x, y, width, height)
	local container = GUI.object(x, y, width, height)

	container.children = {}
	container.draw = GUI.drawContainerContent
	container.deleteChildren = deleteContainersContent
	container.addChild = GUI.addChildToContainer
	container.returnData = containerReturnData
	container.startEventHandling = containerStartEventHandling
	container.stopEventHandling = containerStopEventHandling

	return container
end

-- Container fitted to screen resolution
function GUI.fullScreenContainer()
	return GUI.container(1, 1, buffer.width, buffer.height)
end

----------------------------------------- Buttons -----------------------------------------

local function drawButton(object)
	local xText, yText = GUI.getAlignmentCoordinates(object, {width = unicode.len(object.text), height = 1})
	local buttonColor = object.disabled and object.colors.disabled.background or (object.pressed and object.colors.pressed.background or object.colors.default.background)
	local textColor = object.disabled and object.colors.disabled.text or (object.pressed and object.colors.pressed.text or object.colors.default.text)

	if buttonColor then
		if object.buttonType == 1 then
			buffer.square(object.x, object.y, object.width, object.height, buttonColor, textColor, " ")
		elseif object.buttonType == 2 then
			buffer.text(object.x + 1, object.y, buttonColor, string.rep("▄", object.width - 2))
			buffer.square(object.x, object.y + 1, object.width, object.height - 2, buttonColor, textColor, " ")
			buffer.text(object.x + 1, object.y + object.height - 1, buttonColor, string.rep("▀", object.width - 2))
		else
			buffer.frame(object.x, object.y, object.width, object.height, buttonColor)
		end
	end

	buffer.text(xText, yText, textColor, object.text)

	return object
end

local function pressButton(object)
	object.pressed = true
	drawButton(object)
end

local function releaseButton(object)
	object.pressed = nil
	drawButton(object)
end

local function pressAndReleaseButton(object, pressTime)
	pressButton(object)
	buffer.draw()
	os.sleep(pressTime or 0.2)
	releaseButton(object)
	buffer.draw()
end

local function buttonEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		if object.switchMode then
			object.pressed = not object.pressed
			mainContainer:draw()
			buffer.draw()
			callMethod(object.onTouch, mainContainer, object, eventData)
		else
			object.pressed = true
			mainContainer:draw()
			buffer.draw()
			os.sleep(0.2)
			object.pressed = false
			mainContainer:draw()
			buffer.draw()
			callMethod(object.onTouch, mainContainer, object, eventData)
		end
	end
end

-- Создание таблицы кнопки со всеми необходимыми параметрами
local function createButtonObject(buttonType, x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
	local object = GUI.object(x, y, width, height)

	object.colors = {
		default = {
			background = buttonColor,
			text = textColor
		},
		pressed = {
			background = buttonPressedColor,
			text = textPressedColor
		},
		disabled = {
			background = GUI.colors.disabled.background,
			text = GUI.colors.disabled.text,
		}
	}

	object.eventHandler = buttonEventHandler
	object.buttonType = buttonType
	object.disabled = disabledState
	object.text = text
	object.press = pressButton
	object.release = releaseButton
	object.pressAndRelease = pressAndReleaseButton
	object.draw = drawButton
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)


	return object
end

-- Кнопка фиксированных размеров
function GUI.button(...)
	return createButtonObject(1, ...)
end

-- Кнопка, подстраивающаяся под размер текста
function GUI.adaptiveButton(x, y, xOffset, yOffset, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...) 
	return createButtonObject(1, x, y, unicode.len(text) + xOffset * 2, yOffset * 2 + 1, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...)
end

-- Rounded button
function GUI.roundedButton(...)
	return createButtonObject(2, ...)
end

function GUI.adaptiveRoundedButton(x, y, xOffset, yOffset, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...)
	return createButtonObject(2, x, y, unicode.len(text) + xOffset * 2, yOffset * 2 + 1, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...)
end

-- Кнопка в рамке
function GUI.framedButton(...)
	return createButtonObject(3, ...)
end

function GUI.adaptiveFramedButton(x, y, xOffset, yOffset, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...)
	return createButtonObject(3, x, y, unicode.len(text) + xOffset * 2, yOffset * 2 + 1, buttonColor, textColor, buttonPressedColor, textPressedColor, text, ...)
end

----------------------------------------- TabBar -----------------------------------------

local function tabBarTabEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object.parent.selectedItem = object:indexOf() - 1
		mainContainer:draw()
		buffer.draw()
		callMethod(object.onTouch, mainContainer, object, eventData)
	end
end

local function tabBarDraw(tabBar)
	tabBar.backgroundPanel.width, tabBar.backgroundPanel.height, tabBar.backgroundPanel.colors.background = tabBar.width, tabBar.height, tabBar.colors.default.background
	
	local totalWidth = 0
	for i = 2, #tabBar.children do
		totalWidth = totalWidth + tabBar.children[i].width + tabBar.spaceBetweenTabs
	end
	totalWidth = totalWidth - tabBar.spaceBetweenTabs

	local x = math.floor(tabBar.width / 2 - totalWidth / 2)
	for i = 2, #tabBar.children do
		tabBar.children[i].localPosition.x = x
		x = x + tabBar.children[i].width + tabBar.spaceBetweenTabs
		tabBar.children[i].pressed = (i - 1) == tabBar.selectedItem
	end

	GUI.drawContainerContent(tabBar)

	return tabBar
end

local function tabBarAddItem(tabBar, text)
	local item = tabBar:addChild(GUI.button(1, 1, unicode.len(text) + tabBar.horizontalTabOffset * 2, tabBar.height, tabBar.colors.default.background, tabBar.colors.default.text, tabBar.colors.selected.background, tabBar.colors.selected.text, text))
	
	item.switchMode = true
	item.eventHandler = tabBarTabEventHandler

	return item
end

function GUI.tabBar(x, y, width, height, horizontalTabOffset, spaceBetweenTabs, backgroundColor, textColor, backgroundSelectedColor, textSelectedColor, ...)
	local tabBar = GUI.container(x, y, width, height)

	tabBar.backgroundPanel = tabBar:addChild(GUI.panel(1, 1, 1, 1, backgroundColor))
	tabBar.horizontalTabOffset = horizontalTabOffset
	tabBar.spaceBetweenTabs = spaceBetweenTabs
	tabBar.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		selected = {
			background = backgroundSelectedColor,
			text = textSelectedColor
		}
	}
	tabBar.selectedItem = 1
	tabBar.draw = tabBarDraw
	tabBar.addItem = tabBarAddItem

	local items = {...}
	for i = 1, #items do
		tabBar:addItem(items[i])
	end

	return tabBar
end

----------------------------------------- Panel -----------------------------------------

local function drawPanel(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.background, 0x000000, " ", object.colors.transparency)
	return object
end

function GUI.panel(x, y, width, height, color, transparency)
	local object = GUI.object(x, y, width, height)
	
	object.colors = {background = color, transparency = transparency}
	object.draw = drawPanel
	
	return object
end

----------------------------------------- Label -----------------------------------------

local function drawLabel(object)
	local xText, yText = GUI.getAlignmentCoordinates(object, {width = unicode.len(object.text), height = 1})
	buffer.text(xText, yText, object.colors.text, object.text)
	return object
end

function GUI.label(x, y, width, height, textColor, text)
	local object = GUI.object(x, y, width, height)
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.left, GUI.alignment.vertical.top)
	object.colors = {text = textColor}
	object.text = text
	object.draw = drawLabel
	return object
end

----------------------------------------- Image -----------------------------------------

local function drawImage(object)
	buffer.image(object.x, object.y, object.image)
	return object
end

function GUI.image(x, y, image)
	local object = GUI.object(x, y, image[1], image[2])
	object.image = image
	object.draw = drawImage
	return object
end

----------------------------------------- Action buttons -----------------------------------------

function GUI.actionButtons(x, y, fatSymbol)
	local symbol = fatSymbol and "⬤" or "●"
	
	local container = GUI.container(x, y, 5, 1)
	container.close = container:addChild(GUI.button(1, 1, 1, 1, nil, 0xFF4940, nil, 0x992400, symbol))
	container.minimize = container:addChild(GUI.button(3, 1, 1, 1, nil, 0xFFB640, nil, 0x996D00, symbol))
	container.maximize = container:addChild(GUI.button(5, 1, 1, 1, nil, 0x00B640, nil, 0x006D40, symbol))

	return container
end

----------------------------------------- Dropdown Menu -----------------------------------------

local function drawDropDownMenuElement(object, itemIndex, isPressed)
	local y = object.y + (itemIndex - 1) * object.elementHeight
	local yText = y + math.floor(object.elementHeight / 2)
	if object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
		local textColor = object.items[itemIndex].disabled and object.colors.disabled.text or (object.items[itemIndex].color or object.colors.default.text)

		-- Нажатие
		if isPressed then
			buffer.square(object.x, y, object.width, object.elementHeight, object.colors.pressed.background, object.colors.pressed.text, " ")
			textColor = object.colors.pressed.text
		end

		-- Основной текст
		buffer.text(object.x + object.sidesOffset, yText, textColor, string.limit(object.items[itemIndex].text, object.width - object.sidesOffset * 2, "right"))
		-- Шурткатикус
		if object.items[itemIndex].shortcut then
			buffer.text(object.x + object.width - unicode.len(object.items[itemIndex].shortcut) - object.sidesOffset, yText, textColor, object.items[itemIndex].shortcut)
		end
	else
		-- Сепаратор
		buffer.text(object.x, yText, object.colors.separator, string.rep("─", object.width))
	end
end

local function drawDropDownMenu(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.default.background, object.colors.default.text, " ", object.colors.transparency)
	
	if object.drawShadow then
		GUI.windowShadow(object.x, object.y, object.width, object.height, GUI.colors.contextMenu.transparency.shadow, true)
	end

	for itemIndex = 1, #object.items do
		drawDropDownMenuElement(object, itemIndex, false)
	end
end

local function showDropDownMenu(object)
	object.height = #object.items * object.elementHeight

	local oldPixels = buffer.copy(object.x, object.y, object.width + 1, object.height + 1)
	local function quit()
		buffer.paste(object.x, object.y, oldPixels)
		buffer.draw()
	end

	drawDropDownMenu(object)
	buffer.draw()

	while true do
		local e = {event.pull()}
		if e[1] == "touch" then
			local objectFound = false
			for itemIndex = 1, #object.items do
				if 
					e[3] >= object.x and
					e[3] <= object.x + object.width - 1 and
					e[4] >= object.y + itemIndex * object.elementHeight - object.elementHeight and
					e[4] <= object.y + itemIndex * object.elementHeight - 1
				then
					objectFound = true
					if not object.items[itemIndex].disabled and object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
						drawDropDownMenuElement(object, itemIndex, true)
						buffer.draw()
						os.sleep(0.2)
						quit()
						if object.items[itemIndex].onTouch then object.items[itemIndex].onTouch() end
						return object.items[itemIndex].text, itemIndex
					end
					break
				end
			end

			if not objectFound then quit(); return end
		end
	end
end

local function addDropDownMenuItem(object, text, disabled, shortcut, color)
	local item = {}
	item.type = GUI.dropDownMenuElementTypes.default
	item.text = text
	item.disabled = disabled
	item.shortcut = shortcut
	item.color = color

	table.insert(object.items, item)
	return item
end

local function addDropDownMenuSeparator(object)
	local item = {type = GUI.dropDownMenuElementTypes.separator}
	table.insert(object.items, item)
	return item
end

function GUI.dropDownMenu(x, y, width, elementHeight, backgroundColor, textColor, backgroundPressedColor, textPressedColor, disabledColor, separatorColor, transparency, items)
	local object = GUI.object(x, y, width, 1)
	object.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		pressed = {
			background = backgroundPressedColor,
			text = textPressedColor
		},
		disabled = {
			text = disabledColor
		},
		separator = separatorColor,
		transparency = transparency
	}
	object.sidesOffset = 2
	object.elementHeight = elementHeight
	object.addSeparator = addDropDownMenuSeparator
	object.addItem = addDropDownMenuItem
	object.items = {}
	if items then
		for i = 1, #items do
			object:addItem(items[i])
		end
	end
	object.drawShadow = true
	object.draw = drawDropDownMenu
	object.show = showDropDownMenu
	return object
end

----------------------------------------- Context Menu -----------------------------------------

local function showContextMenu(object)
	-- Расчет ширины окна меню
	local longestItem, longestShortcut = 0, 0
	for itemIndex = 1, #object.items do
		if object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
			longestItem = math.max(longestItem, unicode.len(object.items[itemIndex].text))
			if object.items[itemIndex].shortcut then longestShortcut = math.max(longestShortcut, unicode.len(object.items[itemIndex].shortcut)) end
		end
	end
	object.width = object.sidesOffset + longestItem + (longestShortcut > 0 and 3 + longestShortcut or 0) + object.sidesOffset
	object.height = #object.items * object.elementHeight

	-- А это чтоб за края экрана не лезло
	if object.y + object.height >= buffer.height then object.y = buffer.height - object.height end
	if object.x + object.width + 1 >= buffer.width then object.x = buffer.width - object.width - 1 end

	return object:reimplementedShow()
end

function GUI.contextMenu(x, y, ...)
	local argumentItems = {...}
	local object = GUI.dropDownMenu(x, y, 1, 1, GUI.colors.contextMenu.default.background, GUI.colors.contextMenu.default.text, GUI.colors.contextMenu.pressed.background, GUI.colors.contextMenu.pressed.text, GUI.colors.contextMenu.disabled.text, GUI.colors.contextMenu.separator, GUI.colors.contextMenu.transparency.background)

	-- Заполняем менюшку парашей
	for itemIndex = 1, #argumentItems do
		if argumentItems[itemIndex] == "-" then
			object:addSeparator()
		else
			object:addItem(argumentItems[itemIndex][1], argumentItems[itemIndex][2], argumentItems[itemIndex][3], argumentItems[itemIndex][4])
		end
	end

	object.reimplementedShow = object.show
	object.show = showContextMenu
	object.selectedElement = nil

	return object
end

----------------------------------------- Menu -----------------------------------------

local function menuDraw(menu)
	buffer.square(menu.x, menu.y, menu.width, 1, menu.colors.default.background, menu.colors.default.text, " ", menu.colors.transparency)
	menu:reimplementedDraw()
end

local function menuItemEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object.pressed = true
		mainContainer:draw()
		buffer.draw()
		callMethod(object.onTouch, eventData)
		object.pressed = false
		mainContainer:draw()
		buffer.draw()
	end
end

local function menuAddItem(menu, text, textColor)
	local x = 2; for i = 1, #menu.children do x = x + unicode.len(menu.children[i].text) + 2; end
	local item = menu:addChild(GUI.adaptiveButton(x, 1, 1, 0, nil, textColor or menu.colors.default.text, menu.colors.pressed.background, menu.colors.pressed.text, text))
	item.eventHandler = menuItemEventHandler

	return item
end

function GUI.menu(x, y, width, backgroundColor, textColor, backgroundPressedColor, textPressedColor, backgroundTransparency)
	local menu = GUI.container(x, y, width, 1)
	
	menu.colors = {
		default = {
			background = backgroundColor,
			text = textColor,
		},
		pressed = {
			background = backgroundPressedColor,
			text = textPressedColor,
		},
		transparency = backgroundTransparency
	}
	menu.addItem = menuAddItem
	menu.reimplementedDraw = menu.draw
	menu.draw = menuDraw

	return menu
end

----------------------------------------- ProgressBar Object -----------------------------------------

local function drawProgressBar(object)
	local activeWidth = math.floor(object.value * object.width / 100)
	if object.thin then
		buffer.text(object.x, object.y, object.colors.passive, string.rep("━", object.width))
		buffer.text(object.x, object.y, object.colors.active, string.rep("━", activeWidth))
	else
		buffer.square(object.x, object.y, object.width, object.height, object.colors.passive)
		buffer.square(object.x, object.y, activeWidth, object.height, object.colors.active)
	end

	if object.showValue then
		local stringValue = tostring((object.valuePrefix or "") .. object.value .. (object.valuePostfix or ""))
		buffer.text(math.floor(object.x + object.width / 2 - unicode.len(stringValue) / 2), object.y + 1, object.colors.value, stringValue)
	end

	return object
end

function GUI.progressBar(x, y, width, activeColor, passiveColor, valueColor, value, thin, showValue, valuePrefix, valuePostfix)
	local object = GUI.object(x, y, width, 1)
	
	object.value = value
	object.colors = {active = activeColor, passive = passiveColor, value = valueColor}
	object.thin = thin
	object.draw = drawProgressBar
	object.showValue = showValue
	object.valuePrefix = valuePrefix
	object.valuePostfix = valuePostfix
	
	return object
end

----------------------------------------- Other GUI elements -----------------------------------------

function GUI.windowShadow(x, y, width, height, transparency, thin)
	transparency = transparency
	if thin then
		buffer.square(x + width, y + 1, 1, height - 1, 0x000000, 0x000000, " ", transparency)
		buffer.text(x + 1, y + height, 0x000000, string.rep("▀", width), transparency)
		buffer.text(x + width, y, 0x000000, "▄", transparency)
	else
		buffer.square(x + width, y + 1, 2, height, 0x000000, 0x000000, " ", transparency)
		buffer.square(x + 2, y + height, width - 2, 1, 0x000000, 0x000000, " ", transparency)
	end
end

------------------------------------------------- Error window -------------------------------------------------------------------

function GUI.error(...)
	local args = {...}
	for i = 1, #args do
		if type(args[i]) == "table" then
			args[i] = table.toString(args[i])
		else
			args[i] = tostring(args[i])
		end
	end
	if #args == 0 then args[1] = "nil" end

	local sign = image.fromString([[06030000FF 0000FF 00F7FF▟00F7FF▙0000FF 0000FF 0000FF 00F7FF▟F7FF00 F7FF00 00F7FF▙0000FF 00F7FF▟F7FF00CF7FF00yF7FF00kF7FF00a00F7FF▙]])
	local offset = 2
	local lines = #args > 1 and "\"" .. table.concat(args, "\", \"") .. "\"" or args[1]
	local width = math.floor(buffer.width * 0.5)
	local textWidth = width - image.getWidth(sign) - 2

	lines = string.wrap(lines, textWidth)
	local height = image.getHeight(sign)
	if #lines + 2 > height then
		height = #lines + 2
	end

	local mainContainer = GUI.container(1, math.floor(buffer.height / 2 - height / 2), buffer.width, height + offset * 2)
	local oldPixels = buffer.copy(mainContainer.x, mainContainer.y, mainContainer.width, mainContainer.height)

	local x, y = math.floor(buffer.width / 2 - width / 2), offset + 1
	mainContainer:addChild(GUI.panel(1, 1, mainContainer.width, mainContainer.height, 0x1D1D1D))
	mainContainer:addChild(GUI.image(x, y, sign))
	mainContainer:addChild(GUI.textBox(x + image.getWidth(sign) + 2, y, textWidth, #lines, 0x1D1D1D, 0xEEEEEE, lines, 1, 0, 0)).eventHandler = nil
	local buttonWidth = 12
	local button = mainContainer:addChild(GUI.button(x + image.getWidth(sign) + textWidth - buttonWidth + 2, mainContainer.height - offset, buttonWidth, 1, 0x3366CC, 0xEEEEEE, 0xEEEEEE, 0x3366CC, "Ok"))
	button.onTouch = function()
		mainContainer:stopEventHandling()
		buffer.paste(mainContainer.x, mainContainer.y, oldPixels)
		buffer.draw()
	end
	mainContainer.eventHandler = function(mainContainer, object, eventData)
		if eventData[1] == "key_down" and eventData[4] == 28 then
			button:pressAndRelease()
			button.onTouch()
		end
	end

	mainContainer:draw()
	buffer.draw(true)
	mainContainer:startEventHandling()
end

----------------------------------------- Text Box object -----------------------------------------

local function drawTextBox(object)
	if object.colors.background then buffer.square(object.x, object.y, object.width, object.height, object.colors.background, object.colors.text, " ", object.colors.transparency) end
	local xPos, yPos = GUI.getAlignmentCoordinates(object, {width = 1, height = object.height - object.offset.vertical * 2})
	local lineLimit = object.width - object.offset.horizontal * 2
	for line = object.currentLine, object.currentLine + object.height - 1 do
		if object.lines[line] then
			local lineType, text, textColor = type(object.lines[line])
			if lineType == "table" then
				text, textColor = string.limit(object.lines[line].text, lineLimit), object.lines[line].color
			elseif lineType == "string" then
				text, textColor = string.limit(object.lines[line], lineLimit), object.colors.text
			else
				error("Unknown TextBox line type: " .. tostring(lineType))
			end

			xPos = GUI.getAlignmentCoordinates(
				{
					x = object.x + object.offset.horizontal,
					y = object.y + object.offset.vertical,
					width = object.width - object.offset.horizontal * 2,
					height = object.height - object.offset.vertical * 2,
					alignment = object.alignment
				},
				{width = unicode.len(text), height = object.height}
			)
			buffer.text(xPos, yPos, textColor, text)
			yPos = yPos + 1
		else
			break
		end
	end

	return object
end

local function scrollDownTextBox(object, count)
	count = count or 1
	local maxCountAvailableToScroll = #object.lines - object.height - object.currentLine + 1
	count = math.min(count, maxCountAvailableToScroll)
	if #object.lines >= object.height and object.currentLine < #object.lines - count then
		object.currentLine = object.currentLine + count
	end
	return object
end

local function scrollUpTextBox(object, count)
	count = count or 1
	if object.currentLine > count and object.currentLine >= 1 then object.currentLine = object.currentLine - count end
	return object
end

local function scrollToStartTextBox(object)
	object.currentLine = 1
	return object
end

local function scrollToEndTextBox(object)
	object.currentLine = #lines
	return object
end

local function textBoxScrollEventHandler(mainContainer, object, eventData)
	if eventData[1] == "scroll" then
		if eventData[5] == 1 then
			object:scrollUp()
			mainContainer:draw()
			buffer.draw()
		else
			object:scrollDown()
			mainContainer:draw()
			buffer.draw()
		end
	end
end

function GUI.textBox(x, y, width, height, backgroundColor, textColor, lines, currentLine, horizontalOffset, verticalOffset)
	local object = GUI.object(x, y, width, height)
	
	object.eventHandler = textBoxScrollEventHandler
	object.colors = { text = textColor, background = backgroundColor }
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.left, GUI.alignment.vertical.top)
	object.lines = lines
	object.currentLine = currentLine or 1
	object.draw = drawTextBox
	object.scrollUp = scrollUpTextBox
	object.scrollDown = scrollDownTextBox
	object.scrollToStart = scrollToStartTextBox
	object.scrollToEnd = scrollToEndTextBox
	object.offset = {horizontal = horizontalOffset or 0, vertical = verticalOffset or 0}

	return object
end

----------------------------------------- Horizontal Slider Object -----------------------------------------

local function drawHorizontalSlider(object)
	-- На всякий случай делаем значение не меньше минимального и не больше максимального
	object.value = math.min(math.max(object.value, object.minimumValue), object.maximumValue)
	
	if object.showMaximumAndMinimumValues then
		local stringMaximumValue, stringMinimumValue = tostring(object.roundValues and math.floor(object.maximumValue) or math.roundToDecimalPlaces(object.maximumValue, 2)), tostring(object.roundValues and math.floor(object.minimumValue) or math.roundToDecimalPlaces(object.minimumValue, 2))
		buffer.text(object.x - unicode.len(stringMinimumValue) - 1, object.y, object.colors.value, stringMinimumValue)
		buffer.text(object.x + object.width + 1, object.y, object.colors.value, stringMaximumValue)
	end

	if object.currentValuePrefix or object.currentValuePostfix then
		local stringCurrentValue = (object.currentValuePrefix or "") .. (object.roundValues and math.floor(object.value) or math.roundToDecimalPlaces(object.value, 2)) .. (object.currentValuePostfix or "")
		buffer.text(math.floor(object.x + object.width / 2 - unicode.len(stringCurrentValue) / 2), object.y + 1, object.colors.value, stringCurrentValue)
	end

	local activeWidth = math.floor(object.width - ((object.maximumValue - object.value) * object.width / (object.maximumValue - object.minimumValue)))
	buffer.text(object.x, object.y, object.colors.passive, string.rep("━", object.width))
	buffer.text(object.x, object.y, object.colors.active, string.rep("━", activeWidth))
	buffer.text(object.x + activeWidth - 1, object.y, object.colors.pipe, "⬤")

	return object
end

local function sliderEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" or eventData[1] == "drag" then
		local clickPosition = eventData[3] - object.x + 1
		object.value = object.minimumValue + (clickPosition * (object.maximumValue - object.minimumValue) / object.width)
		mainContainer:draw()
		buffer.draw()
		callMethod(object.onValueChanged, object.value, eventData)
	end
end

function GUI.slider(x, y, width, activeColor, passiveColor, pipeColor, valueColor, minimumValue, maximumValue, value, showMaximumAndMinimumValues, currentValuePrefix, currentValuePostfix)
	local object = GUI.object(x, y, width, 1)
	
	object.eventHandler = sliderEventHandler
	object.colors = {active = activeColor, passive = passiveColor, pipe = pipeColor, value = valueColor}
	object.draw = drawHorizontalSlider
	object.minimumValue = minimumValue
	object.maximumValue = maximumValue
	object.value = value
	object.showMaximumAndMinimumValues = showMaximumAndMinimumValues
	object.currentValuePrefix = currentValuePrefix
	object.currentValuePostfix = currentValuePostfix
	object.roundValues = false
	
	return object
end

----------------------------------------- Switch object -----------------------------------------

local function switchDraw(switch)
	local pipePosition, backgroundColor
	if switch.state then
		pipePosition, backgroundColor = switch.x + switch.width - 2, switch.colors.active
	else
		pipePosition, backgroundColor = switch.x, switch.colors.passive
	end

	buffer.text(switch.x - 1, switch.y, backgroundColor, "⠰")
	buffer.square(switch.x, switch.y, switch.width, 1, backgroundColor, 0x000000, " ")
	buffer.text(switch.x + switch.width, switch.y, backgroundColor, "⠆")


	buffer.text(pipePosition - 1, switch.y, switch.colors.pipe, "⠰")
	buffer.square(pipePosition, switch.y, 2, 1, switch.colors.pipe, 0x000000, " ")
	buffer.text(pipePosition + 2, switch.y, switch.colors.pipe, "⠆")
	
	return switch
end

local function switchEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object.state = not object.state
		mainContainer:draw()
		buffer.draw()
		callMethod(object.onStateChanged, object.state, eventData)
	end
end

function GUI.switch(x, y, width, activeColor, passiveColor, pipeColor, state)
	local switch = GUI.object(x, y, width, 1)
	
	switch.eventHandler = switchEventHandler
	switch.colors = {active = activeColor, passive = passiveColor, pipe = pipeColor, value = valueColor}
	switch.draw = switchDraw
	switch.state = state or false
	
	return switch
end

----------------------------------------- Combo Box Object -----------------------------------------

local function drawComboBox(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.default.background)
	local x, y, limit, arrowSize = object.x + 1, math.floor(object.y + object.height / 2), object.width - 5, object.height
	buffer.text(x, y, object.colors.default.text, string.limit(object.items[object.selectedItem].text, limit, "right"))
	GUI.button(object.x + object.width - arrowSize * 2 + 1, object.y, arrowSize * 2 - 1, arrowSize, object.colors.arrow.background, object.colors.arrow.text, 0x0, 0x0, object.state and "▲" or "▼"):draw()
end

local function selectComboBoxItem(object)
	object.state = true
	object:draw()

	local dropDownMenu = GUI.dropDownMenu(object.x, object.y + object.height, object.width, object.height, object.colors.default.background, object.colors.default.text, object.colors.pressed.background, object.colors.pressed.text, GUI.colors.contextMenu.disabled.text, GUI.colors.contextMenu.separator, GUI.colors.contextMenu.transparency.background, object.items)
	dropDownMenu.items = object.items
	dropDownMenu.sidesOffset = 1
	local _, itemIndex = dropDownMenu:show()

	object.selectedItem = itemIndex or object.selectedItem
	object.state = false
	object:draw()
	buffer.draw()
end

local function comboBoxEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object:selectItem()
		callMethod(object.onItemSelected, object.items[object.selectedItem], eventData)
	end
end

function GUI.comboBox(x, y, width, elementHeight, backgroundColor, textColor, arrowBackgroundColor, arrowTextColor)
	local object = GUI.object(x, y, width, elementHeight)
	
	object.eventHandler = comboBoxEventHandler
	object.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		pressed = {
			background = GUI.colors.contextMenu.pressed.background,
			text = GUI.colors.contextMenu.pressed.text
		},
		arrow = {
			background = arrowBackgroundColor,
			text = arrowTextColor 
		}
	}
	object.items = {}
	object.selectedItem = 1
	object.addItem = addDropDownMenuItem
	object.addSeparator = addDropDownMenuSeparator
	object.draw = drawComboBox
	object.selectItem = selectComboBoxItem
	object.state = false

	return object
end

----------------------------------------- Scrollbar object -----------------------------------------

local function scrollBarDraw(scrollBar)
	local isVertical = scrollBar.height > scrollBar.width
	local valuesDelta = scrollBar.maximumValue - scrollBar.minimumValue + 1
	local part = scrollBar.value / valuesDelta

	if not isVertical and scrollBar.thinHorizontalMode then
		buffer.text(scrollBar.x, scrollBar.y, scrollBar.colors.background, string.rep("▄", scrollBar.width))
	else
		buffer.square(scrollBar.x, scrollBar.y, scrollBar.width, scrollBar.height, scrollBar.colors.background, 0x0, " ")
	end

	if isVertical then
		local barSize = math.ceil(scrollBar.shownValueCount / valuesDelta * scrollBar.height)
		local halfBarSize = math.floor(barSize / 2)
		
		scrollBar.ghostPosition.x = scrollBar.x
		scrollBar.ghostPosition.y = scrollBar.y + halfBarSize
		scrollBar.ghostPosition.width = scrollBar.width
		scrollBar.ghostPosition.height = scrollBar.height - barSize

		buffer.square(
			scrollBar.ghostPosition.x,
			math.floor(scrollBar.ghostPosition.y + part * scrollBar.ghostPosition.height - halfBarSize),
			scrollBar.ghostPosition.width,
			barSize,
			scrollBar.colors.foreground, 0x0, " "
		)
	else
		local barSize = math.ceil(scrollBar.shownValueCount / valuesDelta * scrollBar.width)
		local halfBarSize = math.floor(barSize / 2)
		
		scrollBar.ghostPosition.x = scrollBar.x + halfBarSize
		scrollBar.ghostPosition.y = scrollBar.y
		scrollBar.ghostPosition.width = scrollBar.width - barSize
		scrollBar.ghostPosition.height = scrollBar.height

		if not isVertical and scrollBar.thinHorizontalMode then
			buffer.text(math.floor(scrollBar.ghostPosition.x + part * scrollBar.ghostPosition.width - halfBarSize), scrollBar.ghostPosition.y, scrollBar.colors.foreground, string.rep("▄", barSize))
		else
			buffer.square(
				math.floor(scrollBar.ghostPosition.x + part * scrollBar.ghostPosition.width - halfBarSize),
				scrollBar.ghostPosition.y,
				barSize,
				scrollBar.ghostPosition.height,
				scrollBar.colors.foreground, 0x0, " "
			)
		end
	end

	return scrollBar
end

local function scrollBarEventHandler(mainContainer, object, eventData)
	local newValue = object.value

	if eventData[1] == "touch" or eventData[1] == "drag" then
		local delta = object.maximumValue - object.minimumValue + 1
		if object.height > object.width then
			newValue = math.floor((eventData[4] - object.y + 1) / object.height * delta)
		else
			newValue = math.floor((eventData[3] - object.x + 1) / object.width * delta)
		end
	elseif eventData[1] == "scroll" then
		if eventData[5] == 1 then
			if object.value >= object.minimumValue + object.onScrollValueIncrement then
				newValue = object.value - object.onScrollValueIncrement
			else
				newValue = object.minimumValue
			end
		else
			if object.value <= object.maximumValue - object.onScrollValueIncrement then
				newValue = object.value + object.onScrollValueIncrement
			else
				newValue = object.maximumValue
			end
		end
	end

	if eventData[1] == "touch" or eventData[1] == "drag" or eventData[1] == "scroll" then
		object.value = newValue
		callMethod(object.onTouch, eventData)
		mainContainer:draw()
		buffer.draw()
	end
end

function GUI.scrollBar(x, y, width, height, backgroundColor, foregroundColor, minimumValue, maximumValue, value, shownValueCount, onScrollValueIncrement, thinHorizontalMode)
	local scrollBar = GUI.object(x, y, width, height)

	scrollBar.eventHandler = scrollBarEventHandler
	scrollBar.maximumValue = maximumValue
	scrollBar.minimumValue = minimumValue
	scrollBar.value = value
	scrollBar.onScrollValueIncrement = onScrollValueIncrement
	scrollBar.shownValueCount = shownValueCount
	scrollBar.thinHorizontalMode = thinHorizontalMode
	scrollBar.colors = {
		background = backgroundColor,
		foreground = foregroundColor,
	}
	scrollBar.ghostPosition = {}
	scrollBar.draw = scrollBarDraw

	return scrollBar
end

----------------------------------------- CodeView object -----------------------------------------

local function codeViewDraw(codeView)
	-- local toLine = codeView.fromLine + codeView.height - (codeView.scrollBars.horizontal.hidden and 1 or 2)
	local toLine = codeView.fromLine + codeView.height - 1

	-- Line numbers bar and code area
	codeView.lineNumbersWidth = unicode.len(tostring(toLine)) + 2
	codeView.codeAreaPosition = codeView.x + codeView.lineNumbersWidth
	codeView.codeAreaWidth = codeView.width - codeView.lineNumbersWidth
	buffer.square(codeView.x, codeView.y, codeView.lineNumbersWidth, codeView.height, require("syntax").colorScheme.lineNumbersBackground, require("syntax").colorScheme.lineNumbersText, " ")	
	buffer.square(codeView.codeAreaPosition, codeView.y, codeView.codeAreaWidth, codeView.height, require("syntax").colorScheme.background, require("syntax").colorScheme.text, " ")

	-- Line numbers texts
	local y = codeView.y
	for line = codeView.fromLine, toLine do
		if codeView.lines[line] then
			local text = tostring(line)
			if codeView.highlights[line] then
				buffer.square(codeView.x, y, codeView.lineNumbersWidth, 1, codeView.highlights[line], require("syntax").colorScheme.text, " ", 30)
				buffer.square(codeView.codeAreaPosition, y, codeView.codeAreaWidth, 1, codeView.highlights[line], require("syntax").colorScheme.text, " ")
			end
			buffer.text(codeView.codeAreaPosition - unicode.len(text) - 1, y, require("syntax").colorScheme.lineNumbersText, text)
			y = y + 1
		else
			break
		end	
	end

	local oldDrawLimitX1, oldDrawLimitY1, oldDrawLimitX2, oldDrawLimitY2 = buffer.getDrawLimit()
	buffer.setDrawLimit(codeView.codeAreaPosition, codeView.y, codeView.codeAreaPosition + codeView.codeAreaWidth - 1, codeView.y + codeView.height - 1)

	local function drawUpperSelection(y, selectionIndex)
		buffer.square(
			codeView.codeAreaPosition + codeView.selections[selectionIndex].from.symbol - codeView.fromSymbol + 1,
			y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
			codeView.codeAreaWidth - codeView.selections[selectionIndex].from.symbol + codeView.fromSymbol - 1,
			1,
			codeView.selections[selectionIndex].color or require("syntax").colorScheme.selection, require("syntax").colorScheme.text, " "
		)
	end

	local function drawLowerSelection(y, selectionIndex)
		buffer.square(
			codeView.codeAreaPosition,
			y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
			codeView.selections[selectionIndex].to.symbol - codeView.fromSymbol + 2,
			1,
			codeView.selections[selectionIndex].color or require("syntax").colorScheme.selection, require("syntax").colorScheme.text, " "
		)
	end

	if #codeView.selections > 0 then
		for selectionIndex = 1, #codeView.selections do
			y = codeView.y
			local dy = codeView.selections[selectionIndex].to.line - codeView.selections[selectionIndex].from.line
			if dy == 0 then
				buffer.square(
					codeView.codeAreaPosition + codeView.selections[selectionIndex].from.symbol - codeView.fromSymbol + 1,
					y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
					codeView.selections[selectionIndex].to.symbol - codeView.selections[selectionIndex].from.symbol + 1,
					1,
					codeView.selections[selectionIndex].color or require("syntax").colorScheme.selection, require("syntax").colorScheme.text, " "
				)
			elseif dy == 1 then
				drawUpperSelection(y, selectionIndex); y = y + 1
				drawLowerSelection(y, selectionIndex)
			else
				drawUpperSelection(y, selectionIndex); y = y + 1
				for i = 1, dy - 1 do
					buffer.square(codeView.codeAreaPosition, y + codeView.selections[selectionIndex].from.line - codeView.fromLine, codeView.codeAreaWidth, 1, codeView.selections[selectionIndex].color or require("syntax").colorScheme.selection, require("syntax").colorScheme.text, " "); y = y + 1
				end
				drawLowerSelection(y, selectionIndex)
			end
		end
	end

	-- Code strings
	y = codeView.y
	buffer.setDrawLimit(codeView.codeAreaPosition + 1, y, codeView.codeAreaPosition + codeView.codeAreaWidth - 2, y + codeView.height - 1)
	for i = codeView.fromLine, toLine do
		if codeView.lines[i] then
			if codeView.highlightLuaSyntax then
				require("syntax").highlightString(codeView.codeAreaPosition - codeView.fromSymbol + 2, y, codeView.lines[i], codeView.indentationWidth)
			else
				buffer.text(codeView.codeAreaPosition - codeView.fromSymbol + 2, y, require("syntax").colorScheme.text, codeView.lines[i])
			end
			y = y + 1
		else
			break
		end
	end
	buffer.setDrawLimit(oldDrawLimitX1, oldDrawLimitY1, oldDrawLimitX2, oldDrawLimitY2)

	if #codeView.lines > codeView.height then
		codeView.scrollBars.vertical.hidden = false
		codeView.scrollBars.vertical.colors.background, codeView.scrollBars.vertical.colors.foreground = require("syntax").colorScheme.scrollBarBackground, require("syntax").colorScheme.scrollBarForeground
		codeView.scrollBars.vertical.minimumValue, codeView.scrollBars.vertical.maximumValue, codeView.scrollBars.vertical.value, codeView.scrollBars.vertical.shownValueCount = 1, #codeView.lines, codeView.fromLine, codeView.height
		codeView.scrollBars.vertical.localPosition.x = codeView.width
		codeView.scrollBars.vertical.localPosition.y = 1
		codeView.scrollBars.vertical.height = codeView.height
	else
		codeView.scrollBars.vertical.hidden = true
	end

	if codeView.maximumLineLength > codeView.codeAreaWidth - 2 then
		codeView.scrollBars.horizontal.hidden = false
		codeView.scrollBars.horizontal.colors.background, codeView.scrollBars.horizontal.colors.foreground = require("syntax").colorScheme.scrollBarBackground, require("syntax").colorScheme.scrollBarForeground
		codeView.scrollBars.horizontal.minimumValue, codeView.scrollBars.horizontal.maximumValue, codeView.scrollBars.horizontal.value, codeView.scrollBars.horizontal.shownValueCount = 1, codeView.maximumLineLength, codeView.fromSymbol, codeView.codeAreaWidth - 2
		codeView.scrollBars.horizontal.localPosition.x, codeView.scrollBars.horizontal.width = codeView.lineNumbersWidth + 1, codeView.codeAreaWidth - 1
		codeView.scrollBars.horizontal.localPosition.y = codeView.height
	else
		codeView.scrollBars.horizontal.hidden = true
	end

	codeView:reimplementedDraw()
end

function GUI.codeView(x, y, width, height, lines, fromSymbol, fromLine, maximumLineLength, selections, highlights, highlightLuaSyntax, indentationWidth)
	local codeView = GUI.container(x, y, width, height)
	
	codeView.lines = lines
	codeView.fromSymbol = fromSymbol
	codeView.fromLine = fromLine
	codeView.maximumLineLength = maximumLineLength
	codeView.selections = selections or {}
	codeView.highlights = highlights or {}
	codeView.highlightLuaSyntax = highlightLuaSyntax
	codeView.indentationWidth = indentationWidth

	codeView.scrollBars = {
		vertical = codeView:addChild(GUI.scrollBar(1, 1, 1, 1, 0x0, 0x0, 1, 1, 1, 1, 1, false)),
		horizontal = codeView:addChild(GUI.scrollBar(1, 1, 1, 1, 0x0, 0x0, 1, 1, 1, 1, 1, true))
	}

	codeView.reimplementedDraw = codeView.draw
	codeView.draw = codeViewDraw

	return codeView
end 

----------------------------------------- Color Selector object -----------------------------------------

local function updateFileList(directoriesToShowContent, xOffset, path)
	local localFileList = {}
	for file in fs.list(path) do
		local element = {}
		element.path = path .. file
		element.xOffset = xOffset
		element.isDirectory = fs.isDirectory(element.path)
		table.insert(localFileList, element)
	end

	-- Sort file list alphabeitcally
	table.sort(localFileList, function(a, b) return unicode.lower(a.path) < unicode.lower(b.path) end)
	-- Move folders on top and recursively get their content if needed
	local i, nextDirectoryIndex, nextLocalFileListIndex = 1, 1, 1
	while i <= #localFileList do
		if localFileList[i].isDirectory then
			table.insert(localFileList, nextDirectoryIndex, localFileList[i])
			table.remove(localFileList, i + 1)

			if directoriesToShowContent[localFileList[nextDirectoryIndex].path] then
				local nextLocalFileList = updateFileList(directoriesToShowContent, xOffset + 2, localFileList[nextDirectoryIndex].path)
				
				nextLocalFileListIndex = nextDirectoryIndex + 1
				for j = 1, #nextLocalFileList do
					table.insert(localFileList, nextLocalFileListIndex, nextLocalFileList[j])
					nextLocalFileListIndex = nextLocalFileListIndex + 1
				end
				i, nextDirectoryIndex = i + #nextLocalFileList, nextDirectoryIndex + #nextLocalFileList
			end

			nextDirectoryIndex = nextDirectoryIndex + 1
		end

		i = i + 1
	end

	return localFileList
end

local function treeViewUpdateFileList(treeView)
	treeView.fileList = updateFileList(treeView.directoriesToShowContent, 1, treeView.workPath)
	return treeView
end

local function treeViewDraw(treeView)
	local y = treeView.y + 1
	local showScrollBar = #treeView.fileList > treeView.height
	local textLimit = treeView.width - (showScrollBar and 2 or 1)

	if treeView.colors.default.background then
		buffer.square(treeView.x, treeView.y, treeView.width, treeView.height, treeView.colors.default.background, treeView.colors.default.text, " ")
	end

	for fileIndex = treeView.fromFile, #treeView.fileList do
		local textColor = treeView.colors.default.text
		if treeView.fileList[fileIndex].path == treeView.currentFile then
			textColor = treeView.colors.selected.text
			buffer.square(treeView.x, y, treeView.width, 1, treeView.colors.selected.background, textColor, " ") 
		end

		if treeView.fileList[fileIndex].isDirectory then
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset, y, treeView.colors.arrow, treeView.directoriesToShowContent[treeView.fileList[fileIndex].path] and "▽" or "▷")
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset + 2, y, textColor, unicode.sub("■ " .. fs.name(treeView.fileList[fileIndex].path), 1, textLimit - treeView.fileList[fileIndex].xOffset - 2))
		else
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset, y, textColor, unicode.sub("  □ " .. fs.name(treeView.fileList[fileIndex].path), 1, textLimit - treeView.fileList[fileIndex].xOffset))
		end

		y = y + 1
		if y > treeView.y + treeView.height - 2 then break end
	end

	if showScrollBar then
		GUI.scrollBar(
			treeView.x + treeView.width - 1,
			treeView.y,
			1,
			treeView.height,
			treeView.colors.scrollBar.background, 
			treeView.colors.scrollBar.foreground,
			1,
			#treeView.fileList,
			treeView.fromFile,
			treeView.height - 2,
			1
		):draw()	
	end

	return treeView
end

local function treeViewEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		local fileIndex = eventData[4] - object.y + object.fromFile - 1
		if object.fileList[fileIndex] then
			if object.fileList[fileIndex].isDirectory then
				if object.directoriesToShowContent[object.fileList[fileIndex].path] then
					object.directoriesToShowContent[object.fileList[fileIndex].path] = nil
				else
					object.directoriesToShowContent[object.fileList[fileIndex].path] = true
				end
				object:updateFileList()
				mainContainer:draw()
				buffer.draw()
			else
				object.currentFile = object.fileList[fileIndex].path
				mainContainer:draw()
				buffer.draw()
				callMethod(object.onFileSelected, object.currentFile, eventData)
			end
		end
	elseif eventData[1] == "scroll" then
		if eventData[5] == 1 then
			if object.fromFile > 1 then
				object.fromFile = object.fromFile - 1
				mainContainer:draw()
				buffer.draw()
			end
		else
			if object.fromFile < #object.fileList then
				object.fromFile = object.fromFile + 1
				mainContainer:draw()
				buffer.draw()
			end
		end
	end
end

function GUI.treeView(x, y, width, height, backgroundColor, textColor, selectionColor, selectionTextColor, arrowColor, scrollBarBackground, scrollBarForeground, workPath)
	local treeView = GUI.container(x, y, width, height)
	
	treeView.eventHandler = treeViewEventHandler
	treeView.colors = {
		default = {
			background = backgroundColor,
			text = textColor,
		},
		selected = {
			background = selectionColor,
			text = selectionTextColor,
		},
		scrollBar = {
			background = scrollBarBackground,
			foreground = scrollBarForeground
		},
		arrow = arrowColor
	}
	treeView.directoriesToShowContent = {}
	treeView.fileList = {}
	treeView.workPath = workPath

	treeView.updateFileList = treeViewUpdateFileList
	treeView.draw = treeViewDraw
	treeView.currentFile = nil
	treeView.fromFile = 1

	treeView:updateFileList()

	return treeView
end

----------------------------------------- Color Selector object -----------------------------------------

local function colorSelectorDraw(colorSelector)
	local overlayColor = colorSelector.color < 0x7FFFFF and 0xFFFFFF or 0x000000
	buffer.square(colorSelector.x, colorSelector.y, colorSelector.width, colorSelector.height, colorSelector.color, overlayColor, " ")
	if colorSelector.pressed then
		buffer.square(colorSelector.x, colorSelector.y, colorSelector.width, colorSelector.height, overlayColor, overlayColor, " ", 80)
	end
	if colorSelector.height > 1 then
		buffer.text(colorSelector.x, colorSelector.y + colorSelector.height - 1, overlayColor, string.rep("▄", colorSelector.width), 80)
	end
	buffer.text(colorSelector.x + 1, colorSelector.y + math.floor(colorSelector.height / 2), overlayColor, string.limit(colorSelector.text, colorSelector.width - 2))
	return colorSelector
end

local function colorSelectorEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object.pressed = true
		mainContainer:draw()
		buffer.draw()
		
		object.color = require("palette").show(math.floor(mainContainer.width / 2 - 35), math.floor(mainContainer.height / 2 - 12), object.color) or object.color
		
		object.pressed = false
		mainContainer:draw()
		buffer.draw()
		callMethod(object.onTouch, eventData)
	end
end

function GUI.colorSelector(x, y, width, height, color, text)
	local colorSelector = GUI.object(x, y, width, height)
	
	colorSelector.eventHandler = colorSelectorEventHandler
	colorSelector.color = color
	colorSelector.text = text
	colorSelector.draw = colorSelectorDraw
	
	return colorSelector
end 

----------------------------------------- Chart object -----------------------------------------

local function getAxisValue(number, postfix, roundValues)
	if roundValues then
		return math.floor(number) .. postfix
	else
		local integer, fractional = math.modf(number)
		local firstPart, secondPart = "", ""
		if math.abs(integer) >= 1000 then
			return math.shortenNumber(integer, 2) .. postfix
		else
			if math.abs(fractional) > 0 then
				return string.format("%.2f", number) .. postfix
			else
				return number .. postfix
			end
		end
	end
end

local function drawChart(object)
	-- Sorting by x value
	local valuesCopy = {}
	for i = 1, #object.values do valuesCopy[i] = object.values[i] end
	table.sort(valuesCopy, function(a, b) return a[1] < b[1] end)
	
	if #valuesCopy == 0 then valuesCopy = {{0, 0}} end

	-- Max, min, deltas
	local xMin, xMax, yMin, yMax = valuesCopy[1][1], valuesCopy[#valuesCopy][1], valuesCopy[1][2], valuesCopy[1][2]
	for i = 1, #valuesCopy do yMin, yMax = math.min(yMin, valuesCopy[i][2]), math.max(yMax, valuesCopy[i][2]) end
	local dx, dy = xMax - xMin, yMax - yMin

	-- y axis values and helpers
	local value, chartHeight, yAxisValueMaxWidth, yAxisValues = yMin, object.height - 1 - (object.showXAxisValues and 1 or 0), 0, {}
	for y = object.y + object.height - 3, object.y + 1, -chartHeight * object.yAxisValueInterval do
		local stringValue = getAxisValue(value, object.yAxisPostfix, object.roundValues)
		yAxisValueMaxWidth = math.max(yAxisValueMaxWidth, unicode.len(stringValue))
		table.insert(yAxisValues, {y = math.ceil(y), value = stringValue})
		value = value + dy * object.yAxisValueInterval
	end
	local stringValue = getAxisValue(yMax, object.yAxisPostfix, object.roundValues)
	table.insert(yAxisValues, {y = object.y, value = stringValue})
	yAxisValueMaxWidth = math.max(yAxisValueMaxWidth, unicode.len(stringValue))

	local chartWidth = object.width - (object.showYAxisValues and yAxisValueMaxWidth + 2 or 0) 
	local chartX = object.x + object.width - chartWidth
	for i = 1, #yAxisValues do
		if object.showYAxisValues then
			buffer.text(chartX - unicode.len(yAxisValues[i].value) - 2, yAxisValues[i].y, object.colors.axisValue, yAxisValues[i].value)
		end
		buffer.text(chartX, yAxisValues[i].y, object.colors.helpers, string.rep("─", chartWidth))
	end

	-- x axis values
	if object.showXAxisValues then
		value = xMin
		for x = chartX, chartX + chartWidth - 2, chartWidth * object.xAxisValueInterval do
			local stringValue = getAxisValue(value, object.xAxisPostfix, object.roundValues)
			buffer.text(math.floor(x - unicode.len(stringValue) / 2), object.y + object.height - 1, object.colors.axisValue, stringValue)
			value = value + dx * object.xAxisValueInterval
		end
		local value = getAxisValue(xMax, object.xAxisPostfix, object.roundValues)
		buffer.text(object.x + object.width - unicode.len(value), object.y + object.height - 1, object.colors.axisValue, value)
	end

	-- Axis lines
	for y = object.y, object.y + chartHeight - 1 do
		buffer.text(chartX - 1, y, object.colors.axis, "┨")
	end
	buffer.text(chartX - 1, object.y + chartHeight, object.colors.axis, "┗" .. string.rep("┯━", math.floor(chartWidth / 2)))

	local function fillVerticalPart(x1, y1, x2, y2)
		local dx, dy = x2 - x1, y2 - y1
		local absdx, absdy = math.abs(dx), math.abs(dy)
		if absdx >= absdy then
			local step, y = dy / absdx, y1
			for x = x1, x2, (x1 < x2 and 1 or -1) do
				local yFloor = math.floor(y)
				buffer.semiPixelSquare(math.floor(x), yFloor, 1, math.floor(object.y + chartHeight) * 2 - yFloor - 1, object.colors.chart)
				y = y + step
			end
		else
			local step, x = dx / absdy, x1
			for y = y1, y2, (y1 < y2 and 1 or -1) do
				local yFloor = math.floor(y)
				buffer.semiPixelSquare(math.floor(x), yFloor, 1, math.floor(object.y + chartHeight) * 2 - yFloor - 1, object.colors.chart)
				x = x + step
			end
		end
	end

	-- chart
	for i = 1, #valuesCopy - 1 do
		local x = math.floor(chartX + (valuesCopy[i][1] - xMin) / dx * (chartWidth - 1))
		local y = math.floor(object.y + chartHeight - 1 - (valuesCopy[i][2] - yMin) / dy * (chartHeight - 1)) * 2
		local xNext = math.floor(chartX + (valuesCopy[i + 1][1] - xMin) / dx * (chartWidth - 1))
		local yNext = math.floor(object.y + chartHeight - 1 - (valuesCopy[i + 1][2] - yMin) / dy * (chartHeight - 1)) * 2
		if object.fillChartArea then
			fillVerticalPart(x, y, xNext, yNext)
		else
			buffer.semiPixelLine(x, y, xNext, yNext, object.colors.chart)
		end
	end

	return object
end

function GUI.chart(x, y, width, height, axisColor, axisValueColor, axisHelpersColor, chartColor, xAxisValueInterval, yAxisValueInterval, xAxisPostfix, yAxisPostfix, fillChartArea, values)
	local object = GUI.object(x, y, width, height)

	object.colors = {axis = axisColor, chart = chartColor, axisValue = axisValueColor, helpers = axisHelpersColor}
	object.draw = drawChart
	object.values = values or {}
	object.xAxisPostfix = xAxisPostfix
	object.yAxisPostfix = yAxisPostfix
	object.xAxisValueInterval = xAxisValueInterval
	object.yAxisValueInterval = yAxisValueInterval
	object.fillChartArea = fillChartArea
	object.showYAxisValues = true
	object.showXAxisValues = true

	return object
end

----------------------------------------- Window object -----------------------------------------

local function windowDraw(window)
	GUI.drawContainerContent(window)
	GUI.windowShadow(window.x, window.y, window.width, window.height, nil, true)
	return window
end

local function windowCheck(container, x, y)
	for i = #container.children, 1, -1 do
		if container.children[i].children then
			if windowCheck(container.children[i], x, y) then
				return true
			end
		elseif container.children[i].eventHandler and container.children[i]:isClicked(x, y) then
			return true
		end
	end
end

local function windowEventHandler(mainContainer, object, eventData)
	if eventData ~= mainContainer.focusedWindowEventData then
		mainContainer.focusedWindowEventData = eventData

		if eventData[1] == "touch" then
			mainContainer.focusedWindow = object
			object.lastTouchPosition = object.lastTouchPosition or {}
			object.lastTouchPosition.x, object.lastTouchPosition.y = eventData[3], eventData[4]
			
			if object ~= object.parent.children[#object.parent.children] then
				object:moveToFront()
				mainContainer:draw()
				buffer.draw()
			end
		elseif eventData[1] == "drag" and object == mainContainer.focusedWindow and object.lastTouchPosition and not windowCheck(object, eventData[3], eventData[4]) then
			local xOffset, yOffset = eventData[3] - object.lastTouchPosition.x, eventData[4] - object.lastTouchPosition.y
			object.lastTouchPosition.x, object.lastTouchPosition.y = eventData[3], eventData[4]

			if xOffset ~= 0 or yOffset ~= 0 then
				object.localPosition.x, object.localPosition.y = object.localPosition.x + xOffset, object.localPosition.y + yOffset
				mainContainer:draw()
				buffer.draw()
			end
		elseif eventData[1] == "drop" then
			mainContainer.focusedWindow = nil
			object.lastTouchPosition = nil
		end
	end
end

function GUI.window(x, y, width, height)
	local window = GUI.container(x, y, width, height)
	
	window.eventHandler = windowEventHandler
	window.allowDragMovement = true
	window.draw = windowDraw

	return window
end

function GUI.filledWindow(x, y, width, height, backgroundColor)
	local window = GUI.window(x, y, width, height)

	window.backgroundPanel = window:addChild(GUI.panel(1, 1, width, height, backgroundColor))
	window.actionButtons = window:addChild(GUI.actionButtons(2, 1, false))

	return window
end

function GUI.titledWindow(x, y, width, height, title, addTitlePanel)
	local window = GUI.filledWindow(x, y, width, height, GUI.colors.windows.backgroundPanel)

	if addTitlePanel then
		window.titlePanel = window:addChild(GUI.panel(1, 1, width, 1, GUI.colors.windows.title.background))
		window.backgroundPanel.localPosition.y, window.backgroundPanel.height = 2, window.height - 1
	end
	window.titleLabel = window:addChild(GUI.label(1, 1, width, height, GUI.colors.windows.title.text, title)):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top)
	window.actionButtons:moveToFront()

	return window
end

function GUI.tabbedWindow(x, y, width, height, ...)
	local window = GUI.filledWindow(x, y, width, height, GUI.colors.windows.backgroundPanel)

	window.tabBar = window:addChild(GUI.tabBar(1, 1, window.width, 3, 2, 0, GUI.colors.windows.tabBar.default.background, GUI.colors.windows.tabBar.default.text, GUI.colors.windows.tabBar.selected.background, GUI.colors.windows.tabBar.selected.text, ...))
	window.backgroundPanel.localPosition.y, window.backgroundPanel.height = 4, window.height - 3
	window.actionButtons:moveToFront()
	window.actionButtons.localPosition.y = 2

	return window
end

----------------------------------------- Universal keyboard-input function -----------------------------------------

local function inputDraw(input)
	if input.oldPixels then
		buffer.paste(input.x, input.y, input.oldPixels)
	else
		input.oldPixels = buffer.copy(input.x, input.y, input.width, 1)
	end
	
	buffer.text(
		input.x,
		input.y,
		input.colors.text,
		unicode.sub(
			input.textMask and string.rep(input.textMask, unicode.len(input.text)) or input.text,
			input.textCutFrom,
			input.textCutFrom + input.width - 1
		)
	)

	if input.cursorBlinkState then
		buffer.text(input.x + input.cursorPosition - input.textCutFrom, input.y, input.cursorColor, input.cursorSymbol)
	end

	return input
end

local function inputSetCursorPosition(input, newPosition)
	if newPosition < 1 then
		newPosition = 1
	elseif newPosition > unicode.len(input.text) + 1 then
		newPosition = unicode.len(input.text) + 1
	end

	if newPosition > input.textCutFrom + input.width - 1 then
		input.textCutFrom = input.textCutFrom + newPosition - (input.textCutFrom + input.width - 1)
	elseif newPosition < input.textCutFrom then
		input.textCutFrom = newPosition
	end

	input.cursorPosition = newPosition

	return input
end

local function inputBeginInput(input)
	input.cursorBlinkState = true; input:draw(); buffer.draw()

	while true do
		local e = { event.pull(input.cursorBlinkDelay) }
		if e[1] == "touch" or e[1] == "drag" then
			if input:isClicked(e[3], e[4]) then
				input:setCursorPosition(input.textCutFrom + e[3] - input.x)
				input.cursorBlinkState = true; input:draw(); buffer.draw()
			else
				input.cursorBlinkState = false; input:draw(); buffer.draw()
				return input
			end
		elseif e[1] == "key_down" then
			-- Return
			if e[4] == 28 then
				input.cursorBlinkState = false; input:draw(); buffer.draw()
				return input
			-- Arrows left/right
			elseif e[4] == 203 then
				input:setCursorPosition(input.cursorPosition - 1)
			elseif e[4] == 205 then	
				input:setCursorPosition(input.cursorPosition + 1)
			-- Backspace
			elseif e[4] == 14 then
				input.text = unicode.sub(unicode.sub(input.text, 1, input.cursorPosition - 1), 1, -2) .. unicode.sub(input.text, input.cursorPosition, -1)
				input:setCursorPosition(input.cursorPosition - 1)
			-- Delete
			elseif e[4] == 211 then
				input.text = unicode.sub(input.text, 1, input.cursorPosition - 1) .. unicode.sub(input.text, input.cursorPosition + 1, -1)
			else
				if not keyboard.isControl(e[3]) then
					input.text = unicode.sub(input.text, 1, input.cursorPosition - 1) .. unicode.char(e[3]) .. unicode.sub(input.text, input.cursorPosition, -1)
					input:setCursorPosition(input.cursorPosition + 1)
				end
			end

			input.cursorBlinkState = true; input:draw(); buffer.draw()
		elseif e[1] == "clipboard" then
			input.text = unicode.sub(input.text, 1, input.cursorPosition - 1) .. e[3] .. unicode.sub(input.text, input.cursorPosition, -1)
			input:setCursorPosition(input.cursorPosition + unicode.len(e[3]))
			input.cursorBlinkState = true; input:draw(); buffer.draw()
		else
			input.cursorBlinkState = not input.cursorBlinkState; input:draw(); buffer.draw()
		end
	end
end

function GUI.input(x, y, width, textColor, text, textMask)
	local input = GUI.object(x, y, width, 1)

	input.textCutFrom = 1
	input.cursorPosition = 1
	input.cursorColor = 0x00A8FF
	input.cursorSymbol = "┃"
	input.cursorBlinkDelay = 0.4
	input.cursorBlinkState = false

	input.colors = {text = textColor}
	input.text = text
	input.textMask = textMask

	input.setCursorPosition = inputSetCursorPosition
	input.draw = inputDraw
	input.startInput = inputBeginInput

	input:setCursorPosition(unicode.len(input.text) + 1)

	return input
end

----------------------------------------- Input Text Box object -----------------------------------------

local function drawInputTextBox(inputField)
	local background = inputField.isFocused and inputField.colors.focused.background or inputField.colors.default.background
	local y = math.floor(inputField.y + inputField.height / 2)
	
	local text, foreground, textMask = inputField.text or "", inputField.colors.default.text, inputField.textMask
	if inputField.isFocused then
		if inputField.eraseTextOnFocus then
			text = ""
		else
			text = inputField.text or ""
		end

		foreground = inputField.colors.focused.text
	else
		if inputField.text == "" or not inputField.text then
			text, foreground, textMask = inputField.placeholderText or "", inputField.colors.placeholderText, nil
		end
	end

	if background then
		buffer.square(inputField.x, inputField.y, inputField.width, inputField.height, background, foreground, " ")
	end

	local input = GUI.input(inputField.x + 1, y, inputField.width - 2, foreground, text, textMask)	
	input.onKeyDown = inputField.onKeyDown

	if inputField.isFocused then
		input:startInput()
		if inputField.validator then
			if inputField.validator(input.text) then
				inputField.text = input.text
			end
		else
			inputField.text = input.text
		end
	else
		input:draw()
	end

	return inputField
end

local function inputFieldStartInput(inputField)
	inputField.isFocused = true
	inputField:draw()
	inputField.isFocused = false
	callMethod(inputField.onInputFinished, inputField.text)

	return inputField
end

local function inputFieldEventHandler(mainContainer, object, eventData)
	if eventData[1] == "touch" then
		object:startInput()
		mainContainer:draw()
		buffer.draw()
	end
end

function GUI.inputField(x, y, width, height, backgroundColor, textColor, placeholderTextColor, backgroundFocusedColor, textFocusedColor, text, placeholderText, eraseTextOnFocus, textMask)
	local inputField = GUI.object(x, y, width, height)
	inputField.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		focused = {
			background = backgroundFocusedColor,
			text = textFocusedColor
		},
		placeholderText = placeholderTextColor
	}

	inputField.eventHandler = inputFieldEventHandler
	inputField.text = text
	inputField.placeholderText = placeholderText
	inputField.draw = drawInputTextBox
	inputField.startInput = inputFieldStartInput
	inputField.eraseTextOnFocus = eraseTextOnFocus
	inputField.textMask = textMask

	return inputField
end

----------------------------------------- Layout object -----------------------------------------

local function layoutCheckCell(layout, column, row)
	if column < 1 or column > #layout.grid.columnSizes or row < 1 or row > #layout.grid.rowSizes then
		error("Specified grid position (" .. tostring(column) .. "x" .. tostring(row) .. ") is out of layout grid range")
	end
end

local function layoutGetAbsoluteTotalSize(array)
	local absoluteTotalSize = 0
	for i = 1, #array do
		if array[i].sizePolicy == GUI.sizePolicies.absolute then
			absoluteTotalSize = absoluteTotalSize + array[i].size
		end
	end
	return absoluteTotalSize
end

local function layoutGetCalculatedSize(array, index, dependency)
	if array[index].sizePolicy == GUI.sizePolicies.percentage then
		array[index].calculatedSize = array[index].size * dependency
	else
		array[index].calculatedSize = array[index].size
	end
end

local function layoutCalculate(layout)
	for row = 1, #layout.grid.rowSizes do
		for column = 1, #layout.grid.columnSizes do
			layout.grid[row][column].totalWidth, layout.grid[row][column].totalHeight = 0, 0
		end
	end

	for i = 1, #layout.children do
		layout.children[i].layoutGridPosition = layout.children[i].layoutGridPosition or {column = 1, row = 1}

		if layout.children[i].layoutGridPosition.row >= 1 and layout.children[i].layoutGridPosition.row <= #layout.grid.rowSizes and layout.children[i].layoutGridPosition.column >= 1 and layout.children[i].layoutGridPosition.column <= #layout.grid.columnSizes then
			if layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].direction == GUI.directions.horizontal then
				layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalWidth = layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalWidth + layout.children[i].width + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].spacing
				layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalHeight = math.max(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalHeight, layout.children[i].height)
			else
				layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalWidth = math.max(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalWidth, layout.children[i].width)
				layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalHeight = layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalHeight + layout.children[i].height + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].spacing
			end
		else
			error("Layout child with index " .. i .. " has been assigned to cell (" .. layout.children[i].layoutGridPosition.column .. "x" .. layout.children[i].layoutGridPosition.row .. ") out of layout grid range")
		end
	end

	local columnPercentageTotalSize, rowPercentageTotalSize = layout.width - layoutGetAbsoluteTotalSize(layout.grid.columnSizes), layout.height - layoutGetAbsoluteTotalSize(layout.grid.rowSizes)
	local x, y = 1, 1
	for row = 1, #layout.grid.rowSizes do
		layoutGetCalculatedSize(layout.grid.rowSizes, row, rowPercentageTotalSize)

		for column = 1, #layout.grid.columnSizes do
			layoutGetCalculatedSize(layout.grid.columnSizes, column, columnPercentageTotalSize)

			layout.grid[row][column].x, layout.grid[row][column].y = GUI.getAlignmentCoordinates(
				{
					x = x,
					y = y,
					width = layout.grid.columnSizes[column].calculatedSize,
					height = layout.grid.rowSizes[row].calculatedSize,
					alignment = layout.grid[row][column].alignment,
				},
				{
					width = layout.grid[row][column].totalWidth - (layout.grid[row][column].direction == GUI.directions.horizontal and layout.grid[row][column].spacing or 0),
					height = layout.grid[row][column].totalHeight - (layout.grid[row][column].direction == GUI.directions.vertical and layout.grid[row][column].spacing or 0),
				}
			)
			if layout.grid[row][column].margin then
				layout.grid[row][column].x, layout.grid[row][column].y = GUI.getMarginCoordinates(layout.grid[row][column])
			end

			x = x + layout.grid.columnSizes[column].calculatedSize
		end

		x, y = 1, y + layout.grid.rowSizes[row].calculatedSize
	end

	for i = 1, #layout.children do
		layout.children[i].layoutGridPosition = layout.children[i].layoutGridPosition or {column = 1, row = 1}
		
		if layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].direction == GUI.directions.horizontal then
			layout.children[i].localPosition.x = math.floor(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].x)
			layout.children[i].localPosition.y = math.floor(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].y + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalHeight / 2 - layout.children[i].height / 2)
			layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].x = layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].x + layout.children[i].width + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].spacing
		else
			layout.children[i].localPosition.x = math.floor(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].x + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].totalWidth / 2 - layout.children[i].width / 2)
			layout.children[i].localPosition.y = math.floor(layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].y)
			layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].y = layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].y + layout.children[i].height + layout.grid[layout.children[i].layoutGridPosition.row][layout.children[i].layoutGridPosition.column].spacing
		end
	end
end

local function layoutSetCellPosition(layout, column, row, object)
	layoutCheckCell(layout, column, row)
	object.layoutGridPosition = {column = column, row = row}

	return object
end

local function layoutSetCellDirection(layout, column, row, direction)
	layoutCheckCell(layout, column, row)
	layout.grid[row][column].direction = direction

	return layout
end

local function layoutSetCellSpacing(layout, column, row, spacing)
	layoutCheckCell(layout, column, row)
	layout.grid[row][column].spacing = spacing

	return layout
end

local function layoutSetCellAlignment(layout, column, row, horizontalAlignment, verticalAlignment)
	layoutCheckCell(layout, column, row)
	layout.grid[row][column].alignment.horizontal, layout.grid[row][column].alignment.vertical = horizontalAlignment, verticalAlignment

	return layout
end

local function layoutSetCellMargin(layout, column, row, horizontalMargin, verticalMargin)
	layoutCheckCell(layout, column, row)
	layout.grid[row][column].margin = {
		horizontal = horizontalMargin,
		vertical = verticalMargin
	}

	return layout
end

local function layoutNewCell()
	return {
		alignment = {
			horizontal = GUI.alignment.horizontal.center,
			vertical = GUI.alignment.vertical.center
		},
		direction = GUI.directions.vertical,
		spacing = 1
	}
end

local function layoutCalculatePercentageSize(changingExistent, array, index)
	if array[index].sizePolicy == GUI.sizePolicies.percentage then
		local allPercents, beforeFromIndexPercents = 0, 0
		for i = 1, #array do
			if array[i].sizePolicy == GUI.sizePolicies.percentage then
				allPercents = allPercents + array[i].size

				if i <= index then
					beforeFromIndexPercents = beforeFromIndexPercents + array[i].size
				end
			end
		end

		local modifyer
		if changingExistent then
			if beforeFromIndexPercents > 1 then
				error("Layout summary percentage > 100% at index " .. index)
			end
			modifyer = (1 - beforeFromIndexPercents) / (allPercents - beforeFromIndexPercents)
		else
			modifyer = (1 - array[index].size) / (allPercents - array[index].size)
		end

		for i = changingExistent and index + 1 or 1, #array do
			if array[i].sizePolicy == GUI.sizePolicies.percentage and i ~= index then
				array[i].size = modifyer * array[i].size
			end
		end
	end
end

local function layoutSetColumnWidth(layout, column, sizePolicy, size)
	layout.grid.columnSizes[column].sizePolicy, layout.grid.columnSizes[column].size = sizePolicy, size
	layoutCalculatePercentageSize(true, layout.grid.columnSizes, column)

	return layout
end

local function layoutSetRowHeight(layout, row, sizePolicy, size)
	layout.grid.rowSizes[row].sizePolicy, layout.grid.rowSizes[row].size = sizePolicy, size
	layoutCalculatePercentageSize(true, layout.grid.rowSizes, row)

	return layout
end

local function layoutAddColumn(layout, sizePolicy, size)
	for i = 1, #layout.grid.rowSizes do
		table.insert(layout.grid[i], layoutNewCell())
	end

	table.insert(layout.grid.columnSizes, {
		sizePolicy = sizePolicy,
		size = size
	})
	layoutCalculatePercentageSize(false, layout.grid.columnSizes, #layout.grid.columnSizes)
	-- GUI.error(layout.grid.columnSizes)

	return layout
end

local function layoutAddRow(layout, sizePolicy, size)
	local row = {}
	for i = 1, #layout.grid.columnSizes do
		table.insert(row, layoutNewCell())
	end

	table.insert(layout.grid, row)
	table.insert(layout.grid.rowSizes, {
		sizePolicy = sizePolicy,
		size = size
	})

	layoutCalculatePercentageSize(false, layout.grid.rowSizes, #layout.grid.rowSizes)
	-- GUI.error(layout.grid.rowSizes)

	return layout
end

local function layoutRemoveRow(layout, row)
	table.remove(layout.grid, row)

	layout.grid.rowSizes[row].size = 0
	layoutCalculatePercentageSize(false, layout.grid.rowSizes, row)

	table.remove(layout.grid.rowSizes, row)

	return layout
end

local function layoutRemoveColumn(layout, column)
	for i = 1, #layout.grid.rowSizes do
		table.remove(layout.grid[i], column)
	end

	layout.grid.columnSizes[column].size = 0
	layoutCalculatePercentageSize(false, layout.grid.columnSizes, column)

	table.remove(layout.grid.columnSizes, column)

	return layout
end

local function layoutSetGridSize(layout, columnCount, rowCount)
	layout.grid = {
		rowSizes = {},
		columnSizes = {}
	}

	local rowSize, columnSize = 1 / rowCount, 1 / columnCount
	for i = 1, rowCount do
		layoutAddRow(layout, GUI.sizePolicies.percentage, 1 / i)
	end

	for i = 1, columnCount do
		layoutAddColumn(layout, GUI.sizePolicies.percentage, 1 / i)
	end

	return layout
end

local function layoutDraw(layout)
	layoutCalculate(layout)
	GUI.drawContainerContent(layout)
	if layout.showGrid then
		local x = layout.x
		for i = 1, #layout.grid.columnSizes do
			buffer.square(math.floor(x), layout.y, 1, layout.height, 0xFF0000, 0x0, " ", 40)
			x = x + layout.grid.columnSizes[i].calculatedSize
		end

		local y = layout.y
		for i = 1, #layout.grid.rowSizes do
			buffer.square(layout.x, math.floor(y), layout.width, 1, 0xFF0000, 0x0, " ", 40)
			y = y + layout.grid.rowSizes[i].calculatedSize
		end
	end
end

function GUI.layout(x, y, width, height, columnCount, rowCount)
	local layout = GUI.container(x, y, width, height)

	layout.addRow = layoutAddRow
	layout.addColumn = layoutAddColumn
	layout.removeRow = layoutRemoveRow
	layout.removeColumn = layoutRemoveColumn

	layout.setRowHeight = layoutSetRowHeight
	layout.setColumnWidth = layoutSetColumnWidth

	layout.setCellPosition = layoutSetCellPosition
	layout.setCellDirection = layoutSetCellDirection
	layout.setGridSize = layoutSetGridSize
	layout.setCellSpacing = layoutSetCellSpacing
	layout.setCellAlignment = layoutSetCellAlignment
	layout.setCellMargin = layoutSetCellMargin

	layout.draw = layoutDraw

	layoutSetGridSize(layout, columnCount, rowCount)

	return layout
end

--------------------------------------------------------------------------------------------------------------------------------

-- buffer.setResolution(160, 50)

-- local mainContainer = GUI.fullScreenContainer()
-- mainContainer:addChild(GUI.panel(1, 1, mainContainer.width, mainContainer.height, 0xFF8888))


-- mainContainer:addChild(GUI.switch(2, 2, 8, 0xFFDB40, 0xBBBBBB, 0xFFFFFF, true))
-- mainContainer:addChild(GUI.slider(2, 4, 36, 0xFFDB40, 0xBBBBBB, 0xFFFFFF, 0xBBBBBB, 0, 100, 50, true, "", "%"))

-- local layout = mainContainer:addChild(GUI.layout(2, 2, 157, 48, 4, 4))
-- mainContainer:addChild(GUI.panel(layout.localPosition.x, layout.localPosition.y, layout.width, layout.height, 0xFFFFFF)):moveBackward()

-- for i = 1, 4 do
-- 	layout:setCellPosition(2, 2, layout:addChild(GUI.button(1, 1, 30, 3, 0x0, 0xFFFFFF, 0x555555, 0x888888, "Button 1")))
-- end

-- layout:setCellAlignment(2, 2, GUI.alignment.horizontal.right, GUI.alignment.vertical.bottom)
-- layout:setCellMargin(2, 2, 2, 1)

-- layout:setCellPosition(3, 3, layout:addChild(GUI.button(1, 1, 30, 3, 0x0, 0xFFFFFF, 0x555555, 0x888888, "Button 2")))
-- layout:setColumnWidth(1, GUI.sizePolicies.absolute, 4)
-- layout:setColumnWidth(2, GUI.sizePolicies.percentage, 0.5)
-- layout:setColumnWidth(3, GUI.sizePolicies.percentage, 0.1)
-- layout:setRowHeight(3, GUI.sizePolicies.percentage, 0.4)

-- layout.showGrid = true

-- mainContainer:draw(true)
-- buffer.draw()
-- mainContainer:startEventHandling()


--------------------------------------------------------------------------------------------------------------------------------

return GUI






