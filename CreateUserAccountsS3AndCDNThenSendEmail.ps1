$TCUser="techatagoda"
$TCPassword="xxx"
$S3Region="ap-southeast-1"

$S3AccessKey="zzz"
$S3SecretKey="yyy"
$baseUri = "http://octopus01.southeastasia.cloudapp.azure.com"
$apiKey = "API-aaa"
$TeamCityServerUrl="http://teamcity01.southeastasia.cloudapp.azure.com"
#========================

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
$sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$targetNugetExe = "nuget.exe"
Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe
Set-Alias nuget $targetNugetExe -Scope Global -Verbose
./nuget.exe install Octopus.Client


$x = 27
 foreach( $Attendee in (Import-Csv c:\users.txt))
 {
 Write-Host "============================================"
 Write-Host "    BEGIN PROCESSING   "
 Write-Host $Attendee.username
 Write-Host "============================================"

$EmailAddress=$Attendee.emailaddress
$UserName =$Attendee.username
$Password ="Wednesday$x!"
$x= $x +1 
Add-Type -Path .\Octopus.Client.4.15.2\lib\net45\Octopus.Client.dll

# Octopus create User

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $baseUri, $apiKey

$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$User = New-Object Octopus.Client.Model.UserResource

$User.EmailAddress = $EmailAddress
$User.DisplayName=$UserName 
$User.Username=$UserName
$User.Password=$Password

$repository.Users.Create($User)

# REMEBER TO add to admin group - MANUAL

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $TCUser,$TCPassword)))
    

# TeamCity Create user

$authorization = "Basic " + $base64AuthInfo

$newUser= "<user username='$UserName' name='$UserName' email='$EmailAddress' password='$Password' />"

Invoke-RestMethod "$TeamCityServerUrl/httpAuth/app/rest/users" -Body $newUser -Method POST -Headers @{"AUTHORIZATION" = $authorization;"accept"="application/xml";"Content-Type"="application/xml"} -UseBasicParsing

Invoke-RestMethod "$TeamCityServerUrl/httpAuth/app/rest/users/username:$UserName/roles/SYSTEM_ADMIN/g" -Method PUT -Headers @{"AUTHORIZATION" = $authorization;"accept"="application/xml";"Content-Type"="application/xml"} -UseBasicParsing

#Initialises the S3 Credentials based on the Access Key and Secret Key provided, so that we can invoke the APIs further down
Set-AWSCredentials -AccessKey $S3AccessKey -SecretKey $S3SecretKey 

#Initialises the Default AWS Region based on the region provided
Set-DefaultAWSRegion -Region $S3Region

# create s3 bucket
$BucketName = ("TechAtAgoda$UserName").ToLower()
New-S3Bucket -BucketName $BucketName  -Region $S3Region 

Write-S3BucketWebsite -BucketName $BucketName -WebsiteConfiguration_IndexDocumentSuffix index.html -WebsiteConfiguration_ErrorDocument error.html

$WebSiteDnsName = "$BucketName.s3.amazonaws.com"

# enable for cdn and get address
$origin = New-Object Amazon.CloudFront.Model.Origin
$origin.DomainName = $WebSiteDnsName
$origin.Id = "UniqueOrigin1$BucketName"
$origin.S3OriginConfig = New-Object Amazon.CloudFront.Model.S3OriginConfig
$origin.S3OriginConfig.OriginAccessIdentity = ""
$cloudfront = New-CFDistribution `
      -DistributionConfig_Enabled $true `
      -DistributionConfig_Comment "Test distribution" `
      -Origins_Item $origin `
      -Origins_Quantity 1 `
      -Logging_Enabled $false `
      -Logging_IncludeCookie $true `
      -Logging_Bucket "" `
      -Logging_Prefix "" `
      -DistributionConfig_CallerReference "Client1$UserName" `
      -DistributionConfig_DefaultRootObject index.html `
      -DefaultCacheBehavior_TargetOriginId $origin.Id `
      -ForwardedValues_QueryString $true `
      -Cookies_Forward all `
      -WhitelistedNames_Quantity 0 `
      -TrustedSigners_Enabled $false `
      -TrustedSigners_Quantity 0 `
      -DefaultCacheBehavior_ViewerProtocolPolicy allow-all `
      -DefaultCacheBehavior_MinTTL 1000 `
      -DistributionConfig_PriceClass "PriceClass_All" `
      -CacheBehaviors_Quantity 0 `
      -Aliases_Quantity 0

$cloudFrontUrl = $cloudfront.Location

$BodyText ="Hi,

$EmailAddress 

Welcome to the Tech@Agoda 'Lets DO CI and CD' Demo servers. Below are the details you will need.

TEAM CITY SERVER
http://teamcity01.southeastasia.cloudapp.azure.com
Username: $UserName
Password: $Password

OCTOPUS SERVER
http://octopus01.southeastasia.cloudapp.azure.com
Username: $UserName
Password: $Password

AWS CloudFront and S3 Details
Regin: $S3Region
S3 Bucket Name: $BucketName
S3 Access Key: $S3AccessKey
S3 Secret Key: $S3SecretKey
CloudFront CDN Url: $cloudFrontUrl

You will also get an invite to teh slack group, please login and join the general channel to caht to us.

Please fork this repo on GitHub and clone it locally AFTER YOU FORK IT, https://github.com/tech-at-agoda/Todo-app-sample

If you would like to build the solution on your local (not required for the meetup) you will need to dowload the preview edition of Visual Studio 2017 https://www.visualstudio.com/thank-you-downloading-visual-studio/?ch=pre&sku=Community&rel=15#

Regards,
Joel Dickson
Head Cheerleader
Agoda

Sent to $EmailAddress
"

$BodyText | Out-File "meetup\$UserName.txt"

Send-MailMessage -From "Tech at Agoda <techatagoda@xxxx.ccc>" -To $EmailAddress -Subject "Tech@Agoda Let's Do CI and CD Event - DRY RUN" -Body $BodyText -Priority High -SmtpServer "your_smtp_server" 
}
