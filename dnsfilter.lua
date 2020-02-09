local socket = require("socket")

if not task then dofile("task.lua") end
local task = task

-- SERVERS need to be in pairs for redundancy (default: primary and secondary for each Adguard DNS, OpenDNS and Quad9)
-- The first two servers should be the most trusted ones. Only replies from this pair of servers will be forwarded.
-- Replies from other servers will only be forwarded when they direct to blocking pages
-- We trust Quad9 the most, so their two IPs come first
local SERVERS = {
  "9.9.9.9", "149.112.112.112",
  "176.103.130.132", "176.103.130.134",
  "208.67.222.123", "208.67.220.123"
}

-- BLOCK_IPs are fake IPs that the dns services redirect blocked requests to. List all known IPs (default: Adguard, OpenDNS and Quad9)
local BLOCK_IP = {
  "0.0.0.0", "146.112.61.104", "146.112.61.105", "146.112.61.106", "146.112.61.107", "146.112.61.108", "146.112.61.109", "146.112.61.110",
  "176.103.130.130", "176.103.130.131", "176.103.130.132", "176.103.130.133", "176.103.130.134", "176.103.130.135"
}

local SERVNUM, SERVFLAGS = 0, 0
local IP, PORT, DOMAIN, ANSWERS, REPLY = {}, {}, {}, {}, {}
local busy = false


function setflag(set, flag)
  if set % (2*flag) >= flag then
    return set
  end
  return set + flag
end

local function replier(proxy, forwarder)
  local lifetime, interval = 5, 0.01
  repeat
    if busy then lifetime, busy = 5, false end
    local data,server,_ = forwarder:receivefrom()
    if data and #data > 0 then
      server=server:gsub("%d+", string.char):gsub("(.).", "%1")
      local ID = data:sub(1, 2)
      if IP[ID] then
        ANSWERS[ID]=setflag(ANSWERS[ID],SERVERS[server])
        -- print (ID, DOMAIN[ID], ANSWERS[ID])
        if SERVERS[server]==1 then
         REPLY[ID]=data
        end
        if BLOCK_IP[data:sub(-4)] or string.byte(data:sub(-4,-4))==0 then
         proxy:sendto(data, IP[ID], PORT[ID])
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
