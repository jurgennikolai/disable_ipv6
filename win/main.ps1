
$rootPath = 'C:\ruta\del\script';
$listSRVs = Get-Content -Path "$rootPath\servers.txt";

$creds = Get-Credential;

foreach($srv in $listSRVs)
{
    $session = New-PSSession -ComputerName $srv -Credential $creds;
    try
    {
        $networkInterfaces = Invoke-Command -Session $session -ScriptBlock {
            Get-NetAdapter;
        } -ErrorAction Stop;
        
        foreach ($interface in $networkInterfaces) {
            
            $ipv6before = Invoke-Command -Session $session -ScriptBlock {
                param($interface);Get-NetAdapterBinding -Name $interface.Name -ComponentID "ms_tcpip6";
            } -ErrorAction Stop -ArgumentList $interface;

            if($ipv6before.Enabled){
                $ipv6after = Invoke-Command -Session $session -ScriptBlock {
                    param($interface);Disable-NetAdapterBinding -Name $interface.Name -ComponentID "ms_tcpip6" -PassThru
                } -ErrorAction Stop -ArgumentList $interface;
            }
        }
    }
    catch
    {
        $_; 
    }
    finally {
        Remove-PSSession $session;
    }
}


