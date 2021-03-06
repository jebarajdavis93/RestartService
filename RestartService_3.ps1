Param ([string]$PathToListOfNodes)
write-host "Execution started"
$start=Get-Date;
$serviceName = "iSite Monitor"
[System.Collections.ArrayList]$serviceArray = @()
Invoke-Command -ComputerName (get-content $PathToListOfNodes) {Restart-Service -DisplayName "iSite Monitor"}
$servers = get-content $PathToListOfNodes;
ForEach ($server in $servers) {
		#Iterate through services
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
			while($service.Status -ne 'Running' -and $maxRepeat -lt 10)	{							
				$service.Refresh();
				sleep -Seconds 10
				$maxRepeat++;
				Write-Host  "inside " $server " service status is "$service.Status "Max-Repeat is " $maxRepeat
			}
			$objService = [PSCustomObject] @{ ServerName = $server; ServiceName = $name; ServiceStatus = $service.Status; }
			$serviceArray.Add($objService);
}
 $outputReport = "<HTML><TITLE align=center> Restart Service Report </TITLE> 
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
$end=Get-Date
write-host "Execution completed in " ($start-$end).TotalSeconds