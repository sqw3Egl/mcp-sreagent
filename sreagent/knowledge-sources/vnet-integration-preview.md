# VNet integration for Azure SRE Agent (preview)

Source: https://techcommunity.microsoft.com/blog/appsonazureblog/vnet-integration-for-azure-sre-agent-preview/4524287
Published: 2026-06-02

Summary

Azure SRE Agent supports VNet integration in preview for outbound traffic control. The feature lets the agent send outbound traffic through a delegated subnet in a customer VNet so existing NSG rules, private DNS, routes, firewalls, ExpressRoute, and VPN connectivity can govern access to private resources.

Key points

- There are three egress modes: Unrestricted, Limited, and Azure VNet.
- Azure VNet is the recommended mode for production and regulated workloads.
- The portal path is Settings > Workspace Configuration > Network.
- The selected subnet must be /28 or larger and delegated to Microsoft.App/environments.
- Some outbound categories can optionally stay on a managed bypass path instead of the customer VNet.
- Optional bypass categories mentioned in the article include package registries, code repositories, remote MCP servers, and additional hostnames.
- The preview currently covers outbound traffic only.
- Private inbound access to the agent is not part of this preview.
- Connector traffic still routes over the public internet in this preview.

Operational guidance

- Use Azure VNet mode when the agent needs access to private resources such as monitoring stores, databases, key vaults, internal services, or on-premises systems reached through existing network paths.
- Keep only the minimum required categories on the managed bypass path.
- Restrict who can change egress mode or bypass toggles because those settings change the reachable network surface.
- Test outbound behavior before using the agent with production data.

Why this matters

This feature gives Azure SRE Agent a network boundary under customer control. Identity and RBAC still govern what the agent is authorized to access, but VNet integration adds a lower-level control over where traffic can go.