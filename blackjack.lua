local hmac_util = require("hmacUtil")
local SERVER_ID = 10
rednet.open("back") 

local BALANCE_MIN = 10

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
    local payload = textutils.serialize(data)
    local hmac = hmac_util.hmac(payload, hmac_util.SECRET_KEY)
    local msg = textutils.serialize({payload=payload, hmac=hmac})
    rednet.send(SERVER_ID, msg, "db")
    local _, response = rednet.receive("db", 5)
    if response then
        return textutils.unserialize(response)
    end
end

local function db_get(username, session_token)
    local res = sendSecureRequest({action="get", username=username, token=session_token})
    if res and res.status == "ok" then return res.data end
end

local function db_set(username, session_token, data)
    local res = sendSecureRequest({action="set", username=username, token=session_token, data=data})
    return res and res.status == "ok"
end

local sleep = function(seconds)
    local start = os.clock()
    while os.clock() - start <= seconds do sleep(0.01) end
end

local typePrint = function(text, speed)
    speed = speed or 0.01
    for i = 1, #text do
        io.write(text:sub(i, i))
        io.flush()
        sleep(speed)
    end
end

local instantPrint = function(text)
    print(text)
end

-- Deck setup
local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
local ranks = {
    "Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10",
    "Jack", "Queen", "King"
}

local deck = {}

local function newDeck()
    deck = {}
    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            table.insert(deck, {suit = suit, rank = rank})
        end
    end
end

local function shuffleDeck()
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

local function getCardValue(card)
    local rank = card.rank
    if rank == "Ace" then
        return 11
    elseif rank == "Jack" or rank == "Queen" or rank == "King" then
        return 10
    else
        return tonumber(rank)
    end
end

local function getHandTotal(hand)
    local total = 0
    local aces = 0

    for _, card in ipairs(hand) do
        total = total + getCardValue(card)
        if card.rank == "Ace" then
            aces = aces + 1
        end
    end

    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end

    return total
end

local function dealCard()
    if #deck == 0 then
        newDeck()
        shuffleDeck()
    end
    return table.remove(deck)
end

local function revealDealerCard(card)
    typePrint("Dealer shows: " .. card.rank .. " of " .. card.suit, 0.01)
    print()
    sleep(0.3)
end

local function getBet(balance)
    while true do
        typePrint(string.format("\nYour balance: $%d", balance), 0.02)
        io.write(string.format("\nEnter your bet ($%d - $%d): ", BALANCE_MIN, balance))
        local input = io.read()
        local bet = tonumber(input)
        if bet and bet >= BALANCE_MIN and bet <= balance then
            return bet
        else
            typePrint("Invalid bet. Try again.", 0.02)
            print()
        end
    end
end

local function playBlackjack()
    local username, session_token = loadSession()
    local userData = db_get(username, session_token)
    if not userData then
        print("Session expired or invalid. Returning to portal...")
        sleep(1)
        return false
    end
    local balance = userData.balance or 100

    instantPrint("\nBLACKJACK")
    instantPrint("----------")

    local bet = getBet(balance)

    newDeck()
    shuffleDeck()

    local playerHand = {dealCard(), dealCard()}
    local dealerHand = {dealCard(), dealCard()}
    local playerTotal = 0
    local balanceChange = 0

    -- Player's turn
    while true do
        instantPrint("\nYOUR CARDS:")
        for _, card in ipairs(playerHand) do
            typePrint(card.rank .. " of " .. card.suit, 0.01)
            print()
        end
        playerTotal = getHandTotal(playerHand)
        typePrint("TOTAL: " .. playerTotal, 0.02)
        print()

        if playerTotal > 21 then
            typePrint("\nBUST. You lose.", 0.03)
            print()
            balance = balance - bet
            balanceChange = -bet
            userData.balance = balance
            db_set(username, session_token, userData)
            if balanceChange > 0 then
                typePrint(string.format("You won $%d this round.", balanceChange), 0.02)
            elseif balanceChange < 0 then
                typePrint(string.format("You lost $%d this round.", -balanceChange), 0.02)
            else
                typePrint("No change in balance this round.", 0.02)
            end
            print()
            typePrint(string.format("Your balance is now: $%d", balance), 0.02)
            print()
            return true
        end

        instantPrint("\nDEALER SHOWS:")
        typePrint(dealerHand[1].rank .. " of " .. dealerHand[1].suit, 0.01)
        print()

        io.write("\n[hit/h] or [stand/s]? ")
        local input = io.read():lower()

        if input == "hit" or input == "h" then
            typePrint("Dealing...", 0.02)
            print()
            sleep(0.5)
            table.insert(playerHand, dealCard())
        elseif input == "stand" or input == "s" then
            break
        else
            typePrint("Try again.", 0.02)
            print()
        end
    end

    -- Dealer's turn
    instantPrint("\nDEALER'S MOVE...")
    sleep(0.5)
    revealDealerCard(dealerHand[2])

    while getHandTotal(dealerHand) < 17 do
        typePrint("\nDealer hits...", 0.03)
        print()
        sleep(0.5)
        table.insert(dealerHand, dealCard())
        revealDealerCard(dealerHand[#dealerHand])
    end

    instantPrint("\nDEALER'S HAND:")
    for _, card in ipairs(dealerHand) do
        typePrint(card.rank .. " of " .. card.suit, 0.01)
        print()
    end
    local dealerTotal = getHandTotal(dealerHand)
    typePrint("TOTAL: " .. dealerTotal, 0.02)
    print()

    -- Determine winner 
    instantPrint("\nOUTCOME:")
    sleep(0.3)
    
    if not playerTotal or not dealerTotal then
        typePrint("Error calculating scores", 0.03)
        balanceChange = 0
    elseif dealerTotal > 21 then
        typePrint("Dealer busts! You win!", 0.03)
        balance = balance + bet
        balanceChange = bet
    elseif dealerTotal > playerTotal then
        typePrint("Dealer wins.", 0.03)
        balance = balance - bet
        balanceChange = -bet
    elseif dealerTotal < playerTotal then
        typePrint("You win!", 0.03)
        balance = balance + bet
        balanceChange = bet
    else
        typePrint("Push. Tie game.", 0.03)
        balanceChange = 0
    end
    print()

    userData.balance = balance
    db_set(username, session_token, userData)

    if balanceChange > 0 then
        typePrint(string.format("You won $%d this round.", balanceChange), 0.02)
    elseif balanceChange < 0 then
        typePrint(string.format("You lost $%d this round.", -balanceChange), 0.02)
    else
        typePrint("No change in balance this round.", 0.02)
    end
    print()
    typePrint(string.format("Your balance is now: $%d", balance), 0.02)
    print()
    return true
end

while true do
    local keepPlaying = playBlackjack()
    if not keepPlaying then
        break
    end
    io.write("\nAgain? (y/n) ")
    if io.read():lower() ~= "y" then
        break
    end
end

typePrint("\nThanks for playing!", 0.02)
print()
print()
shell.run("signin.lua")
print()
