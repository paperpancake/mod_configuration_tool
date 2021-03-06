--- MCT UI Object. INTERNAL USE ONLY.
-- @classmod mct_ui

local mct = mct

local ui_obj = {
    -- UICs

    -- script dummy
    dummy = nil,

    -- full panel
    panel = nil,

    -- left side UICs
    mod_row_list_view = nil,
    mod_row_list_box = nil,

    -- right top UICs
    mod_details_panel = nil,

    -- right bottom UICs
    mod_settings_box = nil,

    -- currently selected mod UIC
    selected_mod_row = nil,

    -- var to read whether there have been any settings changed while the panel has been opened
    locally_edited = false,

    game_ui_created = false,

    ui_created_callbacks = {},
}

mct:mixin(ui_obj)

function ui_obj:delete_component(uic)
    if not is_uicomponent(self.dummy) then
        self.dummy = core:get_or_create_component("script_dummy", "ui/mct/script_dummy")
    end

    local dummy = self.dummy

    if is_uicomponent(uic) then
        dummy:Adopt(uic:Address())
    elseif is_table(uic) then
        for i = 1, #uic do
            local test = uic[i]
            if is_uicomponent(test) then
                dummy:Adopt(test:Address())
            else
                -- ERROR WOOPS
            end
        end
    end

    dummy:DestroyChildren()
end

function ui_obj:ui_created()
    self.game_ui_created = true

    for i = 1, #self.ui_created_callbacks do

        local f = self.ui_created_callbacks[i]
        f()
    end

end

function ui_obj:add_ui_created_callback(callback)

    if not is_function(callback) then
        mct:error("add_ui_created_callback() called, but the callback argument passed is not a function!")
        return false
    end

    self.ui_created_callbacks[#self.ui_created_callbacks+1] = callback
end

function ui_obj:create_popup(key, text, two_buttons, button_one_callback, button_two_callback)
    local function func()

        -- verify shit is alright
        if not is_string(key) then
            mct:error("create_popup() called, but the key passed is not a string!")
            return false
        end

        if not is_string(text) then
            mct:error("create_popup() called, but the text passed is not a string!")
            return false
        end

        if not is_boolean(two_buttons) then
            mct:error("create_popup() called, but the two_buttons arg passed is not a boolean!")
            return false
        end

        if not two_buttons then button_two_callback = nil end


        -- build the popup panel itself
        local popup = core:get_or_create_component(key, "ui/common ui/dialogue_box")

        -- grey out the rest of the world
        popup:RegisterTopMost()

        popup:LockPriority()


        -- grab and set the text
        local tx = find_uicomponent(popup, "DY_text")
        tx:SetStateText(text)

        core:add_listener(
            key.."_button_pressed",
            "ComponentLClickUp",
            function(context)
                local button = UIComponent(context.component)
                return (button:Id() == "button_tick" or button:Id() == "button_cancel") and UIComponent(UIComponent(button:Parent()):Parent()):Id() == key
            end,
            function(context)
                local button = UIComponent(context.component)
                local id = context.string

                -- close the popup
                ui_obj:delete_component(popup)

                if id == "button_tick" then
                    button_one_callback()
                else
                    button_two_callback()
                end
            end,
            false
        )
    end
    -- if the game UI hasn't been created, set this as a callback
    if not self.game_ui_created then
        self:add_ui_created_callback(func)
    else
        func()
    end
end


function ui_obj:set_selected_mod(row_uic)
    if is_uicomponent(row_uic) then
        mct:set_selected_mod(row_uic:Id())
        self.selected_mod_row = row_uic
    end
end

function ui_obj:get_selected_mod()
    return self.selected_mod_row
end

-- TODO steal escape in all game modes; seems difficult in frontend :(
function ui_obj:override_escape()
    local panel = self.panel

    -- frontend takes some hackiness :(
    if __game_mode == __lib_type_frontend then

        -- listen for the esc menu shortcut being pressed
        core:add_listener(
            "mct_esc_pressed",
            "ShortcutTriggered",
            function(context)
                return context.string == "escape_menu"
            end,
            function(context)

                -- trigger a listener on the next UI tick, to see if the escape menu has been opened
                real_timer.register_singleshot("next_tick", 0)
                core:add_listener(
                    "next_tick",
                    "RealTimeTrigger",
                    function(context)
                        return context.string == "next_tick"
                    end,
                    function(context)
                        -- find the quit menu
                        local esc_menu = find_uicomponent("quit_box")
                        if not is_uicomponent(esc_menu) then
                            ModLog("fuck")
                            return false
                        end
                        
                        -- press "cancel" to remove all the shits
                        local cancel_button = find_uicomponent(esc_menu, "both_group", "button_cancel")
                        cancel_button:SimulateLClick()

                        -- close the MCT panel
                        --- TODO make sure this doesn't trigger if there's invalid shit in the MCT, mebbeh do a popup?
                        self:close_frame()
                    end,
                    false
                )
            end,
            false
        )

        -- TODO finish this fuck
    else
        if __game_mode == __lib_type_campaign then

        elseif __game_mode == __lib_type_battle then

        end
    end
end

function ui_obj:open_frame()
    -- check if one exists already
    local test = self.panel

    self.locally_edited = false

    -- make a new one!
    if not is_uicomponent(test) then
        -- create the new window and set it visible
        local new_frame = core:get_or_create_component("mct_options", "ui/mct/mct_frame")
        new_frame:SetVisible(true)

        -- resize the panel
        new_frame:SetCanResizeWidth(true) new_frame:SetCanResizeHeight(true)
        new_frame:Resize(new_frame:Width() * 4, new_frame:Height() * 2.5)

        -- edit the name
        local title_plaque = find_uicomponent(new_frame, "title_plaque")
        local title = find_uicomponent(title_plaque, "title")
        title:SetStateText(effect.get_localised_string("mct_ui_settings_title"))

        -- hide stuff from the gfx window
        find_uicomponent(new_frame, "checkbox_windowed"):SetVisible(false)
        find_uicomponent(new_frame, "ok_cancel_buttongroup"):SetVisible(false)
        find_uicomponent(new_frame, "button_advanced_options"):SetVisible(false)
        find_uicomponent(new_frame, "button_recommended"):SetVisible(false)
        find_uicomponent(new_frame, "dropdown_resolution"):SetVisible(false)
        find_uicomponent(new_frame, "dropdown_quality"):SetVisible(false)

        self.panel = new_frame

        -- create the close button
        self:create_close_button()

        -- create the large panels (left, right top/right bottom)
        self:create_panels()

        -- create the MCT row first
        self:new_mod_row(mct:get_mod_by_key("mct_mod"))

        local ordered_mod_keys = {}
        for n in pairs(mct._registered_mods) do
            if n ~= "mct_mod" then
                table.insert(ordered_mod_keys, n)
            end
        end

        table.sort(ordered_mod_keys)

        for i,n in ipairs(ordered_mod_keys) do
            local mod_obj = mct:get_mod_by_key(n)
            self:new_mod_row(mod_obj)
        end

        -- TODO setup
        --self:override_escape()
    else
        test:SetVisible(true)
    end

    core:trigger_custom_event("MctPanelOpened", {["mct"] = mct, ["ui_obj"] = self})
end

function ui_obj:close_frame()
    local panel = self.panel
    if is_uicomponent(panel) then
        self:delete_component(panel)
    end

    --core:remove_listener("left_or_right_pressed")
    core:remove_listener("MctRowClicked")
    core:remove_listener("MCT_SectionHeaderPressed")

    -- clear saved vars
    self.panel = nil
    self.mod_row_list_view = nil
    self.mod_row_list_box = nil
    self.mod_details_panel = nil
    self.mod_settings_box = nil
    self.selected_mod_row = nil
    self.locally_edited = false

    -- clear uic's attached to mct_options
    local mods = mct:get_mods()
    for _, mod in pairs(mods) do
        --mod:clear_uics_for_all_options()
        mod:clear_uics(true)
    end
end

function ui_obj:create_close_button()
    local panel = self.panel
    
    local close_button_uic = core:get_or_create_component("button_mct_close", "ui/templates/round_medium_button", panel)
    local img_path = effect.get_skinned_image_path("icon_cross.png")
    close_button_uic:SetImagePath(img_path)
    close_button_uic:SetTooltipText("Close panel", true)

    -- bottom center
    close_button_uic:SetDockingPoint(8)
    close_button_uic:SetDockOffset(0, -5)
end

function ui_obj:create_panels()
    local panel = self.panel
    -- LEFT SIDE
    local img_path = effect.get_skinned_image_path("parchment_texture.png")

    -- create image background
    local left_panel_bg = core:get_or_create_component("left_panel_bg", "ui/vandy_lib/custom_image_tiled", panel)
    left_panel_bg:SetState("custom_state_2") -- 50/50/50/50 margins
    left_panel_bg:SetImagePath(img_path, 1) -- img attached to custom_state_2
    left_panel_bg:SetDockingPoint(4)
    left_panel_bg:SetDockOffset(20, 0)
    left_panel_bg:SetCanResizeWidth(true) left_panel_bg:SetCanResizeHeight(true)
    left_panel_bg:Resize(panel:Width() * 0.20, panel:Height() - 175)

    local w,h = left_panel_bg:Dimensions()

    -- create listview
    local left_panel_listview = core:get_or_create_component("left_panel_listview", "ui/vandy_lib/vlist", left_panel_bg)
    left_panel_listview:SetCanResizeWidth(true) left_panel_listview:SetCanResizeHeight(true)
    left_panel_listview:Resize(w, h-30) -- -30 to account for the 15px offset below (and the ruffled margin of the image)
    left_panel_listview:SetDockingPoint(5)
    left_panel_listview:SetDockOffset(0, 15)

    local x,y = left_panel_listview:Position()
    local w,h = left_panel_listview:Bounds()

    local lclip = find_uicomponent(left_panel_listview, "list_clip")
    lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
    lclip:MoveTo(x,y)
    lclip:Resize(w,h)

    local lbox = find_uicomponent(lclip, "list_box")
    lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
    lbox:MoveTo(x,y)
    lbox:Resize(w,h)
    
    -- save the listview and list box into the obj
    self.mod_row_list_view = left_panel_listview
    self.mod_row_list_box = lbox

    -- make the stationary title (on left_panel_bg, doesn't scroll)
    local left_panel_title = core:get_or_create_component("left_panel_title", "ui/templates/parchment_divider_title", left_panel_bg)
    left_panel_title:SetStateText(effect.get_localised_string("mct_ui_mods_header"))
    left_panel_title:SetDockingPoint(0)
    local x, y = left_panel_listview:Position()
    left_panel_title:MoveTo(x, y - left_panel_title:Height())
    left_panel_title:Resize(left_panel_listview:Width(), left_panel_title:Height())

    -- RIGHT SIDE
    local right_panel = core:get_or_create_component("right_panel", "ui/mct/mct_frame", panel)
    right_panel:SetVisible(true)

    right_panel:SetCanResizeWidth(true) right_panel:SetCanResizeHeight(true)
    right_panel:Resize(panel:Width() - (left_panel_bg:Width() + 60), left_panel_bg:Height() + left_panel_title:Height())
    right_panel:SetDockingPoint(6)
    right_panel:SetDockOffset(-20, -20) -- margin on bottom + right
    --local x, y = left_panel_title:Position()
    --right_panel:MoveTo(x + left_panel_title:Width() + 20, y)

    -- hide unused stuff
    find_uicomponent(right_panel, "title_plaque"):SetVisible(false)
    find_uicomponent(right_panel, "checkbox_windowed"):SetVisible(false)
    find_uicomponent(right_panel, "ok_cancel_buttongroup"):SetVisible(false)
    find_uicomponent(right_panel, "button_advanced_options"):SetVisible(false)
    find_uicomponent(right_panel, "button_recommended"):SetVisible(false)
    find_uicomponent(right_panel, "dropdown_resolution"):SetVisible(false)
    find_uicomponent(right_panel, "dropdown_quality"):SetVisible(false)

    -- top side
    local mod_details_panel = core:get_or_create_component("mod_details_panel", "ui/vandy_lib/custom_image_tiled", right_panel)
    mod_details_panel:SetState("custom_state_2") -- 50/50/50/50 margins
    mod_details_panel:SetImagePath(img_path, 1) -- img attached to custom_state_2
    mod_details_panel:SetDockingPoint(2)
    mod_details_panel:SetDockOffset(0, 50)
    mod_details_panel:SetCanResizeWidth(true) mod_details_panel:SetCanResizeHeight(true)
    mod_details_panel:Resize(right_panel:Width() * 0.95, right_panel:Height() * 0.3)

    --[[local list_view = core:get_or_create_component("mod_details_panel", "ui/templates/vlist", mod_details_panel)
    list_view:SetDockingPoint(5)
    --list_view:SetDockOffset(0, 50)
    list_view:SetCanResizeWidth(true) list_view:SetCanResizeHeight(true)
    local w,h = mod_details_panel:Bounds()
    list_view:Resize(w,h)

    local mod_details_lbox = find_uicomponent(list_view, "list_clip", "list_box")
    mod_details_lbox:SetCanResizeWidth(true) mod_details_lbox:SetCanResizeHeight(true)
    local w,h = mod_details_panel:Bounds()
    mod_details_lbox:Resize(w,h)]]

    local mod_title = core:get_or_create_component("mod_title", "ui/templates/panel_subtitle", right_panel)
    local mod_author = core:get_or_create_component("mod_author", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    local mod_description = core:get_or_create_component("mod_description", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    --local special_button = core:get_or_create_component("special_button", "ui/mct/special_button", mod_details_panel)

    mod_title:SetDockingPoint(2)
    mod_title:SetCanResizeHeight(true) mod_title:SetCanResizeWidth(true)
    mod_title:Resize(mod_title:Width() * 3.5, mod_title:Height())

    local mod_title_txt = UIComponent(mod_title:CreateComponent("tx_mod_title", "ui/vandy_lib/text/fe_section_heading"))
    mod_title_txt:SetDockingPoint(5)
    mod_title_txt:SetCanResizeHeight(true) mod_title_txt:SetCanResizeWidth(true)
    mod_title_txt:Resize(mod_title:Width(), mod_title_txt:Height())

    self.mod_title_txt = mod_title_txt

    mod_author:SetVisible(true)
    mod_author:SetCanResizeHeight(true) mod_author:SetCanResizeWidth(true)
    mod_author:Resize(mod_details_panel:Width() * 0.8, mod_author:Height() * 1.5)
    mod_author:SetDockingPoint(2)
    mod_author:SetDockOffset(0, 40)

    mod_description:SetVisible(true)
    mod_description:SetCanResizeHeight(true) mod_description:SetCanResizeWidth(true)
    mod_description:Resize(mod_details_panel:Width() * 0.8, mod_description:Height() * 2)
    mod_description:SetDockingPoint(2)
    mod_description:SetDockOffset(0, 70)

    --special_button:SetDockingPoint(8)
    --special_button:SetDockOffset(0, -5)
    --special_button:SetVisible(false) -- TODO temp disabled

    self.mod_details_panel = mod_details_panel

    -- bottom side
    local mod_settings_panel = core:get_or_create_component("mod_settings_panel", "ui/vandy_lib/custom_image_tiled", right_panel)
    mod_settings_panel:SetState("custom_state_2") -- 50/50/50/50 margins
    mod_settings_panel:SetImagePath(img_path, 1) -- img attached to custom_state_2
    mod_settings_panel:SetDockingPoint(2)
    mod_settings_panel:SetDockOffset(0, mod_details_panel:Height() + 70)
    mod_settings_panel:SetCanResizeWidth(true) mod_settings_panel:SetCanResizeHeight(true)
    mod_settings_panel:Resize(right_panel:Width() * 0.95, right_panel:Height() * 0.50)

    local w, h = mod_settings_panel:Dimensions()

    -- create the tabs
    local settings_tab = core:get_or_create_component("settings_tab", "ui/templates/square_small_tab_toggle", mod_settings_panel)
    local logging_tab = core:get_or_create_component("logging_tab", "ui/templates/square_small_tab_toggle", mod_settings_panel)

    settings_tab:SetDockingPoint(1)
    settings_tab:SetDockOffset(0, settings_tab:Height() * -1)
    local img_path = effect.get_skinned_image_path("icon_options_tab.png")
    settings_tab:SetImagePath(img_path)


    logging_tab:SetDockingPoint(1)
    logging_tab:SetDockOffset(logging_tab:Width() * 1.2, logging_tab:Height() * -1)
    local img_path = effect.get_skinned_image_path("icon_records_tab.png")
    logging_tab:SetImagePath(img_path)


    local logging_list_view = core:get_or_create_component("logging_list_view", "ui/vandy_lib/vlist", mod_settings_panel)
    logging_list_view:MoveTo(mod_settings_panel:Position())
    logging_list_view:SetDockingPoint(1)
    logging_list_view:SetDockOffset(0, 10)
    logging_list_view:SetCanResizeWidth(true) logging_list_view:SetCanResizeHeight(true)
    logging_list_view:Resize(w,h-20)

    --local x, y = mod_settings_list_view:Position()

    local logging_list_clip = find_uicomponent(logging_list_view, "list_clip")
    logging_list_clip:SetCanResizeWidth(true) logging_list_clip:SetCanResizeHeight(true)
    --mod_settings_clip:MoveTo(x,y)
    logging_list_clip:SetDockingPoint(1)
    logging_list_clip:SetDockOffset(0, 10)
    logging_list_clip:Resize(w,h-20)

    local logging_list_box = find_uicomponent(logging_list_clip, "list_box")
    logging_list_box:SetCanResizeWidth(true) logging_list_box:SetCanResizeHeight(true)
    --mod_settings_box:MoveTo(x,y)
    logging_list_box:SetDockingPoint(1)
    logging_list_box:SetDockOffset(0, 10)
    logging_list_box:Resize(w,h-20)

    logging_list_box:Layout()

    local l_handle = find_uicomponent(logging_list_view, "vslider")
    l_handle:SetDockingPoint(6)
    l_handle:SetDockOffset(-20, 0)

    -- default to no logging list view (this probably won't work :) )
    logging_list_view:SetVisible(false)

    local mod_settings_list_view = core:get_or_create_component("list_view", "ui/vandy_lib/vlist", mod_settings_panel)
    mod_settings_list_view:MoveTo(mod_settings_panel:Position())
    mod_settings_list_view:SetDockingPoint(1)
    mod_settings_list_view:SetDockOffset(0, 10)
    mod_settings_list_view:SetCanResizeWidth(true) mod_settings_list_view:SetCanResizeHeight(true)
    mod_settings_list_view:Resize(w,h-20)

    --local x, y = mod_settings_list_view:Position()

    local mod_settings_clip = find_uicomponent(mod_settings_list_view, "list_clip")
    mod_settings_clip:SetCanResizeWidth(true) mod_settings_clip:SetCanResizeHeight(true)
    --mod_settings_clip:MoveTo(x,y)
    mod_settings_clip:SetDockingPoint(1)
    mod_settings_clip:SetDockOffset(0, 10)
    mod_settings_clip:Resize(w,h-20)

    local mod_settings_box = find_uicomponent(mod_settings_clip, "list_box")
    mod_settings_box:SetCanResizeWidth(true) mod_settings_box:SetCanResizeHeight(true)
    --mod_settings_box:MoveTo(x,y)
    mod_settings_box:SetDockingPoint(1)
    mod_settings_box:SetDockOffset(0, 10)
    mod_settings_box:Resize(w,h-20)

    mod_settings_box:Layout()

    local handle = find_uicomponent(mod_settings_list_view, "vslider")
    handle:SetDockingPoint(6)
    handle:SetDockOffset(-20, 0)

    -- create the "finalize" button on the panel
    local finalize_button = core:get_or_create_component("button_mct_finalize_settings", "ui/templates/square_large_text_button", mod_settings_panel)
    finalize_button:SetDockingPoint(8)
    finalize_button:SetDockOffset(0, finalize_button:Height()*1.5)

    local finalize_button_txt = find_uicomponent(finalize_button, "button_txt")
    finalize_button_txt:SetStateText("Finalize changes")

    self.mod_settings_panel = mod_settings_panel
end

function ui_obj:populate_panel_on_mod_selected(former_mod_key)
    mct:log("populating panel!")
    local selected_mod = mct:get_selected_mod()

    -- set the positions for all options in the mod
    selected_mod:set_positions_for_options()

    local former_mod = nil
    if is_string(former_mod_key) then
        former_mod = mct:get_mod_by_key(former_mod_key)
    end

    mct:log("Mod selected ["..selected_mod:get_key().."]")

    local mod_details_panel = self.mod_details_panel
    local mod_settings_panel = self.mod_settings_panel
    local mod_title_txt = self.mod_title_txt

    -- set up the mod details - name of selected mod, display author, and whatever blurb of text they want
    local mod_author = core:get_or_create_component("mod_author", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    local mod_description = core:get_or_create_component("mod_description", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    --local special_button = core:get_or_create_component("special_button", "ui/mct/special_button", mod_details_panel)

    local title, author, desc = selected_mod:get_localised_texts()

    -- setting up text & stuff
    do
        local function set_text(uic, text)
            local parent = UIComponent(uic:Parent())
            local ow, oh = parent:Dimensions()
            ow = ow * 0.8
            oh = oh

            uic:ResizeTextResizingComponentToInitialSize(ow, oh)

            local w,h,n = uic:TextDimensionsForText(text)
            uic:SetStateText(text)

            uic:ResizeTextResizingComponentToInitialSize(w,h)
        end

        set_text(mod_title_txt, title)
        set_text(mod_author, author)
        set_text(mod_description, desc)
    end

    --mct:log("testing 3")

    -- remove the previous option rows (does nothing if none are present)
    do
        local destroy_table = {}
        local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")
        if mod_settings_box:ChildCount() ~= 0 then
            for i = 0, mod_settings_box:ChildCount() -1 do
                local child = UIComponent(mod_settings_box:Find(i))
                destroy_table[#destroy_table+1] = child
            end
        end

        -- delet kill destroy
        self:delete_component(destroy_table)

        if not is_nil(former_mod) then
            -- clear the saved UIC objects on the former mod
            former_mod:clear_uics(false)
        end
    end

    local ok, err = pcall(function()
    self:create_sections_and_contents(selected_mod)
    end) if not ok then mct:log(err) end
    --[[local options = selected_mod:get_options()

    -- set up the options propa!
    for k, v in pairs(options) do
        mct:log("Populating new option ["..k.."]")
        self:new_option_row(v)
    end]]

    -- refresh the display once all the option rows are created!
    local box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")
    if not is_uicomponent(box) then
        -- issue
        return
    end

    -- local view = find_uicomponent(mod_settings_panel, "list_view")
    --view:Layout()
    --[[view:Resize(mod_settings_panel:Dimensions())
    view:MoveTo(mod_settings_panel:Position())
    box:Resize(mod_settings_panel:Dimensions())
    box:MoveTo(mod_settings_panel:Position())]]
    box:Layout()

    -- check if the log tab is valid
    local settings_tab = find_uicomponent(mod_settings_panel, "settings_tab")
    local logging_tab = find_uicomponent(mod_settings_panel, "logging_tab")
    local can_settings = true
    local can_log = false

    local logging_list_view = find_uicomponent(mod_settings_panel, "logging_list_view")
    local settings_list_view = find_uicomponent(mod_settings_panel, "list_view")

    -- set settings visible and logging invisible on switching mod selected
    logging_list_view:SetVisible(false)
    settings_list_view:SetVisible(true)

    local path = selected_mod:get_log_file_path()
    local valid = false
    if path == nil then
        valid = false
    else
        if not io.open(path, "r+") then
            valid = false
        else
            valid = true
        end
    end

    if valid == false then
        logging_tab:SetState("inactive")
        logging_tab:SetTooltipText("There is no log file set for this mod. Use `mct_mod:set_log_file_path()` to set one, if you're the modder. If not, oh well.", true)
        can_log = false
    else
        logging_tab:SetState("active")
        logging_tab:SetTooltipText("Open the log file for this mod.", true)
        can_log = true
    end

    if can_settings then
        settings_tab:SetState("selected")
        settings_tab:SetTooltipText("Open the settings path for this mod.", true)
    end

    core:remove_listener("mct_tab_listeners")

    core:add_listener(
        "mct_tab_listeners",
        "ComponentLClickUp",
        function(context)
            return context.string == "settings_tab" or context.string == "logging_tab"
        end,
        function(context)
            if context.string == "settings_tab" then --set the states of each, and make logging invisi and settings visi
                settings_tab:SetState("selected")
                
                if can_log then
                    logging_tab:SetState("active")
                else
                    logging_tab:SetState("inactive")
                end

                -- logging lview invisi
                logging_list_view:SetVisible(false)

                settings_list_view:SetVisible(true)
            else
                logging_tab:SetState("selected")

                if can_settings then
                    settings_tab:SetState("active")
                else
                    settings_tab:SetState("inactive")
                end

                settings_list_view:SetVisible(false)

                logging_list_view:SetVisible(true)

                self:do_log_list_view()
            end
        end,
        true
    )

    core:trigger_custom_event("MctPanelPopulated", {["mct"] = mct, ["ui_obj"] = self, ["mod"] = selected_mod})
end

function ui_obj:do_log_list_view()

    local selected_mod = mct:get_selected_mod()

    local mod_settings_panel = self.mod_settings_panel
    local logging_list_view = find_uicomponent(mod_settings_panel, "logging_list_view")
    local logging_list_box = find_uicomponent(logging_list_view, "list_clip", "list_box")

    -- delete any former logging
    logging_list_box:DestroyChildren()

    local log_file = io.open(selected_mod:get_log_file_path(), "r+")

    if not log_file then
        mct:error("do_log_list_view() called with mod ["..selected_mod:get_key().."], but no log file with the name ["..selected_mod:get_log_file_path().."] was found. Issue!")
        return false
    end

    log_file:close()

    local lines = {}
    for line in io.lines(selected_mod:get_log_file_path()) do
        lines[#lines+1] = line
    end


    for line_num, line_txt in pairs(lines) do
        local ok, err = pcall(function()
        local text_component = core:get_or_create_component("line_text_"..tostring(line_num), "ui/vandy_lib/text/la_gioconda", logging_list_box)

        text_component:Resize(text_component:Width()*4, text_component:Height())

        --local w,h,num = text_component:TextDimensionsForText(tostring(line_num) .. ": " .. line_txt)

        text_component:SetDockingPoint(1)
        text_component:SetDockOffset(10, 10)
        text_component:SetStateText(tostring(line_num) .. ": " .. line_txt)

        text_component:SetVisible(true)
        end) if not ok then mct:error(err) end
    end

    logging_list_box:Layout()
end



function ui_obj:create_sections_and_contents(mod_obj)
    local mod_settings_panel = self.mod_settings_panel
    local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")

    local sections = mod_obj:get_sections()

    --self._sections_to_rows = {}

    core:remove_listener("MCT_SectionHeaderPressed")
    
    local ordered_section_keys = mod_obj:sort_sections()

    for i, section_key in ipairs(ordered_section_keys) do
        --local section_table = sections[i]
        --local section_key = section_table.key
        --self._sections_to_rows[section_key] = {}
        
        local section_obj = mod_obj:get_section_by_key(section_key);

        -- make sure the dummy rows table is clear before doing anything
        section_obj._dummy_rows = {}

        -- first, create the section header
        local section_header = core:get_or_create_component("mct_section_"..section_key, "ui/vandy_lib/expandable_row_header", mod_settings_box)
        --local open = true

        section_obj._header = section_header

        core:add_listener(
            "MCT_SectionHeaderPressed",
            "ComponentLClickUp",
            function(context)
                return context.string == "mct_section_"..section_key
            end,
            function(context)
                mct:log("Changing visibility for section "..section_key)
                local visible = section_obj:is_visible()
                mct:log("Is visible: "..tostring(visible))
                section_obj:set_visibility(not visible)
            end,
            true
        )

        -- TODO set text & width and shit
        section_header:SetCanResizeWidth(true)
        section_header:SetCanResizeHeight(false)
        section_header:Resize(mod_settings_box:Width() * 0.95, section_header:Height())
        section_header:SetCanResizeWidth(false)

        section_header:SetDockOffset(mod_settings_box:Width() * 0.005, 0)
        
        local child_count = find_uicomponent(section_header, "child_count")
        child_count:SetVisible(false)

        local text = section_obj:get_localised_text()

        local dy_title = find_uicomponent(section_header, "dy_title")
        self:uic_SetStateText(dy_title, text)
        --dy_title:SetStateText(text)

        -- lastly, create all the rows and options within
        --local num_remaining_options = 0
        local valid = true

        -- this is the table with the positions to the options
        -- ie. options_table["1,1"] = "option 1 key"
        local options_table, num_remaining_options = section_obj:get_ordered_options() --[[{}

        for option_key, option_obj in pairs(options) do
            num_remaining_options = num_remaining_options + 1

            local x,y = option_obj:get_position()
            local index = tostring(x) .. "," .. tostring(y)

            options_table[index] = option_key
        end]]

        local x = 1
        local y = 1

        local function move_to_next()
            if x >= 3 then
                x = 1
                y = y + 1
            else
                x = x + 1
            end
        end

        -- prevent infinite loops, will only do nothing 3 times
        local loop_num = 0

        --TODO resolve this to better make the dummy rows/columns when nothing is assigned to it

        while valid do
            --loop_num = loop_num + 1
            if num_remaining_options < 1 then
                -- mct:log("No more remaining options!")
                -- no more options, abort!
                break
            end

            if loop_num >= 3 then
                break
            end

            local index = tostring(x) .. "," .. tostring(y)
            local option_key = options_table[index]

            -- check to see if any option was even made at this index!
            --[[if option_key == nil then
                -- skip, go to the next index
                move_to_next()

                -- prevent it from looping without doing anything more than 6 times
                loop_num = loop_num + 1
            else]]
            --loop_num = 0

            if option_key == nil then option_key = "MCT_BLANK" end
            
            local option_obj
            if is_string(option_key) then
                --mct:log("Populating UI option at index ["..index.."].\nOption key ["..option_key.."]")
                if option_key == "NONE" then
                    -- no option objects remaining, kill the engine
                    break
                end
                if option_key == "MCT_BLANK" then
                    option_obj = option_key
                    loop_num = loop_num + 1
                else
                    -- only iterate down this iterator when it's a real option
                    num_remaining_options = num_remaining_options - 1
                    loop_num = 0
                    option_obj = mod_obj:get_option_by_key(option_key)
                end

                if not mct:is_mct_option(option_obj) then
                    mct:error("no option found with the key ["..option_key.."]. Issue!")
                else
                    -- add a new column (and potentially, row, if x==1) for this position
                    self:new_option_row_at_pos(option_obj, x, y, section_key) 
                end

            else
                -- issue? break? dunno?
                mct:log("issue? break? dunno?")
                break
            end
    
            -- move the coords down and to the left when the row is done, or move over one space if the row isn't done
            move_to_next()
            --end
        end

        -- set own visibility (for sections that default to closed)
        section_obj:uic_visibility_change(true)
    end
end


function ui_obj:new_option_row_at_pos(option_obj, x, y, section_key)
    local mod_settings_panel = self.mod_settings_panel
    local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")
    local section_obj = option_obj:get_mod():get_section_by_key(section_key)

    local w,h = mod_settings_panel:Dimensions()
    w = w * 0.95
    h = h * 0.20

    if not mct:is_mct_section(section_obj) then
        mct:log("the section obj isn't a section obj what the heckin'")
    end


    local dummy_row = core:get_or_create_component("settings_row_"..section_key.."_"..tostring(y), "ui/mct/script_dummy", mod_settings_box)

    --[[if section_obj:is_visible() then
        dummy_row:SetVisible(true)
    else
        dummy_row:SetVisible(false)
    end]]

    -- TODO make sliders the entire row so text and all work fine
    -- TODO above isn't really needed, huh?

    -- check to see if it was newly created, and then apply these settings
    if x == 1 then
        section_obj:add_dummy_row(dummy_row)

        dummy_row:SetVisible(true)
        dummy_row:SetCanResizeHeight(true) dummy_row:SetCanResizeWidth(true)
        dummy_row:Resize(w,h)
        dummy_row:SetCanResizeHeight(false) dummy_row:SetCanResizeWidth(false)
        dummy_row:SetDockingPoint(0)
        local w_offset = w * 0.01
        dummy_row:SetDockOffset(w_offset, 0)
        dummy_row:PropagatePriority(mod_settings_box:Priority() +1)
    end

    -- column 1 docks center left, column 2 docks center, column 3 docks center right
    local pos_to_dock = {[1]=4, [2]=5, [3]=6}

    local column = core:get_or_create_component("settings_column_"..tostring(x), "ui/mct/script_dummy", dummy_row)

    -- set the column dimensions & position
    do
        w,h = dummy_row:Dimensions()
        w = w * 0.33
        column:SetVisible(true)
        column:SetCanResizeHeight(true) column:SetCanResizeWidth(true)
        column:Resize(w, h)
        column:SetCanResizeHeight(false) column:SetCanResizeWidth(false)
        column:SetDockingPoint(pos_to_dock[x])
        --column:SetDockOffset(15, 0)
        column:PropagatePriority(dummy_row:Priority() +1)
    end


    if option_obj == "MCT_BLANK" then
        -- no need to do anything, skip
    else
        local dummy_option = core:get_or_create_component(option_obj:get_key(), "ui/mct/script_dummy", column)

        do
            -- set to be flush with the column dummy
            dummy_option:SetCanResizeHeight(true) dummy_option:SetCanResizeWidth(true)
            dummy_option:Resize(w, h)
            dummy_option:SetCanResizeHeight(false) dummy_option:SetCanResizeWidth(false)


            -- set to dock center
            dummy_option:SetDockingPoint(5)

            -- give priority over column
            dummy_option:PropagatePriority(column:Priority() +1)

            -- make some text to display deets about the option
            local option_text = core:get_or_create_component("text", "ui/vandy_lib/text/la_gioconda", dummy_option)
            option_text:SetVisible(true)
            option_text:SetDockingPoint(4)
            option_text:SetDockOffset(5, 0)

            self:uic_SetStateText(option_text, option_obj:get_text())
            self:uic_SetTooltipText(option_text, option_obj:get_tooltip_text(), true)

            local new_option

            --mct:log(tostring(is_uicomponent(dummy_option)))
    
            -- create the interactive option
            do
                local type_to_command = {
                    dropdown = self.new_dropdown_box,
                    checkbox = self.new_checkbox,
                    slider = self.new_slider,
                    textbox = self.new_textbox,
                }
        
                local func = type_to_command[option_obj._type]
                new_option = func(self, option_obj, dummy_option)
            end

            -- resize the text so it takes up the space of the dummy column that is not used by the option
            local n_w = new_option:Width()
            local t_w = dummy_option:Width()
            local w = t_w - n_w
            local _, h = option_text:Dimensions()

            option_text:Resize(w, h)

            new_option:SetDockingPoint(6)

            option_obj:set_uics({new_option, option_text})
            option_obj:set_uic_visibility(option_obj:get_uic_visibility())

            -- TODO do all this shit through /script/campaign/mod/ or similar

            -- read if the option is read-only in campaign (and that we're in campaign)
            if __game_mode == __lib_type_campaign then
                if option_obj:get_read_only() then
                    option_obj:set_uic_locked(true)
                    --option_obj:ui_change_state()
                    --[[local state = new_option:CurrentState()

                    --mct:log("UIc state is ["..state.."]")

                    -- selected_inactive for checkbox buttons
                    if state == "selected" then
                        new_option:SetState("selected_inactive")
                    else
                        new_option:SetState("inactive")
                    end]]
                end

                -- if game is MP, and the local faction isn't the host, lock any non-local settings
                if cm:is_multiplayer() and cm:get_local_faction(true) ~= cm:get_saved_value("mct_host") then
                    mct:log("local faction: "..cm:get_local_faction(true))
                    mct:log("host faction: "..cm:get_saved_value("mct_host"))
                    -- if the option isn't local only, disable it
                    mct:log("mp and client")
                    if not option_obj:get_local_only() then
                        mct:log("option ["..option_obj:get_key().."] is not local only, locking!")
                        option_obj:set_uic_locked(true)
                        --[[local state = new_option:CurrentState()f

                        --mct:log("UIc state is ["..state.."]")
    
                        -- selected_inactive for checkbox buttons
                        if state == "selected" then
                            new_option:SetState("selected_inactive")
                        else
                            new_option:SetState("inactive")
                        end]]
                    end
                end
            end

            -- read-only in battle (do this elsewhere? (TODO))
            if __game_mode == __lib_type_battle then
                option_obj:set_uic_locked(true)
            end

            if option_obj:get_uic_locked() then
                option_obj:set_uic_locked(true)
            end

            --dummy_option:SetVisible(option_obj:get_uic_visibility())
        end
    end
end

function ui_obj.new_checkbox(self, option_obj, row_parent)
    local template = option_obj:get_uic_template()

    local new_uic = core:get_or_create_component("mct_checkbox_toggle", template, row_parent)
    new_uic:SetVisible(true)

    -- returns the default value if none has been selected
    local default_val = option_obj:get_selected_setting()

    if default_val == true then
        new_uic:SetState("selected")
    else
        new_uic:SetState("active")
    end

    option_obj:set_selected_setting(default_val, true)

    return new_uic
end

function ui_obj.new_textbox(self, option_obj, row_parent)
    local template = option_obj:get_uic_template()

    local new_uic = core:get_or_create_component("mct_textbox", template, row_parent)

    -- TODO auto-type the default value
    -- TODO a button next to the textbox to "submit" the new value?
        -- TODO if above, setup some way for the modder to set up specific values and some UX for "this isn't valid!"

    return new_uic
end

function ui_obj.new_dropdown_box(self, option_obj, row_parent)
    local templates = option_obj:get_uic_template()
    local box = "ui/vandy_lib/dropdown_button_no_event"
    local dropdown_option = templates[2]

    local new_uic = core:get_or_create_component("mct_dropdown_box", box, row_parent)
    new_uic:SetVisible(true)

    local popup_menu = find_uicomponent(new_uic, "popup_menu")
    popup_menu:PropagatePriority(1000) -- higher z-value than other shits
    popup_menu:SetVisible(false)
    --popup_menu:SetInteractive(true)

    local popup_list = find_uicomponent(popup_menu, "popup_list")
    popup_list:PropagatePriority(popup_menu:Priority()+1)
    --popup_list:SetInteractive(true)

    local selected_tx = find_uicomponent(new_uic, "dy_selected_txt")

    local dummy = find_uicomponent(popup_list, "row_example")

    local w = 0
    local h = 0

    local default_value = option_obj:get_selected_setting()

    local values = option_obj:get_values()
    for i = 1, #values do
        local value = values[i]
        local key = value.key
        local tt = value.tt
        local text = value.text

        local new_entry = core:get_or_create_component(key, dropdown_option, popup_list)

        -- if they're localised text strings, localise them!
        do
            local test_tt = effect.get_localised_string(tt)
            if test_tt ~= "" then
                tt = test_tt
            end

            local test_text = effect.get_localised_string(text)
            if test_text ~= "" then
                text = test_text
            end
        end

        new_entry:SetTooltipText(tt, true)

        local off_y = 5 + (new_entry:Height() * (i-1))

        new_entry:SetDockingPoint(2)
        new_entry:SetDockOffset(0, off_y)

        w,h = new_entry:Dimensions()

        local txt = find_uicomponent(new_entry, "row_tx")

        txt:SetStateText(text)

        -- check if this is the default value
        if default_value == key then
            new_entry:SetState("selected")
            option_obj:set_selected_setting(default_value, true)

            -- add the value's tt to the actual dropdown box
            selected_tx:SetStateText(text)
            new_uic:SetTooltipText(tt, true)
        end

        new_entry:SetCanResizeHeight(false)
        new_entry:SetCanResizeWidth(false)
    end

    self:delete_component(dummy)

    local border_top = find_uicomponent(popup_menu, "border_top")
    local border_bottom = find_uicomponent(popup_menu, "border_bottom")
    
    border_top:SetCanResizeHeight(true)
    border_top:SetCanResizeWidth(true)
    border_bottom:SetCanResizeHeight(true)
    border_bottom:SetCanResizeWidth(true)

    popup_list:SetCanResizeHeight(true)
    popup_list:SetCanResizeWidth(true)
    popup_list:Resize(w * 1.1, h * (#values) + 10)
    --popup_list:MoveTo(popup_menu:Position())
    popup_list:SetDockingPoint(2)
    --popup_list:SetDocKOffset()

    popup_menu:SetCanResizeHeight(true)
    popup_menu:SetCanResizeWidth(true)
    popup_list:SetCanResizeHeight(false)
    popup_list:SetCanResizeWidth(false)
    
    local w, h = popup_list:Bounds()
    popup_menu:Resize(w,h)

    return new_uic
end


-- UIC Properties:
-- Value
-- minValue
-- maxValue
-- Notify (unused?)
-- update_frequency (doesn't change anything?)
function ui_obj.new_slider(self, option_obj, row_parent)
    local templates = option_obj:get_uic_template()
    local values = option_obj:get_values()

    local left_button_template = templates[1]
    local right_button_template = templates[3]
    
    local text_input_template = templates[2]

    -- hold it all in a dummy
    local new_uic = core:get_or_create_component("mct_slider", "ui/mct/script_dummy", row_parent)
    new_uic:SetVisible(true)
    new_uic:Resize(row_parent:Width() * 0.4, row_parent:Height())

    local left_button = core:get_or_create_component("left_button", left_button_template, new_uic)
    local text_input = core:get_or_create_component("text_input", text_input_template, new_uic)
    local right_button = core:get_or_create_component("right_button", right_button_template, new_uic)

    text_input:SetCanResizeWidth(true)
    text_input:Resize(text_input:Width() * 0.3, text_input:Height())
    text_input:SetCanResizeWidth(false)

    left_button:SetDockingPoint(4)
    text_input:SetDockingPoint(5)
    right_button:SetDockingPoint(6)

    left_button:SetDockOffset(0,0)
    right_button:SetDockOffset(0,0)

    local min = values.min or 0 
    local max = values.max or 100
    local step_size = values.step_size or 1
    local step_size_precision = values.step_size_precision or 0

    local precision = values.precision or 0

    -- TODO refactor this a lot betterly

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

    local ok, err = pcall(function()

    local step_size_str = round(step_size, step_size_precision, false)

    left_button:SetTooltipText("-"..tostring(step_size_str), true)
    right_button:SetTooltipText("+"..tostring(step_size_str), true)

    --step_size = tonumber(step_size)

    local current = option_obj:get_selected_setting()
    current = round(current, precision, true)
    local current_str = round(current, precision, false)

    option_obj:set_selected_setting(current, true)

    text_input:SetStateText(tostring(current_str))
    text_input:SetInteractive(false)

    if current <= min then
        left_button:SetState("inactive")
    elseif current >= max then
        right_button:SetState("inactive")
    end

    -- TODO text input!
    local function set_value(new)

    end

end) if not ok then mct:error(err) end

    -- TODO outsource this to ui_select_value

    return new_uic
end

function ui_obj:new_mod_row(mod_obj)
    local row = core:get_or_create_component(mod_obj:get_key(), "ui/vandy_lib/row_header", self.mod_row_list_box)
    row:SetVisible(true)
    row:SetCanResizeHeight(true) row:SetCanResizeWidth(true)
    row:Resize(self.mod_row_list_view:Width() * 0.95, row:Height() * 1.5)

    local txt = find_uicomponent(row, "name")
    local txt_txt = mod_obj:get_title()

    if not is_string(txt_txt) then
        txt_txt = "No title assigned"
    end

    self:uic_SetStateText(txt, txt_txt)


    local date = find_uicomponent(row, "date")
    local author_txt = mod_obj:get_author()

    --[[if not is_string(author_txt) then
        author_txt = "No author assigned"
    end]]

    date:SetDockingPoint(6)
    self:uic_SetStateText(date, author_txt)

    core:add_listener(
        "MctRowClicked",
        "ComponentLClickUp",
        function(context)
            return UIComponent(context.component) == row
        end,
        function(context)
            local uic = UIComponent(context.component)
            local current_state = uic:CurrentState()

            if current_state ~= "selected" then
                -- deselect the former one
                local former = self:get_selected_mod()
                local former_key = ""
                if is_uicomponent(former) then
                    former:SetState("unselected")
                    former_key = former:Id()
                end

                self:uic_SetState(uic, "selected")

                -- trigger stuff on the right
                self:set_selected_mod(uic)
                self:populate_panel_on_mod_selected(former_key)
            end
        end,
        true
    )

    -- set the mct_mod as selected and all
    if mod_obj:get_key() == "mct_mod" then
        self:uic_SetState(row, "selected")
        
        self:set_selected_mod(row)
        self:populate_panel_on_mod_selected()
    end
end

core:add_listener(
    "mct_dropdown_box",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_dropdown_box"
    end,
    function(context)
        local box = UIComponent(context.component)
        local menu = find_uicomponent(box, "popup_menu")
        if is_uicomponent(menu) then
            if menu:Visible() then
                menu:SetVisible(false)
            else
                menu:SetVisible(true)
                menu:RegisterTopMost()
                -- next time you click something, close the menu!
                core:add_listener(
                    "mct_dropdown_box_close",
                    "ComponentLClickUp",
                    true,
                    function(context)
                        if box:CurrentState() == "selected" then
                            box:SetState("active")
                        end

                        menu:SetVisible(false)
                        menu:RemoveTopMost()
                    end,
                    false
                )
            end
        end
    end,
    true
)

-- Set Selected listeners
core:add_listener(
    "mct_dropdown_box_option_selected",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        
        return UIComponent(uic:Parent()):Id() == "popup_list" and UIComponent(UIComponent(UIComponent(uic:Parent()):Parent()):Parent()):Id() == "mct_dropdown_box"
    end,
    function(context)
        core:remove_listener("mct_dropdown_box_close")

        local uic = UIComponent(context.component)
        local popup_list = UIComponent(uic:Parent())
        local popup_menu = UIComponent(popup_list:Parent())
        local dropdown_box = UIComponent(popup_menu:Parent())


        -- will tell us the name of the option
        local parent_id = UIComponent(dropdown_box:Parent()):Id()
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        -- this operation is set externally (so we can perform the same operation outside of here)
        local ok, err = pcall(function()
        option_obj:ui_select_value(uic:Id())
        end) if not ok then mct:error(err) end
    end,
    true
)

core:add_listener(
    "mct_slider_left_or_right_pressed",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        return (uic:Id() == "left_button" or uic:Id() == "right_button") and uicomponent_descended_from(uic, "mct_slider")
    end,
    function(context)
        local ok, err = pcall(function()
        local step = context.string
        local uic = UIComponent(context.component)

        local slider = UIComponent(uic:Parent())
        local dummy_option = UIComponent(slider:Parent())

        local option_key = dummy_option:Id()
        local mod_obj = mct:get_selected_mod()
        mct:log("getting mod "..mod_obj:get_key())
        mct:log("finding option with key "..option_key)

        local option_obj = mod_obj:get_option_by_key(option_key)

        local values = option_obj:get_values()
        local step_size = values.step_size

        if step == "right_button" then
            mct:log("changing val from "..option_obj:get_selected_setting().. " to "..option_obj:get_selected_setting() + step_size)
            option_obj:ui_select_value(option_obj:get_selected_setting() + step_size)
        elseif step == "left_button" then
            option_obj:ui_select_value(option_obj:get_selected_setting() - step_size)
        end
    end) if not ok then mct:error(err) end
    end,
    true
)

core:add_listener(
    "mct_checkbox_toggle_option_selected",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_checkbox_toggle"
    end,
    function(context)
        local uic = UIComponent(context.component)

        -- will tell us the name of the option
        local parent_id = UIComponent(uic:Parent()):Id()
        --mct:log("Checkbox Pressed - parent id ["..parent_id.."]")
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        if not mct:is_mct_option(option_obj) then
            mct:error("mct_checkbox_toggle_option_selected listener trigger, but the checkbox pressed ["..parent_id.."] doesn't have a valid mct_option attached. Returning false.")
        end

        -- this will return true/false for checked/unchecked
        local current_state = option_obj:get_selected_setting()
        --mct:log("Option obj found. Current setting is ["..tostring(current_state).."], new is ["..tostring(not current_state).."]")
        option_obj:set_selected_setting(not current_state)

        -- TODO put this entire listener into an `option_obj:ui_select_value()` call
        ui_obj.locally_edited = true
    end,
    true
)

-- Finalize settings/print to json
core:add_listener(
    "mct_finalize_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_finalize_settings"
    end,
    function(context)
        mct:finalize()
    end,
    true
)

core:add_listener(
    "mct_close_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_close"
    end,
    function(context)
        -- check if MCT was finalized or no changes were done during the latest UI operation
        if not ui_obj.locally_edited then
            ui_obj:close_frame()
        else
            -- trigger a popup to either close with unsaved changes, or cancel the close procedure
            local key = "mct_unsaved"
            local text = "[[col:red]]WARNING: Unsaved Changes![[/col]]\n\nThere are unsaved changes in the Mod Configuration Tool!\nIf you would like to close anyway, press accept. If you want to go back and save your changes, press cancel and use Finalize Settings!"

            ui_obj:create_popup(key, text, true, function() ui_obj:close_frame() end, nil)
        end
    end,
    true
)

core:add_listener(
    "mct_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_options"
    end,
    function(context)
        ui_obj:open_frame()
    end,
    true
)

return ui_obj
