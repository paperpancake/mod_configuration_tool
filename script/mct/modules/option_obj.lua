--- MCT Option Object
-- @classmod mct_option

-- TODO try and split up the different option types into separate smaller wrapped objects, wrapped with option_obj?
local mct = mct

local mct_option = {
    _mod = nil,
    _key = "",
    _type = nil,
    _text = "No text assigned.",
    _tooltip_text = "No tooltip assigned.",

    __templates = {
        checkbox = "ui/templates/checkbox_toggle",
        dropdown = {"ui/templates/dropdown_button", "ui/vandy_lib/dropdown_option"},
        textbox = "ui/common ui/text_box",
        slider = {"ui/templates/cycle_button_arrow_previous", "ui/common ui/text_box", "ui/templates/cycle_button_arrow_next"}
    },

    ui = mct.ui

    --_wrapped = nil
    --_callback = nil,
    --_selected_setting = nil,
    --_finalized_setting = nil
}

--local mct_checkbox_template = "ui/templates/checkbox_toggle"
--local mct_dropdown_template = {"ui/templates/dropdown_button", "ui/vandy_lib/dropdown_option"}
--local mct_slider_template = "ui/templates/panel_slider_horizontal"

--- For internal use only. Called by @{mct_mod:add_new_option}.
function mct_option.new(mod, option_key, type)
    local self = {}
    setmetatable(self, {
        __index = mct_option,
        __tostring = function() return "MCT_OPTION" end
    })

    self._mod = mod
    self._key = option_key
    self._type = type or "NULL_TYPE"
    --self._text = text or ""
    --self._tooltip_text = tooltip_text or ""
    self._values = {}

    if type == "slider" then
        values = {
            min = 0,
            max = 100,
            step_size = 1,
            step_size_precision = 0,
            precision = 0,
        }
    end

    -- assigned section, used for UI, defaults to the last created section unless one is specified
    self._assigned_section = mod:get_last_section():get_key()

    -- add the option to the mct_section
    self._mod:get_section_by_key(self._assigned_section):assign_option(self)

    -- a callback triggered whenever the setting is changed within the UI
    self._option_set_callback = nil

    -- selected setting is the UI state and the default value; finalized setting is the saved setting in the file/etc
    self._selected_setting = nil
    self._finalized_setting = nil

    -- whether this option obj is read only for campaign
    self._read_only = false

    self._local_only = false
    self._mp_disabled = false

    -- the UICs linked to this option (the option + the txt)
    self._uics = {}

    -- UIC options for construction
    self._uic_visible = true
    self._uic_locked = false

    self._pos = {
        x = 0,
        y = 0
    }

    -- read the "type" field in the metatable's __templates field - ie., __templates[checkbox]
    self._template = self.__templates[type]
    
    --self._wrapped = wrapped

    return self
end

--- Read whether this mct_option is edited exclusively for the client, instead of passed between both PC's.
-- @treturn boolean local_only Whether this option is only edited on the local PC, instead of both.
function mct_option:get_local_only()
    return self._local_only
end

--- Set whether this mct_option is edited for just the local PC, or sent to both PC's.
-- For instance, this is useful for settings that don't edit the model, like enabling script logging.
-- @tparam boolean enabled True for local-only, false for passed-in-MP-and-only-editable-by-the-host.
function mct_option:set_local_only(enabled)
    if is_nil(enabled) then
        enabled = true
    end

    if not is_boolean(enabled) then
        mct:error("set_local_only() called for mct_mod ["..self:get_key().."], but the enabled argument passed is not a boolean or nil!")
        return false
    end

    self._local_only = enabled
end

--- Read whether this mct_option is available in multiplayer.
-- @treturn boolean mp_disabled Whether this mct_option is available in multiplayer or completely disabled.
function mct_option:get_mp_disabled()
    return self._mp_disabled
end

--- Set whether this mct_option exists for MP campaigns.
-- If set to true, this option is invisible for MP and completely untracked by MCT.
-- @tparam boolean enabled True for MP-disabled, false to MP-enabled
function mct_option:set_mp_disabled(enabled)
    if is_nil(enabled) then
        enabled = true
    end

    if not is_boolean(enabled) then
        mct:error("set_mp_disabled() called for mct_mod ["..self:get_key().."], but the enabled argument passed is not a boolean or nil!")
        return false
    end

    self._mp_disabled = enabled
end

--- Read whether this mct_option can be edited or not at the moment.
-- @treturn boolean read_only Whether this option is uneditable or not.
function mct_option:get_read_only()
    return self._read_only
end

--- Set whether this mct_option can be edited or not at the moment.
-- @tparam boolean enabled True for non-editable, false for editable.
function mct_option:set_read_only(enabled)
    if is_nil(enabled) then
        enabled = true
    end

    --enabled = enabled or true

    if not is_boolean(enabled) then
        -- issue
        return false
    end

    self._read_only = enabled
end

--- Assigns the section_key that this option is a member of.
-- Calls @{mct_section:assign_option} internally.
-- @tparam string section_key The key for the section this option is being added to.
function mct_option:set_assigned_section(section_key)
    local mod = self:get_mod()
    local section = mod:get_section_by_key(section_key)
    if not mct:is_mct_section(section) then
        mct:log("set_assigned_section() called for option ["..self:get_key().."] in mod ["..mod:get_key().."] but no section with the key ["..section_key.."] was found!")
        return false
    end

    section:assign_option(self) -- this sets the option's self._assigned_section
end

--- Reads the assigned_section for this option.
-- @treturn string section_key The key of the section this option is assigned to.
function mct_option:get_assigned_section()
    return self._assigned_section
end

--- Get the @{mct_mod} object housing this option.
-- @return @{mct_mod}
function mct_option:get_mod()
    return self._mod
end

--- Internal use only. Clears all the UIC objects attached to this boy.
-- @local
function mct_option:clear_uics(kill_selected)
    --self._selected_setting = nil
    self._uics = {}

    if kill_selected then
        self._selected_setting = nil
    end
end


--- Internal use only. Set UICs through the uic_obj
-- @local
function mct_option:set_uics(uic_obj)
    -- check if it's a table of UIC's
    if is_table(uic_obj) then
        for i = 1, #uic_obj do
            local uic = uic_obj[i]
            if is_uicomponent(uic) then
                self._uics[#self._uics+1] = uic
            end
        end
        return
    end

    -- check if it's just one UIC
    if not is_uicomponent(uic_obj) then
        mct:error("set_uics() called for mct_option with key ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the uic_obj supplied was neither a UIC or a table of UICs! Returning false.")
        return false
    end

    self._uics[#self._uics+1] = uic_obj
end

--- Internal use only. Grab a UIC by a key
-- @local
function mct_option:get_uic_with_key(key)
    if self._uics == nil or self._uics == {} or self._uics[1] == nil then
        mct:error("get_uic_with_key() called for mct_option with key ["..self:get_key().."] but no uics are found! Returning false.")
        return false
    end

    local uic_table = self._uics
    
    for i = 1, #uic_table do
        local uic = uic_table[i]
        if is_uicomponent(uic) then
            if uic:Id() == key then
                return uic
            end
        end
    end

    return false
end

--- Internal use only. Get all UICs.
-- @local
function mct_option:get_uics()
    local uic_table = self._uics
    local copy = {}

    -- first, loop through the table of UICs to make sure they're all still valid; if any are, add them to a copy table
    for i = 1, #uic_table do
        local uic = uic_table[i]
        if is_uicomponent(uic) then
            copy[#copy+1] = uic
        end
    end

    self._uics = copy
    return self._uics
end

--- Set a UIC as visible or invisible, dynamically. If the UIC isn't created yet, it will get the applied setting when it is created.
-- @tparam boolean enable True for visible, false for invisible.
-- @within API
function mct_option:set_uic_visibility(enable)
    -- default to true if a param isn't provided
    if is_nil(enable) then
        enable = true
    end

    if not is_boolean(enable) then
        mct:log("set_uic_visibility() called for option ["..self._key.."], but the argument provided is not a boolean. Returning false!")
        return false
    end

    self._uic_visible = enable

    -- if the UIC exists, set it to the new visibility!
    local uic_table = self:get_uics()
    --mct:log("DOING THIS")
    for i = 1, #uic_table do
        local uic = uic_table[i]
        if is_uicomponent(uic) then
            --mct:log("Setting component to the thing! ["..tostring(self:get_uic_visibility()).."].")
            mct.ui:uic_SetVisible(uic, self:get_uic_visibility())
        end
    end
end

--- Get the current visibility for this mct_option.
-- @treturn boolean visibility True for visible, false for invisible.
-- @within API
function mct_option:get_uic_visibility()
    return self._uic_visible
end

--- Create a callback triggered whenever this option's setting changes within the MCT UI.
-- The function will automatically be passed the mct_option, so you can read the new setting and apply whatever changes are needed.
-- ex:
-- when the "enable" button is checked on or off, all other options are set visible or invisible
-- enable:add_option_set_callback(
--    function(option) 
--        local val = option:get_selected_setting()
--        local options = options_list
--
--        for i = 1, #options do
--            local i_option_key = options[i]
--            local i_option = option:get_mod():get_option_by_key(i_option_key)
--            i_option:set_uic_visibility(val)
--        end
--    end
--)
-- @tparam function callback The callback triggered whenever this option is changed. Callback will be passed one argument - the mct_option.
-- @within API
function mct_option:add_option_set_callback(callback)
    if not is_function(callback) then
        mct:error("Trying `add_option_set_callback()` on option ["..self._key.."], but the supplied callback is not a function. Returning false.")
        return false
    end

    --mct:log("TESTING saving callback on option ["..self._key.."].")

    self._option_set_callback = callback
end

--- Internal use only. Process the callback on option change.
-- @local
function mct_option:process_callback()
    -- ONLY TRIGGER THIS IF A CALLBACK HAS BEEN SET?!?!?!?
    local cb = self._option_set_callback
    if is_function(cb) then
        --mct:log("TESTING calling callback on option ["..self._key.."].")
        --local ok, err = pcall(function() cb(self) end)
        --if not ok then mct:error(err) end
        cb(self)

        --core:trigger_custom_event("MctOptionCallback", {self, "option"}, {})
    end
end

--- Manually set the x/y position for this option, within its section.
-- @warning Use with caution, this needs an overhaul in the future!
-- @tparam number x x-coord
-- @tparam number y y-coord
-- @within API
function mct_option:override_position(x,y)
    if not is_number(x) or not is_number(y) then
        mct:error("override_position() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the x/y coordinates supplied are not numbers! Returning false")
        return false
    end

    -- set internal pos
    self._pos = {x=x,y=y}

    -- set coords defined in the mod obj
    local mod = self._mod
    local index = tostring(x)..","..tostring(y)
    mod._coords[index] = self._key
end

--- Get the x/y coordinates of the mct_option
-- Returns two vals, comma delimited (ie. local x,y = option:get_position())
-- @treturn number x x-coord
-- @treturn number y y-coord
-- @local
function mct_option:get_position()
    return self._pos.x, self._pos.y
end

--- Internal checker to see if the values passed through mct_option methods are valid.
-- @tparam any val Value being tested for type.
function mct_option:is_val_valid_for_type(val)
    local type = self:get_type()
    if type == "slider" then
        if not is_number(val) then
            return false
        end
        -- TODO check if the number is valid in the slider's number range
    elseif type == "checkbox" then
        if not is_boolean(val) then
            return false
        end
    elseif type == "dropdown" then
        if not is_string(val) then
            return false
        end
        -- TODO check if the dropdown value has been assigned as a value already
        --[[if not valid then
            return false
        end]]
    end

    return true
end

--- Getter for the "finalized_setting" for this `mct_option`.
-- @treturn any finalized_setting Finalized setting for this `mct_option` - either the default value set, or the latest saved value if in a campaign, or the latest settings-value if in a new campaign or in frontend.
-- @within API
function mct_option:get_finalized_setting()
    local test = self._finalized_setting
    if is_nil(test) then
        local further_test = self._selected_setting
        if is_nil(further_test) then
            mct:log("get_finalized_setting() called, but there is no finalized or selected setting picked for this option ["..self:get_key().."]. This should never happen!")
            return
        end
        --mct:log("returning as finalized default value ["..tostring(further_test).."] for option ["..self:get_key().."]")
        self._finalized_setting = further_test
        return further_test
    end
    --mct:log("returning finalized value ["..tostring(test).."] for option ["..self:get_key().."]")
    return test
end

--- Internal use only.
-- @todo this sucks!
-- @tparam any val Set the finalized setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
-- @local
function mct_option:set_finalized_setting_event_free(val)
    if self:is_val_valid_for_type(val) then
        -- ignore read-only since this is only used for save/load
        --[[if self:get_read_only() then
            -- can't change finalized setting for read onlys! Error!
            mct:error("set_finalized_setting_event_free() called for mct_option ["..self:get_key().."], but the option is read only! This REALLY shouldn't happen, investigate.")
            return false
        end]]

        self._finalized_setting = val
        self._selected_setting = val
    end
end

--- Internal use only. Sets the finalized setting and triggers the event "MctOptionSettingFinalized".
-- @tparam any val Set the finalized setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
-- @local
function mct_option:set_finalized_setting(val)
    if self:is_val_valid_for_type(val) then
        if self:get_read_only() and __game_mode == __lib_type_campaign then
            -- can't change finalized setting for read onlys! Error!
            mct:error("set_finalized_setting() called for mct_option ["..self:get_key().."], but the option is read only! This REALLY shouldn't happen, investigate.")
            return false
        end

        self._finalized_setting = val

        -- trigger an event to listen for externally
        core:trigger_custom_event("MctOptionSettingFinalized", {mct = mct, mod = self:get_mod(), option = self, setting = val})
    end
end

--- Set the default selected setting when the mct_mod is first created and loaded.
-- @tparam any val Set the default setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
-- @within API
function mct_option:set_default_value(val)
    if self:is_val_valid_for_type(val) then
        self._selected_setting = val
    end
end

--- Triggered via the UI object. Change the mct_option's selected value, and trigger the callback set through @{mct_option:add_option_set_callback}.
-- @tparam any val Set the selected setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
-- @tparam boolean event_free True to skip the process_callback.
-- @local
function mct_option:set_selected_setting(val, event_free)
    if self:is_val_valid_for_type(val) then
        -- save the val as the currently selected setting, used for UI and finalization
        self._selected_setting = val

        if not event_free then
            -- run the callback, passing the mct_option along as an arg
            self:process_callback()
        end
    end
end

--- internal function that calls the operation to change an option's selected value. Exposed here so it can be called through presets and the like.
-- @todo This function only works for dropdowns and sliders so far - has to be set up for each type!
-- @tparam any val Set the selected setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
function mct_option:ui_select_value(val)
    if not self:is_val_valid_for_type(val) then
        mct:error("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
        return false
    end

    --[[
        local uic = UIComponent(context.component)
        local popup_list = UIComponent(uic:Parent())
        local popup_menu = UIComponent(popup_list:Parent())
        local dropdown_box = UIComponent(popup_menu:Parent())

        -- will tell us the name of the option
        local parent_id = UIComponent(dropdown_box:Parent()):Id()
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)
    ]]

    -- trigger separate functions for the types!

    if self:get_type() == "slider" then
        local function round_num(num, numDecimalPlaces)
            local mult = 10^(numDecimalPlaces or 0)
            if num >= 0 then
                return math.floor(num * mult + 0.5) / mult
            else
                return math.ceil(num * mult - 0.5) / mult
            end
        end
    
        local function round(num, places, is_num)
            if is_num then
                return round_num(num, places)
            end
    
            return string.format("%."..(places or 0) .. "f", num)
        end

        mct:log("ui select val for slider")
        mct:log("new val is "..val)

        local option_uic = self:get_uics()[1]

        local right_button = find_uicomponent(option_uic, "right_button")
        local left_button = find_uicomponent(option_uic, "left_button")
        local text_input = find_uicomponent(option_uic, "text_input")

        mct:log("ui select val for slider 2")

        local values = self:get_values()
        local max = values.max
        local min = values.min
        local precision = values.precision

        mct:log("ui select val for slider 3")

        -- enable both buttons & push new value
        right_button:SetState("active")
        left_button:SetState("active")

        if val >= max then
            right_button:SetState("inactive")
            left_button:SetState("active")

            val = max
        elseif val <= min then
            left_button:SetState("inactive")
            right_button:SetState("active")

            val = min
        end

        local new_num = round(val, precision, true)
        --local new_str = round(val, precision, false)

        self:set_selected_setting(new_num)

        local current = self:get_selected_setting()
        current = round(current, precision, true)

        mct:log("ui select val for slider 4")

        local current_str = round(current, precision, false)

        text_input:SetStateText(tostring(current_str))

        if current ~= self:get_finalized_setting() then
            mct.ui.locally_edited = true
        end
    end

    if self:get_type() == "dropdown" then
        -- grab the current setting, so we can deselect that UIC
        local current_val = self:get_selected_setting()
        
        -- grab necessary UIC's
        local dropdown_box_uic = self:get_uic_with_key("mct_dropdown_box")
        if not is_uicomponent(dropdown_box_uic) then
            mct:error("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no dropdown_box_uic was found internally. Aborting!")
            return false
        end

        -- ditto
        local popup_menu = UIComponent(dropdown_box_uic:Find("popup_menu"))
        local popup_list = UIComponent(popup_menu:Find("popup_list"))
        local currently_selected_uic = find_uicomponent(popup_list, current_val)
        local new_selected_uic = find_uicomponent(popup_list, val)


        -- unselected the currently-selected dropdown option
        if is_uicomponent(currently_selected_uic) then
            mct.ui:uic_SetState(currently_selected_uic, "unselected")
        else
            mct:error("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no currently_selected_uic with key ["..tostring(current_val).."] was found internally. Aborting!")
            return false
        end

        -- set the new option as "selected", so it's highlighted in the list; also lock it as the selected setting in the option_obj
        mct.ui:uic_SetState(new_selected_uic, "selected")
        self:set_selected_setting(val)

        -- set the UI obj's "locally_edited" field as true so the close button will know!
        mct.ui.locally_edited = true

        -- set the state text of the dropdown box to be the state text of the row
        local t = find_uicomponent(new_selected_uic, "row_tx"):GetStateText()
        local tt = find_uicomponent(new_selected_uic, "row_tx"):GetTooltipText()
        local tx = find_uicomponent(dropdown_box_uic, "dy_selected_txt")

        mct.ui:uic_SetStateText(tx, t)
        mct.ui:uic_SetTooltipText(dropdown_box_uic, tt, true)

        -- set the menu invisible and unclick the box
        if dropdown_box_uic:CurrentState() == "selected" then
            mct.ui:uic_SetState(dropdown_box_uic, "active")
        end

        popup_menu:SetVisible(false)
        popup_menu:RemoveTopMost()
    end
end

function mct_option:get_uic_locked()
    return self._uic_locked
end

--- Set this option as disabled in the UI, so the user can't interact with it.
-- This will result in `mct_option:ui_change_state()` being called later on.
-- @tparam boolean should_lock Lock this UI option, preventing it from being interacted with.
function mct_option:set_uic_locked(should_lock)
    if is_nil(should_lock) then 
        should_lock = true 
    end

    if not is_boolean(should_lock) then 
        mct:error("set_uic_locked() called for mct_option with key ["..self:get_key().."], but the should_lock argument passed is not a boolean or nil!")
        return false 
    end

    self._uic_locked = should_lock

    -- if the option already exists in UI, update its state
    if is_uicomponent(self:get_uics()[1]) then
        self:ui_change_state()
    end
end

--- Internal function to set the option UIC as disabled or enabled, for read-only/mp-disabled.
-- Use `mct_option:set_uic_locked()` for the external version of this.
-- @see mct_option:set_uic_locked
function mct_option:ui_change_state()
    local type = self:get_type()
    local option_uic = self:get_uics()[1]

    local locked = self:get_uic_locked()
    
    -- TODO lock the text input!
    if type == "slider" then
        local left_button = find_uicomponent(option_uic, "left_button")
        local right_button = find_uicomponent(option_uic, "right_button")
        --local text_input = find_uicomponent(option_uic, "text_input")

        local state = "active"
        if locked then
            state = "inactive"
        end

        --mct.ui:uic_SetInteractive(text_input, not locked)
        mct.ui:uic_SetState(left_button, state)
        mct.ui:uic_SetState(right_button, state)
    end

    if type == "checkbox" then
        local value = self:get_finalized_setting()

        local state = "active"

        if locked then
            -- disable the checkbox, set it as checked if the finalized setting is true
            if value == true then
                state = "selected_inactive"
            else
                state = "inactive"
            end
        else
            if value == true then
                state = "selected"
            else
                state = "active"
            end
        end

        mct.ui:uic_SetState(option_uic, state)
    end

    if type == "dropdown" then
        -- disable the dropdown box
        local state = "active"
        if locked then
            state = "inactive"
        end

        mct.ui:uic_SetState(option_uic, state)
    end
end

--- Getter for the current selected setting. This is the default_value if nothing has been selected yet in the UI.
-- Used when finalizing settings.
-- @treturn any val The value set as the selected_setting for this mct_option.
-- @within API
function mct_option:get_selected_setting()
    if self._selected_setting == nil then
        -- this should default to the default value, or the finalized setting if there is one
        self._selected_setting = self._finalized_setting
    end

    --mct:log("["..self._key.."], selected setting iiiiis: "..tostring(self._selected_setting))

    --mct:log(tostring(self._selected_setting))
    return self._selected_setting
end

--- Set function to set the step size for moving left/right through the slider.
-- Works with floats and other numbers. Use the optional second argument if using floats/decimals
-- @tparam number step_size The number to jump when using the left/right button.
-- @tparam number step_size_precision The precision for the step size, to prevent weird number changing. If the step size is 0.2, for instance, the precision would be 1, for one-decimal-place.
function mct_option:slider_set_step_size(step_size, step_size_precision)
    if not self:get_type() == "slider" then
        mct:error("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end

    if not is_number(step_size) then
        mct:error("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the step size value supplied ["..tostring(step_size).."] is not a number! Returning false.")
        return false
    end

    if is_nil(step_size_precision) then
        step_size_precision = 0
    end

    if not is_number(step_size_precision) then
        mct:error("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the step size precision value supplied ["..tostring(step_size_precision).."] is not a number! Returning false.")
        return false
    end

    self._values.step_size = step_size
    self._values.step_size_precision = step_size_precision
end

--- Setter for the precision on the slider's displayed value. Necessary when working with decimal numbers.
-- The number should be how many decimal places you want, ie. if you are using one decimal place, send 1 to this function; if you are using none, send 0.
-- @tparam number precision The precision used for floats.
function mct_option:slider_set_precision(precision)
    if not self:get_type() == "slider" then
        mct:error("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end

    if not is_number(precision) then
        mct:error("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the min value supplied ["..tostring(precision).."] is not a number! Returning false.")
        return false
    end

    self._values.precision = precision
end

--- Setter for the minimum and maximum values for the slider.
-- @tparam number min The minimum number the slider value can reach.
-- @tparam number max The maximum number the slider value can reach.
-- @within API
function mct_option:slider_set_min_max(min, max)
    if not self:get_type() == "slider" then
        mct:error("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end

    if not is_number(min) then
        mct:error("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the min value supplied ["..tostring(min).."] is not a number! Returning false.")
        return false
    end

    if not is_number(max) then
        mct:error("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the max value supplied ["..tostring(max).."] is not a number! Returning false.")
        return false
    end

    --[[if not is_number(current) then
        mct:error("slider_set_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the current value supplied ["..tostring(current).."] is not a number! Returning false.")
        return false
    end]]

    self._values.min = min
    self._values.max = max

    --self:set_default_value(current)
end

--- Method to set the `dropdown_values`. This function takes a table of tables, where the inner tables have the fields ["key"], ["text"], ["tt"], and ["is_default"]. The latter three are optional.
-- ex:
--      mct_option:add_dropdown_values({
--          {key = "example1", text = "Example Dropdown Value", tt = "My dropdown value does this!", is_default = true},
--          {key = "example2", text = "Lame Dropdown Value", tt = "This dropdown value does another thing!", is_default = false},
--      })
-- @within API
function mct_option:add_dropdown_values(dropdown_table)
    if not self:get_type() == "dropdown" then
        mct:error("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a dropdown! Returning false.")
        return false
    end

    if not is_table(dropdown_table) then
        mct:error("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the dropdown_table supplied is not a table! Returning false.")
        return false
    end

    if is_nil(dropdown_table[1]) then
        mct:error("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the dropdown_table supplied is an empty table! Returning false.")
        return false
    end

    for i = 1, #dropdown_table do
        local dropdown_option = dropdown_table[i]
        local key = dropdown_option.key
        local text = dropdown_option.text or ""
        local tt = dropdown_option.tt or ""
        local is_default = dropdown_option.default or false

        self:add_dropdown_value(key, text, tt, is_default)
    end
end

--- Used to create a single dropdown_value; also called within @{mct_option:add_dropdown_values}
-- @tparam string key The unique identifier for this dropdown value.
-- @tparam string text The localised text for this dropdown value.
-- @tparam string tt The localised tooltip for this dropdown value.
-- @tparam boolean is_default Whether or not to set this dropdown_value as the default one, when the dropdown box is created.
function mct_option:add_dropdown_value(key, text, tt, is_default)
    if not self:get_type() == "dropdown" then
        mct:error("add_dropdown_value() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a dropdown! Returning false.")
        return false
    end

    if not is_string(key) then
        mct:error("add_dropdown_value() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the key supplied is not a string! Returning false.")
        return false
    end

    text = text or ""
    tt = tt or ""

    local val = {
        key = key,
        text = text,
        tt = tt
    }

    self._values[#self._values+1] = val

    -- check if it's the first value being assigned to the dropdown, to give at least one default value
    if #self._values == 1 then
        self:set_default_value(key)
    end

    if is_default then
        self:set_default_value(key)
    end
end

--- Getter for the available values for this mct_option - true/false for checkboxes, different stuff for sliders/dropdowns/etc.
-- @local
function mct_option:get_values()
    return self._values
end

--- Getter for this mct_option's type; slider, dropdown, checkbox
-- @local
function mct_option:get_type()
    return self._type
end

--- Getter for this option's UIC template for quick reference.
-- @local
function mct_option:get_uic_template()
    return self._template
end

--- Getter for this option's key.
-- @within API
-- @treturn string key mct_option's unique identifier
function mct_option:get_key()
    return self._key
end

--- Setter for this option's text, which displays next to the dropdown box/checkbox.
-- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_text`.
-- @tparam string text The text string for this option. You can either supply hard text - ie., "My Cool Option" - or a loc key - ie., "`ui_text_replacements_my_cool_option`".
-- @tparam boolean is_localised True if a loc key was supplied for the text parameter.
function mct_option:set_text(text, is_localised)
    if not is_string(text) then
        mct:error("set_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")
        return false
    end

    is_localised = is_localised or false

    self._text = {text, is_localised}
end

--- Setter for this option's tooltip, which displays when hovering over the option or the text.
-- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_tooltip`.
-- @tparam string text The tootlip string for this option. You can either supply hard text - ie., "My Cool Option's Tooltip" - or a loc key - ie., "`ui_text_replacements_my_cool_option_tt`".
-- @tparam boolean is_localised True if a loc key was supplied for the text parameter.
function mct_option:set_tooltip_text(text, is_localised)
    if not is_string(text) then
        mct:error("set_tooltip_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the tooltip_text supplied is not a string! Returning false.")
        return false
    end

    is_localised = is_localised or false 

    self._tooltip_text = {text, is_localised}
end

--- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_text`, before seeing if any was supplied through @{mct_option:set_text}.
function mct_option:get_text()
    -- default to checking the loc files
    local text = effect.get_localised_string("mct_"..self:get_mod():get_key().."_"..self:get_key().."_text")
    if text ~= "" then
        return text
    end
    -- nothing found, check for anything supplied by `set_text()`, or send the default "No text assigned"
    text = self._text
    if is_table(text) then
        if text[2] == true then
            local test = effect.get_localised_string(text[1])
            if test ~= "" then
                text = test
            end
        else
            text = text[1]
        end
    end
    
    return text
end

--- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_tooltip`, before seeing if any was supplied through @{mct_option:set_tooltip_text}.
function mct_option:get_tooltip_text()
    local text = effect.get_localised_string("mct_"..self._mod:get_key().."_"..self:get_key().."_tooltip")
    if text ~= "" then
        return text
    end

    -- nothing found, check for anything supplied by `set_tooltip()`, or send the default "No tooltip assigned"
    text = self._tooltip_text
    if is_table(text) then
        if text[2] then
            local test = effect.get_localised_string(text[1])
            if test ~= "" then
                text = test
            end
        else
            text = text[1]
        end
    end

    return text
end

return mct_option
