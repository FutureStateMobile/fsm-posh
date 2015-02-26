function Invoke-Nunit ( [string] $targetAssembly, [string] $outputDir, [string] $runCommand, [string] $testAssemblyRootNamespace ) {

    if ( $includeCoverage ){
        Invoke-NUnitWithCoverage $targetAssembly $outputDir $runCommand $testAssemblyRootNamespace
    } else {
        $fileName = Get-TestFileName $outputDir $runCommand

        $xmlFile = "$fileName-TestResults.xml"
        $txtFile = "$fileName-TestResults.txt"
        
        exec { nunit-console.exe $targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0 } ($msgs.error_tests_failed -f $runCommand)
    }    
}

function Invoke-NUnitWithCoverage ( [string] $targetAssembly, [string] $outputDir, [string] $runCommand, [string] $testAssemblyRootNamespace){
    $fileName = Get-TestFileName $outputDir $runCommand

    $xmlFile = "$fileName-TestResults.xml"
    $txtFile = "$fileName-TestResults.txt"
    $coverageFile = "$fileName-CoverageResults.dcvr"

    $coverageConfig = (Get-TestFileName "$buildFilesDir\coverageRules" $testAssemblyRootNamespace) + ".config"
    # /AttributeFilters="Test;TestFixture;SetUp;TearDown"
    Write-Host "dotcover.exe cover $coverageConfig /TargetExecutable=$nunitRunnerDir\nunit-console.exe /TargetArguments=$targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0 /Output=$coverageFile /ReportType=html /Filters=$coverageFilter"
    exec{ dotcover.exe cover $coverageConfig /TargetExecutable=$nunitRunnerDir\nunit-console.exe /TargetArguments="$targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0" /Output=$coverageFile /ReportType=html } ($msgs.error_coverage_failed -f $runCommand)
    $msgs.msg_teamcity_importdata -f 'dotNetCoverage', 'dotcover', $coverageFile
}

function Invoke-XUnit ([string] $targetAssembly, [string] $outputDir, [string] $runCommand){
        if ( $includeCoverage ){
        Invoke-XUnitWithCoverage $targetAssembly $outputDir $runCommand
    } else {
        $fileName = Get-TestFileName $outputDir $runCommand
        $xmlFile = "$fileName-TestResults.xml"
        $txtFile = "$fileName-TestResults.txt"
        
        exec {xunit.console.exe $targetAssembly /xml $xmlFile}
    }
}

function Invoke-XUnitWithCoverage  ([string] $targetAssembly, [string] $outputDir, [string] $runCommand){
    $fileName = Get-TestFileName $outputDir $runCommand

    $xmlFile = "$fileName-TestResults.xml"
    $txtFile = "$fileName-TestResults.txt"
    $coverageFile = "$fileName-CoverageResults.dcvr"

    exec{ dotcover.exe cover /TargetExecutable=$xunitRunnerDir\xunit.console.exe /TargetArguments="$targetAssembly /xml $xmlFile" /Output=$coverageFile /ReportType=html} ($msgs.error_coverage_failed -f $runCommand)
    $msgs.msg_teamcity_importdata -f 'dotNetCoverage', 'dotcover', $coverageFile
}

function Invoke-SpecFlow ( [string] $testProjectFile, [string] $outputDir, [string] $runCommand ) {
    $fileName = Get-TestFileName $outputDir $runCommand

    $xmlFile = "$fileName-TestResults.xml"
    $txtFile = "$fileName-TestResults.txt"
    $htmlFile = "$fileName.html"

    exec { specflow.exe nunitexecutionreport $testProjectFile /xmlTestResult:$xmlFile /testOutput:$txtFile /out:$htmlFile } ($msgs.error_specflow_failed -f $fileName)
}

function Get-TestFileName ( [string] $outputDir, [string] $runCommand ){
    $fileName = $runCommand -replace "\.", "-"
    return "$outputDir\$fileName"
}

function Invoke-GruntTests ([string] $rootPath){
        push-location $rootPath

        # We're using npm install because of the nested node_modules path issue on Windows.
        #There's a bug in karma whereby it doesn't kill the IE instance it creates.
        exec { npm install grunt-cli -g}
        exec { npm install karma-cli -g }
        exec { npm install --save-dev}
        exec { grunt test}

        pop-location
}

function Invoke-GruntMinification {

}

function Invoke-EntityFrameworkMigrations ([string] $targetAssembly, [string] $startupDirectory, [string] $connectionString, [string] $databaseName, [switch] $dropDB){
    if($dropDB.IsPresent){ 
        Write-Host "Dropping current database."
        try{
            Invoke-SqlStatement "DROP DATABASE $databaseName" $connectionString -useMaster | Out-Null
        } catch [Exception] {
            Write-Warning $_
        }

    }

    Write-Host "`nRunning Entity Framework Migrations."
    exec {migrate.exe $targetAssembly /StartUpDirectory=$startupDirectory /connectionString=$connectionString /connectionProviderName="System.Data.SqlClient"}
}

function Get-WarningsFromMSBuildLog {
    Param(
        [parameter(Mandatory=$true)] [alias("f")] $FilePath,
        [parameter()] [alias("ro")] $rawOutputPath,
        [parameter()][alias("o")] $htmlOutputPath
    )
     
    $warnings = @(Get-Content -ErrorAction Stop $FilePath |       # Get the file content
                    Where {$_ -match '^.*warning CS.*$'} |        # Extract lines that match warnings
                    %{ $_.trim() -replace "^s*d+>",""  } |        # Strip out any project number and caret prefixes
                    sort-object | Get-Unique -asString)           # remove duplicates by sorting and filtering for unique strings
     
    $count = $warnings.Count
     
    # raw output
    Write-Host "MSBuild Warnings - $count warnings ==================================================="
    $warnings | % { Write-Host " * $_" }
     
    #TeamCity output
    $msgs.msg_teamcity_buildstatus -f "{build.status.text}, Build warnings: $count"
    $msgs.msg_teamcity_buildstatisticvalue -f 'buildWarnings', $count
     
    # file output
    if( $rawOutputPath ){
        $stream = [System.IO.StreamWriter] $RawOutputPath
        $stream.WriteLine("Build Warnings")
        $stream.WriteLine("====================================")
        $stream.WriteLine("")
        $warnings | % { $stream.WriteLine(" * $_")}
        $stream.Close()
    }
     
    # html report output
    if( $htmlOutputPath -and $rawOutputPath ){
        $stream = [System.IO.StreamWriter] $htmlOutputPath
        $stream.WriteLine(@"
<html>
    <head>
        <style>*{margin:0;padding:0;box-sizing:border-box}body{margin:auto 10px}table{color:#333;font-family:sans-serif;font-size:.9em;font-weight:300;text-align:left;line-height:40px;border-spacing:0;border:1px solid #428bca;width:100%;margin:20px auto}thead tr:first-child{background:#428bca;color:#fff;border:none}th{font-weight:700}td:first-child,th:first-child{padding:0 15px 0 20px}thead tr:last-child th{border-bottom:2px solid #ddd}tbody tr:hover{background-color:#f0fbff}tbody tr:last-child td{border:none}tbody td{border-bottom:1px solid #ddd}td:last-child{text-align:left;padding-left:10px}</style>
</head>
<body>
"@)
        $stream.WriteLine("<table>")
        $stream.WriteLine(@"
<thead>
    <tr>
        <th colspan="2">Build Warnings</th>
    </tr>
    <tr>
        <th>#</th>
        <th>Message</th>
    </tr>
</thead>
<tbody>
"@)
        $warnings | % {$i=1} { $stream.WriteLine("<tr><td>$i</td><td>$_</td></tr>"); $i++ }
        $stream.WriteLine("</tbody></table>")
        $stream.WriteLine("</body></html>")
        $stream.Close()
    }
}