This DNS forwarder listens for incoming DNS queries and forwards them to multiple pairs of upstream DNS servers at the same time.
It replies as soon as one of each pair of servers have answered.

This allows to combine multiple filtering DNS services at the same time, thus adding the capabilities of services like Cisco Umbrella/OpenDNS, Quad9, Adguard DNS and others for a combination of malware filter, ad blocker and family shield.

It runs super light weight on e.g. OpenWRT (with luasocket installed).
It listens on UDP port 5553 and is meant to act as upstream resolver for a local caching DNS server like dnsmasq.

DNS queries will always be answered with replies from the first pair of listed DNS servers (by default this is Quad9). Replies from the other pairs of upstream servers will only be returned if they point to blocking pages (or e.g. 0.0.0.0 or 127.0.0.1). So these other pairs of servers are only used for malware, content or ad filtering. The first pair of servers should be trustworthy as they do the actual DNS resolving.
  
Dependencies
----------------------------

This DNS forwarder requires lua and luasocket installed.
It runs light weight even on small OpenWRT routers.

INSTALL
---------------------

Run the service with "lua dnsfilter.lua &"
You can test it with: "nslookup www.google.com 127.0.0.1#5553"

Point to this forwarder in your dnsmask config like this:

server=127.0.0.1#5553

LICENSE
----------------------

This is a fork of uleelx/dnsforwarder
Filtering-Multi-DNS-Forwarder is distributed under the MIT license.
