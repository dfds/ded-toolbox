Function Convert-Base64 {

    [CmdletBinding()]
    [Alias("base64", "b64")]

    Param(

        [Parameter(
            Position = 0,
            Mandatory = $True,
            ValueFromPipeline = $True
        )]
        [AllowEmptyString()]
        [Alias('Input')]
        [string[]]$InputString,

        [Parameter(Mandatory = $False)]
        [Alias('d')]
        [switch]$decode

    )

    # Must be wrapped in "process" scriptblock, in order to handle blank lines in pipeline input
    process {

        If ($InputString) {

            If ($decode) {
                Return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputString))
            }

            else {
                Return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($InputString))
            }

        }

    }
            
}