# AzurePrivateLinkResolver

This CoreDNS based resolver can be used to improve name resolutin inside Azure Networks when using Private Link DNS Zones.

## The Problem

When using Private Links with Private DNS Zones in Azure the name resolution for resources that also use Private Links but aren't in the linked Private DNS Zone can not be resolved.

## The Solution

This resolver improves that by first querying the internal Azure resolver [168.63.129.16](https://docs.microsoft.com/azure/virtual-network/what-is-ip-address-168-63-129-16). If this resolver returns a NXDOMAIN the request is forwarded to an external resolver.
