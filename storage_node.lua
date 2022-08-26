function read_id_item_name(direction)
    local drawer = peripheral.wrap(direction)
    return drawer.list()[2].name
end

function extract_id(id_item_name)
    return string.gsub(string.gsub(id_item_name, "minecraft:", ""), "_terracotta", "")
end

function read_lines(filename)
    local file = io.open(filename, "r")
    local lines = {}
    if file ~= nil then
        for i, line in pairs(file:lines()) do
            lines[i] = line
        end
        file:close()
        return lines
    end
end

function write_lines(filename, lines)
    local file = io.open(filename, "w")
    if file ~= nil then
        local lines_concat = ""
        for i, line in pairs(lines) do
            lines_concat = lines_concat .. tostring(line) .. "\n"
        end
        file:write(lines_concat)
        file:close()
    end
end

function table_count(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function list_inventory(direction)
    local inventory = peripheral.wrap(direction)
    local items = inventory.list()
    if table_count(items) == 0 then
        return nil
    end
    return items
end

function in_table(value, table)
    for k, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function modem_timeout()
    os.sleep(10)
end

function transmit_data_to_controller(id, item_register, transmission_results, modem, send_channel, receive_channel)
    return function()
        modem.open(receive_channel)
        modem.transmit(send_channel, receive_channel, { id = id, item_register = item_register })
        local event, side, channel, replyChannel, message, distance
        repeat
            event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        until channel == receive_channel
        transmission_results["success"] = true
        transmission_results["id"] = message["id"]
        modem.close(receive_channel)
    end
end


function main()
    local send_channel = 0
    local receive_channel = 1
    local top_piston = "top"
    local bottom_hopper = "back"
    local id_drawer = "bottom"
    -- 8 ticks per 64 items in 5 slots
    local time_for_hopper_flush = 0.05 * 8 * 64 * 5
    -- load list of items from file and ID from storage drawer
    local node_id = extract_id(read_id_item_name(id_drawer))
    local item_register = read_lines("item_register.txt")
    local modem = peripheral.find("modem")
    -- set default redstone states
    redstone.setOutput(bottom_hopper, true)
    redstone.setOutput(top_piston, false)
    -- enter wait for items loop
    while true do
        os.sleep(time_for_hopper_flush)
        local found_new_item = false
        -- block item flow and check for items
        redstone.setOutput(top_piston, true)
        local hopper_contents = list_inventory("back")
        if hopper_contents ~= nil then
            -- for all items, check if item is already in list
            for slot, item in pairs(hopper_contents) do
                -- if not, add to list
                if not in_table(item.name, item_register) then
                    item_register[table_count(item_register) + 1] = item.name
                    found_new_item = true
                end
            end
            -- if register was modified, send register along with id to controller, and wait for confirmation of id 
            -- if no reply in time or reply has different id, repeat request
            if found_new_item then
                write_lines("item_register.txt", item_register)
                local transmission_in_progress = true
                while transmission_in_progress do
                    local transmission_results = { success = nil }
                    parallel.waitForAny(modem_timeout, transmit_data_to_controller(node_id, item_register, transmission_results, modem, send_channel, receive_channel))
                    if transmission_results["success"] and transmission_results["id"] == node_id then
                        transmission_in_progress = false
                    end
                end
            end
            -- flush hopper
            redstone.setOutput(bottom_hopper, false)
            os.sleep(time_for_hopper_flush)
            redstone.setOutput(bottom_hopper, true)
        end
        redstone.setOutput(top_piston, false)    
    end
end

main()