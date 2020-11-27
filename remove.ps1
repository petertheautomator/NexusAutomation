<#
    Usage: ./remove.ps1 -URL http://<yourhost> -user <username> -Password <password>
#> 
PARAM (
    [string]$user = 'admin',
    [string]$password = (Get-Content -path 'C:\ProgramData\sonatype-work\nexus3\admin.password'),
    [string]$URL
)

#Do not edit
[string]$baseURL = "$URL/service/rest"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $Password)))
[array]$Defaultrepos = 'maven','nuget'

#Remove default repos
$repos = invoke-restmethod -Method GET -uri "$baseURL/v1/repositories" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } 

#Find removals
foreach($r in $Defaultrepos) { $removals += $repos.name | Where-Object { $_ -like "$r*" }}

#Remove repos
Foreach ($repo in $removals) {
    Write-host "Removing $repo repository"
    invoke-restmethod -method DELETE -Uri "$baseURL/v1/repositories/$repo" -ContentType "application/json" -Headers @{Authorization = "Basic $base64AuthInfo" } 
}
