<#
.SYNOPSIS
    Shared PLAN.md config parser. Dot-source this from any script that needs service identity or
    stack values (service_name, module_path, ports, router/db/auth/observability choices) instead
    of hardcoding them. PLAN.md's `## Project` block is the single source of truth — see GUIDE.md
    section 0.
#>

$script:PlanConfigDefaults = [ordered]@{
    service_name  = 'service'
    module_path   = 'github.com/CHANGEME/service-name'
    main_pkg      = ''            # computed as ./cmd/<service_name> when blank
    http_port     = '8080'
    db_name       = 'servicedb'
    spec_file     = 'SPEC.md'
    router        = 'chi'
    db_driver     = 'pgx'
    auth          = 'jwt'
    observability = 'prometheus'
    health_path   = '/health/ready'
}

function Get-PlanConfig {
    <#
    .SYNOPSIS
        Parses the `## Project` block of PLAN.md (lines shaped `- key: value`) and returns an
        ordered hashtable merged with defaults. A missing PLAN.md or missing keys just fall back
        to the defaults above.
    #>
    param([string] $PlanPath = 'PLAN.md')

    $cfg = [ordered]@{}
    foreach ($k in $script:PlanConfigDefaults.Keys) { $cfg[$k] = $script:PlanConfigDefaults[$k] }

    if (Test-Path $PlanPath) {
        $inBlock = $false
        foreach ($line in Get-Content $PlanPath) {
            if ($line -match '^##\s+Project\s*$') { $inBlock = $true; continue }
            if ($line -match '^##\s') { $inBlock = $false; continue }
            if (-not $inBlock) { continue }
            if ($line -match '^\s*-\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$') {
                $cfg[$Matches[1]] = $Matches[2].Trim('`', ' ')
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$cfg['main_pkg'])) {
        $cfg['main_pkg'] = "./cmd/$($cfg['service_name'])"
    }
    return $cfg
}
