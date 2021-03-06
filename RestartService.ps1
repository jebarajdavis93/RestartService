#Parameters Domain(not FQDN), User name and Password
Param ([string]$ConfigXML)

#Generating Credential object
function ServerCredential
{
	Param([string]$domain, [string]$userName, [string]$password)
	$objPassword = $password | ConvertTo-SecureString -asPlainText -Force;
	$objUsername = $domain + "\" + $userName;
	$credential = New-Object System.Management.Automation.PSCredential($objUsername,$objPassword);
	return $credential
}

#List all the servers in the domain
function Get-Domain-Servers
{
	Param ([string]$computerName, [System.Management.Automation.PSCredential]$cred)
	Invoke-Command -ScriptBlock {Import-Module ActiveDirectory; $listServers = Get-ADComputer -Filter * -Property IPv4Address; $listServers} -ComputerName $computerName -Authentication Default -Credential $cred;
}

#Add the server to Trusted hosts
function AddToTrustedHosts
{
	Param ([string]$computerName)
	set-item wsman:\localhost\client\trustedhosts -Value $computerName  -Force -Confirm:$false;
}

#---------------Execution Starts Here----------------------
Write-Host "Script execution started."
$global:currentDirectory = get-location
[XML]$global:serverList = get-content $ConfigXML;
[System.Collections.ArrayList]$resultArray = @() 
[System.Collections.ArrayList]$serviceArray = @()
$global:cred = ServerCredential -domain $serverList.ServerServices.Domain -userName $serverList.ServerServices.UserName -password $serverList.ServerServices.Password
#Get LocalIPAddress
$global:localIPAddress = (gwmi Win32_NetworkAdapterConfiguration|?{$_.ipenabled}).IPAddress
$commaSeperatedJobIds="";
ForEach($serverservice in $serverList.ServerServices.ServerService) {
            Invoke-Command -scriptblock {
                ForEach ($server in $serverservice.ServerList.Split(",")) {
                        #Iterate through services
                        ForEach ($serviceName in $serverservice.ServiceList.Split(",")) {
                            $name = $serviceName.Trim();
                            #Get service status
                            if($server.Trim() -eq $localIPAddress[0])
                            {
							$service = Get-Service -DisplayName "$name" }
                            else
                            {
							#$service = Get-WMIObject Win32_Service -ComputerName $server.Trim() -Credential $cred -Filter "DisplayName LIKE '$name'" 
							$service = Get-Service -ComputerName $server.Trim() -DisplayName "$name" }
                            #start-job -name restart -scriptblock { Restart-Service -InputObject $service }
							$running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
							if ($running.Count -le 8) {
								Start-Job {
									 $list = Invoke-Command -ComputerName $server.Trim() -scriptblock { Restart-Service -DisplayName $args[0] } -argumentList $name
								}
							} else {
								 $running | Wait-Job
							}
							Get-Job | Receive-Job
								#Write-Host $name" status is " $service.Status "and repeat count is "$maxRepeat "on "$server.Trim()
							#$service.Refresh();                           
                        }
                    }
            }
    }
	#wait-job -name restart
	ForEach($serverservice in $serverList.ServerServices.ServerService) {
            Invoke-Command -scriptblock {
                ForEach ($server in $serverservice.ServerList.Split(",")) {
                        #Iterate through services
                        ForEach ($serviceName in $serverservice.ServiceList.Split(",")) {
                            $name = $serviceName.Trim();
                            #Get service status
                            if($server.Trim() -eq $localIPAddress[0])
                            {
							$service = Get-Service -DisplayName "$name" }
                            else
                            {
							#$service = Get-WMIObject Win32_Service -ComputerName $server.Trim() -Credential $cred -Filter "DisplayName LIKE '$name'" 
							$service = Get-Service -ComputerName $server.Trim() -DisplayName "$name" }
							$maxRepeat=0;
							Write-Host  "inside " $server " service status is "$service.Status "Max-Repeat is " $maxRepeat
							while($service.Status -ne 'Running' -and $maxRepeat -lt 10)							{							
								$service.Refresh();
								sleep -Seconds 10
								$maxRepeat++;
								Write-Host  "inside " $server " service status is "$service.Status "Max-Repeat is " $maxRepeat
							}
                            $objService = [PSCustomObject] @{ ServerName = $server; ServiceName = $name; ServiceStatus = $service.Status; }
                            $serviceArray.Add($objService);
                            
                        }
                    }
            }
    }
 $outputReport = "<HTML><TITLE align=center> Server Health Check Report </TITLE> 
                     <BODY background-color:peachpuff> 
                     <font color =""#99000"" face=""Microsoft Tai le""> 
                     <H2> Restart service Report </H2></font> 
                     <font color =""#0000FF"" face=""Microsoft Tai le""> 
                   <H3> Service Status On Individual Node</H3></font>
                   <Table border=1 cellpadding=0 cellspacing=0> 
                        <TR bgcolor=""#CED8AB""><TD><B>ServerName</B></TD>
                        <TD><B>Service Name</B></TD> 
                        <TD><B>Service Status</B></TD></TR>";

#Service status report
Foreach($serviceEntry in $serviceArray)  {

    if($serviceEntry.ServiceStatus -eq $null)
    {$tableData = "<TD align=center bgcolor=""grey"">Service Not Available</TD>";}
    elseif(($serviceEntry.ServiceStatus -eq "Started") -OR ($serviceEntry.ServiceStatus -eq "Running"))
    {$tableData = "<TD align=center bgcolor=""green"">$($serviceEntry.ServiceStatus)</TD>";}
    elseif(($serviceEntry.ServiceStatus -eq "Stopped"))
    {$tableData = "<TD align=center bgcolor=""red"">$($serviceEntry.ServiceStatus)</TD>";}
    else
    {$tableData = "<TD align=center bgcolor=""red"">$($serviceEntry.ServiceStatus)</TD>";}

    $outputReport +="<TR><TD align=center>$($serviceEntry.ServerName)</TD><TD align=center>$($serviceEntry.ServiceName)</TD>" + $tableData + "</TR>";
}
$outputReport += "</Table><BR /></BODY></HTML>";
$fileName = "Results_" + $serverList.ServerServices.Domain + [DateTime]::Now.ToString("yyyyMMddHHmmss") + ".htm"
$outputReport | out-file (Join-Path $currentDirectory.Path -childPath $fileName);  

Write-Host "Script execution completed and results file " $fileName " available in " $currentDirectory.Path " path";
#----------------- Execution ends here--------------------------------------


