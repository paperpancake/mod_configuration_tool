--- MCT UI Object. INTERNAL USE ONLY.
-- @module mct_ui

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
    selected_mod_row = nil
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

--[[function ui_obj:set_uic_can_resize(uic, enable)
    mct:log(tostring(enable))
    enable = enable or true

    if not is_boolean(enable) then
        -- issue
        return false
    end

    if is_uicomponent(uic) then
        self:uic_SetCanResizeHeight(uic, enable)
        self:uic_SetCanResizeWidth(uic, enable)
    end
end]]

--[[function ui_obj:set_uic_children_can_resize(uic, enable)
    enable = enable or true

    if not is_boolean(enable) then
        -- issue
        return false
    end

    if is_uicomponent(uic) then
        for i = 0, uic:ChildCount() -1 do
            local child = UIcomponent(uic:Find(i))
            if is_uicomponent(child) then
                child:SetCanResizeHeight(enable)
                child:SetCanResizeWidth(enable)
            end
        end
    end
end]]

function ui_obj:set_selected_mod(row_uic)
    if is_uicomponent(row_uic) then
        mct:set_selected_mod(row_uic:Id())
        self.selected_mod_row = row_uic
    end
end

function ui_obj:get_selected_mod()
    return self.selected_mod_row
end

-- [[TODO redo the find_uicomponent() and get_or_create_component() functions so this all doesn't suck]]
-- TODO or just give up wrap_uic or use it way less, probably this
-- [[TODO maybe both]]
function ui_obj:open_frame()
    -- check if one exists already
    local test = self.panel

    -- make a new one!
    if not test then
        -- create the new window and set it visible
        local new_frame = core:get_or_create_component("mct_options", "ui/mct/mct_frame")
        new_frame:SetVisible(true)

        mct:log("test 1")
        -- resize the panel
        new_frame:SetCanResizeWidth(true) new_frame:SetCanResizeHeight(true)
        mct:log("test 2")
        new_frame:Resize(new_frame:Width() * 4, new_frame:Height() * 2.5)
        mct:log("test 3")

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
        self:new_mod_row(mct:get_mod_with_name("mct_mod"))

        -- create UI rows on the left, for each registered mod
        for mod_name, mod in pairs(mct._registered_mods) do
            -- skip MCT dupe
            if mod_name ~= "mct_mod" then
                self:new_mod_row(mod)
            end
        end
    else
        test:SetVisible(true)
    end
end

function ui_obj:close_frame()
    local panel = self.panel
    if is_uicomponent(panel) then
        panel:SetVisible(false)
    end
end

function ui_obj:create_close_button()
    local panel = self.panel
    
    local close_button_uic = core:get_or_create_component("button_mct_close", "ui/templates/round_medium_button", panel)
    close_button_uic:SetImagePath("ui/skins/warhammer2/icon_check.png")
    close_button_uic:SetTooltipText("Close panel", true)

    -- bottom center
    close_button_uic:SetDockingPoint(8)
    close_button_uic:SetDockOffset(0, 0)
end

function ui_obj:create_panels()
    local panel = self.panel
    -- LEFT SIDE

    -- create image background
    local left_panel_bg = core:get_or_create_component("left_panel_bg", "ui/vandy_lib/custom_image_tiled", panel)
    left_panel_bg:SetState("custom_state_2") -- 50/50/50/50 margins
    left_panel_bg:SetImagePath("ui/skins/warhammer2/parchment_texture.png", 1) -- img attached to custom_state_2
    left_panel_bg:SetDockingPoint(4)
    left_panel_bg:SetDockOffset(20, 0)
    left_panel_bg:SetCanResizeWidth(true) left_panel_bg:SetCanResizeHeight(true)
    left_panel_bg:Resize(panel:Width() * 0.25, panel:Height() - 175)

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

    --[[do
        local w,h,x,y = left_panel_listview:Bounds(), left_panel_listview:Position()
        mct:log("LVIEW: ("..tostring(w)..", "..tostring(h)..") ("..tostring(x)..", "..tostring(y)..").")
    end

    do
        local w,h,x,y = lclip:Bounds(), lclip:Position()
        mct:log("LCLIP: ("..tostring(w)..", "..tostring(h)..") ("..tostring(x)..", "..tostring(y)..").")
    end

    do
        local w,h,x,y = lbox:Bounds(), lbox:Position()
        mct:log("LBOX: ("..tostring(w)..", "..tostring(h)..") ("..tostring(x)..", "..tostring(y)..").")
    end]]

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
    mod_details_panel:SetImagePath("ui/skins/warhammer2/parchment_texture.png", 1) -- img attached to custom_state_2
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
    local special_button = core:get_or_create_component("special_button", "ui/mct/special_button", mod_details_panel)

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

    special_button:SetDockingPoint(8)
    special_button:SetDockOffset(0, -5)
    --special_button:SetVisible(false) -- TODO temp disabled

    self.mod_details_panel = mod_details_panel

    -- bottom side
    local mod_settings_panel = core:get_or_create_component("mod_settings_panel", "ui/vandy_lib/custom_image_tiled", right_panel)
    mod_settings_panel:SetState("custom_state_2") -- 50/50/50/50 margins
    mod_settings_panel:SetImagePath("ui/skins/warhammer2/parchment_texture.png", 1) -- img attached to custom_state_2
    mod_settings_panel:SetDockingPoint(2)
    mod_settings_panel:SetDockOffset(0, mod_details_panel:Height() + 70)
    mod_settings_panel:SetCanResizeWidth(true) mod_settings_panel:SetCanResizeHeight(true)
    mod_settings_panel:Resize(right_panel:Width() * 0.95, right_panel:Height() * 0.50)

    local w, h = mod_settings_panel:Dimensions()

    local mod_settings_list_view = core:get_or_create_component("list_view", "ui/vandy_lib/vlist", mod_settings_panel)
    mod_settings_list_view:MoveTo(mod_settings_panel:Position())
    mod_settings_list_view:SetDockingPoint(1)
    mod_settings_list_view:SetDockOffset(0, 10)
    mod_settings_list_view:SetCanResizeWidth(true) mod_settings_list_view:SetCanResizeHeight(true)
    mod_settings_list_view:Resize(w,h-20)

    local x, y = mod_settings_list_view:Position()

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
    local former_mod = mct:get_mod_with_name(former_mod_key)
    mct:log("Mod selected ["..selected_mod:get_key().."]")

    local mod_details_panel = self.mod_details_panel
    local mod_settings_panel = self.mod_settings_panel
    local mod_title_txt = self.mod_title_txt

    -- set up the mod details - name of selected mod, display author, and whatever blurb of text they want
    local mod_author = core:get_or_create_component("mod_author", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    local mod_description = core:get_or_create_component("mod_description", "ui/vandy_lib/text/la_gioconda", mod_details_panel)
    local special_button = core:get_or_create_component("special_button", "ui/mct/special_button", mod_details_panel)

    local title, author, desc, link = selected_mod:get_localised_texts()

    mct:log(title .. "; " .. author .. "; " .. desc .. "; " .. link)

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

        special_button:SetProperty("url", link)
    end

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
            former_mod:clear_uics_for_all_options()
        end
    end


    self:create_sections_and_contents(selected_mod)

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

    local view = find_uicomponent(mod_settings_panel, "list_view")
    --view:Layout()
    --[[view:Resize(mod_settings_panel:Dimensions())
    view:MoveTo(mod_settings_panel:Position())
    box:Resize(mod_settings_panel:Dimensions())
    box:MoveTo(mod_settings_panel:Position())]]
    box:Layout()

    --[[do
        local x,y = mod_settings_panel:Position()
        local w,h = mod_settings_panel:Dimensions()

        mct:log("PANEL: ("..tostring(x)..", "..tostring(y).."); ("..tostring(w)..", "..tostring(h)..").")
    end
    
    do 
        local x,y = view:Position()
        local w,h = view:Dimensions()

        mct:log("VIEW: ("..tostring(x)..", "..tostring(y).."); ("..tostring(w)..", "..tostring(h)..").")
    end

    do 
        local x,y = box:Position()
        local w,h = box:Dimensions()

        mct:log("BOX: ("..tostring(x)..", "..tostring(y).."); ("..tostring(w)..", "..tostring(h)..").")
    end]]
end

function ui_obj:section_visibility_change(section_key, enable)
    local attached_rows = self._sections_to_rows[section_key]
    for i = 1, #attached_rows do
        local row = attached_rows[i]
        if is_uicomponent(row) then
            row:SetVisible(enable)
        end
    end
end

function ui_obj:create_sections_and_contents(mod_obj)
    local mod_settings_panel = self.mod_settings_panel
    local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")

    local sections = mod_obj:get_sections()

    self._sections_to_rows = {}

    core:remove_listener("MCT_SectionHeaderPressed")

    for i = 1, #sections do
        local section_table = sections[i]
        local section_key = section_table.key
        self._sections_to_rows[section_key] = {}
        -- first, create the section header
        local section_header = core:get_or_create_component("mct_section_"..section_key, "ui/vandy_lib/expandable_row_header", mod_settings_box)
        local open = true

        core:add_listener(
            "MCT_SectionHeaderPressed",
            "ComponentLClickUp",
            function(context)
                return context.string == "mct_section_"..section_key
            end,
            function(context)
                open = not open
                self:section_visibility_change(section_key, open)
            end,
            true
        )

        -- TODO set text & width and shit
        section_header:SetCanResizeWidth(true)
        section_header:SetCanResizeHeight(false)
        section_header:Resize(mod_settings_box:Width() * 0.99, section_header:Height())
        section_header:SetCanResizeWidth(false)

        section_header:SetDockOffset(mod_settings_box:Width() * 0.005, 0)
        
        local child_count = find_uicomponent(section_header, "child_count")
        child_count:SetVisible(false)

        local text = section_table.txt
        if is_nil(text) then
            text = "No Text Assigned"
        else
            local test = effect.get_localised_string(text)
            if test ~= "" then
                text = test
            --else
                --text = text
            end
        end

        if not is_string(text) then
            text = "No Text Assigned"
        end

        local dy_title = find_uicomponent(section_header, "dy_title")
        dy_title:SetStateText(text)

        -- lastly, create all the rows and options within
        local num_remaining_options = 0
        local options = mod_obj:get_options_by_section(section_key)
        local valid = true

        for _,_ in pairs(options) do
            num_remaining_options = num_remaining_options + 1 
        end

        local x = 1
        local y = 1

        while valid do
            if num_remaining_options < 1 then
                -- mct:log("No more remaining options!")
                -- no more options, abort!
                break
            end
            local index = tostring(x) .. "," .. tostring(y)
            local option_key = mod_obj:get_option_key_for_coords(x, y)
            mct:log("Populating UI option at index ["..index.."].\nOption key ["..option_key.."]")
            local option_obj
            if is_string(option_key) then
                if option_key == "NONE" then
                    -- no option objects remaining, kill the engine
                    break
                end
                if option_key == "MCT_BLANK" then
                    option_obj = option_key
                else
                    -- only iterate down this iterator when it's a real option
                    num_remaining_options = num_remaining_options - 1
                    option_obj = mod_obj:get_option_by_key(option_key)
                end
    
                -- add a new column (and potentially, row, if x==1) for this position
                self:new_option_row_at_pos(option_obj, x, y, section_key)
            else
                -- issue? break? dunno?
            end
    
            -- move the coords down and to the left when the row is done, or move over one space if the row isn't done
            if x >= 3 then
                x = 1 
                y = y + 1
            else
                x = x + 1
            end
        end
    end
end

function ui_obj:create_settings_rows(mod_obj)
    mct:log("Is This thing On")

    local mod_settings_panel = self.mod_settings_panel
    local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")

    local num_remaining_options = 0
    local options = mod_obj:get_options()
    local valid = true

    for k,v in pairs(options) do
        num_remaining_options = num_remaining_options + 1
    end

    mct:log("Num remaining options: "..tostring(num_remaining_options))

    local x = 1
    local y = 1

    -- where [index] is "x,y"
    -- local option_key = mod_obj._coords[index]

    -- loop through, creating a new row every time x == 1
    -- grab an option obj for the valid option key at each coord
    -- if there are no more option keys, break
    while valid do
        if num_remaining_options < 1 then
            mct:log("No more remaining options!")
            -- no more options, abort!
            break
        end

        local index = tostring(x) .. "," .. tostring(y)
        local option_key = mod_obj:get_option_key_for_coords(x, y)
        mct:log("Populating UI option at index ["..index.."].\nOption key ["..option_key.."]")
        local option_obj
        if is_string(option_key) then
            if option_key == "NONE" then
                -- no option objects remaining, kill the engine
                break
            end
            if option_key == "MCT_BLANK" then
                option_obj = option_key
            else
                -- only iterate down this iterator when it's a real option
                num_remaining_options = num_remaining_options - 1
                option_obj = mod_obj:get_option_by_key(option_key)
            end

            -- add a new column (and potentially, row, if x==1) for this position
            self:new_option_row_at_pos(option_obj, x, y)
        else
            -- issue? break? dunno?
        end

        -- move the coords down and to the left when the row is done, or move over one space if the row isn't done
        if x >= 3 then
            x = 1 
            y = y + 1
        else
            x = x + 1
        end        
    end
end

function ui_obj:new_option_row_at_pos(option_obj, x, y, section_key)
    local mod_settings_panel = self.mod_settings_panel
    local mod_settings_box = find_uicomponent(mod_settings_panel, "list_view", "list_clip", "list_box")
    local w,h = mod_settings_panel:Dimensions()
    w = w * 0.95
    h = h * 0.20

    -- first up, grab the dummy row - it will either create a new one, or get one that's already created
    local dummy_row = core:get_or_create_component("settings_row_"..section_key.."_"..tostring(y), "ui/mct/script_dummy", mod_settings_box)

    local table = self._sections_to_rows[section_key]

    table[#table+1] = dummy_row
    
    -- check to see if it was newly created, and then apply these settings
    if x == 1 then
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
        dummy_option = core:get_or_create_component(option_obj._key, "ui/mct/script_dummy", column)

        do
            -- set to be flush with the column dummy
            dummy_option:SetCanResizeHeight(true) dummy_option:SetCanResizeWidth(true)
            dummy_option:Resize(w, h)
            dummy_option:SetCanResizeHeight(false) dummy_option:SetCanResizeWidth(false)


            -- set to dock center
            dummy_option:SetDockingPoint(5)

            -- give priority over column
            dummy_option:PropagatePriority(column:Priority() +1)

            -- assign tt text to the dummy section -- TODO put this on the text not the option??
            dummy_option:SetTooltipText(option_obj:get_tooltip_text(), true)

            -- make some text to display deets about the option
            local option_text = core:get_or_create_component("text", "ui/vandy_lib/text/la_gioconda", dummy_option)
            option_text:SetVisible(true)
            option_text:SetDockingPoint(4)
            option_text:SetDockOffset(5, 0)
            option_text:SetStateText(option_obj:get_text())

            local new_option 

            mct:log(tostring(is_uicomponent(dummy_option)))
    
            -- create the interactive option
            do
                local type_to_command = {
                    dropdown = self.new_dropdown_box,
                    checkbox = self.new_checkbox,
                    slider = self.new_slider
                }
        
                local func = type_to_command[option_obj._type]
                new_option = func(self, option_obj, dummy_option)
            end

            new_option:SetDockingPoint(6)

            option_obj:set_uics({new_option, option_text})
            option_obj:set_uic_visibility(option_obj:get_uic_visibility())

            mct:log("this is probably it huh")
            -- read if the option is read-only in campaign (and that we're in campaign)
            if __game_mode == __lib_type_campaign and option_obj:get_read_only() then
                local state = new_option:CurrentState()

                mct:log("UIc state is ["..state.."]")

                -- selected_inactive for checkbox buttons
                if state == "selected" then
                    new_option:SetState("selected_inactive")
                else
                    new_option:SetState("inactive")
                end        
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

    option_obj:set_selected_setting(default_val)

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
            option_obj:set_selected_setting(default_value)

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
function ui_obj.new_slider(self, option_obj, row_parent)
    local template = option_obj:get_uic_template()
    local values = option_obj:get_values()

    local min = values.min or 0
    local max = values.max or 100
    local current = values.current or 50

    local new_uic = core:get_or_create_component("mct_horizontal_slider", template, row_parent)
    new_uic:SetVisible(true)

    new_uic:SetProperty("Value", current)
    new_uic:SetProperty("minValue", min)
    new_uic:SetProperty("maxValue", max)

    local displ = core:get_or_create_component("display_text", "ui/vandy_lib/text/la_gioconda", new_uic)
    displ:SetDockingPoint(4)
    displ:SetDockOffset(-80, displ:Height() /2)
    displ:SetStateText(tostring(current))

    option_obj:set_selected_setting(current)

    -- TODO notify system

    --new_uic:SetProperty("Notify", displ:Address())

    --new_uic:SetMoveable(true)
    --new_uic:SetDockingPoint(2)

    return new_uic
end

function ui_obj:new_mod_row(mod_obj)
    local row = core:get_or_create_component(mod_obj:get_key(), "ui/vandy_lib/row_header", self.mod_row_list_box)
    row:SetVisible(true)
    row:SetCanResizeHeight(true) row:SetCanResizeWidth(true)
    row:Resize(self.mod_row_list_view:Width() * 0.95, row:Height() * 1.5)

    local txt = find_uicomponent(row, "name")
    txt:SetStateText(mod_obj:get_title())

    local date = find_uicomponent(row, "date")
    date:SetDockingPoint(6)
    date:SetStateText(mod_obj:get_author())

    core:add_listener(
        "MctRowClicked"..mod_obj:get_key(),
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

                uic:SetState("selected")

                -- trigger stuff on the right
                self:set_selected_mod(uic)
                self:populate_panel_on_mod_selected(former_key)
            end
        end,
        true
    )

    -- auto-click on making the MCT Mod one
    if mod_obj:get_key() == "mct_mod" then
        row:SimulateLClick()
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

        -- set the older option as unselected
        local current_val = option_obj:get_selected_setting()
        mct:log(current_val)

        local currently_selected_uic = find_uicomponent(popup_list, current_val)

        if is_uicomponent(currently_selected_uic) then
            currently_selected_uic:SetState("unselected")
        else
            -- errmsg, wtf
            return false
        end

        -- set the new option as "selected", so it's highlighted in the list
        uic:SetState("selected")
        option_obj:set_selected_setting(context.string)

        -- set the state text of the dropdown box to be the state text of the row
        local t = find_uicomponent(uic, "row_tx"):GetStateText()
        local tt = find_uicomponent(uic, "row_tx"):GetTooltipText()
        local tx = find_uicomponent(dropdown_box, "dy_selected_txt")
        tx:SetStateText(t)
        dropdown_box:SetTooltipText(tt, true)

        -- set the menu invisible and unclick the box
        if dropdown_box:CurrentState() == "selected" then
            dropdown_box:SetState("active")
        end

        popup_menu:SetVisible(false)
        popup_menu:RemoveTopMost()
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
        mct:log("Checkbox Pressed - parent id ["..parent_id.."]")
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        if is_nil(option_obj) then
            -- errmsg
            return false
        end

        -- this will return true/false for checked/unchecked
        local current_state = option_obj:get_selected_setting()
        mct:log("Option obj found. Current setting is ["..tostring(current_state).."], new is ["..tostring(not current_state).."]")
        option_obj:set_selected_setting(not current_state)
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
        mct.settings:finalize()
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
        ui_obj:close_frame()
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