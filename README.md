The Challenge
-----------------------------
Public DNS services (Cisco Umbrella/OpenDNS, Quad9, NextDNS, AdGuard DNS and others) that block phishing sites, malware sites, advertisements or pornography are great, as they can protect an entire household when configured on the local Internet router as an upstream DNS server. They are typically free for personal use and do not require additional hardware or in fact any resources. Nor do they negatively affect Internet access performance significantly.

The downside is, though, that you have to choose one public DNS service to use in your home, as you typically cannot use more than one DNS service at the same time. This is unfortunate as different public DNS services have different strengths and weaknesses: Quad9 might be great against malware and phishing but it does not filter pornography to protect your kids, nor does it block ads. OpenDNS/Umbrella adds a "Family Shield" to this but still does not block advertisements. AdGuard DNS is great against ads but might be less effective against malware. 

It would be great to be able to combine the features of any number of public DNS service to one super DNS filtering service. Also this should be able to run on your existing Internet router with minimal resource requirements. There obviously should also not be a slow down of access speeds and you would also like to be able to choose which of the services you trust the most for the actual name resolution.

The Solution
-----------------------------

This DNS forwarder listens for incoming DNS queries and forwards them to multiple pairs of upstream DNS servers at the same time.
It replies as soon as one server of each pair of servers have answered.

**This allows combining multiple filtering DNS services at the same time, thus adding the capabilities of services like Cisco Umbrella/OpenDNS, Quad9, NextDNS, AdGuard DNS and others for a combination of malware and phishing filter, ad blocker and family shield.**

It runs super lightweight on e.g. OpenWRT (with luasocket installed) with only a few lines of lua code.
It listens on UDP port 5553 and is meant to act as upstream resolver for a local caching DNS server like dnsmasq.

DNS queries will always be answered with replies from the first pair of listed DNS servers (by default this is OpenDNS). Replies from the other pairs of upstream servers will only be returned if they point to blocking pages (or e.g. 0.0.0.0 or 127.0.0.1). So these other pairs of servers are only used for filtering of malware, ads and other unwanted content. The first pair of servers should be trustworthy as it does the actual DNS resolving.
  
Dependencies
----------------------------

This DNS forwarder requires lua and lua-socket installed.
It runs lightweight even on small OpenWRT routers.

INSTALL
---------------------

Run the service with "lua dnsfilter.lua &"

You can test it with: 
"nslookup www.google.com 127.0.0.1:5553" on OpenWRT
or "nslookup -port=5553 www.google.com 127.0.0.1" on Linux

Point to this forwarder in your dnsmasq config like this:

```
server=127.0.0.1#5553

#You also might want to resolve the blocking pages from Adguard or OpenDNS via their local service:

server=/opendns.com/208.67.222.123

server=/adguard.com/94.140.14.33

#Prevent Apple Private Relay:

host-record=mask.icloud.com,0.0.0.0
host-record=mask-api.icloud.com,0.0.0.0
host-record=mask-h2.icloud.com,0.0.0.0
host-record=mask-api.fe2.apple-dns.net,0.0.0.0
host-record=mask.apple-dns.net,0.0.0.0
host-record=safebrowsing-proxy.g.aaplimg.com,0.0.0.0

#Additional recommended settings:

dns-forward-max=1000
cache-size=10000
strict-order

```

LICENSE
----------------------

This is a fork of uleelx/dnsforwarder

Filtering-Multi-DNS-Forwarder is distributed under the MIT license.
