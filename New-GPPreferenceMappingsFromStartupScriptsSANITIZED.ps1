<#
	.SYNOPSIS
		Converts old logon batch files into Group Policy Preference XML

	.DESCRIPTION
		Scans through all filtered batch files, and extracts net use statments, it then formats them into 
        XML suitable to be pasted into the Drives.xml document that creates your Drive Mappings in GP Preferences
        The <drive></drive> elements should all be pasted within the <drives></drives> elements in the Drives.xml 
        production file in your SYSVOL

	.EXAMPLE
		.\New-GPPreferenceMappingsFromStartupScriptsSANITIZED.ps1

    .EXAMPLE
        Example logon script
        ifmember.exe "SiteCode Staff Group"
        Net Use X \\FSSiteCodePath

        Ifmember.exe "SiteCode Stu Group"
        Net use X \\FSSiteCode\Path

	.OUTPUTS
		.\XMLStu.xml

	.OUTPUTS
		.\XMLStu.xml

	.NOTES
        Name: New-GPPreferenceMappingsFromStartupScripts
		Author: Smartguy5000
		Created: 2016-07-25
		Version: 1.0.0.0


#>
Function Create-XML($inObj)
    {
    
        #begin drive element
        $xmlWriter.WriteStartElement('Drive')
        $xmlWriter.WriteAttributeString('clsid',$($inObj.CLSID))
        $xmlWriter.WriteAttributeString('name', "$($inObj.name)")
        $xmlWriter.WriteAttributeString('status', "$($inObj.driveLetter):")
        $xmlWriter.WriteAttributeString('image', '0')
        $xmlWriter.WriteAttributeString('changed', $(get-date -uformat "%Y-%m-%d %T"))
        $xmlWriter.WriteAttributeString('uid',"{$([guid]::NewGuid().ToString())}")
        $xmlWriter.WriteAttributeString('bypassErrors', '1')
    
        #begin properties element
        $xmlWriter.WriteStartElement('Properties')
        $xmlWriter.WriteAttributeString('action',"R")
        $xmlWriter.WriteAttributeString('thisDrive',"NOCHANGE")
        $xmlWriter.WriteAttributeString('allDrives',"NOCHANGE")
        $xmlWriter.WriteAttributeString('userName',"")
        $xmlWriter.WriteAttributeString('path',"$($inObj.path)")
        $xmlWriter.WriteAttributeString('label',"$($inObj.label)")
        $xmlWriter.WriteAttributeString('persistent',"0")
        $xmlWriter.WriteAttributeString('useLetter',"1")
        $xmlWriter.WriteAttributeString('letter',"$($inObj.driveLetter)")

        #end properties element
        $xmlwriter.WriteEndElement()
    
        #begin filters element
        $xmlWriter.WriteStartElement('Filters')

        #begin filterGroup element
        $xmlWriter.WriteStartElement('FilterGroup')
        $xmlWriter.WriteAttributeString('bool', "AND")
        $xmlWriter.WriteAttributeString('not', "0")
        $xmlWriter.WriteAttributeString('name', "$NetbiosShortName\$($inObj.Group)")
        $xmlWriter.WriteAttributeString('sid', "$($inObj.Sid.ToString())")
        $xmlWriter.WriteAttributeString('userContext', "1")
        $xmlWriter.WriteAttributeString('primaryGroup', "0")
        $xmlWriter.WriteAttributeString('localGroup', "0")
        #endFilterGroup Element   
        $xmlwriter.WriteEndElement()

        #unnecessary, environment specific
        If ($inObj.qmap -eq 'True')
        {
        #begin filterGroup element
        $xmlWriter.WriteStartElement('FilterGroup')
        $xmlWriter.WriteAttributeString('bool', "AND")
        $xmlWriter.WriteAttributeString('not', "0")
        $xmlWriter.WriteAttributeString('name', "$NetbiosShortName\$($inObj.Group2)")
        $xmlWriter.WriteAttributeString('sid', "$($inObj.Sid2.ToString())")
        $xmlWriter.WriteAttributeString('userContext', "1")
        $xmlWriter.WriteAttributeString('primaryGroup', "0")
        $xmlWriter.WriteAttributeString('localGroup', "0")
        #endFilterGroup Element   
        $xmlwriter.WriteEndElement()
        }
        

        #end Filters element
        $xmlWriter.WriteEndElement()

        #end drive element
        $xmlwriter.WriteEndElement()
    }

#define arrays and variables
$fileArray = New-Object -TypeName System.Collections.ArrayList
$MapArray = New-Object -TypeName System.Collections.ArrayList
$siteArray = New-Object -TypeName System.Collections.ArrayList
$xmlStuArray = New-Object -TypeName System.Collections.ArrayList
$xmlStaffArray = New-Object -TypeName System.Collections.ArrayList
#assumes dnsdomain is AD.CONTOSO.COM
$NETBiosShortName = 'AD'
$GroupsSearchBaseDN = 'OU=Groups,DC=contoso,DC=com'
$StaffGroupsSearchBaseDN = 'OU=MoreSpecificGropu,OU=Groups,DC=contoso,DC=com'
$driveCLSID = "{935D1B74-9CB8-4e3c-9914-7DD559B7A417}"
$arrayOfSiteNumbersGroups = Get-ADGroup -filter * -searchbase $StaffGroupsSearchBaseDN
$arrayOfSiteNumbers = $arrayOfSiteNumbersGroups.Name.SubString(0,4)


#Grab all of the old terrible batch files from sysvol
$files = Get-ChildItem -Path "\\$env:userdnsdomain\SysVol\$env:userdnsdomain\Policies" -filter *.bat -recurse

#filter out Site startup scripts
$filteredfiles = $files | Where-Object {$_.Name -match '<#REGEXString targeted script match#>'}



#scrape out all net use statements, ignore commented out ones
ForEach ($fileobj in $filteredfiles)
    {        
         $file = Get-Content -literalpath $($fileobj.FullName)
         #each file is an array of strings so now we need to work with each line in each file
            ForEach ($line in $file)
            {
                If (($line -match 'net use*') -AND ($line -notmatch 'rem net use*'))
                {
                    $obj = New-Object -typeName PSObject -Property @{
                    Line = $Line
                    FileName = $Fileobj.Name
                    }
                    $fileArray.Add($obj) | Out-Null
                }
            }
    }

$filteredFileArray = $fileArray | Where-Object -filter {(($_.Line -like "net use i:*") -OR ($_.line -like "net use j:*") -OR ($_.line -like "net use k:*") -OR ($_.line -like "net use q:*") -OR ($_.line -like "net use u:*") -OR ($_.line -like "net use v:*") -OR ($_.line -like "net use w:*") -OR ($_.line -like "net use x:*"))}
#iterate once per Site, site codes determine which login script to use and subsequently which security groups to apply
ForEach ($num in $arrayOfSiteNumbers)
    {
        #define new array to be used in each iteration of Site loop        
        $MapArray = New-Object -TypeName System.Collections.ArrayList
        $added = $:false

        #go through all files
            ForEach ($site in $filteredFileArray)
                {
                    #match Site number to batch file            
                    If ($num -eq $($site.FileName.SubString(0,4)))
                        {
                            $added = $:true
                            #filter out parameter from net use lines
                            If ($($Site.Line) -notmatch " /Y")
                                {
                                    $MapArray.Add($($site.Line.ToString())) | Out-Null
                                }
                            Else
                                {                        
                                    $MapArray.Add($($site.Line.ToString().SubString(0,$site.Line.ToString().Length-3))) | Out-Null
                                }
                    
                        
                        }
                }
            If ($added)
                {
                    #create new object and populate with Site number and array of files from each site
                    $siteObjArray = New-Object -typeName PSObject -Property @{
                    SiteNum = $num
                    Lines = $MapArray
                    }
                    $SiteArray.Add($SiteObjArray) | Out-Null
                }
    }

#go through each new object in the site array and clean them up, then put them in a new object format to be converted into XML
#most of below is environment specific logic but can be trimmed to only include specified scripts and paths
ForEach ($siteObj in $SiteArray)
    {
        $driveLetterArray = New-Object -TypeName System.Collections.ArrayList   
        ForEach ($lineObj in $siteObj.lines)
            {
                $lineObj = $lineObj -replace '/','\'
                $splitLine = $lineObj.Split(" ")
                $driveLetter = $splitLine[2].SubString(0,1)        
                $UNCPath = $splitLine[3]

                If (($UNCPath -match '<#Regex filter certain paths#>') -and ($UNCPath -notmatch '<#Regex filter out certain paths#>'))
                    {            
                        $SplitUNCPath = $UNCPath.SubString(1).Split("\")
                        $len = $SplitUNCPath.Length
                        $label = $SplitUNCPath[$len-1]                                                      
                        $Group =  Get-ADGroup -ldapfilter "<#Filter specific group for Item Level Target#>" -searchbase $GroupsSearchBaseDN
                        If ($driveLetterArray -contains $driveLetter)
                            {
                                $Group = Get-ADGroup -ldapfilter "<#Filter specific group for Item Level Target#>" -searchbase $GroupsSearchBaseDN
                            }
                        If ($label -eq "%Username%")
                            {
                                $label = $SplitUNCPath[$len-2]
                                $Group = Get-ADGroup -ldapfilter "<#Filter specific group for Item Level Target#>" -searchbase $GroupsSearchBaseDN
                            }                
                        $partialPath = $($SplitUNCPath[2..$($len-1)])               
                        $fixedpath = $partialPath -join  '\'                
                        $finalPath = "\\FS$($SiteObj.SiteNum)\$fixedPath"
                            $xmlObj = New-Object -typeName PSObject -Property @{
                            DriveLetter = $($driveLetter.ToUpper())
                            Path = $finalPath
                            Label = ""
                            CLSID = $driveCLSID
                            group = $Group.Name                            
                            sid = $Group.sid
                            group2 = ""
                            sid2 = ""
                            qmap = 'false'
                            name = "${DriveLetter}: $($($SiteObj.SiteNum) + " " + $label)"
                            }
                        If ($($xmlObj.Group) -like "*Students")
                            {
                                $xmlStuArray.Add($xmlObj) | Out-Null
                            }
                        Else
                            {
                                $xmlStaffArray.Add($xmlObj) | Out-Null
                            }
                
                    }
                If (($UNCPath -match '<#Regex filter certain paths#>') -and ($UNCPath -match '<#Regex filter secondary creteria of certain paths#>'))
                    {            
                        $SplitUNCPath = $UNCPath.SubString(1).Split("\")
                        $len = $SplitUNCPath.Length
                        $label = $SplitUNCPath[$len-1]
                        $Group = Get-ADGroup -filter {name -eq "<#Filter specific group for Item Level Target#>"} -searchbase $GroupsSearchBaseDN
                        $Group2 = Get-ADGroup -ldapfilter "<#Add second filter group#>" -searchbase $GroupsSearchBaseDN                  
                        $partialPath = $($SplitUNCPath[2..$($len-1)])               
                        $fixedpath = $partialPath -join  '\'                
                        $finalPath = "\\FS$($SiteObj.SiteNum)\$fixedPath"
                            $xmlObj = New-Object -typeName PSObject -Property @{
                            DriveLetter = $($driveLetter.ToUpper())
                            Path = $finalPath
                            Label = ""
                            CLSID = $driveCLSID
                            group = $Group.Name
                            sid = $Group.sid
                            group2 = $Group2.Name
                            sid2 = $group2.sid
                            qmap = 'True'
                            name = "${DriveLetter}: $($($SiteObj.SiteNum) + " " + $label)"
                            }
                        $xmlStaffArray.Add($xmlObj) | Out-Null
                    }
                    $driveLetterArray.Add($driveLetter) | Out-Null
        
        
            }
    }

#generate the XML with the new XML arrays
$pathArray = "$PSScriptRoot\XMLStu.xml","$PSScriptRoot\XMLStaff.xml"
ForEach ($path in $pathArray)
    {
        
        $XmlWriter = New-Object -typeName System.XMl.XmlTextWriter($Path,$Null)
        #xml setup
        $xmlWriter.Formatting = 'Indented'
        $xmlWriter.Indentation = 1
        $XmlWriter.IndentChar = "`t"
        $xmlWriter.WriteStartDocument() 
        $xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")
        $xmlWriter.WriteStartElement('Drives')
        If ($path -like "*Stu.xml")
            {
                
                ForEach ($element in $xmlStuArray)
                    {
                        Create-XML $element  
                    }
            }
        Else
            {
                
                ForEach ($element in $xmlStaffArray)
                    {
                        Create-XML $element  
                    }
            }
            
        #cleanup and close xml stream
        $xmlWriter.WriteEndElement()
        $xmlWriter.Flush()
        $xmlWriter.Close()

    }



