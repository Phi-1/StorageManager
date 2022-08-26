json = require "json"

function read_json(filename)
    file = io.open(filename, "r")
    if file ~= nil then
        return json.decode(file:read())
    end
    return nil
end

function write_json(table, filename)
    file = io.open(filename, "w")
    if file ~= nil then
        file:write(json.encode(table))
    end
end

function get_modem_message(receive_channel)
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == receive_channel
    return message
end

function main()
    local receive_channel = 0
    local send_channel = 1
    local node_modem_side = "left"
    local turtle_modem_side = "top"
    local item_register = {}
    local node_modem = peripheral.wrap(node_modem_side)
    local turtle_modem = peripheral.wrap(turtle_modem_side)
    -- open item register
    item_register = read_json("item_register.json")
    -- wait for network request
    node_modem.open(receive_channel)
    turtle_modem.open(receive_channel)
    while true do
        local message = get_modem_message(receive_channel)
        if message ~= nil then
            if message["id"] == "turtle" then
                -- if turtle, supply item register
                turtle_modem.transmit(send_channel, receive_channel, item_register)
            else
                -- if anything else, save new item register and transmit back id for confirmation
                item_register[message["id"]] = message["item_register"]
                node_modem.transmit(send_channel, receive_channel, { id = message["id"] })
            end
            write_json(item_register, "item_register.json")
        end
    end
end

main()