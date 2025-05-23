local hmac_util = require("hmacUtil")
local SERVER_ID = 10
rednet.open("back")

local VALID_APPS = {
    "blackjack",
    "kekRoulette",
}

local SESSION_TIMEOUT = 1800 -- 30 minutes in seconds

local session_token = nil
local session_time = nil

local function sendSecureRequest(data)
    local payload = textutils.serialize(data)
    local hmac = hmac_util.hmac(payload, hmac_util.SECRET_KEY)
    local msg = textutils.serialize({payload=payload, hmac=hmac})
    rednet.send(SERVER_ID, msg, "db")
    local _, response = rednet.receive("db", 5)
    if response then
        return textutils.unserialize(response)
    end
end

local function db_login(username, password)
    return sendSecureRequest({action="login", username=username, password=password})
end

local function db_create(username, password)
    return sendSecureRequest({action="create", username=username, data={password=password, userid=tostring(math.random(100000,999999)), balance=100}})
end

local function db_exists(username)
    local res = sendSecureRequest({action="exists", username=username})
    return res == true
end

local function promptCredentials()
    term.write("Username: ")
    local username = read()
    term.write("Password: ")
    local password = read("*")
    return username, password
end

local function saveSession(username, token)
    local userFile = fs.open("current_user.txt", "w")
    userFile.write(username)
    userFile.close()
    local tokenFile = fs.open("session_token.txt", "w")
    tokenFile.write(textutils.serialize({token=token, time=os.epoch("utc")}))
    tokenFile.close()
end

local function loadSession()
    if not fs.exists("current_user.txt") or not fs.exists("session_token.txt") then
        return nil, nil, nil
    end
    local userFile = fs.open("current_user.txt", "r")
    local username = userFile.readAll()
    userFile.close()
    local tokenFile = fs.open("session_token.txt", "r")
    local tokenData = textutils.unserialize(tokenFile.readAll())
    tokenFile.close()
    if type(tokenData) == "table" and tokenData.token and tokenData.time then
        return username, tokenData.token, tokenData.time
    end
    return nil, nil, nil
end

local function clearSession()
    if fs.exists("current_user.txt") then fs.delete("current_user.txt") end
    if fs.exists("session_token.txt") then fs.delete("session_token.txt") end
    session_token = nil
    session_time = nil
end

local function createAccount()
    print("=== Create Account ===")
    while true do
        term.write("Choose a username: ")
        local username = read()
        if db_exists(username) then
            print("Username already exists. Try another.")
        else
            term.write("Choose a password: ")
            local password = read("*")
            local res = db_create(username, password)
            if res and res.status == "ok" then
                print("Account created! Logging in...")
                local loginRes = db_login(username, password)
                if loginRes and loginRes.status == "ok" then
                    session_token = loginRes.token
                    session_time = os.epoch("utc")
                    saveSession(username, session_token)
                    return username, password
                else
                    print("Login failed after account creation.")
                    return nil
                end
            else
                print("Account creation failed.")
            end
        end
    end
end

local function signIn()
    print("=== Sign In ===")
    for _ = 1, 3 do
        local username, password = promptCredentials()
        local res = db_login(username, password)
        if res and res.status == "ok" then
            print("Welcome, " .. username .. "!")
            session_token = res.token
            session_time = os.epoch("utc")
            saveSession(username, session_token)
            return username, password
        else
            print("Invalid credentials. Try again.")
        end
    end
    print("Too many failed attempts.")
    return nil
end

local function mainMenu()
    print("Welcome to the J.U.I.C.E Login Portal!")
    print("[1] Sign In")
    print("[2] Create Account")
    term.write("Choose an option: ")
    local choice = read()
    return choice
end

local function getAvailableApps()
    local apps = {}
    for _, app in ipairs(VALID_APPS) do
        if fs.exists(app .. ".lua") then
            table.insert(apps, app)
        end
    end
    return apps
end

local function appLauncher(username)
    while true do
        local apps = getAvailableApps()
        if #apps == 0 then
            print("No available applications found.")
            return false
        end
        print("\nAvailable Applications:")
        for i, app in ipairs(apps) do
            print(string.format("[%d] %s", i, app))
        end
        print("[Q] Quit")
        term.write("Select an application to launch: ")
        local choice = read()
        if choice:lower() == "q" then
            print("Goodbye!")
            return false
        end
        local idx = tonumber(choice)
        if idx and apps[idx] then
            saveSession(username, session_token)
            shell.run(apps[idx] .. ".lua")
        else
            print("Invalid selection.")
        end
    end
end

while true do
    local username, token, time = loadSession()
    local now = os.epoch("utc")
    if username and token and time and (now - time) < SESSION_TIMEOUT * 1000 then
        session_token = token
        session_time = time
        saveSession(username, session_token)
        local stay = appLauncher(username)
        if not stay then
            clearSession()
        end
    else
        clearSession()
        username, session_token, session_time = nil, nil, nil
        while not username do
            local choice = mainMenu()
            if choice == "1" then
                username, _ = signIn()
            elseif choice == "2" then
                username, _ = createAccount()
            else
                print("Invalid option.")
            end
        end
        local stay = appLauncher(username)
        if not stay then
            clearSession()
        end
    end
end
