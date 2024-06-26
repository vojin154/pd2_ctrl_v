local function ctrl()
    local k = Input:keyboard()

	return k and (k:down(Idstring("left ctrl")) or k:down(Idstring("right ctrl")) or k:has_button(Idstring("ctrl")) and k:down(Idstring("ctrl")))
end

local function paste(k)
    return (k == Idstring("insert")) or (ctrl() and k == Idstring("v"))
end

local pasted = false
local function remove_underline(str)
    if pasted then
        str = str:sub(1, str:len() - 1)
        pasted = false
    end

    return str
end

local function enter_text(self, old_func, ...)
    local args = {...}
    local str = args[#args]

    str = remove_underline(str)
    args[#args] = str

    old_func(self, unpack(args))
end

local function key_press(self, old_func, o, k, row_item)
    local text = (row_item and row_item.gui_text) or (self._input_panel and self._input_panel:child("input_text")) or (self._search and self._search.text)

    if not alive(text) then
        return
    end

    local original_text = text:text()

    if row_item then
        old_func(self, row_item, o, k)
    else
        old_func(self, o, k)
    end

    if paste(k) then
        local clipboard = Application:get_clipboard() or ""

        if clipboard == "" then
            return
        end

        pasted = true
        text:set_text(original_text)
        text:replace_text(clipboard)

        local lbs = text:line_breaks()

        if self.MAX_SEARCH_LENGTH and (self.MAX_SEARCH_LENGTH < #text:text()) then
			text:set_text(string.sub(text:text(), 1, self.MAX_SEARCH_LENGTH))
		end

        if #lbs > 1 then
            local s = lbs[2]
            local e = utf8.len(text:text())

            text:set_selection(s, e)
            text:replace_text("")
        end

        if row_item then
            self:_layout(row_item)
        else
            self:update_caret()
        end
    end
end

local function key_down(self, old_func, o, k)
    if not paste(k) then
        return old_func(self, o, k)
    end

    wait(0.6)

    while paste(k) do
        local text = self._input_panel and self._input_panel:child("input_text")

        if not alive(text) then
            return old_func(self, o, k)
        end

        local clipboard = Application:get_clipboard() or ""

        if clipboard == "" then
            return
        end

        pasted = true
        text:replace_text(clipboard)

        local lbs = text:line_breaks()

        if self.MAX_SEARCH_LENGTH and (self.MAX_SEARCH_LENGTH < #text:text()) then
			text:set_text(string.sub(text:text(), 1, self.MAX_SEARCH_LENGTH))
		end

        if #lbs > 1 then
            local s = lbs[2]
            local e = utf8.len(text:text())

            text:set_selection(s, e)
            text:replace_text("")
        end

        self:update_caret()
		wait(0.03)
    end
end

local function wrap(class)
    local old_enter_text = class.enter_text
    function class:enter_text(...)
        enter_text(self, old_enter_text, ...)
    end

    --DISABLED UNTIL I FIND A WAY TO FIX RANDOM UNDERLINES APPEARING
    --[[local old_update_key_down = class.update_key_down
    function class:update_key_down(o, k)
        key_down(self, old_update_key_down, o, k)
    end]]

    local old_key_press = class.key_press
    local old_search_key_press = class.search_key_press

    if class == MenuItemInput then
        function class:key_press(row_item, o, k)
            if (not row_item) or (not self._editing) then
                return
            end

            key_press(self, old_key_press, o, k, row_item)
        end
    elseif old_search_key_press then
        function class:search_key_press(o, k)
            key_press(self, old_search_key_press, o, k)
        end
    else
        function class:key_press(o, k)
            key_press(self, old_key_press, o, k)
        end
    end
end

if RequiredScript == "lib/managers/chatmanager" then
    wrap(ChatGui)
elseif RequiredScript == "lib/managers/hud/hudchat" then
    wrap(HUDChat)
elseif RequiredScript == "lib/managers/menu/achievementlistgui" then
    wrap(AchievementListGui)
elseif RequiredScript == "lib/managers/menu/contractbrokergui" then
    wrap(ContractBrokerGui)
elseif RequiredScript == "lib/managers/menu/items/menuiteminput" then
    wrap(MenuItemInput)
end