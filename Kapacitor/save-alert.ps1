Function Get-Hash {
    param($string)
    $hash = [System.Security.Cryptography.HashAlgorithm]::Create("sha256").ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($string))
    $result = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    return $result
}

$directory = '/etc/kapacitor/tcw-slack/alerts/'
$alertData = Read-Host | ConvertFrom-Json
$fileName = $directory + $(Get-Hash $alertData.id) + "-$($alertData.level).json"
$alertData | ConvertTo-Json -Depth 5 | Out-File $fileName -Force
