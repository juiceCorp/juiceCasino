local SECRET_KEY = "mySuperSecretKey123" -- Change this to a strong, secret value!

local function simple_hmac(message, key)
    local hash = 5381
    for i = 1, #message do
        hash = bit.bxor(hash, message:byte(i))
        hash = (hash * 33) % 4294967296
    end
    for i = 1, #key do
        hash = bit.bxor(hash, key:byte(i))
        hash = (hash * 33) % 4294967296
    end
    return tostring(hash)
end

return {
    SECRET_KEY = SECRET_KEY,
    hmac = simple_hmac
}