# Applies application-specific IIS configuration during the container image
# build. Kept as a standalone script rather than inline Dockerfile RUN
# commands so it's the one place to update when the app team changes a
# requirement, and so it can be tested outside a Docker build if needed.

Import-Module WebAdministration

# Request size limit increase for CRM file uploads
Set-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering/requestLimits" `
    -PSPath "IIS:\Sites\Default Web Site" -Name maxAllowedContentLength -Value 104857600

# Enable dynamic + static compression
Enable-WebGlobalModule -Name DynamicCompressionModule -ErrorAction SilentlyContinue
Enable-WebGlobalModule -Name StaticCompressionModule -ErrorAction SilentlyContinue

# Lightweight healthz endpoint for Kubernetes liveness/readiness probes —
# deliberately doesn't touch the app's own database connections, so a slow
# DB doesn't get misread by Kubernetes as a dead pod.
New-Item -Path "C:\inetpub\wwwroot\healthz" -ItemType File -Force | Out-Null
Set-Content -Path "C:\inetpub\wwwroot\healthz" -Value "OK"
