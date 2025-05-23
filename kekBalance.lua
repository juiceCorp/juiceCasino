-- CLIENT: check_balance.lua with PIN auth
rednet.open("back") -- Adjust for modem side

local SERVER_ID = 11 -- Your server computer ID

while true do
    print("\n=== Balance Checker ===")
    io.write("Enter username (or 'exit'): ")
    local username = read()

    if username:lower() == "exit" then
        print("Goodbye.")
        break
    end

    io.write("Enter PIN: ")
    local pin = read("*") -- Hides input

    local user_lower = string.lower(username)

    -- Send balance request with PIN
    rednet.send(SERVER_ID, {
        action = "get",
        user = user_lower,
        pin = pin
    })

    local _, response = rednet.receive(3)

    if response and response.status == "ok" then
        print("Balance for " .. username .. ": $" .. response.balance)
    elseif response and response.reason then
        print("Error: " .. response.reason)
    else
        print("No response or unknown error.")
    end
end
