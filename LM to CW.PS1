###############################################################################
#                            LOGICMONITOR                                     #
###############################################################################
#Pull all LM devices
#LM API information
$AccessKey = ""  
$AccessId = "" 
$Company = '' 
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
#take only devices that are device type 0
#These are normal non-cloud devices in LM
$devicetype0 = @()
foreach ($device in $allDevices){
    if($device.devicetype -eq 0){
    $devicetype0 += $device
    }
}

###############################################################################
#                            Connectwise                                      #
###############################################################################

#API information from ConnectWise
$PrivateKey = "" 
$PublicKey  = ""
$Company    = ""
$ClientID   = ""

Connect-CWM -ClientID $ClientID -Company $Company -PrivateKey $PrivateKey -PubKey $PublicKey -Server https://sandbox-na.myconnectwise.net

$CWAlldevicesCollection = Get-CWMCompanyConfiguration -all

# Get-CWMCompanyConfiguration creates groups of 999 devices each
# This moves them all into a single array rather than being grouped seperately
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

#sort so matching is faster
$devicetype0 = $devicetype0 |sort -Descending
$CWDevices = $CWDevices |sort -Descending

#match devices by name
# I should look into removing devices from their arrays after something is done with them
# This could hopefully speed up the script at least a little bit, Current run time is about 3 hours
"Comparing Devices" 
foreach ($LMDevice in $devicetype0){
"Next Device"
    $ismatch = $null
        foreach ($CWDevice in $CWDevices){

        #Get CompanyID
        $CompanyID = 19298
        $LMdevice.inheritedProperties.ForEach({if($_.name -eq 'connectwisev2.companyid'){$LMCompanyID = $_.value}})
        #Set SysOS to a default so that devices without it don't get set to the previous device value
        $SysOS = 'None Found'
        #Set SysOS to the devices OS information in LM
        $LMDevice.systemProperties.ForEach({if($_.name -eq 'system.sysinfo'){$SysOS = $_.value}})
        
        #Connectwise doesn't accept letters in the IP address field
        # Any devices that are being monitored by Hostname will have thier IP changed to 127.0.0.1
        if ($LMDevice.name -match "[a-z]"){$LMDevice.name = '127.0.0.1'}
        
        #Set devicename and IP
        $LMname = $LMDevice.displayName
        $IPaddress = "$LMIP"


            #if the name and CompanyID match in both arrays then the information will be synced
            #Otherwise if the device has no matches then it will be added
             if($lmdevice.displayname -eq $CWDevice.name -and $LMCompanyID -eq $CWDevice.company.id){

                $ismatch = 'true'
                $devicename = $lmdevice.displayname 
                $cwdevicename = $CWDevice.name 
                Write-Output "Syncing " + $CWDevice.name
                ##########################################################
                #                   update device                        #
                ##########################################################
                
                #IPaddress
                    Update-CWMCompanyConfiguration -id $CWDevice.id -Operation replace -Path ipAddress -Value $LMDevice.name
                #OS
                    Update-CWMCompanyConfiguration -id $CWDevice.id -Operation replace -Path osInfo -Value $SysOS
                    
                    continue

         }
         

}

if($ismatch -ne 'true') {
$devicename = $LMDevice.displayname
"No Match for $devicename......... adding device"

##################################################################
#                         Add Device                             #
##################################################################
$LMDevice.inheritedProperties.ForEach({if($_.name -eq 'cw_Type'){$DeviceType = $_.value}})
        $company = @{"id"="$CompanyID"}
        $type = @{"name"="$DeviceType"}

New-CWMCompanyConfiguration -company $company -name $LMname -type $type -ipAddress $IPaddress -osinfo $SysOS -notes $notes

}
}

