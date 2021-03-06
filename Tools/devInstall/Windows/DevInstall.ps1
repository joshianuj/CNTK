﻿#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
#
<#
  .SYNOPSIS
 Use this cmdlet to install a CNTK development environment on your machine

 .DESCRIPTION
 The script will download and install the files necessary to create a CNTK development environment on your system. 

 It will analyse your machine and will determine which components are required. 
 The required components will be downloaded in [c:\installCacheCntk]
 Repeated operation of this script will reuse already downloaded components.

 .PARAMETER Execute
 This is an optional parameter. Without setting this switch, no changes to the machine setup/installation will be performed

  .PARAMETER NoGpu
 This is an optional parameter. By setting this switch the GPU specific tools (Cuda, CuDnn, Cub) will not be installed.

 .PARAMETER localCache
 This optional parameter can be used to specify the directory downloaded components will be stored in

 .PARAMETER AnacondaBasePath
 This is an optional parameter and can be used to specify an already installed Anaconda3 installation.
 By default a version of Anaconda3 will be installed into [C:\local\Anaconda3-4.1.1-Windows-x86_64]

 .EXAMPLE
 .\devInstall.ps1
 
 Run the installer and see what operations would be performed
 .EXAMPLE
 .\devInstall.ps1 -Execute
 
 Run the installer and install the development tools
 
 .EXAMPLE
 .\devInstall.ps1 -Execute -AnacondaBasePath d:\mytools\Anaconda34

 If the directory [d:\mytools\Anaconda34] exists, the installer will assume it contains a complete Anaconda installation. 
 If the directory doesn't exist, Anaconda will be installed into this directory.

#>

[CmdletBinding()]
Param(
    [parameter(Mandatory=$false)] [switch] $Execute,
    [parameter(Mandatory=$false)] [string] $localCache = "c:\installCacheCntk",
    [parameter(Mandatory=$false)] [string] $InstallLocation = "c:\local",
    [parameter(Mandatory=$false)] [string] $AnacondaBasePath = "C:\local\Anaconda3-4.1.1-Windows-x86_64")
    
$roboCopyCmd = "robocopy.exe"
$localDir = $InstallLocation


# Get the current script's directory
$MyDir = Split-Path $MyInvocation.MyCommand.Definition

$CloneDirectory = Split-Path $mydir
$CloneDirectory = Split-Path $CloneDirectory
$CloneDirectory = Split-Path $CloneDirectory

$reponame = Split-Path $CloneDirectory -Leaf
$repositoryRootDir = Split-Path $CloneDirectory

$solutionfile = Join-Path $CloneDirectory "CNTK.SLN"

if (-not (Test-Path -Path $solutionFile -PathType Leaf)) {
    Write-Warning "The install script was started out of the [$mydir] location. Based on this"
    Write-Warning "[$CloneDirectory] should be the location of the CNTK sourcecode directory."
    Write-Warning "The specified directory is not a valid clone of the CNTK Github project."
    throw "Terminating install operation"
}


. "$MyDir\helper\Display"
. "$MyDir\helper\Common"
. "$MyDir\helper\Operations"
. "$MyDir\helper\Verification"
. "$MyDir\helper\Download"
. "$MyDir\helper\Action"
. "$MyDir\helper\PreRequisites"

Function main
{
    try { if (-not (DisplayStart)) {
            Write-Host 
            Write-Host " ... Quitting ... "
            Write-Host
            return
        }
    
        if (-not (Test-Path -Path $localCache)) {
            new-item -Path $localcache -ItemType Container -ErrorAction Stop | Out-Null
        }

        ClearScriptVariables

        $operation = @();
        $operation += OpScanProgram
        $operation += OpCheckVS15Update3

        $operation += OpCheckCuda8
        $operation += OpNVidiaCudnn5180 -cache $localCache -targetFolder $localDir
        $operation += OpNvidiaCub141 -cache $localCache -targetFolder $localDir

        $operation += OpCMake362 -cache $localCache
        $operation += OpMSMPI70 -cache $localCache
        $operation += OpMSMPI70SDK -cache $localCache
        $operation += OpBoost160VS15 -cache $localCache -targetFolder $localDir
        $operation += OpCNTKMKL3 -cache $localCache -targetFolder $localDir
        $operation += OpSwig3010 -cache $localCache -targetFolder $localDir
        $operation += OpProtoBuf310VS15 -cache $localCache -targetFolder $localDir -repoDirectory $CloneDirectory
        $operation += OpProtoBuf310VS15Prebuild -cache $localCache -targetFolder $localDir
        $operation += OpZlibVS15 -cache $localCache -targetFolder $localDir -repoDirectory $CloneDirectory
        $operation += OpZlibVS15Prebuild -cache $localCache -targetFolder $localDir
        $operation += OpOpenCV31 -cache $localCache -targetFolder $localDir
        $operation += OpAnaconda3411 -cache $localCache -AnacondaBasePath $AnacondaBasePath
        $operation += OpAnacondaEnv34 -AnacondaBasePath $AnacondaBasePath -repoDir $repositoryRootDir -repoName $reponame

        $operationList = @()
        $operationList += (VerifyOperations $operation)

        PreReqOperations $operationList

        if (DisplayAfterVerify $operationList) {

            DownloadOperations $operationList 

            ActionOperations $operationList 

            DisplayEnd
        }
    }
    catch {
        Write-Host "Exception caught - function main / failure"
        Write-Host ($Error[0]).Exception
        Write-Host
    }
}

main

exit 0

# vim:set expandtab shiftwidth=2 tabstop=2: