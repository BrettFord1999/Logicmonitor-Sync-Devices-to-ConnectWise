###############################################################################
#                            LOGICMONITOR                                     #
###############################################################################

$AccessKey = "********************************"  
$AccessId = "*****************" 
$Company = 'Company Name' 
#Create list to keep devices 
$allDevices = @() 
#Loop through getting all devices 
$count = 0 
$done = 0 
while ($done -eq 0){    
    #Request Info 
    $httpVerb ='GET' 
    $resourcePath = '/device/devices' 
    $data='' 
    $queryParams ='?offset='+ "$count"+'&size=999' 
    #Construct URL  
    $url = 'https://'+ $Company +'.logicmonitor.com/santaba/rest' + $resourcePath + $queryParams 
    #Get current time in milliseconds 
    $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds) 
    #Concatenate Request details 
    $requestVars = $httpVerb + $epoch + $data + $resourcePath 
    #Construct signature 
$hmac = New-Object System.Security.Cryptography.HMACSHA256     
$hmac.Key = [Text.Encoding]::UTF8.GetBytes($AccessKey)     
$signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))     
$signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'     
$signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower())) 
#Construct headers 
$auth = 'LMv1 ' + $AccessId + ':' + $signature + ':' + $epoch     
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"     
$headers.Add("Authorization",$auth)     
$headers.Add("Content-Type",'application/json') 
$headers.Add("x-version",3)   
    #Make request 
    $response = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers  
    #Parse response & total devices returned 
     
    $allDevices += $response.items 
    $count = $allDevices.Count 
    $total = $response.total 
    if ($count -eq $total){ 
        Write-Output "All LM Devices pulled" 
        $done = 1}  
}

$devicetype0 = @()
foreach ($device in $allDevices){
    if($device.devicetype -eq 0){
    $devicetype0 += $device
    }
}

###############################################################################
#                            Connectwise                                      #
###############################################################################

$PrivateKey = "*************" 
$PublicKey  = "*************"
$Company    = "Company Name"
$ClientID   = "***********************"
#$URI = 'https://na.myconnectwise.net/v4_6_release/apis/3.0/company/configurations'

Connect-CWM -ClientID $ClientID -Company $Company -PrivateKey $PrivateKey -PubKey $PublicKey -Server https://na.myconnectwise.net

$CWAlldevicesCollection = Get-CWMCompanyConfiguration -all
$CWDevices = @()
$counter = $CWAlldevicesCollection.count
while ($counter -gt -1){
    $CWDevices += $CWAlldevicesCollection[$counter]

    $counter -=1
}
"All CW Devices pulled"
###############################################################################
#                           Device Matching                                   #
###############################################################################

$devicetype0 = $devicetype0 |sort -Descending
$CWDevices = $CWDevices |sort -Descending

#match devices by name
"Comparing Devices" 
foreach ($LMDevice in $devicetype0){
"device"
    $ismatch = $null
        foreach ($CWDevice in $CWDevices){

        
        $CompanyID = 19298
        $LMdevice.inheritedProperties.ForEach({if($_.name -eq 'connectwisev2.companyid'){$LMCompanyID = $_.value}})
        #$LMDevice|select -ExpandProperty inheritedproperties |ForEach-Object {
        #if($_.name -eq 'connectwisev2.companyid') {$CompanyID = $_.value}
        #}

        $SysOS = 'None Found'
        $LMDevice.systemProperties.ForEach({if($_.name -eq 'system.sysinfo'){$SysOS = $_.value}})
        #$LMDevice|select -ExpandProperty systemproperties |ForEach-Object {
        #if($_.name -eq 'system.sysinfo') {$SysOS = $_.value}
        #}
        if ($LMDevice.name -match "[a-z]"){$LMDevice.name = '127.0.0.1'}
                $LMname = $LMDevice.displayName
                $LMIP = $lmdevice.name


        $IPaddress = "$LMIP"
        $ostype = "$SysOS"
        #$properties = $LMDevice.systemProperties + $LMDevice.autoProperties
        #$notes = $properties |Out-String


             if($lmdevice.displayname -eq $CWDevice.name -and $LMCompanyID -eq $CWDevice.company.id){

                $ismatch = 'true'
                $devicename = $lmdevice.displayname 
                $cwdevicename = $CWDevice.name 
                Write-Output "$devicename matches $cwdevicename"
                ##########################################################
                #                   update device                        #
                ##########################################################
                #had comparison if statements here to only update changes but it made the script take forever
                
                #IPaddress
                    Update-CWMCompanyConfiguration -id $CWDevice.id -Operation replace -Path ipAddress -Value $LMDevice.name
                #Notes
                    #Update-CWMCompanyConfiguration -id $CWDevice.id -Operation replace -Path notes -Value $Notes
                #OS
                    Update-CWMCompanyConfiguration -id $CWDevice.id -Operation replace -Path osInfo -Value $SysOS
                    
                    continue

         }
         

}

if($ismatch -ne 'true') {
$devicename = $LMDevice.displayname
"No Match for $devicename......... adding device"

##################################################################
#Add Device

$LMDevice.inheritedProperties.ForEach({if($_.name -eq 'cw_Type'){$DeviceType = $_.value}})
        $company = @{"id"="$CompanyID"}
        $name = "$LMname"
        $type = @{"name"="$DeviceType"}

New-CWMCompanyConfiguration -company $company -name $name -type $type -ipAddress $IPaddress -osinfo $ostype -notes $notes

}
}
