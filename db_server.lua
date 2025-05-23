local DATABASE_PATH = "database.json"

-- Load database
local function loadDatabase()
    local file = fs.open(DATABASE_PATH, "r")
    if not file then return {} end
    local content = file.readAll()
    file.close()
    if content and #content > 0 then
        return textutils.unserializeJSON(content)
    else
        return {}
    end
end

-- Save database
local function saveDatabase(db)
    local file = fs.open(DATABASE_PATH, "w")
    file.write(textutils.serializeJSON(db))
    file.close()
end

rednet.open("back") -- Change to your modem side

print("Database server started.")
while true do
    local senderId, message, protocol = rednet.receive()
    if protocol == "db" then
        local req = textutils.unserialize(message)
        local db = loadDatabase()
        if req.action == "get" then
            if db[req.username] then
                print("[READ] User:", req.username)
                rednet.send(senderId, textutils.serialize(db[req.username]), "db")
            else
                print(string.format("[ERROR] User not found for READ: '%s' from computer %d", tostring(req.username), senderId))
                rednet.send(senderId, textutils.serialize(nil), "db")
            end
        elseif req.action == "set" then
            local old = db[req.username] or {}
            local new = req.data or {}
            print("[WRITE] User:", req.username)
            for k, v in pairs(new) do
                local oldVal = old[k]
                if oldVal ~= v then
                    print(string.format("  %s: %s -> %s", k, tostring(oldVal), tostring(v)))
                end
            end
            db[req.username] = req.data
            saveDatabase(db)
            rednet.send(senderId, "OK", "db")
        elseif req.action == "exists" then
            print("[EXISTS] User:", req.username)
            rednet.send(senderId, db[req.username] ~= nil, "db")
        elseif req.action == "all" then
            print("[READ ALL] Entire database sent")
            rednet.send(senderId, textutils.serialize(db), "db")
        else
            print("[UNKNOWN ACTION]", req.action)
        end
    end
end