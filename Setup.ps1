#edit
PARAM (
    [string]$user = 'admin',
    [string]$password = (Get-Content -path 'C:\ProgramData\sonatype-work\nexus3\admin.password'),
    [string]$URL, #URL of the nexus repository
    [string]$Product, #Name of the product
    [string]$RepositoryType, #repo type. don't use capital letters.
    [string]$ProxyURL #URL of the to proxy that needs to be created
)

#Do not edit
[string]$baseURL = "$URL/service/rest"
[string]$BlobStorage = "$Product-Blob"
[string]$Repository = "$Product-Repo"
[string]$Proxy = "$Product-Proxy"
[string]$Hosted = "$Product-Hosted"

#Create basic creds
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $Password)))

#region Repositories
#Create Blob storage
$Blobs = invoke-restmethod -Method GET -uri "$baseURL/v1/blobstores" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } #Get blobs
if ($blobs.name -notcontains $BlobStorage) {
    #Create blob storage
    $Jsonbody = (Get-content "$PSScriptroot\json\blob.json").Replace("<BlobStorage>",$BlobStorage)
    
    Write-Host "Creating blob with name $BlobStorage"
    invoke-restmethod -Method Post -uri "$baseURL/v1/blobstores/file" -body $Jsonbody -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" }
} else {
    Write-Host "Blob storage $BlobStorage already exists"
}

#Determ if a proxy is required
If ($ProxyURL) {
    $CreateRepos = "proxy","hosted","group"
} else {
    $CreateRepos = "hosted", "group"
}

#Get current repositories
write-host "Getting repository info"
$repo = invoke-restmethod -Method GET -uri "$baseURL/v1/repositories" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" }

#Prepare the json files for the repositories
Foreach ($Item in $CreateRepos){
    $Jsonbody=""
    Switch ($Item) {
        "proxy" {
            write-host "Preparing `'Proxy`' repository"
            $Name = "$Product-$Item"
            $Jsonbody = (Get-content "$PSScriptroot\json\proxy.json").Replace("<BlobStorage>", $BlobStorage).Replace("<Proxy>", $Proxy).Replace("<ProxyURL>", $ProxyURL)
            break;
        }
        "hosted" {
            write-host "Preparing `'Hosted`' repository"
            $Name = "$Product-$Item"
            $Jsonbody = (Get-content "$PSScriptroot\json\hosted.json").Replace("<BlobStorage>", $BlobStorage).Replace("<Repository>", $Hosted)
            break;
        }
        "group" {
            write-host "Preparing `'Group`' repository"
            $Name = "$Product"
            If ($ProxyURL) {
                $Jsonbody = (Get-content "$PSScriptroot\json\group-proxy.json").Replace("<Product>", $Product).Replace("<Repository>", $Hosted).Replace("<Proxy>", $Proxy).Replace("<BlobStorage>", $BlobStorage)
            }
            else {
                $Jsonbody = (Get-content "$PSScriptroot\json\group.json").Replace("<Product>", $Product).Replace("<Repository>", $Hosted).Replace("<BlobStorage>", $BlobStorage)
            }
            break;
        }
        default {
            throw "$Item is an known repository!"
        }
    }    
    
    #Create the repositories
    if ($repo.name -notcontains $Name) {
        Write-Host "Creating $item repository with name $Repository"
        invoke-restmethod -Method Post -uri "$baseURL/v1/repositories/$RepositoryType/$Item" -body $Jsonbody -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" }
    }
    else {
        Write-Host "Repository $Name already exists"
    }
}
#endregion Repositories

#region security realms
#add Nuget API-Key to the realm
$Realms = invoke-restmethod -Method GET -uri "$baseURL/v1/security/realms/active" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } 
If ($Realms -notcontains 'NuGetApiKey') {
    $Jsonbody = Get-content "$PSScriptroot\json\nugetrealm.json"
    Write-Host "Adding 'NuGetApiKey' to the security realm"
    invoke-restmethod -Method Put -uri "$baseURL/v1/security/realms/active" -body $Jsonbody -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" }
} else {
    Write-Host "'NuGetApiKey' is already a member of the security realm"
}

#Enable anonymous login
$Security = invoke-restmethod -Method GET -uri "$baseURL/v1/security/anonymous" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } 
if($Security.enabled -ne 'True') {
    Write-Host "Enabling anonymous authentication"
    $Jsonbody = Get-content "$PSScriptRoot\json\anonymous.json"
    invoke-restmethod -Method PUT -uri "$baseURL/v1/security/anonymous" -body $Jsonbody -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } 
} else {
    Write-Host "Anonymous authentication is already enabled"
}
#endregion security realms