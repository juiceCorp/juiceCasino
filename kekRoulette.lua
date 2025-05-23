-- roulette_client.lua (no wheel visual)

rednet.open("back")
local SERVER_ID = 10 -- Use your DB server ID

-- Load current user and session token
local userFile = fs.open("current_user.txt", "r")
local USERNAME = userFile.readAll()
userFile.close()
local tokenFile = fs.open("session_token.txt", "r")
local SESSION_TOKEN = tokenFile.readAll()
tokenFile.close()

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
local BALANCE = 0

local function sendRequest(data)
    data.username = USERNAME
    data.token = SESSION_TOKEN
    rednet.send(SERVER_ID, textutils.serialize(data), "db")
    local senderId, response = rednet.receive("db", 5)
    if senderId == SERVER_ID and response then
        local res = textutils.unserialize(response)
        return res
    end
end

local function get_balance()
    local res = sendRequest({action="get"})
    if res and res.status == "ok" and res.data and res.data.balance then
        return res.data.balance
    end
    return 0
end

local function update_balance(newBal, reason)
    local res = sendRequest({action="set", data={balance=newBal}})
    if res and res.status == "ok" then BALANCE = newBal return true end
    return false
end

-- Game loop
local function roulette_game()
    BALANCE = get_balance()
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
roulette_game()
