-- Version 1.2 1.12.2024

local socket = require("socket")

if not task then dofile("task.lua") end
local task = task

-- SERVERS need to be in pairs for redundancy (default: primary and secondary for each Adguard DNS, OpenDNS and Quad9)
-- The first two servers should be the most trusted ones. Only replies from this pair of servers will be forwarded.
-- Replies from other servers will only be forwarded when they direct to blocking pages
-- We trust OpenDNS the most, so their two IPs come first
local SERVERS = {
  "208.67.222.123", "208.67.220.123",
--  "76.76.2.2", "76.76.10.2",
--  "9.9.9.9", "149.112.112.112",
  "94.140.14.15", "94.140.15.16"
}

-- BLOCK_IPs are fake IPs that the dns services redirect blocked requests to. List all known IPs (default: Adguard, OpenDNS and Quad9)
local BLOCK_IP = {
  "0.0.0.0", "146.112.61.104", "146.112.61.105", "146.112.61.106", "146.112.61.107", "146.112.61.108", "146.112.61.109", "146.112.61.110",
  "94.140.14.33", "94.140.14.35"
}

-- BLOCK_QTYPES is the list of query types to block. We do not like IOS14 using query Type 65
local BLOCK_QTYPES = {
  65
}
-- Helper array that will be filled with flags:
local BLOCK_QTYPE = {}

local SERVNUM, SERVFLAGS = 0, 0
local IP, PORT, DOMAIN, ANSWERS, REPLY = {}, {}, {}, {}, {}
local busy = false


function setflag(set, flag)
  if set % (2*flag) >= flag then
    return set
  end
  return set + flag
end


local function get_question_type(data)
    -- Helper function to convert a byte to an integer
    local function byte_to_int(b)
        return string.byte(b)
    end

    -- Start at the Question Section (after the 12-byte header)
    local pos = 13

    -- Parse the domain name
    while byte_to_int(string.sub(data, pos, pos)) ~= 0 do
        -- Get the length of the current label
        local length = byte_to_int(string.sub(data, pos, pos))
        -- Move past the label (length + 1 to include the length byte)
        pos = pos + length + 1
    end

    -- Move past the null byte that terminates the domain name
    pos = pos + 1

    -- Read the Type field (2 bytes)
    local type_hi = byte_to_int(string.sub(data, pos, pos))   -- High byte
    local type_lo = byte_to_int(string.sub(data, pos + 1, pos + 1)) -- Low byte
    local type_field = (type_hi * 256) + type_lo             -- Combine to get the Type

    -- Return the Type as an integer
    return type_field
end

local function replier(proxy, forwarder)
  local lifetime, interval = 5, 0.01
  repeat
    if busy then lifetime, busy = 5, false end
    local data,server,_ = forwarder:receivefrom()
    if data and #data > 0 then
      server=server:gsub("%d+", string.char):gsub("(.).", "%1")
      local QTYPE = get_question_type(data)
      -- print (QTYPE)
      local ID = data:sub(1, 2)
      if IP[ID] then
        ANSWERS[ID]=setflag(ANSWERS[ID],SERVERS[server])
        -- print (ID, DOMAIN[ID], ANSWERS[ID])
        if (SERVERS[server]==1 and not BLOCK_QTYPE[QTYPE]) or (SERVERS[server]==2 and BLOCK_QTYPE[QTYPE]) then
         REPLY[ID]=data
        end
        if BLOCK_IP[data:sub(-4)] and string.byte(data:sub(-5,-5))==4 then
         proxy:sendto(data, IP[ID], PORT[ID])
         os.execute("logger Blocked "..DOMAIN[ID].." "..SERVERS[server])
         IP[ID], PORT[ID], DOMAIN[ID], ANSWERS[ID], REPLY[ID] = nil, nil, nil, nil, nil
        elseif ANSWERS[ID]==SERVFLAGS then
         proxy:sendto(REPLY[ID], IP[ID], PORT[ID])
         IP[ID], PORT[ID], DOMAIN[ID], ANSWERS[ID], REPLY[ID] = nil, nil, nil, nil, nil
        end
      end
    end
    lifetime = lifetime - interval
    task.sleep(interval)
  until lifetime < 0
  IP, PORT, DOMAIN, ANSWERS, REPLY = {}, {}, {}, {}, {}
end

local function listener(proxy, forwarder)
  while true do
    local data, ip, port = proxy:receivefrom()
    if data and #data > 0 then
      local domain = (data:sub(14, -6):gsub("[^%w]", "."))
      local ID = data:sub(1, 2)
      -- local QTYPE = string.byte(data:sub(-3,-2),1,1)+256*string.byte(data:sub(-4,-3),1,1)
      -- print(string.byte(ID,1),string.byte(ID,2), domain)
      IP[ID], PORT[ID], DOMAIN[ID], ANSWERS[ID] = ip, port, domain, 0
      for _, server in ipairs(SERVERS) do
        local dns_ip, dns_port = string.match(server, "([^:]*):?(.*)")
        dns_port = tonumber(dns_port) or 53
        forwarder:sendto(data, dns_ip, dns_port)
      end
      busy = true
      if task.count() == 1 then task.go(replier, proxy, forwarder) end
    end
    task.sleep(0.02)
  end
end

local function main()

  SERVNUM=#SERVERS
  SERVFLAGS=(2^(SERVNUM/2))-1

  for _, ip in ipairs(BLOCK_IP) do
    BLOCK_IP[ip:gsub("%d+", string.char):gsub("(.).", "%1")] = true
  end

  for _, qt in ipairs(BLOCK_QTYPES) do
    BLOCK_QTYPE[qt] = true
  end

  for num, ip in ipairs(SERVERS) do
    local bit=num-1
    if bit%2==1 then
     bit=bit-1
    end
    bit=2^(bit/2)
    SERVERS[ip:gsub("%d+", string.char):gsub("(.).", "%1")] = bit
  end

  local proxy = socket.udp()
  proxy:settimeout(0)
  assert(proxy:setsockname("*", 5553))

  local forwarder = socket.udp()
  forwarder:settimeout(0)
  assert(forwarder:setsockname("*", 0))

  task.go(listener, proxy, forwarder)
  task.loop()
end

main()
