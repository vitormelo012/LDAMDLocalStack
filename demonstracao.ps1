# Script de Demonstração - LocalStack + Flutter
# Roteiro automatizado para apresentação em sala

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("setup", "listar", "verificar", "baixar", "limpar", "completo")]
    [string]$Acao = "completo"
)

$ENDPOINT = "http://localhost:4566"
$BUCKET = "shopping-images"

Write-Host "[DEMO] DEMONSTRACAO LOCALSTACK + FLUTTER" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host ""

function Passo1-Infraestrutura {
    Write-Host "[1] PASSO 1: INFRAESTRUTURA" -ForegroundColor Yellow
    Write-Host "Verificando se LocalStack esta rodando..." -ForegroundColor White
    
    try {
        $containers = docker ps --filter "name=localstack-s3" --format "{{.Status}}"
        
        if ($containers -match "Up") {
            Write-Host "[OK] LocalStack esta rodando!" -ForegroundColor Green
            Write-Host "Status: $containers" -ForegroundColor Gray
            Write-Host ""
        } else {
            throw "Container nao encontrado"
        }
    } catch {
        Write-Host "[ERRO] LocalStack nao esta rodando!" -ForegroundColor Red
        Write-Host "Execute primeiro: docker-compose up -d" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

function Passo2-Configuracao {
    Write-Host "[2] PASSO 2: CONFIGURACAO" -ForegroundColor Yellow
    Write-Host "Listando buckets S3..." -ForegroundColor White
    Write-Host ""
    
    # Verificar se AWS CLI está instalado
    try {
        $awsVersion = aws --version 2>&1
        Write-Host "[OK] AWS CLI detectado: $awsVersion" -ForegroundColor Gray
    } catch {
        Write-Host "[ERRO] AWS CLI nao esta instalado ou nao esta no PATH!" -ForegroundColor Red
        Write-Host "Instale em: https://aws.amazon.com/cli/" -ForegroundColor Yellow
        Write-Host "Ou feche e reabra o terminal se acabou de instalar" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    
    $buckets = aws --endpoint-url=$ENDPOINT s3 ls
    
    if ($buckets -match $BUCKET) {
        Write-Host "[OK] Bucket '$BUCKET' encontrado!" -ForegroundColor Green
        Write-Host $buckets
    } else {
        Write-Host "❌ Bucket '$BUCKET' não encontrado!" -ForegroundColor Red
        Write-Host "Criando bucket..." -ForegroundColor Yellow
        aws --endpoint-url=$ENDPOINT s3 mb s3://$BUCKET
    }
    Write-Host ""
}

function Passo3-ConteudoInicial {
    Write-Host "[3] PASSO 3: CONTEUDO ATUAL DO BUCKET" -ForegroundColor Yellow
    Write-Host "Listando arquivos em s3://$BUCKET/..." -ForegroundColor White
    Write-Host ""
    
    $objetos = aws --endpoint-url=$ENDPOINT s3 ls s3://$BUCKET/
    
    if ([string]::IsNullOrWhiteSpace($objetos)) {
        Write-Host "[INFO] Bucket vazio (nenhuma foto ainda)" -ForegroundColor Gray
    } else {
        Write-Host $objetos
        $count = ($objetos -split "`n").Count
        Write-Host ""
        Write-Host "[INFO] Total de fotos: $count" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Passo4-AguardarApp {
    Write-Host "[4] PASSO 4: AGUARDANDO INTERACAO NO APP" -ForegroundColor Yellow
    Write-Host "Agora:" -ForegroundColor White
    Write-Host "  1. Abra o app Flutter no celular/emulador" -ForegroundColor White
    Write-Host "  2. Crie uma nova tarefa" -ForegroundColor White
    Write-Host "  3. Tire uma foto do produto" -ForegroundColor White
    Write-Host "  4. Salve a tarefa" -ForegroundColor White
    Write-Host ""
    Write-Host "Pressione ENTER após salvar a foto no app..." -ForegroundColor Yellow
    Read-Host
    Write-Host ""
}

function Passo5-Validacao {
    Write-Host "[5] PASSO 5: VALIDACAO - FOTO NO S3" -ForegroundColor Yellow
    Write-Host "Verificando se foto foi salva no S3..." -ForegroundColor White
    Write-Host ""
    
    $objetos = aws --endpoint-url=$ENDPOINT s3 ls s3://$BUCKET/
    
    if ([string]::IsNullOrWhiteSpace($objetos)) {
        Write-Host "[ERRO] Nenhuma foto encontrada!" -ForegroundColor Red
        Write-Host "Verifique se o app está configurado corretamente" -ForegroundColor Yellow
    } else {
        Write-Host $objetos
        $count = ($objetos -split "`n").Count
        Write-Host ""
        Write-Host "[SUCESSO] $count foto(s) encontrada(s)!" -ForegroundColor Green
        
        # Pegar a ultima foto
        $ultimaFoto = ($objetos -split "`n")[-1] -replace '.*\s+(\S+)$', '$1'
        
        Write-Host ""
        Write-Host "[INFO] Detalhes da ultima foto:" -ForegroundColor Cyan
        aws --endpoint-url=$ENDPOINT s3api head-object --bucket $BUCKET --key $ultimaFoto.Trim() | ConvertFrom-Json | Format-List
    }
    Write-Host ""
}

function BaixarFoto {
    Write-Host "[DOWNLOAD] BAIXAR FOTO DO S3" -ForegroundColor Yellow
    
    $objetos = aws --endpoint-url=$ENDPOINT s3 ls s3://$BUCKET/
    
    if ([string]::IsNullOrWhiteSpace($objetos)) {
        Write-Host "[ERRO] Nenhuma foto para baixar!" -ForegroundColor Red
        return
    }
    
    $ultimaFoto = ($objetos -split "`n")[-1] -replace '.*\s+(\S+)$', '$1'
    $ultimaFoto = $ultimaFoto.Trim()
    
    $destino = ".\foto_demonstracao.jpg"
    
    Write-Host "Baixando: $ultimaFoto" -ForegroundColor White
    aws --endpoint-url=$ENDPOINT s3 cp s3://$BUCKET/$ultimaFoto $destino
    
    if (Test-Path $destino) {
        Write-Host "[OK] Foto baixada: $destino" -ForegroundColor Green
        Write-Host "Abrindo foto..." -ForegroundColor White
        Start-Process $destino
    }
    Write-Host ""
}

function LimparBucket {
    Write-Host "[LIMPAR] LIMPAR BUCKET" -ForegroundColor Yellow
    Write-Host "Deletando todas as fotos de s3://$BUCKET/..." -ForegroundColor White
    
    $confirm = Read-Host "Tem certeza? (s/N)"
    
    if ($confirm -eq 's' -or $confirm -eq 'S') {
        aws --endpoint-url=$ENDPOINT s3 rm s3://$BUCKET/ --recursive
        Write-Host "[OK] Bucket limpo!" -ForegroundColor Green
    } else {
        Write-Host "[CANCELADO] Operacao cancelada" -ForegroundColor Red
    }
    Write-Host ""
}

function MostrarEstatisticas {
    Write-Host "[STATS] ESTATISTICAS" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    $objetos = aws --endpoint-url=$ENDPOINT s3 ls s3://$BUCKET/
    
    if ([string]::IsNullOrWhiteSpace($objetos)) {
        Write-Host "Total de fotos: 0" -ForegroundColor White
    } else {
        $count = ($objetos -split "`n").Count
        Write-Host "Total de fotos: $count" -ForegroundColor White
        
        # Calcular tamanho total
        $lines = $objetos -split "`n"
        $tamanhoTotal = 0
        foreach ($line in $lines) {
            if ($line -match '\s+(\d+)\s+') {
                $tamanhoTotal += [int]$matches[1]
            }
        }
        
        $tamanhoMB = [math]::Round($tamanhoTotal / 1MB, 2)
        Write-Host "Tamanho total: $tamanhoMB MB" -ForegroundColor White
    }
    Write-Host ""
}

# Executar ações baseado no parâmetro
switch ($Acao) {
    "setup" {
        Passo1-Infraestrutura
        Passo2-Configuracao
    }
    "listar" {
        Passo1-Infraestrutura
        Passo3-ConteudoInicial
        MostrarEstatisticas
    }
    "verificar" {
        Passo1-Infraestrutura
        Passo5-Validacao
    }
    "baixar" {
        Passo1-Infraestrutura
        BaixarFoto
    }
    "limpar" {
        Passo1-Infraestrutura
        LimparBucket
    }
    "completo" {
        Passo1-Infraestrutura
        Passo2-Configuracao
        Passo3-ConteudoInicial
        Passo4-AguardarApp
        Passo5-Validacao
        MostrarEstatisticas
        
        Write-Host "[SUCESSO] DEMONSTRACAO COMPLETA!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Opcoes adicionais:" -ForegroundColor Cyan
        Write-Host "  - Baixar foto: .\demonstracao.ps1 -Acao baixar" -ForegroundColor White
        Write-Host "  - Limpar bucket: .\demonstracao.ps1 -Acao limpar" -ForegroundColor White
        Write-Host "  - Ver estatísticas: .\demonstracao.ps1 -Acao listar" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "[OK] Script finalizado!" -ForegroundColor Green
