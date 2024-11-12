```markdown
# TCW Alert Sender via Amazon SES

  

## Descrição

Este script em PowerShell automatiza o envio de mensagens de alerta do **TCW** (Total Cloud Watch) por e-mail utilizando o **Amazon SES (Simple Email Service)**. Ele lê alertas de arquivos JSON em um diretório específico, processa esses alertas, gera anexos em formato XML quando necessário e envia notificações por e-mail para os destinatários configurados.

## Índice
- [Instalação](#instalação)
- [Configuração](#configuração)
  - [Arquivo `appsettings.json`](#arquivo-appsettingsjson)
- [Uso](#uso)
- [Estrutura de Diretórios](#estrutura-de-diretórios)
- [Logs](#logs)
- [Segurança](#segurança)
- [Exemplos](#exemplos)
- [Licença](#licença)


## Instalação

1. **Clone ou Baixe o Repositório:**

   ```bash
   git clone repourl
   ```

   Ou baixe o ZIP e extraia o conteúdo na pasta desejada.

2. **Navegue até o Diretório do Script:**

   ```powershell
   cd \TCWEmailSender
   ```

## Configuração

### Arquivo `appsettings.json`

O script utiliza um arquivo de configuração `appsettings.json` para armazenar parâmetros essenciais, evitando a necessidade de hardcoding de informações sensíveis no código.

1. **Crie o Arquivo `appsettings.json`:**

   Na mesma pasta onde está o script (`TCWEmailSender.ps1`), crie um arquivo chamado `appsettings.json`.

2. **Estrutura do `appsettings.json`:**

   ```json
   {
     "BaseDir": "C:\\Users\\mateus.paape\\Documents\\tcw-slack\\tcw-slack",
     "SMTP": {
       "Server": "email-smtp.sa-east-1.amazonaws.com",
       "Port": 587,
       "Username": "SEU_USUARIO_SMTP",
       "Password": "SUA_SENHA_SMTP",
       "FromEmail": "tcloudwatch@totvs.com.br",
       "ToEmail": "@totvs.com.br,@totvs.com.br"
     },
     "FieldName": {
       "field": "lock_tree" // Substitua conforme necessário
     },
     "LogFiles": {
       "Standard": "logs/standard.log",
       "Error": "logs/error.log"
     }
   }
   ```

   **Notas:**

   - **BaseDir:** Diretório base onde o script operará. Ajuste conforme necessário.
   - **SMTP:**
     - **Server:** Endpoint SMTP do Amazon SES.
     - **Port:** Porta utilizada (geralmente 587).
     - **Username:** Sua AWS SMTP Username.
     - **Password:** Sua AWS SMTP Password.
     - **FromEmail:** Endereço de e-mail verificado no Amazon SES.
     - **ToEmail:** Lista de destinatários separados por vírgula.
   - **FieldName:** Campo específico usado no processamento do alerta (ajuste conforme seu JSON de alerta).
   - **LogFiles:**
     - **Standard:** Caminho para o arquivo de log padrão.
     - **Error:** Caminho para o arquivo de log de erros.

3. **Segurança das Credenciais:**

   - **Proteja o `appsettings.json`:**
     - **Permissões de Arquivo:** Configure as permissões do arquivo para que apenas usuários autorizados possam lê-lo.
     - **Controle de Versão:** Adicione `appsettings.json` ao seu `.gitignore` para evitar que credenciais sensíveis sejam versionadas.

## Uso

1. **Execute o Script:**

   Abra o PowerShell com permissões adequadas e execute o script:

   ```powershell
   .\TCWEmailSender.ps1
   ```

2. **Monitoramento:**

   - O script ficará em execução contínua, verificando a pasta de alertas a cada 5 segundos.
   - Logs serão registrados nos arquivos especificados em `appsettings.json`.

## Estrutura de Diretórios

Certifique-se de que a seguinte estrutura de diretórios exista dentro do `BaseDir`:

```
BaseDir/
│
├── alerts/
│   └── *.json            # Arquivos de alerta a serem processados
│
├── history/
│   ├── In progress/
│   │   └── *.json        # Alertas em andamento
│   └── finished/
│       └── *.json        # Alertas finalizados
│
├── tmp/
│   └── *.xml             # Arquivos XML temporários
│
└── logs/
    ├── standard.log      # Logs padrão
    └── error.log         # Logs de erro
```

**Notas:**

- **alerts/**: Diretório onde os arquivos de alerta JSON são colocados para serem processados.
- **history/In progress/**: Diretório para armazenar o histórico dos alertas que estão sendo processados.
- **history/finished/**: Diretório para armazenar o histórico dos alertas que foram processados com sucesso.
- **tmp/**: Diretório para armazenar arquivos XML temporários gerados durante o processamento.
- **logs/**: Diretório para armazenar logs de operações padrão e de erro.

## Logs

O script registra suas operações em dois arquivos de log:

- **Logs Padrão (`standard.log`):** Informações sobre operações bem-sucedidas.
- **Logs de Erro (`error.log`):** Informações sobre falhas e exceções.

**Rotação de Logs:**

- Quando o tamanho do log excede aproximadamente 9 MB (`9537520` bytes), o script mantém apenas as últimas 100 linhas para evitar o crescimento excessivo dos arquivos de log.

## Segurança

- **Proteção de Credenciais:**
  - **Não compartilhe** o arquivo `appsettings.json` que contém suas credenciais SMTP.
  - Utilize métodos seguros para armazenar e gerenciar suas credenciais, como **Azure Key Vault**, **AWS Secrets Manager** ou **variáveis de ambiente**.

- **Permissões de Diretórios e Arquivos:**
  - Configure permissões restritas para os diretórios e arquivos utilizados pelo script para evitar acessos não autorizados.

## Exemplos

### Estrutura de um Arquivo de Alerta JSON (`alert.json`)

```json
{
  "id": "unique-alert-id",
  "level": "critical",
  "time": "2024-11-12T05:15:10Z",
  "message": "Descrição do alerta",
  "data": {
    "series": {
      "tags": {
        "alertName": "CPUUsageHigh",
        "host": "NSN16UCSD9719.dbcloud.local"
      },
      "columns": ["lock_tree"],
      "values": ["<tree-data>"]
    }
  }
}
```

### Executando o Script

Após configurar o `appsettings.json` e garantir que a estrutura de diretórios está correta:

1. **Coloque os arquivos de alerta no diretório `alerts/`.**
2. **Execute o script:**

   ```powershell
   .\TCWEmailSender.ps1
   ```

3. **Verifique os logs para confirmar o envio dos e-mails e movimentação dos arquivos de histórico.**

 

## Licença

Este projeto está licenciado sob a Licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

 