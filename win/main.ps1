function SaveLog($srvname, $process, $txt) {
    Add-Content -Path $pathLOG -Value "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")|$srvname|$process] \\> $txt";
    Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")|$srvname|$process] \\> $txt"
}
function SaveCSV($srvname, $interface, $ipv6before, $ipv6after, $comment){
    Add-Content -Path $pathCSV -Value "$srvname,$interface,$ipv6before,$ipv6after,$comment";
}

$rootPath = 'C:\Users\Administrator.AD01\Documents\DisableIPV6'
$listSRVs = Get-Content -Path "$rootPath\servers.txt";
$pathCSV = "$rootPath\output.csv";
$pathLOG = "$rootPath\log.txt";


New-Item -Path $pathCSV -ItemType File -Force -Value "Hostname,Interface,IPv6Before,IPv6After,Comment`n";

$creds = Get-Credential;


foreach($srv in $listSRVs)
{
    SaveLog $srv "Start" "*** Opening Remote Session - $srv***"
    $session = New-PSSession -ComputerName $srv -Credential $creds;
    SaveLog $srv "Session" "Id :$($session.Id), InstanceId: $($session.InstanceId), Name: $($session.Name), ComputerName: $($session.ComputerName), State: $($session.State), IdleTimeout: $($session.IdleTimeout)"
        
    try
    {
        $networkInterfaces = Invoke-Command -Session $session -ScriptBlock {
            Get-NetAdapter;
        } -ErrorAction Stop;
        
        # Iterar sobre cada interfaz de red
        foreach ($interface in $networkInterfaces) {
            SaveLog $srv "Interface" "Name: $($interface.Name), IDescription: $($interface.InterfaceDescription), Status: $($interface.Status), MacAddress: $($interface.MacAddress), LinkSpeed: $($interface.LinkSpeed), ifIndex: $($interface.ifIndex), ifOperStatus: $($interface.ifOperStatus), ifAlias: $($interface.ifAlias)"
            
            # Deshabilitar IPv6 en la interfaz actual
            $ipv6before = Invoke-Command -Session $session -ScriptBlock {
                param($interface);Get-NetAdapterBinding -Name $interface.Name -ComponentID "ms_tcpip6";
            } -ErrorAction Stop -ArgumentList $interface;
            
            SaveLog $srv "$($interface.Name)|Before" "Enabled: $($ipv6before.Enabled), ComponentId: $($ipv6before.ComponentID), Description: $($ipv6before.Description)";

            if($ipv6before.Enabled){
                $ipv6after = Invoke-Command -Session $session -ScriptBlock {
                    param($interface);Disable-NetAdapterBinding -Name $interface.Name -ComponentID "ms_tcpip6" -PassThru
                } -ErrorAction Stop -ArgumentList $interface;
                SaveLog $srv "$($interface.Name)|After" "Enabled: $($ipv6after.Enabled), ComponentId: $($ipv6after.ComponentID), Description: $($ipv6after.Description)";
                SaveCSV $srv $interface.Name $ipv6before.Enabled $ipv6after.Enabled "Applied"
            }else{
                SaveLog $srv "$($interface.Name)|After" "Enabled: $($ipv6before.Enabled), ComponentId: $($ipv6before.ComponentID), Description: $($ipv6before.Description)";
                SaveCSV $srv $interface.Name $ipv6before.Enabled $ipv6before.Enabled "No Applied"
            }
        }
        
    }
    catch
    {
        SaveLog $srv "Error" $_
        SaveCSV $srv "" "" "" $_
    }
    finally
    {
        Remove-PSSession $session
        SaveLog $srv "End" "*** Closing Remote Session - $srv ***"
    }
   
}


