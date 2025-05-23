-- roulette_client.lua (no wheel visual)

rednet.open("back") -- Adjust as needed
local SERVER_ID = 11 -- Replace with actual storage_server Rednet ID

-- Utils
local sleep = function(seconds)
    local start = os.clock()
    while os.clock() - start <= seconds do end
end

local typePrint = function(text, speed)
    speed = speed or 0.02
    for i = 1, #text do
        io.write(text:sub(i, i))
        io.flush()
        sleep(speed)
    end
    print()
end

-- Constants
local RED_NUMBERS = {
  [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,
  [14]=true,[16]=true,[18]=true,[19]=true,[21]=true,[23]=true,
  [25]=true,[27]=true,[30]=true,[32]=true,[34]=true,[36]=true
}

-- Helpers
local function getColor(num)
    if num == 0 then return "green"
    elseif RED_NUMBERS[num] then return "red"
    else return "black" end
end

-- User data
local USERNAME, PIN, BALANCE = nil, nil, 0

local function sendRequest(data)
    rednet.send(SERVER_ID, data)
    local senderId, response = rednet.receive(5)
    if senderId == SERVER_ID then return response end
end

-- Auth
local function sign_in()
    print("\n=== SIGN IN ===")
    io.write("Username: ")
    USERNAME = string.lower(read())
    io.write("PIN: ")
    PIN = read("*")

    local res = sendRequest({action="get", user=USERNAME, pin=PIN})
    if res and res.status == "ok" then
        BALANCE = res.balance or 100
        typePrint("Welcome back, " .. USERNAME .. "!")
        return true
    else
        typePrint("Login failed: " .. (res and res.reason or "No response"))
        return false
    end
end

local function create_account()
    print("\n=== CREATE ACCOUNT ===")
    io.write("Choose a username: ")
    USERNAME = string.lower(read())
    io.write("Set a PIN: ")
    PIN = read("*")
    BALANCE = 100

    local res = sendRequest({action="update", user=USERNAME, pin=PIN, balance=BALANCE})
    if res and res.status == "ok" then
        typePrint("Account created! Welcome, " .. USERNAME)
        return true
    else
        typePrint("Account creation failed.")
        return false
    end
end

local function update_balance(newBal, reason)
    local res = sendRequest({action="update", user=USERNAME, pin=PIN, balance=newBal, reason=reason})
    if res and res.status == "ok" then BALANCE = newBal return true end
    return false
end

-- Game loop
local function roulette_game()
    while true do
        typePrint("\nYour balance: $" .. BALANCE)
        print("1) Odd / Even")
        print("2) Red / Black / Green")
        print("3) Quit")
        io.write("Choose bet type (1-3): ")
        local betType = read()

        if betType == "3" then print("Thanks for playing!") break end

        local betChoice
        if betType == "1" then
            io.write("Bet on (odd/even): ")
            betChoice = read():lower()
            if betChoice ~= "odd" and betChoice ~= "even" then print("Invalid.") goto continue end
        elseif betType == "2" then
            io.write("Bet on (red/black/green): ")
            betChoice = read():lower()
            if not (betChoice == "red" or betChoice == "black" or betChoice == "green") then print("Invalid.") goto continue end
        else
            print("Invalid choice.") goto continue
        end

        io.write("Bet amount: $")
        local betAmount = tonumber(read())
        if not betAmount or betAmount <= 0 or betAmount > BALANCE then print("Invalid amount.") goto continue end

        typePrint("Spinning...")
        sleep(1)
        local result = math.random(0, 36)
        local resultColor = getColor(result)

        print("Result: " .. result .. " (" .. resultColor .. ")")
        local win = false

        if betType == "1" then
            if result ~= 0 and ((betChoice == "odd" and result % 2 == 1) or (betChoice == "even" and result % 2 == 0)) then
                win = true
            end
        elseif betType == "2" and resultColor == betChoice then
            win = true
        end

        local payout = 0
        if win then
            payout = betAmount * (betType == "2" and (betChoice == "green" and 14 or 2) or 2)
            BALANCE = BALANCE + payout
            typePrint("You won! +$" .. payout)
        else
            BALANCE = BALANCE - betAmount
            typePrint("You lost. -$" .. betAmount)
        end

        update_balance(BALANCE, "Roulette bet: " .. betChoice .. " $" .. betAmount)

        if BALANCE <= 0 then
            typePrint("You're out of money. Game over.")
            break
        end
        ::continue::
    end
end

-- Start
while true do
    print("\nWelcome to Roulette!")
    print("1) Sign In")
    print("2) Create Account")
    io.write("Choice: ")
    local c = read()
    if c == "1" and sign_in() then break
    elseif c == "2" and create_account() then break
    else print("Try again.") end
end

roulette_game()
