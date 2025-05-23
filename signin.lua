local SERVER_ID = 10
rednet.open("back") 

local function db_get(username)
    rednet.send(SERVER_ID, textutils.serialize({action="get", username=username}), "db")
    local _, msg = rednet.receive("db", 2)
    if msg then return textutils.unserialize(msg) end
end

local function db_set(username, data)
    rednet.send(SERVER_ID, textutils.serialize({action="set", username=username, data=data}), "db")
    local _, msg = rednet.receive("db", 2)
    return msg == "OK"
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
            local userid = tostring(math.random(100000, 999999))
            local data = {
                password = password,
                userid = userid,
                balance = 100
            }
            db_set(username, data)
            print("Account created! Your user ID is: " .. userid)
            return username
        end
    end
end

local function signIn()
    print("=== Sign In ===")
    for _ = 1, 3 do
        local username, password = promptCredentials()
        local data = db_get(username)
        if data and data.password == password then
            print("Welcome, " .. username .. "!")
            return username
        else
            print("Invalid credentials. Try again.")
        end
    end
    print("Too many failed attempts.")
    return nil
end

local function mainMenu()
    print("Welcome to Blackjack!")
    print("[1] Sign In")
    print("[2] Create Account")
    term.write("Choose an option: ")
    local choice = read()
    return choice
end

local username
while not username do
    local choice = mainMenu()
    if choice == "1" then
        username = signIn()
    elseif choice == "2" then
        username = createAccount()
    else
        print("Invalid option.")
    end
end

local userFile = fs.open("current_user.txt", "w")
userFile.write(username)
userFile.close()

shell.run("blackjack.lua")