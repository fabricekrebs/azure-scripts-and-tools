# This file contains all steps required to create, package, test, apply and publish a DSC configuration
# Define the configuration
Configuration EnsureFirewallDomainProfile
{
    Import-DscResource -ModuleName 'PSDscResources'

    Node localhost
    {
        Script SetFirewall
        {
            GetScript = {
                @{
                    GetScript = {
                        $firewall = Get-NetFirewallProfile -Profile Domain
                        return @{ Result = $firewall.Enabled }
                    }
                    TestScript = {
                        $firewall = Get-NetFirewallProfile -Profile Domain
                        return $firewall.Enabled -eq 'True'
                    }
                    SetScript = {
                        Set-NetFirewallProfile -Profile Domain -Enabled True
                    }
                }
            }
            TestScript = {
                $firewall = Get-NetFirewallProfile -Profile Domain
                return $firewall.Enabled -eq 'True'
            }
            SetScript = {
                Set-NetFirewallProfile -Profile Domain -Enabled True
            }
        }
    }
}

EnsureFirewallDomainProfile

# Create a package that will only audit compliance
$params = @{
    Name          = 'EnsureFirewallDomainProfile'
    Configuration = './EnsureFirewallDomainProfile/localhost.mof'
    Type          = 'AuditAndSet'
    Force         = $true
}
New-GuestConfigurationPackage @params