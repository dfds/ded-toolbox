$Accounts = (aws organizations list-accounts --profile saml) | ConvertFrom-Json 
$Regions = (aws ec2 describe-regions --region eu-central-1 --output json) | ConvertFrom-Json 

$Accounts = $Accounts.Accounts

# Debug override
#$Accounts = '[{"Name": "sandbox-emcla", "ID": "090185641622"}]' | ConvertFrom-Json
#$Regions = '{"Regions": [{"RegionName": "eu-central-1"}, {"RegionName": "eu-west-1"}]}' | ConvertFrom-Json

$Instances = @{}

$Payload = [System.Collections.ArrayList]@()

foreach ($Account in $Accounts) {

	$ARN = "arn:aws:iam::$($Account.ID):role/OrgRole"
  $AWS_ROLE = (aws sts assume-role --role-arn $ARN --role-session-name Temp --profile saml --region eu-central-1) | ConvertFrom-Json

	$Env:AWS_ACCESS_KEY_ID = $AWS_ROLE.Credentials.AccessKeyId
	$Env:AWS_SECRET_ACCESS_KEY = $AWS_ROLE.Credentials.SecretAccessKey
  $Env:AWS_SESSION_TOKEN = $AWS_ROLE.Credentials.SessionToken
    
  Write-Output "Getting EC2 instances for Account ID: $($Account.ID)"
  Write-Output "Account Name: $($Account.Name)"

  Write-Output (aws sts get-caller-identity --region=eu-central-1)

  foreach ($Region in $Regions.Regions) {
    $result = (aws ec2 describe-instances --output json --region $($Region.RegionName)) | ConvertFrom-Json    

    foreach ($Reservation in $result.Reservations) {
      foreach ($Instance in $Reservation.Instances) {
        if ($Instances.ContainsKey($Account.ID)) {
          $Instances[$Account.ID].Add($Instance) | Out-Null
        } else {
          $Instances.Add($Account.ID, [System.Collections.ArrayList]@())
          $Instances[$Account.ID].Add($Instance) | Out-Null
        }

      }
    }
  }

  foreach ($val in $Instances.GetEnumerator()) {
    $entries = $val.Value | Select-Object -Property ImageId,InstanceId,LaunchTime,InstanceType,AwsAccountId,AwsAccountName
    foreach ($instance in $entries) {
      $instance.AwsAccountId = $Account.ID
      $instance.AwsAccountName = $Account.Name
    }

    $Payload = $Payload + $entries
  }

}

Write-Output $Payload | ConvertTo-Csv
