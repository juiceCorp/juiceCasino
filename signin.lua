local SERVER_ID = 10
rednet.open("back")

local VALID_APPS = {
    "blackjack",
    "kekRoulette",
}

local session_token = nil

local function db_login(username, password)
    rednet.send(SERVER_ID, textutils.serialize({action="login", username=username, password=password}), "db")
    local _, msg = rednet.receive("db", 2)
    if msg then return textutils.unserialize(msg) end
end

local function db_create(username, password)
    rednet.send(SERVER_ID, textutils.serialize({action="create", username=username, data={password=password, userid=tostring(math.random(100000,999999)), balance=100}}), "db")
    local _, msg = rednet.receive("db", 2)
    if msg then return textutils.unserialize(msg) end
end

local function db_exists(username)
    rednet.send(SERVER_ID, textutils.serialize({action="exists", username=username}), "db")
    local _, msg = rednet.receive("db", 2)
    return msg == true
end

local function promptCredentials()
    term.write("Username: ")
    local username = read()
    term.write("Password: ")
    local password = read("*")
    return username, password
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
                -- Immediately log in after account creation
                local loginRes = db_login(username, password)
                if loginRes and loginRes.status == "ok" then
                    session_token = loginRes.token
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

local function appLauncher(username, password)
    while true do
        local apps = getAvailableApps()
        if #apps == 0 then
            print("No available applications found.")
            return
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
            return
        end
        local idx = tonumber(choice)
        if idx and apps[idx] then
            -- Save username and session token for the app
            local userFile = fs.open("current_user.txt", "w")
            userFile.write(username)
            userFile.close()
            local tokenFile = fs.open("session_token.txt", "w")
            tokenFile.write(session_token)
            tokenFile.close()
            shell.run(apps[idx] .. ".lua")
        else
            print("Invalid selection.")
        end
    end
end

-- Main logic
local username, password
while not username do
    local choice = mainMenu()
    if choice == "1" then
        username, password = signIn()
    elseif choice == "2" then
        username, password = createAccount()
    else
        print("Invalid option.")
    end
end

appLauncher(username, password)
