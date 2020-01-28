$envs = @('dev', 'test', 'accept', 'uat', 'edu', 'prod')
$response = Invoke-WebRequest -Uri 'http://localhost:9090/api/v1/query?query=sort_desc(sum(increase(traefik_backend_requests_total%5B7d%5D))%20by%20(backend)%20!%3D0)' -Method GET

$result = ($response.Content | ConvertFrom-Json).Data.result | Select-Object @{N = 'Backend'; E = { $_.metric.backend } }, @{N = 'Value'; E = { [math]::Round($_.value[1]) } }

$parsedResult = ForEach ($entry in $result) {

    $backendParts = $entry.Backend.Split('/')
    $hostname = $backendParts[0]

    $env = ""
    $backendParts | ForEach-Object {
        If ($envs -contains $_) {
            $env = $_
        }
    }

    $service = ($backendParts -notmatch $hostname | Where-Object { $envs -notcontains $_ }) -join '/'
    If (!$service) { $service = $hostname }

    [pscustomobject]@{
        backend  = $entry.Backend
        hostname = $hostname
        service  = $service
        env      = $env
        reqs     = $entry.Value
    }

}

$parsedResult | Group-Object -Property service | Select-Object @{N = 'Service'; E = { $_.Name } }, @{N = 'Hostnames'; E = { ($_.Group.hostname | Select-Object -Unique) -join ', ' } }, @{N = 'Requests'; E = { ($_.Group | Measure-Object -Property reqs -Sum).Sum } } | Sort-Object -Descending Requests | Export-Csv traefik_requests.csv -Delimiter ';'
