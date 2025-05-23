local hmac_util = require("hmacUtil")
rednet.open("back")
local SERVER_ID = 10

local function loadSession()
    local userFile = fs.open("current_user.txt", "r")
    local username = userFile.readAll()
    userFile.close()
    local tokenFile = fs.open("session_token.txt", "r")
    local tokenData = textutils.unserialize(tokenFile.readAll())
    tokenFile.close()
    local session_token = type(tokenData) == "table" and tokenData.token or tokenData
    return username, session_token
end

local function sendSecureRequest(data)
    local username, session_token = loadSession()
    data.username = username
    data.token = session_token
    local payload = textutils.serialize(data)
    local hmac = hmac_util.hmac(payload, hmac_util.SECRET_KEY)
    local msg = textutils.serialize({payload=payload, hmac=hmac})
    rednet.send(SERVER_ID, msg, "db")
    local senderId, response = rednet.receive("db", 5)
    if senderId == SERVER_ID and response then
        local res = textutils.unserialize(response)
        return res
    end
end

local function get_balance()
    local res = sendSecureRequest({action="get"})
    if res and res.status == "ok" and res.data and res.data.balance then
        return res.data.balance
    end
    return 0
end

local function update_balance(newBal, reason)
    local res = sendSecureRequest({action="set", data={balance=newBal}})
    return res and res.status == "ok"
end

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

local RED_NUMBERS = {
  [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,
  [14]=true,[16]=true,[18]=true,[19]=true,[21]=true,[23]=true,
  [25]=true,[27]=true,[30]=true,[32]=true,[34]=true,[36]=true
}

local function getColor(num)
    if num == 0 then return "green"
    elseif RED_NUMBERS[num] then return "red"
    else return "black" end
end

local function roulette_game()
    local BALANCE = get_balance()
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

roulette_game()
shell.run("signin.lua")
