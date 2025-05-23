local DATABASE_PATH = "database.json"
local SESSIONS_PATH = "sessions.json"

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

-- Session helpers
local function loadSessions()
    local file = fs.open(SESSIONS_PATH, "r")
    if not file then return {} end
    local content = file.readAll()
    file.close()
    if content and #content > 0 then
        return textutils.unserializeJSON(content)
    else
        return {}
    end
end

local function saveSessions(sessions)
    local file = fs.open(SESSIONS_PATH, "w")
    file.write(textutils.serializeJSON(sessions))
    file.close()
end

local function generateToken()
    local t = ""
    for i = 1, 32 do
        t = t .. string.char(math.random(33, 126))
    end
    return t
end

rednet.open("back") -- Change to your modem side

print("Database server started.")
while true do
    local senderId, message, protocol = rednet.receive()
    if protocol == "db" then
        local req = textutils.unserialize(message)
        local db = loadDatabase()
        local sessions = loadSessions()

        if req.action == "login" then
            -- Authenticate user and generate session token
            local user = db[req.username]
            if user and user.password == req.password then
                local token = generateToken()
                sessions[req.username] = token
                saveSessions(sessions)
                print("[LOGIN] User:", req.username, "Session:", token)
                rednet.send(senderId, textutils.serialize({status="ok", token=token, data=user}), "db")
            else
                print(string.format("[ERROR] Failed login for '%s' from computer %d", tostring(req.username), senderId))
                rednet.send(senderId, textutils.serialize({status="fail", reason="Invalid credentials"}), "db")
            end

        elseif req.action == "logout" then
            sessions[req.username] = nil
            saveSessions(sessions)
            print("[LOGOUT] User:", req.username)
            rednet.send(senderId, textutils.serialize({status="ok"}), "db")

        elseif req.action == "get" or req.action == "set" then
            -- Session token required
            if not (req.username and req.token and sessions[req.username] == req.token) then
                print(string.format("[SECURITY] Invalid or missing session for '%s' from computer %d", tostring(req.username), senderId))
                rednet.send(senderId, textutils.serialize({status="fail", reason="Invalid session"}), "db")
            else
                if req.action == "get" then
                    if db[req.username] then
                        print("[READ] User:", req.username)
                        rednet.send(senderId, textutils.serialize({status="ok", data=db[req.username]}), "db")
                    else
                        print(string.format("[ERROR] User not found for READ: '%s' from computer %d", tostring(req.username), senderId))
                        rednet.send(senderId, textutils.serialize({status="fail", reason="User not found"}), "db")
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
                    rednet.send(senderId, textutils.serialize({status="ok"}), "db")
                end
            end

        elseif req.action == "exists" then
            print("[EXISTS] User:", req.username)
            rednet.send(senderId, db[req.username] ~= nil, "db")

        elseif req.action == "create" then
            if db[req.username] then
                rednet.send(senderId, textutils.serialize({status="fail", reason="User exists"}), "db")
            else
                db[req.username] = req.data
                saveDatabase(db)
                print("[CREATE] User:", req.username)
                rednet.send(senderId, textutils.serialize({status="ok"}), "db")
            end

        elseif req.action == "all" then
            print("[READ ALL] Entire database sent")
            rednet.send(senderId, textutils.serialize(db), "db")
        else
            print("[UNKNOWN ACTION]", req.action)
        end
    end
end
