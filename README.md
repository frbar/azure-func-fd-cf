# Purpose

This repository contains a Terraform template to setup 2 indentical Azure Functions, in 2 different regions, and Azure Front Door as load balancer in front, and a domain name in Cloudflare.

# PowerShell script (Windows) to deploy the infrastructure, build and deploy the functions

```powershell
az login

$subscription = "Training Subscription"
az account set --subscription $subscription

# Configuration

$envName = "frbar111" # lowercase, only a-z and 0-9
$location1 = "West Europe"
$location2 = "North Europe"

$env:CF_API_TOKEN  = "xxx"
$env:CF_ZONE_ID    = "xxx"
$env:CF_DOMAIN     = "xxx"

# Infrastructure provisioning

./terraform.exe -chdir=tf init
./terraform.exe -chdir=tf apply -var "env_name=$($envName)" `
                                -var "location1=$($location1)" `
                                -var "location2=$($location2)" `
                                -var "cf_zone_id=$($env:CF_ZONE_ID)" `
                                -var "cf_api_token=$($env:CF_API_TOKEN)" `
                                -var "cf_domain=$($env:CF_DOMAIN)" `
                                -auto-approve

# Build of the function

remove-item publish\* -recurse -force
dotnet publish src\ -c Release -o publish
Compress-Archive publish\* publish.zip -Force

# Deployments of the function

az functionapp deployment source config-zip --src .\publish.zip -n "$($envName)-func-0" -g "$($envName)-rg"
az functionapp deployment source config-zip --src .\publish.zip -n "$($envName)-func-1" -g "$($envName)-rg"

echo "done!"
```

# Tear down

```powershell
az group delete --name "$($envName)-rg"
```