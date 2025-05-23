-- storage_server.lua

rednet.open("back") -- Change "back" to your modem side

-- Discord webhook URL (replace with your actual webhook URL)
local webhookURL = ""

local data = {}

-- Load stored data from file
if fs.exists("balances.txt") then
    local file = fs.open("balances.txt", "r")
    data = textutils.unserialize(file.readAll()) or {}
    file.close()
end

-- Save data back to file
local function save_data()
    local file = fs.open("balances.txt", "w")
    file.write(textutils.serialize(data))
    file.close()
end

-- Send a message to Discord webhook
local function sendLogToDiscord(message)
    if not http then
        print("HTTP API is not enabled!")
        return
    end

    local payload = {
        content = message
    }
    local jsonPayload = textutils.serializeJSON(payload)

    local response = http.post(webhookURL, jsonPayload, {["Content-Type"] = "application/json"})
    if response then
        print("Log sent to Discord!")
        response.close()
    else
        print("Failed to send log to Discord.")
    end
end

-- Log transaction locally and to Discord
local function log_transaction(user, oldBalance, newBalance, reason)
    local logFile = fs.open("transactions.log", "a")
    local timeStamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] User: %s | Balance: %d -> %d | Reason: %s\n", timeStamp, user, oldBalance or 0, newBalance, reason or "Update")
    logFile.write(line)
    logFile.close()

    -- Send to Discord (truncate if too long)
    local message = line
    if #message > 1900 then
        message = message:sub(1, 1900) .. "..."
    end
    sendLogToDiscord(message)
end

print("Storage server started, waiting for requests...")

while true do
    local senderId, msg = rednet.receive()

    if type(msg) == "table" then
        local user = msg.user and string.lower(msg.user) or nil

        if msg.action == "update" and user and msg.balance then
            data[user] = data[user] or {}
            local oldBalance = data[user].balance or 0
            data[user].balance = msg.balance
            if msg.pin then
                data[user].pin = msg.pin
            end
            save_data()

            print(string.format("Updated balance for user '%s': %d -> %d", user, oldBalance, msg.balance))
            log_transaction(user, oldBalance, msg.balance, "Balance update")

            rednet.send(senderId, {status = "ok", balance = msg.balance})

        elseif msg.action == "get" and user and msg.pin then
            local entry = data[user]
            if entry and entry.pin == msg.pin then
                rednet.send(senderId, {status = "ok", balance = entry.balance or 100})
            else
                rednet.send(senderId, {status = "error", reason = "Invalid username or PIN"})
            end

        else
            rednet.send(senderId, {status = "error", reason = "Invalid request"})
        end
    else
        rednet.send(senderId, {status = "error", reason = "Malformed message"})
    end
end
