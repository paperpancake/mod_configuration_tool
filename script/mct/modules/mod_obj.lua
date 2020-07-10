--- MCT Mod Object
-- @classmod mct_mod

local mct = mct

-- TODO make "Finalize settings" validate all MCT options; if some are invalid, give some UX notifs that they're not valid. esp. for the textboxes.

-- TODO this can be done cleaner. Read all option obj types?
mct._valid_option_types = {
    slider = true,
    dropdown = true,
    checkbox = true,
    textbox = false,
}

local mct_mod = {
    --_name = "",
    --_options = {},

    _valid_option_types = mct._valid_option_types
}

--- For internal use, called by the MCT Manager.
-- @tparam string key The identifying key for this mod object.
-- @see mct:register_mod
function mct_mod.new(key)
    local self = {}
    setmetatable(self, {
        __index = mct_mod,
        __tostring = function() return "MCT_MOD" end
    })

    self._key = key
    self._options = {}
    self._options_by_type = {
        dropdown = {},
        checkbox = {},
        slider = {},
        textbox = {}
    }
    self._coords = {
        --["1,2"] = option_key,
        --["3,5"] = option_key
        -- etcetc
    } -- positions for all the options, individual tables ordered numerically by top left -> top right -> down

    self._finalized_settings = {
        -- ["option_key"] = value,
        -- etc
    } -- read from the mct_settings.lua file

    -- start with the default section, if none are specified this is what's used
    self._sections = {
        {key = "default", txt = "Default Category"},
    }

    self._title = "No Title Assigned"
    self._author = "No Author Assigned"
    self._description = "No Description Assigned"
    --self._workshop_link = ""


    return self
end

--- Add a new section to the mod's settings view, to separate them into several categories.
-- When this function is called, it assumes all following options being defined are being assigned to this section, unless further specified with
-- mct_option.
-- @tparam string section_key The unique identifier for this section.
-- @tparam string localised_name The localised text for this section. You can provide a direct string - "My Section Name" - or a loc key - "`loc_key_example_my_section_name`". If a loc key is provided, it will check first at runtime to see if that localised text exists. If no localised_name is provided, it will default to "No Text Assigned"
function mct_mod:add_new_section(section_key, localised_name)
    if not is_string(section_key) then
        mct:error("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the section_key supplied was not a string! Returning false.")
        return false
    end

    local table = {
        key = section_key,
        txt = localised_name
    }

    -- put the section key at the bottom of the sections list - used to find the last-made section, which is what new options will default to
    self._sections[#self._sections+1] = table
end

--- Returns a k/v table of {option_key=option_obj} for options that are linked to this section.
-- Shouldn't need to be used externally.
-- @tparam string section_key The unique identifier for this section.
function mct_mod:get_options_by_section(section_key)
    local options = self:get_options()
    local retval = {}
    for option_key, option_obj in pairs(options) do
        if option_obj:get_assigned_section() == section_key then
            retval[option_key] = option_obj
        end
    end

    return retval
    --return self._options_by_section[section_key]
end

--- Returns a table of all "sections" within the mct_mod.
-- These are returned as an array of tables, and each table has two indexes - ["key"] and ["txt"], for internal key and localised name, in that order.
function mct_mod:get_sections()
    return self._sections
end

--- Return a specific section within the mct_mod.
-- This is returned as a single table, with two indexes - ["key"] and ["txt"], for internal key and localised name, in that order.
-- @tparam string section_key The unique identifier for the desired section.
function mct_mod:get_section_by_key(section_key)
    local sections = self:get_sections()
    for i = 1, #sections do
        local section = sections[i]
        if section.key == section_key then
            return section
        end
    end

    return nil
end

-- TODO turn sections into Lua objects!
-- TODO change the below ui method to also change the section header state

--- Set the rows of a section visible or invisible.
-- @tparam string section_key The unique identifier for the desired section.
-- @tparam boolean visible Set the rows visible (true) or invisible (false)
function mct_mod:set_section_visibility(section_key, visible)
    local section = self:get_section_by_key(section_key)
    if is_nil(section) then
        mct:error("set_section_visibility() called for mct_mod ["..self:get_key().."] for section with key ["..section_key.."], but no section with that key exists!")
        return false
    end

    self.ui:section_visibility_change(section_key, visible)
end

--- Internal use only, no real need for use anywhere else.
-- Specifically used when creating new options, to find the last-made section.
-- @local
function mct_mod:get_last_section()
    -- return the last index in the _sections table
    return self._sections[#self._sections] or ""
end

--- Getter for the mct_mod's key
-- @treturn string key The key for this mct_mod
function mct_mod:get_key()
    return self._key
end

--- The finalize function is used for all actions needed to be performmed when the `mct_mod` is done being created, like setting positions for all options.
-- Triggered once the file which housed this `mod_obj` is done loading
-- @local
function mct_mod:finalize()
    -- disable mp-disabled options in mp
    if __game_mode == __lib_type_campaign and cm.game_interface:model():is_multiplayer() then
        local options = self:get_options()

        for key, option_obj in pairs(options) do
            if option_obj:get_mp_disabled() == true then
                -- literally just remove it
                self._options[key] = nil
            end
        end
    end

    self:set_positions_for_options()
end

--- Loops through all sections, and checks all options within each section, to save the x/y coordinates of each option.
-- Order the options by key within each section, giving sliders a full row to their own self
-- @local
function mct_mod:set_positions_for_options()
    local sections = self:get_sections()

    mct:log("setting positions for options in mod ["..self:get_key().."]")
    
    for i = 1, #sections do
        local section_key = sections[i].key
        local attached_options = self:get_options_by_section(section_key)

        mct:log("in section ["..section_key.."].")

        --local total = 0
        --local option_keys = {}

        local ordered_option_keys = {}

        for key,_ in pairs(attached_options) do
            -- disable options in MP if they're, well, mp-disabled
            --local option_obj = self:get_option_by_key(key)
            --if __game_mode == __lib_type_campaign and (cm:is_multiplayer() and option_obj:get_mp_disabled()) then
                -- do nothing
            --else
            --mct:log("option with key ["..key.."] detected in section.")
                table.insert(ordered_option_keys, key)
            --total = total + 1
            --option_keys[#option_keys+1] = key
           -- end
        end

        table.sort(ordered_option_keys)

        local total = #ordered_option_keys

        mct:log("total num = " .. tostring(total))

        --local num_remaining = total

        local x = 1
        local y = 1

        -- only put sliders on x == 2

        local valid = true
        local j = 1
        local any_added_on_current_row = false
        local slider_added_on_current_row = false

        -- TODO disabled for now with the new sliders
        local function valid_for_type(type, x,y)
            -- hard check for sliders, must be in center and can't have any other options on the same row
            --[[if type == "slider" then
                if x == 2 and not any_added_on_current_row then return true end
                return false
            end

            -- only sliders!
            if slider_added_on_current_row then
                return false
            end]]
            
            -- everything else is fine (for now!!!!!!)
            return true
        end

        local function iterate(added)
            if x == 3 then
                x = 1
                y = y + 1

                -- new row, set to false
                any_added_on_current_row = false
                slider_added_on_current_row = false
            else
                x = x + 1

                -- same row
                if added then
                    any_added_on_current_row = true
                end
            end
            if added then j = j + 1 end
        end

        while valid do
            if j > total then
                break
            end

            local option_key = ordered_option_keys[j]
            local option_obj = self:get_option_by_key(option_key)

            if mct:is_mct_option(option_obj) then                
                -- check if it's a valid position for that option's type (sliders only on 2)
                if valid_for_type(option_obj:get_type(), x, y) then
                    if option_obj:get_type() == "slider" then slider_added_on_current_row = true end
                    mct:log("setting pos for ["..option_key.."] at ("..tostring(x)..", "..tostring(y)..").")
                    option_obj:override_position(x,y)

                    iterate(true)

                    --j = j + 1
                else
                    -- if the current one is invalid, we should check the next few options to see if any are valid.
                    local done = false
                    --[[for k = 1, 2 do
                        if not done then
                            local next_option_key = ordered_option_keys[j+k]
                            local next_option_obj = self:get_option_by_key(next_option_key)
                            if mct:is_mct_option(next_option_obj) then
                                if valid_for_type(next_option_obj:get_type(), x, y) then
                                    if next_option_obj:get_type() == "slider" then slider_added_on_current_row = true end
                                    mct:log("setting pos for ["..next_option_key.."] at ("..tostring(x)..", "..tostring(y)..").")
                                    next_option_obj:override_position(x,y)

                                    done = true

                                    -- swap the positions of the last two keys
                                    ordered_option_keys[j] = next_option_key
                                    ordered_option_keys[j+k] = option_key
                                    --j = j + 1

                                    --break
                                end
                            end
                        end
                    end]]

                    iterate(done)
                end
            end
        end
    end
end

--- Used when loading the mct_settings.lua file.
-- @local
function mct_mod:load_finalized_settings()
    local options = self:get_options()

    local ret = {}
    for key, option in pairs(options) do
        ret[key] = {}
        ret[key] = option:get_finalized_setting()
    end

    self._finalized_settings = ret

    --return ret
end

--- Used when finalizing the settings in MCT.
-- @local
function mct_mod:finalize_settings()
    local options = self:get_options()

    local ret = {}
    for key, option in pairs(options) do
        ret[key] = {}

        -- only trigger the option-changed event if it's actually changing setting
        local selected = option:get_selected_setting()
        if option:get_finalized_setting() ~= selected then
            option:set_finalized_setting(selected)
        end

        ret[key] = option:get_finalized_setting()
    end

    self._finalized_settings = ret

    return ret
end

--- Returns the `finalized_settings` field of this `mct_mod`.
function mct_mod:get_settings()
    --[[local options = self:get_options()
    local retval = {}

    for key, option in pairs(options) do
        retval[key] = option:get_finalized_setting()
    end]]

    return self._finalized_settings
end

-- Unused
--[[
function mct_mod:get_last_coord()
    local coords = self._coords
    local last_coord = coords[#coords]
    if last_coord then
        return #coords, last_coord.x, last_coord.y
    end
end
]]

-- Unused
--[[
function mct_mod:get_option_key_for_coords(x,y)
    if not is_number(x) or not is_number(y) then
        mct:error("get_option_key_for_coords() called for mct_mod with key ["..self:get_key().."], but the x/y coordinates supplied are not numbers! Returning false.")
        return false
    end

    local index = tostring(x) .. "," .. tostring(y)
    local object_key = self._coords[index]
    return object_key or "NONE"
end
]]

--- Enable localisation for this mod's title. Accepts either finalized text, or a localisation key.
-- @tparam string title_text The text supplied for the title. You can supply the text - ie., "My Mod", or a loc-key, ie. "ui_text_replacements_my_dope_mod". Please note you can also skip this method, and just make a loc key called: `mct_[mct_mod_key]_title`, and MCT will automatically read that.
-- @tparam boolean is_localised True if the title_text supplied is a loc key.
function mct_mod:set_title(title_text, is_localised)
    if is_string(title_text) then

        self._title = {
            text = title_text, 
            is_localised = is_localised
        }
    end
end

--- Set the Author text for this mod.
-- @tparam string author_text The text supplied for the author. Doesn't accept loc-keys. Please note you can skip this method, and just make a loc key called: `mct_[mct_mod_key]_author`, and MCT will automatically read that.
function mct_mod:set_author(author_text)
    if is_string(author_text) then

        self._author = author_text
    end
end

--- Enable localisation for this mod's description. Accepts either finalized text, or a localisation key.
-- @tparam string desc_text The text supplied for the description. You can supply the text - ie., "My Mod's Description", or a loc-key, ie. "ui_text_replacements_my_dope_mod_description". Please note you can also skip this method, and just make a loc key called: `mct_[mct_mod_key]_description`, and MCT will automatically read that.
-- @tparam boolean is_localised True if the desc_text supplied is a loc key.
function mct_mod:set_description(desc_text, is_localised)
    if is_string(desc_text) then

        self._description = {
            text = desc_text, 
            is_localised = is_localised
        }
    end
end

--[[function mct_mod:set_workshop_link(link_text)
    if is_string(link_text) then
        self._workshop_link = link_text
    end
end]]

--- Grabs the title text. First checks for a loc-key `mct_[mct_mod_key]_title`, then checks to see if anything was set using @{mct_mod:set_title}. If not, "No title assigned" is returned.
-- @treturn string title_text The returned string for this mct_mod's title.
function mct_mod:get_title()
    -- check if a title exists in the localised texts!
    local title = effect.get_localised_string("mct_"..self:get_key().."_title")
    if title ~= "" then
        return title
    end

    title = self._title
    if title.is_localised then
        local test = effect.get_localised_string(title.text)
        if test ~= "" then
            return test
        end
    end

    return self._title.text or "No title assigned"
end

--- Grabs the author text. First checks for a loc-key `mct_[mct_mod_key]_author`, then checks to see if anything was set using @{mct_mod:set_author}. If not, "No author assigned" is returned.
-- @treturn string author_text The returned string for this mct_mod's author.
function mct_mod:get_author()
    local author = effect.get_localised_string("mct_"..self:get_key().."_author")
    if author ~= "" then
        return author
    end

    --if author == "" then
        --return
    --end

    return self._author --or "No author assigned"
end

--- Grabs the description text. First checks for a loc-key `mct_[mct_mod_key]_description`, then checks to see if anything was set using @{mct_mod:set_description}. If not, "No description assigned" is returned.
-- @treturn string description_text The returned string for this mct_mod's description.
function mct_mod:get_description()
    local description = effect.get_localised_string("mct_"..self:get_key().."_description")
    if description ~= "" then
        return description
    end

    description = self._description
    if description.is_localised then
        local test = effect.get_localised_string(description.text)
        if test ~= "" then
            return test
        end
    end

    return self._description.text or "No description assigned"
end

--[[function mct_mod:get_workshop_link()
    return self._workshop_link
end]]

--- Returns all three localised texts - title, author, description.
-- @treturn string title_text The returned string for this mct_mod's title.
-- @treturn string author_text The returned string for this mct_mod's author.
-- @treturn string description_text The returned string for this mct_mod's description.
function mct_mod:get_localised_texts()
    return 
        self:get_title(),
        self:get_author(),
        self:get_description()
        --self:get_workshop_link()
end

--- Returns every @{mct_option} attached to this mct_mod.
function mct_mod:get_options()
    return self._options
end

--- Returns every @{mct_option} of a type.
-- @tparam string option_type The option_type to limit the search by.
function mct_mod:get_option_keys_by_type(option_type)
    if not is_string(option_type) then
        mct:error("Trying `get_option_keys_by_type` for mod ["..self:get_key().."], but type provided is not a string! Returning false.")
        return false
    end

    local valid_types = self._valid_option_types
    if not valid_types[option_type] then
        mct:error("Trying `get_option_keys_by_type` for mod ["..self:get_key().."], but type ["..option_type.."] is not a valid type! Returning false.")
        return false
    end

    return self._options_by_type[option_type]
end

--- Returns a @{mct_option} with the specific key on the mct_mod.
-- @tparam string option_key The unique identifier for the desired mct_option.
-- @return @{mct_option}
function mct_mod:get_option_by_key(option_key)
    if not is_string(option_key) then
        mct:error("Trying `get_option_by_key` for mod ["..self:get_key().."] but key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return false
    end

    return self._options[option_key]
end

--- Creates a new @{mct_option} with the specified key, of the desired type.
-- Use this! It calls an internal function, @{mct_option.new}, but wraps it with error checking and the like.
-- @tparam string option_key The unique identifier for the new mct_option.
-- @tparam string option_type The type for the new mct_option.
function mct_mod:add_new_option(option_key, option_type)
    -- check first to see if an option with this key already exists; if it does, return that one!

    mct:log("Adding option with key ["..option_key.."] to mod ["..self:get_key().."].")
    if not is_string(option_key) then
        mct:error("Trying `add_new_option()` for mod ["..self:get_key().."] but option key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return false
    end

    if not is_string(option_type) then
        mct:error("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a string! Returning false.")
        return false
    end

    local valid_types = self._valid_option_types

    if not valid_types[option_type] then
        mct:error("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a valid type! Returning false.")
        return false
    end

    local mod = self

    local new_option = mct._MCT_OPTION.new(mod, option_key, option_type)

    -- set a default value of unticked if it's a checkbox
    if option_type == "checkbox" then
        new_option:set_default_value(false)
    end

    self._options[option_key] = new_option
    self._options_by_type[option_type][#self._options_by_type[option_type]+1] = option_key

    --mct:log("Assigned section: " .. tostring(new_option:get_assigned_section()))

    return new_option
end

--- bloop
-- @local
function mct_mod:clear_uics_for_all_options()
    local opts = self:get_options()
    for _, option in pairs(opts) do
        option:clear_uics()
    end
end

return mct_mod