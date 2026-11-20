# cPanel Reseller Disk Usage Reporter

Readme: [EN](README.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.0-green.svg)](https://github.com/sr00t3d/cpanel-reseller-usage/releases)
[![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

<img width="700" src="cpanel-reseller-usage-cover.webp" alt="cPanel Reseller Disk Usage Reporter" />

**cPanel Reseller Disk Usage Reporter v2.0.0** e uma ferramenta CLI em Bash sem dependencias externas para administradores cPanel/WHM que audita o consumo real de disco (`du -sm`) de um Revendedor e todas as suas subcontas em servidores multi-particao (`/home`, `/home2`, `/home3`, ...), calculando totais em MB/GB, percentual de uso por conta, ordenacao e exportacao em tabela, JSON ou CSV.

---

## Funcionalidades

- **Resolucao Multi-Particao de Home**: localiza o diretorio real de cada subconta via `getent passwd` (com fallback para `/home`, `/home2`, `/home3`, `/home4`)
- **Zero Dependencias Externas**: usa aritmetica nativa em `awk`, dispensando a instalacao do pacote `bc`
- **Descoberta de Revendedores (`--list-resellers`)**: lista todos os revendedores unicos e a quantidade de subcontas a partir do `/etc/trueuserowners`
- **Analise e Filtros**: calcula `% Share` por subconta, ordena por `--sort size` (decrescente) ou `--sort name` e permite filtrar por `--min-mb N`
- **Simulacao Dry-Run (`--dry-run`)**: descobre contas e diretorios home sem executar `du`
- **Relatorios Multi-Formato (`-o table|json|csv`) e `--save PATH`**: imprime em stdout para pipelines ou salva em arquivo protegido com `chmod 600`

---

## Requisitos

- Servidor Linux cPanel/WHM com Bash 4+
- Utilitarios padrao (`du`, `awk`, `sort`, `getent`)
- Permissao root (ou leitura equivalente) sobre os diretorios home das subcontas

---

## Instalacao

```bash
curl -fsSLO https://raw.githubusercontent.com/sr00t3d/cpanel-reseller-usage/main/cp-reseller-usage.sh
chmod +x cp-reseller-usage.sh
```

---

## Uso

```bash
./cp-reseller-usage.sh <REVENDEDOR> [OPCOES]
./cp-reseller-usage.sh --list-resellers [OPCOES]

Opcoes:
  -r, --reseller USER     Usuario do revendedor a auditar
  --list-resellers        Lista todos os revendedores encontrados em /etc/trueuserowners
  --owners-file PATH      Caminho alternativo do arquivo trueuserowners
  --sort MODE             Ordenacao: size (padrao, decrescente) ou name (crescente)
  --min-mb N              Inclui apenas contas com consumo minimo de N MB (padrao: 0)
  --save PATH             Salva copia do relatorio em arquivo (chmod 600)
  --dry-run               Lista contas e diretorios sem executar du
  -o, --output FORMATO    Formato de saida: table (padrao), json, csv
  -q, --quiet             Suprime saida padrao (mantem erros em stderr)
  --no-color              Desativa cores ANSI
  -V, --version           Exibe a versao e encerra
  -h, --help              Exibe a ajuda e encerra
```

### Exemplos

```bash
# Listar todos os revendedores do servidor
./cp-reseller-usage.sh --list-resellers

# Inspecionar contas do revendedor sem executar du
./cp-reseller-usage.sh agencia01 --dry-run

# Auditar revendedor ordenado por maior consumo e salvar relatorio chmod 600
./cp-reseller-usage.sh agencia01 --sort size --save /root/usage-agencia01.txt

# Filtrar contas >= 500 MB com saida JSON
./cp-reseller-usage.sh agencia01 --min-mb 500 -o json

# Exportar CSV para planilhas de capacidade e faturamento
./cp-reseller-usage.sh agencia01 -o csv
```

---

## Exemplo de Saida Real

Capturado em servidor AlmaLinux 8.10 com cPanel/WHM:

### Listar revendedores (`--list-resellers`)

```text
$ ./cp-reseller-usage.sh --list-resellers --owners-file /tmp/reseller-e2e/trueuserowners --no-color

cPanel Resellers (/tmp/reseller-e2e/trueuserowners)
+----------------------+----------+
| Reseller             | Accounts |
+----------------------+----------+
| agencia01            |        3 |
| root                 |        1 |
+----------------------+----------+
```

### Saida em tabela (padrao)

```text
$ ./cp-reseller-usage.sh agencia01 --owners-file /tmp/reseller-e2e/trueuserowners --save /tmp/reseller-e2e/report.txt --no-color

cPanel Reseller Disk Usage Reporter v2.0.0
Host      : cpanel-test.local
Reseller  : agencia01
Accounts  : 3 (min-mb: 0, sort: size)
Dry-Run   : no
Status    : SUCCESS
Timestamp : 2026-11-20T06:30:16Z

+------------------+------------------------+----------+----------+--------+--------------+
| Account          | Home Directory         |       MB |       GB |  Share | Status       |
+------------------+------------------------+----------+----------+--------+--------------+
| e2e_client1      | /home/e2e_client1      |       13 |     0.01 |  68.4% | OK           |
| e2e_client2      | /home/e2e_client2      |        5 |     0.00 |  26.3% | OK           |
| percio           | /home/percio           |        1 |     0.00 |   5.3% | OK           |
+------------------+------------------------+----------+----------+--------+--------------+
TOTAL     : 19 MB (0.02 GB) across 3 account(s)
```

### Saida JSON (`-o json`)

```json
{
  "version": "2.0.0",
  "status": "SUCCESS",
  "hostname": "cpanel-test.local",
  "reseller": "agencia01",
  "owners_file": "/tmp/reseller-e2e/trueuserowners",
  "accounts_count": 3,
  "total_mb": 19,
  "total_gb": 0.02,
  "errors": 0,
  "dry_run": false,
  "timestamp": "2026-11-20T06:30:16Z",
  "accounts": [
    {"user": "e2e_client1", "home": "/home/e2e_client1", "mb": 13, "gb": 0.01, "share_pct": 68.4, "status": "OK"},
    {"user": "e2e_client2", "home": "/home/e2e_client2", "mb": 5, "gb": 0.00, "share_pct": 26.3, "status": "OK"},
    {"user": "percio", "home": "/home/percio", "mb": 1, "gb": 0.00, "share_pct": 5.3, "status": "OK"}
  ]
}
```

### Saida CSV (`-o csv`)

```csv
timestamp,reseller,user,home,mb,gb,share_pct,status
2026-11-20T06:30:16Z,"agencia01","e2e_client1","/home/e2e_client1",13,0.01,68.4,OK
2026-11-20T06:30:16Z,"agencia01","e2e_client2","/home/e2e_client2",5,0.00,26.3,OK
2026-11-20T06:30:16Z,"agencia01","percio","/home/percio",1,0.00,5.3,OK
```

---

## Licenca

Apache-2.0. Consulte [LICENSE](LICENSE) para detalhes.

## Autor

[Percio Castelo](https://perciocastelo.com.br)
