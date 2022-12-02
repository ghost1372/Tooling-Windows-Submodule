Param (    
    [Parameter(HelpMessage = "The full path of the csproj to generated references to.", Mandatory = $true)] 
    [string]$projectPath,

    [Parameter(HelpMessage = "A path to a .props file where generated content should be saved to.", Mandatory = $true)] 
    [string]$outputPath,

    [Parameter(HelpMessage = "The path to the template used to generate the props file.")] 
    [string]$templatePath = "$PSScriptRoot/MultiTargetAwareProjectReference.props.template",

    [Parameter(HelpMessage = "The path to the props file that contains the default MultiTarget values.")] 
    [string]$multiTargetDefaultPropsPath = "$PSScriptRoot/Defaults.props",

    [Parameter(HelpMessage = "The placeholder text to replace when inserting the project file name into the template.")] 
    [string]$projectFileNamePlaceholder = "[ProjectFileName]",

    [Parameter(HelpMessage = "The placeholder text to replace when inserting the project path into the template.")] 
    [string]$projectRootPlaceholder = "[ProjectRoot]"
)

$relativeProjectPath = (Resolve-Path -Path $projectPath);
$templateContents = Get-Content -Path $templatePath;

# Insert csproj file name.
$csprojFileName = [System.IO.Path]::GetFileName($relativeProjectPath);
$templateContents = $templateContents -replace [regex]::escape($projectFileNamePlaceholder), $csprojFileName;

# Insert project directory
$projectDirectory = [System.IO.Path]::GetDirectoryName($relativeProjectPath);
$templateContents = $templateContents -replace [regex]::escape($projectRootPlaceholder), $projectDirectory;


function LoadMultiTargetsFrom([string] $path) {
    $fileContents = "";

    # If file does not exist
    if ((Test-Path $path) -eq $false)
    {
        # Load defaults
        $fileContents = Get-Content $multiTargetDefaultPropsPath -ErrorAction Stop;
    }
    else 
    {
        # Load requested file
        $fileContents = Get-Content $path -ErrorAction Stop;
    }

    # Parse file contents
	$regex = Select-String -Pattern '<MultiTarget>(.+?)<\/MultiTarget>' -InputObject $fileContents;

	if ($null -eq $regex -or $null -eq $regex.Matches -or $null -eq $regex.Matches.Groups -or $regex.Matches.Groups.Length -lt 2) {
		Write-Error "Couldn't get MultiTarget property from $path";
		exit(-1);
	}

	return $regex.Matches.Groups[1].Value;
}

# Load multitarget preferences for project
$multiTargets = LoadMultiTargetsFrom("$projectDirectory\MultiTargets.props");


$templateContents = $templateContents -replace [regex]::escape("[CanTargetWasm]"), $multiTargets.Contains("wasm").ToString();

# Save to disk
Set-Content -Path $outputPath -Value $templateContents;