# AD Cloud USer Sanity-check

Check for common issues for user accounts that are meant to be used in AWS, Azure DevOps etc.

## Example Usage

Example command:

```Powershell
.\Check-ADUserCloud.ps1 raras, ruabr
```

Example output:

```
CN=Rask Rasmus (DFDS A/S),OU=Data Centres,OU=Support & Infrastructure,OU=IT,OU=DFDS AS,DC=dk,DC=dfds,DC=root
 - User Principal Name suffix (UPN-suffix) should be 'dfds.com':  OK (is 'DFDS.COM')
 - Mail address field must be populated:                          OK (is 'raras@dfds.com')
 - Email address and UPN should match:                            OK (UPN: raras@DFDS.COM, Mail: raras@dfds.com)
 - Email address and UPN should match:                            OK (UPN: raras@DFDS.COM, Mail: raras@dfds.com)
 - Account should probably be in DK domain:                       OK (is 'dk.dfds.root')

CN=Abrahamsson Rune (DFDS A/S),OU=Temps,OU=Support & Infrastructure,OU=IT,OU=DFDS AS,DC=dk,DC=dfds,DC=root
 - User Principal Name suffix (UPN-suffix) should be 'dfds.com':  OK (is 'DFDS.COM')
 - Mail address field must be populated:                          OK (is 'ruabr@dfds.com')
 - Email address and UPN should match:                            OK (UPN: ruabr@DFDS.COM, Mail: ruabr@dfds.com)
 - Email address and UPN should match:                            OK (UPN: ruabr@DFDS.COM, Mail: ruabr@dfds.com)
 - Account should probably be in DK domain:                       OK (is 'dk.dfds.root')

See https://wiki.build.dfds.com/infrastructure/user-accounts for more info.
```