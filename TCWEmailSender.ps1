<#
    Mateus Paape e Henrique Queiroz
    11/2024

    Realizar o envio das mensagens de alerta do TCW por e-mail via Amazon SES.
#>


$configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "appsettings.json"
# Verifica se o arquivo de configuração existe
if (-not (Test-Path $configFilePath)) {
    Write-Error "Arquivo de configuração 'appsettings.json' não encontrado no diretório do script."
    exit 1
}

# Carrega as configurações do arquivo JSON
$configContent = Get-Content -Path $configFilePath -Raw
$config = $configContent | ConvertFrom-Json

$BaseDir = $config.BaseDir
Set-Location -Path $BaseDir
$smtpServer   = $config.SMTP.Server
$smtpPort     = $config.SMTP.Port
$smtpUsername = $config.SMTP.Username
$smtpPassword = $config.SMTP.Password
$fromEmail    = $config.SMTP.FromEmail
$toEmail      = $config.SMTP.ToEmail
$field_name   = $config.FieldName.field
$logFile      = Join-Path -Path $BaseDir -ChildPath $config.LogFiles.Standard
$logFileError = Join-Path -Path $BaseDir -ChildPath $config.LogFiles.Error


#region Functions
Function Get-Hash {
    param($string)
    $hash = [System.Security.Cryptography.HashAlgorithm]::Create("sha256").ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($string))

    $result = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    return $result
}

Function Add-LogRecord {
    <#
    .SYNOPSIS
       Salva os logs.
    #>
    param($string, $file)
    $currentDate = (get-date).ToString("yyyy-MM-dd HH:mm:ss")
    $string = "$currentDate - $string"
    if ($file -eq "error") {
        $logFile = $logFileError
    }
    $size = (Get-Item $logFile).Length -gt 9537520
    if ($size -eq $true) {
        Get-Content $logFile | Select-Object -Last 100 | Out-File -Encoding utf8 $logFile -Force
    }
    $string | Out-File -Encoding utf8 $logFile -Append
    return ($? -eq $true)
}

Function Send-EmailAlert {
    param (
        $Subject,
        $Body,
        $AttachmentPath = $null
    )

    try {
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = $fromEmail
        $mail.To.Add($toEmail)
        $mail.Subject = $Subject
        $mail.Body = $Body
        $mail.IsBodyHtml = $false  # Defina como $true se quiser enviar o e-mail em HTML

        if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
            $attachment = New-Object System.Net.Mail.Attachment($AttachmentPath)
            $mail.Attachments.Add($attachment)
        }

        $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUsername, $smtpPassword)
        $smtp.Send($mail)
        $mail.Dispose()

        Add-LogRecord -string "E-mail enviado com sucesso para $toEmail"
        return $true
    }
    catch {
        Add-LogRecord -string "Falha ao enviar e-mail: $_" -file "error"
        return $false
    }
}

Function New-AlertMessage {
    param ($Alert)
    $id = Get-Hash $Alert.id
    $existFile = Test-Path "$BaseDir/history/In progress/$id.json"
    if ($existFile -eq $true) {
        Write-Warning "$(Get-Date) $id - Alerta já enviado anteriormente"
        return $false
    }
    try {
        $sendMessage = $true
        $id = Get-Hash $Alert.id
        Write-Host "$(Get-Date) $id - Analisando columns, values"
        $alertProp = [PSCustomObject]@{}
        $emailMessage = $Alert.data.series.tags
        $emailMessage | Add-Member -NotePropertyName time -NotePropertyValue $Alert.time -Force
        $emailMessage | Add-Member -NotePropertyName message -NotePropertyValue $Alert.message -Force
        $emailMessage | Add-Member -NotePropertyName severity -NotePropertyValue $Alert.level -Force
        $index = 0
        $Alert.data.series.columns | ForEach-Object -Process {
            $alertProp | Add-Member -NotePropertyName $_ -NotePropertyValue $Alert.data.series.values[$index]
            $index++
        }
    }
    catch {
        $sendMessage = $false
        Write-Error "$(Get-Date) $id - Falha ao realizar o parsing da mensagem $id - $($Alert.message)"
        Add-LogRecord -string "Falha ao realizar o parsing da mensagem $id - $($Alert.message)" -file "error"
        Move-Item $Alert.FullName "$BaseDir/history/failures/" -Force
        return $false
    }

    try {
        $sendFile = $true
        Write-Host "$(Get-Date) $id - Gerando XML"
        if ((($alertProp.$field_name) -notmatch "alertproperties") -and ((($alertProp.$field_name).Length) -gt 0)) {
            $xml = @()
            $xml += "<?xml version='1.0' encoding='utf-8'?> <alertproperties version='1.0'>"
            $xml += $alertProp.$field_name
            $xml += "</alertproperties>"
        }
        [xml]$xmlData = $xml
        $xmlFilePath = "$BaseDir/tmp/$id-$($emailMessage.host).xml"
        $xmlData.Save($xmlFilePath)
        $alertProp | Add-Member -NotePropertyName xmlFile -NotePropertyValue $xmlFilePath -Force
    }
    catch {
        Add-LogRecord -string "Falha ao realizar o parsing do XML $id"
        $sendFile = $false
    }

    if ($sendMessage -eq $true) {
        Add-LogRecord -string "$id - Enviando alerta por e-mail"
        $emailBody = "Alerta: $($emailMessage.alertName)`nHost: $($emailMessage.host)`nMensagem: $($emailMessage.message) `nOccurredAt : $($emailMessage.time)"
        $emailSubject = "Alerta: $($emailMessage.alertName) em $($emailMessage.host)"

        # Enviando o e-mail
        $emailSent = Send-EmailAlert -Subject $emailSubject -Body $emailBody -AttachmentPath $alertProp.xmlFile

        if ($emailSent) {
            $alertObject = [ordered]@{
                Alert      = $Alert
                AlertProps = $alertProp
                Message    = $emailMessage
            }
            $alertObject | ConvertTo-Json -Depth 15 | Out-File "$BaseDir/history/In progress/$id.json" -Force
        } else {
            Move-Item $Alert.FullName "$BaseDir/history/failures/" -Force
            return $false
        }

        if ((Test-Path $alertProp.xmlFile) -eq $true) {
            Remove-Item $alertProp.xmlFile -Force
        }

        return $alertObject
    }

}


#endregion

#region Run

while ($true) {
    $alerts = Get-Item "$BaseDir/alerts/*.json" -ErrorAction SilentlyContinue

    if ($alerts) {
        $alerts = @($alerts)
        $alertOK = $alerts | Where-Object { ($_.Name -match "-OK.json") }
        $alertSend = $alerts | Where-Object { ($_.Name -notmatch "-OK.json") }

        foreach ($file in $alertSend) {
            $alert = Get-Content $file.FullName | ConvertFrom-Json
            $alert | Add-Member -NotePropertyName FullName  -NotePropertyValue $file.FullName -Force
            $level = $alert.level
            $level = $level.ToUpper()
            $action = New-AlertMessage -Alert $alert
            Remove-Item $file.FullName -Force 
        }

        foreach ($file in $alertOK) {
            $alert = Get-Content $file.FullName | ConvertFrom-Json
            $alert | Add-Member -NotePropertyName FullName  -NotePropertyValue $file.FullName -Force
            $level = $alert.level
            $level = $level.ToUpper()
            $action = New-AlertResponse -Alert $alert
            Remove-Item $file.FullName -Force
        }
    }
    Start-Sleep -Seconds 5
}

#endregion
