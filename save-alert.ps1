
$configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "appsettings.json"
# Verifica se o arquivo de configuração existe
if (-not (Test-Path $configFilePath)) {
    Write-Error "Arquivo de configuração 'appsettings.json' não encontrado no diretório do script."
    exit 1
}

# Carrega as configurações do arquivo JSON
$configContent = Get-Content -Path $configFilePath -Raw
$config = $configContent | ConvertFrom-Json



Function Get-Hash {
    param($string)
    $hash = [System.Security.Cryptography.HashAlgorithm]::Create("sha256").ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($string))
    $result = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    return $result
}

$directory = '$config.BaseDir/alerts/'
$alertData = Read-Host | ConvertFrom-Json
$fileName = $directory + $(Get-Hash $alertData.id) + "-$($alertData.level).json"
$alertData | ConvertTo-Json -Depth 5 | Out-File $fileName -Force
